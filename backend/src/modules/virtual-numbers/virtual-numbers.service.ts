import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import * as crypto from 'crypto';
import {
  ACTIVE_VIRTUAL_NUMBER_STATUSES,
  VirtualNumberRequest,
  VirtualNumberRequestDocument,
  VirtualNumberStatus,
} from '../../database/schemas/virtual-number-request.schema';
import {
  VirtualNumberCatalog,
  VirtualNumberCatalogDocument,
  VirtualNumberService,
} from '../../database/schemas/virtual-number-catalog.schema';
import {
  VirtualNumberApp,
  VirtualNumberAppDocument,
} from '../../database/schemas/virtual-number-app.schema';
import {
  VirtualNumberProduct,
  VirtualNumberProductDocument,
} from '../../database/schemas/virtual-number-product.schema';
import {
  Provider,
  ProviderDocument,
  ProviderStatus,
  ProviderType,
} from '../../database/schemas/provider.schema';
import {
  ProfitMarginType,
  Product,
  ProductDocument,
  ProductType,
} from '../../database/schemas/product.schema';
import { Order, OrderDocument, OrderStatus } from '../../database/schemas/order.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Role } from '../../common/interfaces/role.enum';
import {
  WalletTransaction,
  WalletTransactionDocument,
  TransactionStatus,
  TransactionType,
} from '../../database/schemas/wallet-transaction.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { HEROSMS_DEFAULT_ENDPOINT } from './herosms.client';
import {
  VirtualNumberClient,
  VirtualNumberHandle,
  digitsOnly,
  extractVerificationCode,
  pickStringValue,
  readSmsText,
} from './virtual-number-client';
import {
  VIRTUAL_NUMBER_PROVIDER_TYPES,
  createVirtualNumberClient,
} from './virtual-number-clients';
import {
  resolveAppMeta,
  resolveCountryMeta,
} from './virtual-numbers-dictionary';
import { isHiddenServerName } from './fivesim.client';

/** يُخفي سيرفرات المزوّد الداخلية (virtual4، virtual21…) عن كل واجهات العرض */
function visibleOperators(
  operators?: Array<{ code: string; name: string }>,
): Array<{ code: string; name: string }> {
  return (operators ?? []).filter(
    (op) => !isHiddenServerName(op.code) && !isHiddenServerName(op.name),
  );
}

// كم من الوقت يبقى الكتالوج المخزّن صالحاً قبل إعادة جلبه من المزود
const CATALOG_TTL_MS = 6 * 60 * 60 * 1000;
// مهلة انتظار رمز التحقق: بعدها يُلغى الرقم ويُرجع المبلغ تلقائياً
const DEFAULT_WAIT_TTL_MINUTES = 20;
// بعد وصول الرمز تبقى الصفحة تعرضه هذه المدة ثم يُغلق الطلب تلقائياً
const CODE_READ_WINDOW_MS = 20 * 60 * 1000;
// وتيرة المسح الدوري: فحص الأرقام الحيّة وإنهاء المنتهية
const SWEEP_INTERVAL_MS = 60 * 1000;

// مفاتيح env البديلة حين لا يسجل مزود في لوحة الإدارة: نفس ترتيب الأنواع المعتمدة
const ENV_PROVIDER_PRESETS: Array<{
  type: ProviderType;
  label: string;
  keyVar: string;
  urlVar: string;
  defaultUrl: string;
}> = [
  {
    type: ProviderType.FIVESIM,
    label: '5sim',
    keyVar: 'FIVESIM_API_KEY',
    urlVar: 'FIVESIM_BASE_URL',
    defaultUrl: 'https://5sim.net/v1',
  },
  {
    type: ProviderType.HEROSMS,
    label: 'Hero-SMS',
    keyVar: 'HEROSMS_API_KEY',
    urlVar: 'HEROSMS_BASE_URL',
    defaultUrl: HEROSMS_DEFAULT_ENDPOINT,
  },
];

@Injectable()
export class VirtualNumbersService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(VirtualNumbersService.name);

  private sweepTimer?: ReturnType<typeof setInterval>;
  private sweepKickoffTimer?: ReturnType<typeof setTimeout>;
  private isSweeping = false;

  constructor(
    @InjectModel(VirtualNumberRequest.name)
    private readonly requestModel: Model<VirtualNumberRequestDocument>,
    @InjectModel(VirtualNumberCatalog.name)
    private readonly catalogModel: Model<VirtualNumberCatalogDocument>,
    @InjectModel(VirtualNumberApp.name)
    private readonly appModel: Model<VirtualNumberAppDocument>,
    @InjectModel(VirtualNumberProduct.name)
    private readonly productModel: Model<VirtualNumberProductDocument>,
    // خدمة الأرقام اليدوية هي منتج متجر (type=manual) بلا تطبيق متجر: تُحقن
    // بمسمى مستقل لأن productModel محجوز لمنتجات الدول (VirtualNumberProduct)
    @InjectModel(Product.name)
    private readonly manualServiceModel: Model<ProductDocument>,
    @InjectModel(Order.name)
    private readonly orderModel: Model<OrderDocument>,
    @InjectModel(Provider.name)
    private readonly providerModel: Model<ProviderDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    @InjectModel(WalletTransaction.name)
    private readonly transactionModel: Model<WalletTransactionDocument>,
    private readonly notificationsService: NotificationsService,
    private readonly configService: ConfigService,
  ) {}

  onModuleInit() {
    // المؤقّتات unref فلا تُبقي العملية حيّة ولا تُعلّق اختبارات vitest
    this.sweepKickoffTimer = setTimeout(() => {
      void this.runSweep().catch(() => undefined);
    }, 20_000);
    this.sweepKickoffTimer.unref?.();
    this.sweepTimer = setInterval(() => {
      void this.runSweep().catch(() => undefined);
    }, SWEEP_INTERVAL_MS);
    this.sweepTimer.unref?.();
  }

  onModuleDestroy() {
    if (this.sweepTimer) clearInterval(this.sweepTimer);
    if (this.sweepKickoffTimer) clearTimeout(this.sweepKickoffTimer);
  }

  // ===========================================================================
  // المزود والموصل
  // ===========================================================================

  /**
   * مزود الأرقام الوهمية: سجل Provider مفعّل من أنواع الأرقام (5sim أو Hero-SMS،
   * تديره الإدارة من شاشة المزودين)، أو مفاتيح env عند عدم وجود سجل بعد.
   * يُقدَّم ما حالته online كي لا يُوجَّه العميل إلى مزود متعطل والآخر سليم.
   */
  private async resolveProvider(): Promise<ProviderDocument> {
    const activeFilter = {
      providerType: { $in: VIRTUAL_NUMBER_PROVIDER_TYPES },
      isActive: { $ne: false },
    };
    const provider =
      (await this.providerModel.findOne({
        ...activeFilter,
        status: ProviderStatus.ONLINE,
      })) ?? (await this.providerModel.findOne(activeFilter));
    if (provider) return provider;

    const configured = await this.providerModel.findOne({
      providerType: { $in: VIRTUAL_NUMBER_PROVIDER_TYPES },
    });
    if (configured) {
      // السجل موجود لكنه موقوف: اللوحة هي المرجع ولا يُلتف عليها بمفاتيح env
      throw new BadRequestException(
        'خدمة الأرقام الوهمية متوقفة حالياً، ولم يتم خصم أي مبلغ من رصيدك',
      );
    }

    const fromEnv = this.buildEnvProvider();
    if (fromEnv) return fromEnv;

    throw new BadRequestException(
      'لم يتم إعداد مزود الأرقام الوهمية بعد؛ تواصل مع الإدارة',
    );
  }

  /** مزود مؤقت غير محفوظ من env: يكفي لتشغيل الميزة قبل تسجيله في اللوحة */
  private buildEnvProvider(): ProviderDocument | null {
    for (const preset of ENV_PROVIDER_PRESETS) {
      const apiKey = (
        this.configService.get<string>(preset.keyVar) || ''
      ).trim();
      if (!apiKey) continue;

      const baseUrl =
        (this.configService.get<string>(preset.urlVar) || '').trim() ||
        preset.defaultUrl;

      return {
        _id: new Types.ObjectId(),
        name: `${preset.label} (env)`,
        baseUrl,
        apiKey,
        providerType: preset.type,
        status: ProviderStatus.ONLINE,
        balance: 0,
        profitMarginType: ProfitMarginType.PERCENTAGE,
        profitMarginValue: 25,
        isActive: true,
        headers: {},
        lastError: '',
      } as unknown as ProviderDocument;
    }
    return null;
  }

  private clientFor(provider: ProviderDocument): VirtualNumberClient {
    // المصنع يقرأ نوع المزود (أو اسمه/رابطه) فيختار بروتوكول 5sim أو Hero-SMS
    return createVirtualNumberClient({
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      providerType: provider.providerType,
      name: provider.name,
    });
  }

  /** سعر البيع من تكلفة المزود وفق هامش ربح المزود نفسه (نفس قاعدة بقية المنتجات) */
  private computeSalePrice(
    cost: number,
    marginType: ProfitMarginType,
    marginValue: number,
  ): number {
    const safeCost = Number(cost) || 0;
    const margin = Number(marginValue) || 0;
    const price =
      marginType === ProfitMarginType.FIXED
        ? safeCost + margin
        : safeCost * (1 + margin / 100);
    // أرقام التحقق رخيصة (بضع مئات من الدولار): نقرب لأقرب سنت لأعلى حتى لا يصير الربح صفراً
    return Math.ceil(price * 100) / 100;
  }

  // ===========================================================================
  // الكتالوج (الخدمات والدول والأسعار)
  // ===========================================================================

  /**
   * خيارات الأرقام المعروضة للعميل: تُقرأ من التخزين المحلي وإن تجاوز مهلته،
   * ويُجلب الجديد من المزود عند الغياب فقط حتى لا تتعطل الصفحة بتعطل المزود.
   * لا تُعرض أي خدمة إلا إذا أنشأت الإدارة تطبيقاً مفعّلاً لها وأضافة دولة مفعّلة
   * ضمنه — نفس طريقة تطبيقات المتجر: القائمة المُنتقاة هي المرجع، لا الكتالوج كامل.
   */
  async getOptions() {
    // مزود مُسجَّل لكنه موقوف (isActive=false): تُبلَغ صفحة العميل بعدم الإتاحة
    // بوضع providerStopped فتُخفى الأرقام (ويُمسح المخزّن في التطبيق) بدل إبقاء
    // أرقام معروضة لا يمكن شراؤها. الإدارة ترى التطبيقات ودولها من مسار آخر.
    const activeNumberProvider = await this.providerModel.findOne({
      providerType: { $in: VIRTUAL_NUMBER_PROVIDER_TYPES },
      isActive: { $ne: false },
    });
    if (!activeNumberProvider) {
      const stoppedProvider = await this.providerModel.findOne({
        providerType: { $in: VIRTUAL_NUMBER_PROVIDER_TYPES },
        isActive: false,
      });
      if (stoppedProvider) {
        return {
          available: false,
          providerStopped: true,
          providerOnline: false,
          waitMinutes: this.waitTtlMinutes(),
          curated: await this.appModel.countDocuments({}),
          margin: {
            type: stoppedProvider.profitMarginType ?? ProfitMarginType.PERCENTAGE,
            value: stoppedProvider.profitMarginValue ?? 0,
          },
          services: [],
          // «تفعيل مضمون» يُنفّذه المشرف بلا مزود، فيبقى معروضاً ولو توقّف المزود
          manualServices: await this.listActiveManualServices(),
          syncedAt: null,
        };
      }
    }

    const provider = await this.resolveProvider();
    let catalog = await this.catalogModel.findOne({ providerId: provider._id });

    const isStale =
      !catalog ||
      !catalog.fetchedAt ||
      Date.now() - new Date(catalog.fetchedAt).getTime() > CATALOG_TTL_MS;

    if (isStale) {
      // الفشل لا يمنع العرض: نُبقي المخزّن القديم ويسجّل المزود سبب الخطأ للإدارة
      await this.syncCatalog(provider).catch((err: any) => {
        this.logger.warn(`Virtual numbers catalog refresh failed: ${err.message}`);
      });
      catalog = await this.catalogModel.findOne({ providerId: provider._id });
    }

    const services = await this.buildCuratedServices(
      (catalog?.services ?? []) as VirtualNumberService[],
      provider,
    );

    return {
      available: services.length > 0,
      // هوية المزود وأخطاؤه الداخلية للإدارة فقط: payload العميل يحمل مؤشر إتاحة
      // بلا أسماء ولا رسائل مزودين، حتى لا يُستنتج من الشاشة مورد الخدمة
      providerOnline: provider.status === ProviderStatus.ONLINE,
      waitMinutes: this.waitTtlMinutes(),
      // الكتالوج مُنتقًى: تُبلغ الصفحة الإدارةَ بعدّة التطبيقات كي تعرف إن كان
      // عليها تنسيق المنتجات قبل أن تظهر أي أرقام للعملاء
      curated: await this.appModel.countDocuments({}),
      margin: {
        type: provider.profitMarginType ?? ProfitMarginType.PERCENTAGE,
        value: provider.profitMarginValue ?? 0,
      },
      services,
      // القسم الأول في صفحة الأرقام: خدمات التفعيل المضمون (يدوية بمشرف)
      manualServices: await this.listActiveManualServices(),
      syncedAt: catalog?.fetchedAt ?? null,
    };
  }

  /**
   * يبني قائمة العميل من المُنتقى فقط: لكل تطبيق مفعّل، دوله المفعّلة التي توجد
   * فعلياً في كتالوج المزود الحالي. السعر حيّ (تكلفة الكتالوج + هامش المزود)،
   * فلا يخضع لإدارة يدوية ويطابق قرارات التسعير المعتمدة (هامش المزود تلقائياً).
   */
  private async buildCuratedServices(
    catalogServices: VirtualNumberService[],
    provider: ProviderDocument,
  ) {
    const apps = await this.appModel
      .find({ isActive: true })
      .sort({ sortOrder: 1, createdAt: -1 });
    if (apps.length === 0) return [];

    const products = await this.productModel.find({
      appId: { $in: apps.map((a) => a._id) },
      isActive: true,
    });

    const marginType = provider.profitMarginType ?? ProfitMarginType.PERCENTAGE;
    const marginValue = provider.profitMarginValue ?? 0;
    const byService = new Map(catalogServices.map((s) => [s.code, s]));
    const productsByApp = new Map<string, VirtualNumberProduct[]>();
    for (const p of products) {
      const key = p.appId.toString();
      const list = productsByApp.get(key) ?? [];
      list.push(p);
      productsByApp.set(key, list);
    }

    const out: Array<{
      code: string;
      name: string;
      nameAr?: string;
      nameEn?: string;
      icon?: string;
      herosmsCode?: string;
      fivesimCode?: string;
      countries: any[];
      fromPrice: number;
    }> = [];

    for (const app of apps) {
      const svc = byService.get(app.serviceCode);
      if (!svc) continue; // الخدمة غابت عن كتالوج المزود الحالي: لا تُعرض
      const catalogByCountry = new Map(
        (svc.countries ?? []).map((c) => [c.code, c]),
      );

      const appMeta = resolveAppMeta(app.serviceCode, provider?.providerType);
      const countries = (productsByApp.get(app._id.toString()) ?? [])
        .map((product) => {
          // السعر من الكتالوج الحيّ إن وُجدت الدولة، وإلا من لقطة المنتج
          const live = catalogByCountry.get(product.countryCode);
          const cost = Number(live?.cost ?? product.cost) || 0;
          const salePrice = this.computeSalePrice(cost, marginType, marginValue);
          const cMeta = resolveCountryMeta(product.countryCode || product.countryName, provider?.providerType);
          return {
            code: product.countryCode,
            name: live?.name || product.countryName || cMeta.name,
            nameAr: (live as any)?.nameAr || cMeta.nameAr,
            nameEn: (live as any)?.nameEn || cMeta.nameEn,
            flag: (live as any)?.flag || cMeta.flag,
            iso: (live as any)?.iso || cMeta.iso,
            cost,
            count: live?.count ?? product.count ?? 0,
            operators: visibleOperators(live?.operators ?? product.operators),
            salePrice,
          };
        })
        .filter((country) => country.salePrice > 0)
        .sort((a, b) => a.salePrice - b.salePrice);

      if (countries.length === 0) continue; // تطبيق بلا دولة مفعّلة بسعر صالح
      out.push({
        code: app.serviceCode,
        name: app.name || (svc as any)?.name || appMeta.name,
        nameAr: (svc as any)?.nameAr || appMeta.nameAr,
        nameEn: (svc as any)?.nameEn || appMeta.nameEn,
        icon: app.iconUrl || (svc as any)?.icon || appMeta.icon,
        herosmsCode: (svc as any)?.herosmsCode || appMeta.herosmsCode,
        fivesimCode: (svc as any)?.fivesimCode || appMeta.fivesimCode,
        countries,
        fromPrice: countries[0].salePrice,
      });
    }

    return out.sort((a, b) => a.fromPrice - b.fromPrice);
  }

  /** مزامنة الكتالوج من المزود (تُستدعى عند الحاجة ومن زر الإدارة) */
  async syncCatalog(providerInput?: ProviderDocument) {
    const provider = providerInput ?? (await this.resolveProvider());
    const client = this.clientFor(provider);

    try {
      const services = await client.getCatalog();
      await this.catalogModel.findOneAndUpdate(
        { providerId: provider._id },
        {
          providerId: provider._id,
          services,
          serviceCount: services.length,
          fetchedAt: new Date(),
          lastError: '',
        },
        { upsert: true, new: true },
      );

      // أسماء الخدمات في الكتالوج تُصلح أسماء التطبيقات التي حُفظت كرموز
      await this.healCodeAppNames(services).catch(() => undefined);

      // رصيد المزود يُحدَّث مع المزامنة كي يظهر في اللوحة ويُتحقق منه قبل الطلب
      await this.refreshProviderBalance(provider).catch(() => undefined);

      return {
        message: `تم تحديث قائمة الأرقام (${services.length} خدمة)`,
        serviceCount: services.length,
      };
    } catch (err: any) {
      const reason = err?.message || 'تعذر جلب القائمة من المزود';
      await this.catalogModel
        .findOneAndUpdate(
          { providerId: provider._id },
          { providerId: provider._id, lastError: reason, serviceCount: 0 },
          { upsert: true, new: true },
        )
        .catch(() => undefined);
      throw new BadRequestException(reason);
    }
  }

  /**
   * أسماء التطبيقات التي حُفظت كرموز (لأن أسماء المزود لم تكن تُجلب) تُستبدل
   * بالاسم الحقيقي من الكتالوج المزامَن — تُشغَّل مع كل مزامنة ولا تعدّل شيئاً
   * بعد أول تشغيل (الاسم لم يبق مساوياً لرمز الخدمة).
   */
  private async healCodeAppNames(services: VirtualNumberService[]) {
    const appNameByCode = new Map(
      services
        .filter((svc) => svc.name && svc.name !== svc.code)
        .map((svc) => [svc.code, svc.name]),
    );
    if (appNameByCode.size === 0) return;

    const apps = await this.appModel.find({}, 'name serviceCode');
    const ops = apps
      .filter((app) => {
        const real = appNameByCode.get(app.serviceCode);
        return !!real && (!app.name || app.name === app.serviceCode);
      })
      .map((app) => ({
        updateOne: {
          filter: { _id: app._id },
          update: { $set: { name: appNameByCode.get(app.serviceCode) } },
        },
      }));
    if (ops.length > 0) await this.appModel.bulkWrite(ops);
  }

  private async refreshProviderBalance(provider: ProviderDocument) {
    const client = this.clientFor(provider);
    const profile = await client.getProfile();
    await this.providerModel.updateOne(
      { _id: provider._id },
      {
        $set: {
          balance: profile.balance,
          status: ProviderStatus.ONLINE,
          lastCheckAt: new Date(),
          lastError: undefined,
        },
      },
    );
    provider.balance = profile.balance;
    provider.status = ProviderStatus.ONLINE;
    return profile;
  }

  private waitTtlMinutes(): number {
    const raw = Number(this.configService.get<string>('VIRTUAL_NUMBER_TTL_MINUTES'));
    return Number.isFinite(raw) && raw > 0 ? Math.min(raw, 60) : DEFAULT_WAIT_TTL_MINUTES;
  }

  // ===========================================================================
  // طلب رقم (خصم المحفظة ثم طلب المزود)
  // ===========================================================================

  async requestNumber(params: {
    userId: string;
    service: string;
    country: string;
    operator?: string;
    clientRequestId?: string;
  }) {
    const user = await this.userModel.findById(params.userId);
    if (!user) throw new NotFoundException('المستخدم غير موجود');

    const cleanService = (params.service || '').trim();
    const cleanCountry = (params.country || '').trim();
    if (!cleanService || !cleanCountry) {
      throw new BadRequestException('يرجى اختيار الخدمة والدولة أولاً');
    }

    // طلب حيّ واحد لكل عميل: يحمي الرصيد ويمنع حرق أرقام المزود
    const active = await this.requestModel.findOne({
      userId: new Types.ObjectId(user._id),
      status: { $in: ACTIVE_VIRTUAL_NUMBER_STATUSES },
    });
    if (active) {
      throw new BadRequestException(
        `لديك رقم نشط بالفعل (${active.phoneNumber || 'قيد التجهيز'})؛ ألغِه أو انتظر رمزه قبل طلب رقم جديد`,
      );
    }

    const provider = await this.resolveProvider();
    if (provider.isActive === false) {
      throw new BadRequestException(
        'خدمة الأرقام الوهمية متوقفة حالياً، ولم يتم خصم أي مبلغ من رصيدك',
      );
    }

    // لا يُباع إلا المُنتقَى: لا بد أن يكون للخدمة تطبيق مفعّل وهذه الدولة مفعّلة ضمنه،
    // وإلا رُفض الطلب برسالة عامة مطابقة لرسالة غياب الخدمة عن الكتالوج
    await this.assertCurated(cleanService, cleanCountry);

    const picked = await this.pickPrice(provider, cleanService, cleanCountry);
    const { cost, salePrice, serviceName, countryName } = picked;

    // رصيد المزود يجب أن يغطي التكلفة قبل المساس بمحفظة العميل
    await this.ensureProviderFunded(provider, cost);

    const requestNumber = this.generateRequestNumber();
    const cleanRequestId =
      typeof params.clientRequestId === 'string' && params.clientRequestId.trim()
        ? params.clientRequestId.trim()
        : undefined;

    let debited: UserDocument;
    try {
      const updated = await this.userModel.findOneAndUpdate(
        { _id: user._id, balance: { $gte: salePrice } },
        { $inc: { balance: -salePrice } },
        { new: true },
      );
      if (!updated) {
        throw new BadRequestException(
          `رصيدك غير كافٍ. المبلغ المطلوب: $${salePrice.toFixed(2)}، رصيدك الحالي: $${user.balance.toFixed(2)}`,
        );
      }
      debited = updated;
    } catch (err: any) {
      if (err instanceof BadRequestException) throw err;
      this.logger.error(`Wallet debit failed for ${user._id}: ${err?.message}`);
      throw new BadRequestException('تعذر إتمام العملية، لم يتم خصم أي مبلغ');
    }

    const balanceAfter = Number(debited.balance.toFixed(2));
    const balanceBefore = Number((balanceAfter + salePrice).toFixed(2));

    let request: VirtualNumberRequestDocument;
    try {
      request = await this.requestModel.create({
        requestNumber,
        clientRequestId: cleanRequestId,
        userId: user._id,
        providerId: provider._id,
        service: cleanService,
        serviceName,
        country: cleanCountry,
        countryName,
        operator: (params.operator || '').trim(),
        amount: salePrice,
        cost,
        profit: Number((salePrice - cost).toFixed(2)),
        status: VirtualNumberStatus.PENDING,
        expiresAt: new Date(Date.now() + this.waitTtlMinutes() * 60 * 1000),
      });
    } catch (saveErr: any) {
      // تكرار الإرسال بنفس المعرّف: نُعيد الطلب الأصلي بلا خصم جديد
      if (saveErr?.code === 11000 && cleanRequestId) {
        const existing = await this.requestModel.findOne({
          clientRequestId: cleanRequestId,
        });
        if (existing) {
          await this.compensateDuplicateDebit(user, salePrice, existing);
          return {
            message: 'طلبك السابق نفسه قيد التنفيذ',
            request: this.toView(existing),
            newBalance: Number(
              ((await this.userModel.findById(user._id))?.balance ?? 0).toFixed(2),
            ),
          };
        }
      }
      await this.refundUnpersistedDebit(user, salePrice, saveErr);
      throw new BadRequestException(
        'تعذر إنشاء طلب الرقم، تم إرجاع المبلغ إلى محفظتك',
      );
    }

    try {
      await this.transactionModel.create({
        userId: user._id,
        type: TransactionType.PURCHASE,
        amount: -salePrice,
        balanceBefore,
        balanceAfter,
        description: `تفعيل رقم وهمي (${serviceName || cleanService})`,
        referenceType: 'VirtualNumber',
        referenceId: request._id.toString(),
        status: TransactionStatus.COMPLETED,
      });
    } catch (ledgerErr: any) {
      // المال سُحب والدفتر لم يسجّل: نُرجعه فوراً ونُغلق الطلب
      this.logger.error(
        `Virtual number ledger entry failed for ${requestNumber}: ${ledgerErr.message}`,
      );
      await this.refundRequest(request, 'تعذر تسجيل الحركة المالية، تم إرجاع المبلغ');
      throw new BadRequestException(
        'تعذر إتمام العملية، لم يتم خصم أي مبلغ من رصيدك',
      );
    }

    // طلب الرقم من المزود: الفشل يُرجع المال فوراً (لم يستفد العميل من شيء)
    const client = this.clientFor(provider);
    let number: VirtualNumberHandle;
    try {
      number = await client.requestNumber({
        service: cleanService,
        country: cleanCountry,
        operator: request.operator || undefined,
      });
    } catch (err: any) {
      const isTimeout = Boolean(err?.isTimeout);
      // السبب التفصيلي في السجل وترويسة المزود للإدارة، أما العميل فيقرأ
      // عبارة عامة: رسائل المزودين تكشف مواردهم وقد تحمل تفاصيل داخلية
      const reason = err?.message || 'تعذر الاتصال بمزود الأرقام';
      this.logger.warn(
        `Virtual number request failed for ${params.userId}: provider=${provider.name} ${reason}`,
      );
      await this.providerModel.updateOne(
        { _id: provider._id },
        { $set: { lastError: reason } },
      );
      if (!isTimeout) {
        await this.refundRequest(
          request,
          'تعذر تجهيز الرقم، وتم إرجاع المبلغ إلى محفظتك',
        );
        throw new BadRequestException(
          'تعذر تجهيز الرقم حالياً، وتم إرجاع المبلغ إلى محفظتك',
        );
      }
      // مهلة بلا جواب: قد يكون الرقم طُلب فعلاً — يبقى الطلب معلّقاً يحسمه المسح
      request.status = VirtualNumberStatus.PENDING;
      request.note = 'جارٍ التحقق من حالة الرقم، قد يصلك الرمز خلال دقائق';
      await request.save().catch(() => undefined);
      throw new BadRequestException(
        'انقطع الاتصال أثناء تجهيز الرقم؛ طلبك محفوظ وقيد التحقق، وقد يصلك الرقم خلال دقائق',
      );
    }

    request.providerRef = number.id;
    request.phoneNumber = number.number;
    request.status = VirtualNumberStatus.WAITING;
    request.raw = number.raw as Record<string, any>;
    request.note = undefined;
    await request.save();

    await this.notifyAdminsSafe(
      'طلب رقم وهمي جديد',
      `العميل ${user.name} فعّل رقم #${requestNumber} لخدمة ${serviceName || cleanService} بمبلغ $${salePrice.toFixed(2)}`,
    );

    return {
      message: 'تم تجهيز الرقم، أدخله في التطبيق المطلوب وسيصل الرمز تلقائياً',
      request: this.toView(request),
      newBalance: balanceAfter,
    };
  }

  // قراءة السعر من الكتالوج المخزّن (أو من المزود مباشرة إن غاب)
  private async pickPrice(
    provider: ProviderDocument,
    service: string,
    country: string,
  ) {
    let catalog = await this.catalogModel.findOne({ providerId: provider._id });
    const stale =
      !catalog ||
      !catalog.fetchedAt ||
      Date.now() - new Date(catalog.fetchedAt).getTime() > CATALOG_TTL_MS;

    let entry = this.findCatalogEntry(catalog?.services ?? [], service, country);
    if (!entry && stale) {
      await this.syncCatalog(provider).catch(() => undefined);
      catalog = await this.catalogModel.findOne({ providerId: provider._id });
      entry = this.findCatalogEntry(catalog?.services ?? [], service, country);
    }
    if (!entry) {
      throw new BadRequestException('هذه الخدمة أو الدولة غير متاحة حالياً');
    }

    const marginType = provider.profitMarginType ?? ProfitMarginType.PERCENTAGE;
    const marginValue = provider.profitMarginValue ?? 0;
    return {
      cost: entry.cost,
      salePrice: this.computeSalePrice(entry.cost, marginType, marginValue),
      serviceName: entry.serviceName,
      countryName: entry.countryName,
    };
  }

  private findCatalogEntry(
    services: VirtualNumberService[],
    service: string,
    country: string,
  ) {
    const svc = services.find((s) => s.code === service);
    if (!svc) return null;
    const c = (svc.countries ?? []).find((x) => x.code === country);
    if (!c) return null;
    return {
      cost: Number(c.cost) || 0,
      serviceName: svc.name,
      countryName: c.name,
    };
  }

  private async ensureProviderFunded(provider: ProviderDocument, cost: number) {
    // فحص الحيوية عند الحاجة فقط (نفس نهج بقية المزودين)
    const lastCheck = provider.lastCheckAt
      ? new Date(provider.lastCheckAt).getTime()
      : 0;
    if (!lastCheck || Date.now() - lastCheck > 10 * 60 * 1000) {
      await this.refreshProviderBalance(provider).catch((err: any) =>
        this.logger.warn(`Virtual numbers readiness check failed: ${err.message}`),
      );
    }

    if (provider.status === ProviderStatus.ERROR) {
      throw new BadRequestException(
        'خدمة الأرقام غير متاحة حالياً، ولم يتم خصم أي مبلغ من رصيدك',
      );
    }

    const balance = Number(provider.balance) || 0;
    if (cost > 0 && balance < cost) {
      // نفاد رصيد المزود يوقفه كي لا تُعرض خدمة لا تستطيع التنفيذ
      await this.providerModel.updateOne(
        { _id: provider._id },
        {
          $set: {
            isActive: false,
            status: ProviderStatus.ERROR,
            lastError: `الرصيد $${balance.toFixed(2)} أقل من تكلفة رقم $${cost.toFixed(2)}`,
          },
        },
      );
      await this.notifyAdminsSafe(
        'إيقاف مزود الأرقام الوهمية: الرصيد غير كافٍ',
        `أُوقف المزود "${provider.name}" لأن رصيده $${balance.toFixed(2)} لا يغطي تكلفة رقم ($${cost.toFixed(2)}). أعد شحنه ثم فعّله من إدارة المزودين.`,
      );
      throw new BadRequestException(
        'الخدمة غير متاحة حالياً، ولم يتم خصم أي مبلغ من رصيدك. يرجى المحاولة لاحقاً',
      );
    }
  }

  // ===========================================================================
  // حالة الطلب واستقبال الرمز
  // ===========================================================================

  /**
   * يفحص المزود ويحدّث المستند: وصول الرمز، أو إلغاء المزود للرقم (يُرجع المبلغ).
   * تُستدعى من واجهة العميل أثناء الانتظار ومن المسح الدوري.
   */
  async syncRequest(request: VirtualNumberRequestDocument): Promise<VirtualNumberRequestDocument> {
    if (!this.isLive(request)) return request;

    const provider = await this.providerModel.findById(request.providerId);
    if (!provider) {
      // خلل إعداد داخلي: يُسجّل للإدارة ولا يُقرأ منه العميل شيئا
      this.logger.error(
        `Virtual number #${request.requestNumber} references missing provider ${request.providerId}`,
      );
      request.note = 'تعذّرت متابعة الرقم، يرجى مراجعة الإدارة';
      await request.save().catch(() => undefined);
      return request;
    }

    const client = this.clientFor(provider);
    // بلا رقم بعد: لا شيء يُفحص إلا انقضاء المهلة (يتولاها المسح الدوري)
    if (!request.providerRef) return request;

    let result;
    try {
      result = await client.fetchStatus(request.providerRef);
    } catch (err: any) {
      this.logger.warn(
        `Virtual numbers status check failed for ${request.requestNumber}: ${err?.message}`,
      );
      return request;
    }

    if (result.state === 'received') {
      request.status = VirtualNumberStatus.RECEIVED;
      request.smsText = result.smsText ?? request.smsText;
      request.smsCode = result.code ?? request.smsCode;
      request.codeReceivedAt = request.codeReceivedAt ?? new Date();
      // نافذة قراءة الرمز ثم يُغلق الطلب تلقائياً بلا إرجاع (الخدمة سُلّمت)
      request.expiresAt = new Date(Date.now() + CODE_READ_WINDOW_MS);
      await request.save();

      await this.notificationsService
        .createNotification({
          userId: request.userId.toString(),
          title: 'وصل رمز التحقق 📲',
          body: `رمز ${request.serviceName || request.service}: ${request.smsCode || 'يرجى فتح صفحة الأرقام الوهمية'}`,
          type: 'virtual_number_code',
          data: {
            requestId: request._id.toString(),
            requestNumber: request.requestNumber,
          },
        })
        .catch((err: any) =>
          this.logger.warn(`Code notification failed: ${err.message}`),
        );
      return request;
    }

    if (result.state === 'cancelled') {
      await this.refundRequest(
        request,
        'أُلغي الرقم قبل وصول رمز التحقق (لم تصل رسالة خلال المهلة)، وتم إرجاع المبلغ',
        VirtualNumberStatus.EXPIRED,
      );
      return request;
    }

    return request;
  }

  /**
   * معالجة إشعار الويب هوك الوارد من مزودي الأرقام (Hero-SMS أو 5sim أو متوافقات SMS-Activate):
   * يُستقبل عند وصول رسالة SMS أو تحديث حالة الطلب لدى المزود الخارجي فوراً دون انتظار الفحص الدوري.
   */
  async processIncomingWebhook(
    payload: any,
    query?: Record<string, any>,
    headers?: Record<string, any>,
  ): Promise<{
    success: boolean;
    action?: string;
    message: string;
    requestId?: string;
    requestNumber?: string;
    code?: string;
  }> {
    const data: Record<string, any> = { ...(query || {}), ...(payload || {}) };
    this.logger.log(`Virtual numbers webhook received: ${JSON.stringify(data).slice(0, 300)}`);

    // 1. استخراج معرف المزود (providerRef)
    const rawRef =
      data.order_id ??
      data.orderId ??
      data.activationId ??
      data.id ??
      data.providerRef ??
      data.ref ??
      data.orderNumber;
    const providerRef = rawRef !== undefined && rawRef !== null ? String(rawRef).trim() : '';

    // 2. استخراج رقم الهاتف إن وجد
    const rawPhone = data.phone ?? data.phoneNumber ?? data.phone_number;
    const phoneDigits = rawPhone ? digitsOnly(String(rawPhone)) : '';

    if (!providerRef && !phoneDigits) {
      this.logger.warn('Webhook ignored: missing order_id/activationId and phone number');
      return { success: false, message: 'Missing order_id or phone number in payload' };
    }

    // 3. البحث عن الطلب المعني في قاعدة البيانات
    let request: VirtualNumberRequestDocument | null = null;
    if (providerRef) {
      request = await this.requestModel.findOne({ providerRef });
    }
    if (!request && phoneDigits && phoneDigits.length >= 6) {
      // مطابقة رقم الهاتف (مباشرة أو مع + أو نهاية الرقم)
      request =
        (await this.requestModel.findOne({
          phoneNumber: phoneDigits,
          status: { $in: ACTIVE_VIRTUAL_NUMBER_STATUSES },
        })) ??
        (await this.requestModel.findOne({
          phoneNumber: `+${phoneDigits}`,
          status: { $in: ACTIVE_VIRTUAL_NUMBER_STATUSES },
        })) ??
        (await this.requestModel.findOne({
          phoneNumber: { $regex: new RegExp(`${phoneDigits.slice(-8)}$`) },
          status: { $in: ACTIVE_VIRTUAL_NUMBER_STATUSES },
        }));
    }

    if (!request) {
      this.logger.warn(
        `Webhook order not found for providerRef="${providerRef}", phoneDigits="${phoneDigits}"`,
      );
      return {
        success: false,
        message: 'No matching virtual number request found',
      };
    }

    // 4. استخراج كود التحقق ونص الرسالة
    let smsText = readSmsText(data) || '';
    if (!smsText && typeof data.text === 'string') smsText = data.text;
    if (!smsText && typeof data.smsText === 'string') smsText = data.smsText;
    if (!smsText && typeof data.message === 'string') smsText = data.message;
    if (!smsText && typeof data.msg === 'string') smsText = data.msg;

    let smsCode = pickStringValue(data, ['code', 'smsCode', 'passcode', 'otp', 'pin']);
    if (!smsCode && smsText) {
      smsCode = extractVerificationCode(smsText) || null;
    }

    // 5. التحقق من حالات الإلغاء أو انتهاء الصلاحية من طرف المزود
    const actionOrStatus = String(data.status ?? data.action ?? data.state ?? '').toUpperCase();
    const isCancelled =
      /CANCEL|TIMEOUT|EXPIRE|BANNED|ACCESS_CANCEL|STATUS_CANCEL/i.test(actionOrStatus);

    if (isCancelled) {
      if (this.isLive(request)) {
        await this.refundRequest(
          request,
          'أُلغي الرقم من طرف مزود الأرقام (Webhook)، وتم إرجاع المبلغ إلى محفظتك',
          VirtualNumberStatus.EXPIRED,
        );
        return {
          success: true,
          action: 'cancelled_and_refunded',
          message: 'Order cancelled and refunded',
          requestId: request._id.toString(),
          requestNumber: request.requestNumber,
        };
      }
      return {
        success: true,
        action: 'already_closed',
        message: 'Order was already closed',
        requestId: request._id.toString(),
      };
    }

    // 6. وصول كود التحقق
    if (smsCode || smsText) {
      if (request.status === VirtualNumberStatus.COMPLETED) {
        return {
          success: true,
          action: 'already_completed',
          message: 'Order was already completed',
          requestId: request._id.toString(),
        };
      }

      request.status = VirtualNumberStatus.RECEIVED;
      if (smsCode) request.smsCode = smsCode;
      if (smsText) request.smsText = smsText;
      request.codeReceivedAt = request.codeReceivedAt ?? new Date();
      request.expiresAt = new Date(Date.now() + CODE_READ_WINDOW_MS);
      if (!request.raw) request.raw = {};
      request.raw.lastWebhook = data;
      await request.save();

      // إشعار المستخدم فوراً
      await this.notificationsService
        .createNotification({
          userId: request.userId.toString(),
          title: 'وصل رمز التحقق 📲',
          body: `رمز ${request.serviceName || request.service}: ${request.smsCode || 'يرجى فتح صفحة الأرقام الوهمية'}`,
          type: 'virtual_number_code',
          data: {
            requestId: request._id.toString(),
            requestNumber: request.requestNumber,
            code: request.smsCode,
          },
        })
        .catch((err: any) =>
          this.logger.warn(`Webhook code notification failed: ${err.message}`),
        );

      this.logger.log(
        `Webhook successfully processed for #${request.requestNumber}, code=${smsCode}`,
      );

      return {
        success: true,
        action: 'code_received',
        message: 'Verification code received and saved',
        requestId: request._id.toString(),
        requestNumber: request.requestNumber,
        code: smsCode ?? undefined,
      };
    }

    // تحديث بيانات عامة فقط
    if (!request.raw) request.raw = {};
    request.raw.lastWebhook = data;
    await request.save();

    return {
      success: true,
      action: 'status_updated',
      message: 'Webhook status payload recorded',
      requestId: request._id.toString(),
      requestNumber: request.requestNumber,
    };
  }

  /** حالة رقم معيّن لصاحبها (مع فحص المزود عند الحاجة) */
  async getMyRequest(userId: string, id: string, refresh = true) {
    const request = await this.requestModel.findOne({
      _id: new Types.ObjectId(id),
      userId: new Types.ObjectId(userId),
    });
    if (!request) throw new NotFoundException('الطلب غير موجود');
    const synced = refresh ? await this.syncRequest(request) : request;
    return this.toView(synced);
  }

  /** أرقام العميل: الحالي والحالات السابقة */
  async getMyRequests(userId: string) {
    const mine = await this.requestModel
      .find({ userId: new Types.ObjectId(userId) })
      .sort({ createdAt: -1 })
      .limit(50);

    // الرقم الحيّ يُفحص كي يصل الرمز حتى لو كانت الصفحة لم تُحدَّث
    const live = mine.filter((r) => this.isLive(r));
    if (live.length > 0) {
      await Promise.all(
        live.map((r) => this.syncRequest(r).catch(() => r)),
      );
    }

    return mine.map((r) => this.toView(r));
  }

  /**
   * يغلق العميل رقمه: بعد وصول الرمز يُنهى الطلب لدى المزود (بلا إرجاع)،
   * وقبل وصوله يُلغى ويُرجع المبلغ كاملاً.
   */
  async closeMyRequest(userId: string, id: string, reason?: string) {
    const request = await this.requestModel.findOne({
      _id: new Types.ObjectId(id),
      userId: new Types.ObjectId(userId),
    });
    if (!request) throw new NotFoundException('الطلب غير موجود');

    if (!this.isLive(request)) {
      throw new BadRequestException('هذا الطلب مغلق بالفعل');
    }

    const gotCode =
      request.status === VirtualNumberStatus.RECEIVED ||
      Boolean(request.smsCode);

    if (gotCode) {
      return this.finishRequest(
        request,
        reason || 'تم استلام الرمز وإغلاق الرقم',
      );
    }
    return this.cancelRequest(
      request,
      reason || 'ألغى العميل الطلب قبل وصول الرمز',
    );
  }

  private async finishRequest(
    request: VirtualNumberRequestDocument,
    note: string,
    adminNote?: string,
  ) {
    const provider = await this.providerModel.findById(request.providerId);
    if (provider && request.providerRef) {
      await this.clientFor(provider)
        .markFinished(request.providerRef)
        .catch((err: any) =>
          this.logger.warn(`Virtual number finish call failed: ${err.message}`),
        );
    }

    request.status = VirtualNumberStatus.COMPLETED;
    request.note = note;
    request.adminNote = adminNote;
    request.closedAt = new Date();
    request.expiresAt = undefined;
    await request.save();
    return { message: 'تم إغلاق الرقم بنجاح', request: this.toView(request) };
  }

  /** إلغاء مع إرجاع المبلغ (تُستدعى من العميل ومن المسح الدوري ومن الإدارة) */
  private async cancelRequest(
    request: VirtualNumberRequestDocument,
    note: string,
    status: VirtualNumberStatus = VirtualNumberStatus.CANCELLED,
    notifyUser = true,
    adminNote?: string,
  ) {
    const provider = await this.providerModel.findById(request.providerId);
    if (provider && request.providerRef) {
      await this.clientFor(provider)
        .cancelNumber({
          id: request.providerRef,
          service: request.service,
          country: request.country,
          operator: request.operator || undefined,
        })
        .catch((err: any) =>
          this.logger.warn(`Virtual number cancel call failed: ${err.message}`),
        );
    }

    const refunded = await this.refundRequest(
      request,
      note,
      status,
      adminNote,
    );

    if (notifyUser) {
      await this.notificationsService
        .createNotification({
          userId: request.userId.toString(),
          title: 'تم إرجاع مبلغ رقم التحقق',
          body: `${note}${refunded ? ` وأُرجع $${request.amount.toFixed(2)} إلى محفظتك.` : '.'}`,
          type: 'virtual_number_cancelled',
          data: { requestId: request._id.toString() },
        })
        .catch((err: any) => this.logger.warn(`Cancel notify failed: ${err}`));
    }

    return {
      message: refunded
        ? 'تم إلغاء الرقم وإرجاع المبلغ إلى محفظتك'
        : 'تم إلغاء الرقم، وسيراجع الإدارة إرجاع المبلغ',
      request: this.toView(request),
    };
  }

  /**
   * إرجاع المبلغ مرة واحدة فقط: المستند الذي لا يحمل refundedAt هو وحده الذي
   * يفوز بالتحديث، فلا يُضاعف المسح الدوري أو الإلغاء المتزامن رصيد العميل.
   */
  private async refundRequest(
    request: VirtualNumberRequestDocument,
    reason: string,
    status: VirtualNumberStatus = VirtualNumberStatus.CANCELLED,
    adminNote?: string,
  ): Promise<boolean> {
    if (request.refundedAt) return true; // أُرجع سابقاً
    if (request.amount <= 0) {
      request.status = status;
      request.note = reason;
      request.adminNote = adminNote;
      request.closedAt = request.closedAt ?? new Date();
      await request.save().catch(() => undefined);
      return false;
    }

    const claimed = await this.requestModel.findOneAndUpdate(
      { _id: request._id, refundedAt: null },
      {
        $set: {
          refundedAt: new Date(),
          status,
          note: reason,
          ...(adminNote ? { adminNote } : {}),
          closedAt: new Date(),
          expiresAt: null,
        },
      },
      { new: true },
    );
    if (!claimed) return false; // سبقتها حملة أخرى — لا إرجاع مزدوج

    Object.assign(request, claimed.toObject());

    let credited: UserDocument | null = null;
    try {
      credited = await this.userModel.findByIdAndUpdate(
        request.userId,
        { $inc: { balance: request.amount } },
        { new: true },
      );
    } catch (err: any) {
      this.logger.error(
        `Virtual number refund credit failed for ${request.requestNumber}: ${err.message}`,
      );
      await this.notifyAdminsSafe(
        'تنبيه مالي: إرجاع رقم وهمي غير معوّض',
        `الطلب #${request.requestNumber} أُلغي ($${request.amount.toFixed(2)}) لكن إرجاع المبلغ للعميل فشل؛ يلزم تدخل يدوي.`,
      );
      return false;
    }

    const balanceAfter = Number((credited?.balance ?? request.amount).toFixed(2));
    try {
      await this.transactionModel.create({
        userId: request.userId,
        type: TransactionType.REFUND,
        amount: request.amount,
        balanceBefore: Number((balanceAfter - request.amount).toFixed(2)),
        balanceAfter,
        description: `إرجاع تلقائي لطلب رقم وهمي #${request.requestNumber}`,
        referenceType: 'VirtualNumber',
        referenceId: request._id.toString(),
        status: TransactionStatus.COMPLETED,
      });
    } catch (err: any) {
      this.logger.error(
        `Virtual number refund ledger failed for ${request.requestNumber}: ${err.message}`,
      );
      await this.notifyAdminsSafe(
        'تنبيه دفتر: حركة إرجاع رقم وهمي غير مسجلة',
        `أُرجع $${request.amount.toFixed(2)} للعميل في الطلب #${request.requestNumber} لكن تسجيل الحركة فشل؛ يلزم مراجعة الدفتر.`,
      );
    }

    return true;
  }

  private isLive(request: VirtualNumberRequestDocument): boolean {
    return ACTIVE_VIRTUAL_NUMBER_STATUSES.includes(request.status);
  }

  // ===========================================================================
  // المسح الدوري: وصول الرموز، انتهاء المهلة، إغلاق الرموز المقروءة
  // ===========================================================================

  private async runSweep() {
    if (this.isSweeping) return;
    this.isSweeping = true;
    try {
      const now = new Date();

      // 1) الأرقام التي تجاوزت مهلتها بلا رمز: تُلغى لدى المزود ويُرجع المبلغ
      const expired = await this.requestModel.find({
        status: { $in: [VirtualNumberStatus.PENDING, VirtualNumberStatus.WAITING] },
        expiresAt: { $lte: now },
      });
      for (const request of expired) {
        await this.cancelRequest(
          request,
          `انتهت مهلة انتظار رمز التحقق (${this.waitTtlMinutes()} دقيقة) دون وصول رسالة`,
          VirtualNumberStatus.EXPIRED,
        ).catch((err: any) =>
          this.logger.warn(`Expiry sweep failed for ${request.requestNumber}: ${err.message}`),
        );
      }

      // 2) الرموز التي مضت عليها نافذة القراءة: تُغلق (الخدمة سُلّمت فلا إرجاع)
      const readDone = await this.requestModel.find({
        status: VirtualNumberStatus.RECEIVED,
        expiresAt: { $lte: now },
      });
      for (const request of readDone) {
        await this.finishRequest(
          request,
          'تم إغلاق الرقم بعد استلام رمز التحقق',
        ).catch((err: any) =>
          this.logger.warn(`Finish sweep failed for ${request.requestNumber}: ${err.message}`),
        );
      }

      // 3) الطلبات الحيّة التي لم تُخصم من مهلتها: فحص المزود كي يصل الرمز
      //    حتى لو كانت صفحة العميل مغلقة
      const live = await this.requestModel
        .find({
          status: { $in: ACTIVE_VIRTUAL_NUMBER_STATUSES },
          providerRef: { $exists: true, $ne: null },
          expiresAt: { $gt: now },
        })
        .sort({ createdAt: 1 })
        .limit(40);
      for (const request of live) {
        await this.syncRequest(request).catch((err: any) =>
          this.logger.warn(`Live sweep failed for ${request.requestNumber}: ${err.message}`),
        );
      }
    } finally {
      this.isSweeping = false;
    }

    return { ranAt: new Date().toISOString() };
  }

  /** زر التشغيل في لوحة الإدارة */
  async runSweepNow() {
    return this.runSweep();
  }

  // ===========================================================================
  // الإدارة
  // ===========================================================================

  async getAdminRequests(params: { status?: string; search?: string; limit?: number } = {}) {
    const filter: Record<string, any> = {};
    if (params.status && params.status !== 'all') filter.status = params.status;

    const limit = Math.min(Math.max(params.limit ?? 100, 1), 300);
    const rows = await this.requestModel
      .find(filter)
      .populate('userId', 'name email phone userId')
      .sort({ createdAt: -1 })
      .limit(limit);

    const term = (params.search || '').trim().toLowerCase();
    if (!term) return rows.map((r) => this.toAdminView(r));

    return rows
      .map((r) => this.toAdminView(r))
      .filter((row) =>
        [row.requestNumber, row.userEmail, row.userPhone, row.customUserId, row.phoneNumber, row.serviceName, row.service, row.countryName]
          .filter(Boolean)
          .some((value) => String(value).toLowerCase().includes(term)),
      );
  }

  async getAdminStats() {
    type StatusRow = { _id: string; count: number; amount: number; cost: number };
    const rows = await this.requestModel.aggregate<StatusRow>([
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
          amount: { $sum: '$amount' },
          cost: { $sum: '$cost' },
        },
      },
    ]);

    const byStatus: Record<string, { count: number; amount: number; cost: number }> = {};
    let total = 0;
    let revenue = 0;
    let spend = 0;
    for (const row of rows) {
      byStatus[row._id] = { count: row.count, amount: row.amount, cost: row.cost };
      total += row.count;
      revenue += row.amount;
      spend += row.cost;
    }

    const provider = await this.providerModel
      .findOne({ providerType: { $in: VIRTUAL_NUMBER_PROVIDER_TYPES } })
      .catch(() => null);

    return {
      total,
      revenue: Number(revenue.toFixed(2)),
      cost: Number(spend.toFixed(2)),
      profit: Number((revenue - spend).toFixed(2)),
      byStatus,
      provider: provider
        ? {
            id: provider._id.toString(),
            name: provider.name,
            status: provider.status,
            isActive: provider.isActive !== false,
            balance: Number(provider.balance) || 0,
            lastError: provider.lastError ?? '',
            lastCheckAt: provider.lastCheckAt ?? null,
          }
        : null,
    };
  }

  /** الأدمن: إلغاء رقم واسترجاع المبلغ يدوياً (لحالات ما بعد المهلة أو شكوى العميل) */
  async adminCancelRequest(id: string, adminId: string, reason?: string) {
    const request = await this.requestModel.findById(id);
    if (!request) throw new NotFoundException('الطلب غير موجود');
    if (!this.isLive(request)) {
      throw new BadRequestException('الطلب مغلق بالفعل');
    }

    // سبب الأدمن يبقى داخلياً في adminNote: رسالة العميل عامة حتى لا تُكشف
    // أسماء المزودين ولا هوية من نفّذ الإجراء داخل الشركة
    const result = await this.cancelRequest(
      request,
      'أُلغي الرقم بواسطة الإدارة، وتم إرجاع المبلغ إلى محفظتك',
      VirtualNumberStatus.CANCELLED,
      true,
      `${reason || 'ألغته الإدارة الرقمَ وأرجعت المبلغ للعميل'} (بواسطة الإدارة ${adminId})`,
    );
    return result;
  }

  /** الأدمن: إغلاق رقم بعد تأكيد تسليم الرمز */
  async adminFinishRequest(id: string, reason?: string) {
    const request = await this.requestModel.findById(id);
    if (!request) throw new NotFoundException('الطلب غير موجود');
    if (!this.isLive(request)) throw new BadRequestException('الطلب مغلق بالفعل');
    return this.finishRequest(
      request,
      'تم إغلاق الرقم بعد استلام رمز التحقق',
      reason || 'أغلقت الإدارة الطلب بعد استلام الرمز',
    );
  }

  /** حالة اتصال المزود كما تراها الإدارة (زر الفحص في اللوحة) */
  async adminCheckProvider() {
    const provider = await this.resolveProvider();
    const profile = await this.refreshProviderBalance(provider);
    const catalog = await this.catalogModel.findOne({ providerId: provider._id });
    return {
      provider: {
        id: provider._id.toString(),
        name: provider.name,
        status: provider.status,
        isActive: provider.isActive !== false,
        balance: profile.balance,
        rating: profile.rating,
      },
      serviceCount: catalog?.serviceCount ?? 0,
      syncedAt: catalog?.fetchedAt ?? null,
    };
  }

  // ===========================================================================
  // المُنتقَى: تطبيقات الأرقام ودولها (يُدار من لوحتين مثل المتجر)
  // ===========================================================================

  /** خدمة+دولة مفعّلتان في اللوحة فقط هما اللتان تُباعان للعميل */
  private async assertCurated(service: string, country: string) {
    const app = await this.appModel.findOne({
      serviceCode: service,
      isActive: true,
    });
    if (!app) {
      throw new BadRequestException('هذه الخدمة أو الدولة غير متاحة حالياً');
    }
    const allowed = await this.productModel.exists({
      appId: app._id,
      countryCode: country,
      isActive: true,
    });
    if (!allowed) {
      throw new BadRequestException('هذه الخدمة أو الدولة غير متاحة حالياً');
    }
  }

  /** جلب كتالوج مزود (معيّن أو المُحال تلقائياً) بعد تجديده إن قدُم */
  private async ensureFreshCatalog(provider: ProviderDocument) {
    let catalog = await this.catalogModel.findOne({ providerId: provider._id });
    const stale =
      !catalog ||
      !catalog.fetchedAt ||
      Date.now() - new Date(catalog.fetchedAt).getTime() > CATALOG_TTL_MS;
    if (stale) {
      await this.syncCatalog(provider).catch((err: any) =>
        this.logger.warn(`Catalog refresh failed: ${err.message}`),
      );
      catalog = await this.catalogModel.findOne({ providerId: provider._id });
    }
    return (catalog?.services ?? []) as VirtualNumberService[];
  }

  /** مزود الإدارة: المسجّل في اللوحة، وإلا المُحال افتراضياً */
  private async resolveAdminProvider(providerId?: string) {
    if (providerId && Types.ObjectId.isValid(providerId)) {
      const found = await this.providerModel.findById(providerId);
      if (found) return found;
    }
    return this.resolveProvider();
  }

  /** تطبيقات الأرقام مع عدّ منتجاتها — لشاشة «إدارة الأرقام» */
  async listAdminApps() {
    const apps = await this.appModel
      .find()
      .sort({ sortOrder: 1, createdAt: -1 });
    if (apps.length === 0) return [];

    // أجلب كل المنتجات (الدول) لكل التطبيقات ثم أجمّعها يدويًا
    // حتى يُعاد اسم كل دولة وحالتها ضمن بطاقة التطبيق
    const allProducts = await this.productModel
      .find({ appId: { $in: apps.map((a) => a._id) } })
      .select('appId countryCode countryName isActive')
      .lean();

    const productsByApp = new Map<string, typeof allProducts>();
    for (const p of allProducts) {
      const key = p.appId.toString();
      const list = productsByApp.get(key) ?? [];
      list.push(p);
      productsByApp.set(key, list);
    }

    return apps.map((app) => {
      const products = productsByApp.get(app._id.toString()) ?? [];
      const activeCount = products.filter((p) => p.isActive !== false).length;
      return {
        id: app._id.toString(),
        name: app.name,
        iconUrl: app.iconUrl ?? '',
        serviceCode: app.serviceCode,
        isActive: app.isActive !== false,
        sortOrder: app.sortOrder ?? 0,
        productCount: products.length,
        activeProductCount: activeCount,
        countries: products.map((p) => ({
          code: p.countryCode,
          name: p.countryName || p.countryCode,
          active: p.isActive !== false,
        })),
      };
    });
  }

  /** إنشاء تطبيق أرقام فارغ (اسم + رمز خدمة من كتالوج المزود) */
  async createApp(dto: {
    name: string;
    serviceCode: string;
    iconUrl?: string;
    providerId?: string;
    isActive?: boolean;
    sortOrder?: number;
  }) {
    const name = (dto.name || '').trim();
    const serviceCode = (dto.serviceCode || '').trim();
    if (!serviceCode) {
      throw new BadRequestException('اختر خدمة من كتالوج المزود أولاً');
    }
    const existing = await this.appModel.findOne({ serviceCode });
    if (existing) {
      throw new BadRequestException('يوجد تطبيق لهذا الخدمة بالفعل');
    }
    const app = await this.appModel.create({
      name: name || serviceCode,
      serviceCode,
      iconUrl: (dto.iconUrl || '').trim() || undefined,
      providerId:
        dto.providerId && Types.ObjectId.isValid(dto.providerId)
          ? new Types.ObjectId(dto.providerId)
          : undefined,
      isActive: dto.isActive !== false,
      sortOrder: dto.sortOrder ?? 0,
    });
    return { id: app._id.toString(), message: 'تم إنشاء التطبيق' };
  }

  async updateApp(
    id: string,
    dto: {
      name?: string;
      iconUrl?: string;
      sortOrder?: number;
      isActive?: boolean;
    },
  ) {
    const app = await this.appModel.findById(id);
    if (!app) throw new NotFoundException('التطبيق غير موجود');
    if (dto.name !== undefined) app.name = (dto.name || '').trim() || app.name;
    if (dto.iconUrl !== undefined) {
      const icon = (dto.iconUrl || '').trim();
      app.iconUrl = icon.length > 0 ? icon : undefined;
    }
    if (dto.sortOrder !== undefined) app.sortOrder = dto.sortOrder;
    if (dto.isActive !== undefined) app.isActive = dto.isActive;
    await app.save();
    return { message: 'تم تحديث التطبيق' };
  }

  async toggleApp(id: string) {
    const app = await this.appModel.findById(id);
    if (!app) throw new NotFoundException('التطبيق غير موجود');
    app.isActive = app.isActive === false;
    await app.save();
    return { isActive: app.isActive, message: 'تم تحديث حالة التطبيق' };
  }

  async deleteApp(id: string) {
    const app = await this.appModel.findById(id);
    if (!app) throw new NotFoundException('التطبيق غير موجود');
    await this.productModel.deleteMany({ appId: app._id });
    await app.deleteOne();
    return { message: 'تم حذف التطبيق ودوله المرتبطة' };
  }

  /**
   * مُسرِّع التنسيق: يُنشئ تطبيقاً مفعّلاً لكل خدمة في كتالوج المزود لم تُضَف بعد،
   * بلا دول (تُضاف وتُفعَّل لاحقاً من صفحة المزود). لا يُصدِر أي رقم قبل اختيار الدول.
   */
  async bulkCreateApps(providerId?: string) {
    const provider = await this.resolveAdminProvider(providerId);
    const services = await this.ensureFreshCatalog(provider);
    const existing = await this.appModel.distinct('serviceCode');
    const have = new Set(existing.map((s) => String(s)));

    let created = 0;
    for (const svc of services) {
      if (have.has(svc.code)) continue;
      const appMeta = resolveAppMeta(svc.code, provider?.providerType);
      await this.appModel.create({
        name: svc.name || appMeta.name,
        serviceCode: svc.code,
        iconUrl: appMeta.icon,
        providerId: provider._id,
        isActive: true,
      });
      created += 1;
    }
    return {
      created,
      message: `تم إنشاء ${created} تطبيقاً من الكتالوج`,
    };
  }

  /**
   * كتالوج المزود مُثري بالمُنتقَى: لكل خدمة ودولها، هل لها تطبيق، وهل أُضيفت
   * الدولة منتجاً وحالتها — يملأ شاشة «المنتجات» في صفحة مزودي الأرقام.
   */
  async getAdminCatalog(providerId?: string) {
    const provider = await this.resolveAdminProvider(providerId);
    const services = await this.ensureFreshCatalog(provider);

    const apps = await this.appModel.find();
    const appByService = new Map(apps.map((a) => [a.serviceCode, a]));

    // كل المنتجات الحالية مفهرسة بمفتاح خدمة|دولة
    const products = await this.productModel.find({});
    const productByKey = new Map<string, VirtualNumberProductDocument>();
    for (const p of products) {
      productByKey.set(`${p.serviceCode}|${p.countryCode}`, p);
    }

    const marginType = provider.profitMarginType ?? ProfitMarginType.PERCENTAGE;
    const marginValue = provider.profitMarginValue ?? 0;

    return {
      provider: {
        id: provider._id.toString(),
        name: provider.name,
        status: provider.status,
      },
      margin: { type: marginType, value: marginValue },
      services: services.map((svc) => {
        const app = appByService.get(svc.code);
        const appMeta = resolveAppMeta(svc.code, provider?.providerType);
        return {
          code: svc.code,
          name: app?.name || svc.name || appMeta.name,
          nameAr: (svc as any)?.nameAr || appMeta.nameAr,
          nameEn: (svc as any)?.nameEn || appMeta.nameEn,
          icon: app?.iconUrl || (svc as any)?.icon || appMeta.icon,
          herosmsCode: (svc as any)?.herosmsCode || appMeta.herosmsCode,
          fivesimCode: (svc as any)?.fivesimCode || appMeta.fivesimCode,
          countryCount: (svc.countries ?? []).length,
          appId: app ? app._id.toString() : null,
          appName: app?.name ?? '',
          appActive: app ? app.isActive !== false : false,
          countries: (svc.countries ?? []).map((c) => {
            const product = productByKey.get(`${svc.code}|${c.code}`);
            const cost = Number(c.cost) || 0;
            const cMeta = resolveCountryMeta(c.code || c.name, provider?.providerType);
            return {
              code: c.code,
              name: c.name || cMeta.name,
              nameAr: (c as any)?.nameAr || cMeta.nameAr,
              nameEn: (c as any)?.nameEn || cMeta.nameEn,
              flag: (c as any)?.flag || cMeta.flag,
              iso: (c as any)?.iso || cMeta.iso,
              cost,
              count: c.count ?? 0,
              operators: visibleOperators(c.operators),
              salePrice: this.computeSalePrice(cost, marginType, marginValue),
              added: Boolean(product),
              productId: product ? product._id.toString() : null,
              productActive: product ? product.isActive !== false : false,
            };
          }),
        };
      }),
    };
  }

  /** إضافة دول المختارة من الكتالوج إلى التطبيق كمنتجات مفعّلة */
  async addCountriesToApp(dto: {
    appId: string;
    providerId?: string;
    countries: Array<{
      code: string;
      name?: string;
      cost?: number;
      count?: number;
      operators?: Array<{ code: string; name: string }>;
    }>;
  }) {
    const app = await this.appModel.findById(dto.appId);
    if (!app) throw new NotFoundException('التطبيق غير موجود');
    const countries = dto.countries ?? [];
    if (countries.length === 0) {
      throw new BadRequestException('اختر دولة واحدة على الأقل');
    }

    let added = 0;
    for (const c of countries) {
      const code = (c.code || '').trim();
      if (!code) continue;
      const exists = await this.productModel.exists({
        appId: app._id,
        countryCode: code,
      });
      if (exists) continue;
      await this.productModel.create({
        appId: app._id,
        serviceCode: app.serviceCode,
        countryCode: code,
        countryName: (c.name || '').trim() || code,
        cost: Number(c.cost) || 0,
        count: Number(c.count) || 0,
        operators: (c.operators ?? []).map((o) => ({
          code: o.code,
          name: o.name,
        })),
        providerId:
          dto.providerId && Types.ObjectId.isValid(dto.providerId)
            ? new Types.ObjectId(dto.providerId)
            : app.providerId,
        isActive: true,
      });
      added += 1;
    }
    return { added, message: `تمت إضافة ${added} دولة إلى التطبيق` };
  }

  /** تغيير حالة دولة (منتج): تظهر أو تختفي عن العميل */
  async toggleProduct(id: string) {
    const product = await this.productModel.findById(id);
    if (!product) throw new NotFoundException('المنتج غير موجود');
    product.isActive = product.isActive === false;
    await product.save();
    return {
      isActive: product.isActive,
      message: product.isActive ? 'تم تفعيل الدولة' : 'تم إيقاف الدولة',
    };
  }

  async removeProduct(id: string) {
    const product = await this.productModel.findById(id);
    if (!product) throw new NotFoundException('المنتج غير موجود');
    await product.deleteOne();
    return { message: 'تم حذف الدولة من التطبيق' };
  }

  // ===========================================================================
  // خدمات الأرقام اليدوية (تفعيل مضمون) — القسم الأول في صفحة أرقام العميل
  // الخدمة منتج (type=manual) بلا تطبيق متجر، بل مرتبطة بتطبيق أرقام؛ وطلبها
  // يمر عبر /orders نفسه فيسلك مسار الخدمات اليدوية: مشرف مُسند، محفظة ذرّية
  //، عمل في مساحة المشرف، وظهر في «طلباتي».
  // ===========================================================================

  private manualServiceView(service: any, apps: Map<string, any> = new Map()) {
    const app = apps.get(String(service.virtualNumberAppId?._id ?? service.virtualNumberAppId ?? ''));
    return {
      id: service._id.toString(),
      name: service.name,
      description: service.description ?? '',
      instructions: service.instructions ?? '',
      price: Number(service.salePrice) || 0,
      requiredFields: service.requiredFields ?? [],
      estimatedMinutes: service.estimatedMinutes ?? 120,
      isActive: service.isActive !== false,
      appId: app ? app._id.toString() : String(service.virtualNumberAppId ?? ''),
      appName: app?.name ?? '',
      appIcon: app?.iconUrl ?? '',
      // رمز الخدمة يُستعمل لاختيار أيقونة مدمجة عند غياب الأيقونة المخصصة
      appServiceCode: app?.serviceCode ?? '',
      supervisorName: service.assignedSupervisorId?.name ?? '',
      openOrders: service.openOrders ?? null,
    };
  }

  /** خدمات التفعيل المضمون النشطة: تظهر في القسم الأول لعملاء صفحة الأرقام */
  async listActiveManualServices() {
    const services = await this.manualServiceModel
      .find({
        type: ProductType.MANUAL,
        virtualNumberAppId: { $exists: true, $ne: null },
        isActive: true,
      })
      .populate('virtualNumberAppId', 'name iconUrl serviceCode isActive')
      .populate('assignedSupervisorId', 'name')
      .sort({ salePrice: 1, createdAt: -1 })
      .lean();

    return services
      .filter((s: any) => (s.virtualNumberAppId as any)?.isActive !== false)
      .map((s: any) =>
        this.manualServiceView(s, new Map([[String(s.virtualNumberAppId._id), s.virtualNumberAppId]])),
      );
  }

  /** كل خدمات الأرقام اليدوية للإدارة، مع عدد الطلبات الجارية لكل خدمة */
  async listAdminManualServices() {
    const services = await this.manualServiceModel
      .find({
        type: ProductType.MANUAL,
        virtualNumberAppId: { $exists: true, $ne: null },
      })
      .populate('virtualNumberAppId', 'name iconUrl serviceCode')
      .populate('assignedSupervisorId', 'name email phone')
      .sort({ createdAt: -1 })
      .lean();

    const open = await this.orderModel.aggregate<{ serviceId: string; count: number }>([
      {
        $match: {
          virtualNumberAppId: { $exists: true, $ne: null },
          status: {
            $nin: [OrderStatus.COMPLETED, OrderStatus.REFUNDED, OrderStatus.REJECTED],
          },
        },
      },
      { $group: { _id: '$productId', count: { $sum: 1 } } },
      { $project: { serviceId: { $toString: '$_id' }, count: 1 } },
    ]);
    const openByService = new Map(open.map((row) => [row.serviceId, row.count]));

    return services.map((s: any) => ({
      ...this.manualServiceView(s, new Map([[String(s.virtualNumberAppId?._id), s.virtualNumberAppId]])),
      sensitiveFields: s.sensitiveFields ?? [],
      isSensitive: Boolean(s.isSensitive),
      supervisorId: s.assignedSupervisorId?._id
        ? String(s.assignedSupervisorId._id)
        : null,
      openOrders: openByService.get(String(s._id)) ?? 0,
    }));
  }

  /** معرّف صالح أو null (المشرف اختياري: الخدمة قد تُسلَّم لأي مشرف متاح) */
  private toOidOrNull(value: any, label: string): Types.ObjectId | null {
    const clean = typeof value === 'string' ? value.trim() : '';
    if (!clean) return null;
    if (!Types.ObjectId.isValid(clean)) {
      throw new BadRequestException(label);
    }
    return new Types.ObjectId(clean);
  }

  async createManualService(dto: {
    name?: string;
    vnAppId?: string;
    supervisorId?: string;
    price?: number;
    description?: string;
    instructions?: string;
    requiredFields?: string[];
    estimatedMinutes?: number;
    isSensitive?: boolean;
    isActive?: boolean;
  }) {
    const name = (dto.name || '').trim();
    if (!name) throw new BadRequestException('اسم الخدمة مطلوب');
    const vnApp = await this.appModel.findById((dto.vnAppId || '').trim());
    if (!vnApp) throw new BadRequestException('اختر تطبيق أرقام أولاً');
    const price = Number(dto.price);
    if (!Number.isFinite(price) || price <= 0) {
      throw new BadRequestException('حدد سعر الخدمة بالدولار');
    }

    const supervisorId = this.toOidOrNull(
      dto.supervisorId,
      'معرّف المشرف غير صالح',
    );
    if (supervisorId) {
      const supervisor = await this.userModel.findById(supervisorId);
      if (!supervisor) throw new BadRequestException('المشرف غير موجود');
    }

    const requiredFields = (dto.requiredFields ?? [])
      .map((f) => String(f).trim())
      .filter(Boolean);
    // البيانات الحساسة تُشفَّر وتُحفَر في الطلب: الحقول المطلوبة كلها محتملة الحساسية
    const isSensitive = dto.isSensitive === true;

    const saved = await this.manualServiceModel.create({
      virtualNumberAppId: vnApp._id,
      name,
      description: (dto.description || '').trim(),
      type: ProductType.MANUAL,
      // لا هامش ولا تكلفة مزود: السعر الذي تحدده الإدارة هو ما يُخصم من العميل
      costPrice: 0,
      profitMarginType: ProfitMarginType.FIXED,
      profitMarginValue: 0,
      salePrice: price,
      kind: 'service',
      quantityLabel: '',
      requiredFields: requiredFields.length > 0 ? requiredFields : ['المعرف'],
      estimatedMinutes: Number(dto.estimatedMinutes) || 120,
      isSensitive,
      sensitiveFields: isSensitive ? requiredFields : [],
      instructions: (dto.instructions || '').trim(),
      assignedSupervisorId: supervisorId ?? undefined,
      isActive: dto.isActive !== false,
      inventoryCodes: [],
    });

    await this.reconcileSupervisorRole(supervisorId);
    return { id: saved._id.toString(), message: 'تمت إضافة الخدمة' };
  }

  async updateManualService(
    id: string,
    dto: {
      name?: string;
      vnAppId?: string;
      supervisorId?: string | null;
      price?: number;
      description?: string;
      instructions?: string;
      requiredFields?: string[];
      estimatedMinutes?: number;
      isSensitive?: boolean;
      isActive?: boolean;
    },
  ) {
    const service = await this.manualServiceModel.findById(id);
    if (!service || !service.virtualNumberAppId) {
      throw new NotFoundException('الخدمة غير موجودة');
    }
    const previousSupervisorId = service.assignedSupervisorId
      ? service.assignedSupervisorId.toString()
      : null;

    if (dto.name !== undefined) {
      const name = dto.name.trim();
      if (!name) throw new BadRequestException('اسم الخدمة مطلوب');
      service.name = name;
    }
    if (dto.vnAppId !== undefined) {
      const vnApp = await this.appModel.findById((dto.vnAppId || '').trim());
      if (!vnApp) throw new BadRequestException('اختر تطبيق أرقام أولاً');
      service.virtualNumberAppId = vnApp._id;
    }
    if (dto.price !== undefined) {
      const price = Number(dto.price);
      if (!Number.isFinite(price) || price <= 0) {
        throw new BadRequestException('حدد سعر الخدمة بالدولار');
      }
      service.salePrice = price;
    }
    if (dto.description !== undefined) {
      service.description = (dto.description || '').trim();
    }
    if (dto.instructions !== undefined) {
      service.instructions = (dto.instructions || '').trim();
    }
    if (dto.requiredFields !== undefined) {
      const requiredFields = dto.requiredFields
        .map((f) => String(f).trim())
        .filter(Boolean);
      service.requiredFields =
        requiredFields.length > 0 ? requiredFields : service.requiredFields;
      // الحقول الحساسة مشتقة من المطلوبة: تُحدَّث مع كل تغيير في الحقول
      if (service.isSensitive) service.sensitiveFields = service.requiredFields;
    }
    if (dto.estimatedMinutes !== undefined) {
      service.estimatedMinutes = Number(dto.estimatedMinutes) || 120;
    }
    if (dto.isSensitive !== undefined) {
      service.isSensitive = dto.isSensitive === true;
      service.sensitiveFields = service.isSensitive ? service.requiredFields : [];
    }
    if (dto.isActive !== undefined) service.isActive = dto.isActive !== false;

    const supervisorId = this.toOidOrNull(
      dto.supervisorId,
      'معرّف المشرف غير صالح',
    );
    if (supervisorId) {
      const supervisor = await this.userModel.findById(supervisorId);
      if (!supervisor) throw new BadRequestException('المشرف غير موجود');
    }
    service.assignedSupervisorId = supervisorId ?? undefined;

    await service.save();
    // الرتب تتزامن مع الإسناد: القديم يعود عميلاً إن لم يبقَ لديه عمل، والجديد يُرقّى
    await this.reconcileSupervisorRole(supervisorId);
    if (previousSupervisorId && previousSupervisorId !== supervisorId?.toString()) {
      await this.reconcileSupervisorRole(new Types.ObjectId(previousSupervisorId));
    }
    return { message: 'تم تحديث الخدمة' };
  }

  async toggleManualService(id: string) {
    const service = await this.manualServiceModel.findById(id);
    if (!service || !service.virtualNumberAppId) {
      throw new NotFoundException('الخدمة غير موجودة');
    }
    service.isActive = service.isActive === false;
    await service.save();
    return {
      isActive: service.isActive,
      message: service.isActive ? 'تم تفعيل الخدمة' : 'تم إيقاف الخدمة',
    };
  }

  /** حذف الخدمة؛ الطلبات الجارية تُغلق الخدمة بدل حذفها كي لا يتعطل عمل المشرفين */
  async deleteManualService(id: string) {
    const service = await this.manualServiceModel.findById(id);
    if (!service || !service.virtualNumberAppId) {
      throw new NotFoundException('الخدمة غير موجودة');
    }
    const assignedTo = service.assignedSupervisorId ?? null;
    const openCount = await this.orderModel.countDocuments({
      productId: service._id,
      status: {
        $nin: [OrderStatus.COMPLETED, OrderStatus.REFUNDED, OrderStatus.REJECTED],
      },
    });
    if (openCount > 0) {
      service.isActive = false;
      await service.save();
      await this.reconcileSupervisorRole(assignedTo);
      return {
        deactivated: true,
        message: `أُوقفت الخدمة لوجود ${openCount} طلباً قيد التنفيذ`,
      };
    }
    await service.deleteOne();
    await this.reconcileSupervisorRole(assignedTo);
    return { deactivated: false, message: 'تم حذف الخدمة' };
  }

  /**
   * مزامنة رتبة المشرف مع الإسناد (نفس قاعدة مسار المنتجات): من بقيت لديه
   * خدمة أو طلب غير منتهي يبقى مشرف، ومن زالت إسناداته يعود عميلاً.
   */
  private async reconcileSupervisorRole(
    userId?: Types.ObjectId | string | null,
  ) {
    if (!userId || !Types.ObjectId.isValid(String(userId))) return;
    const user = await this.userModel.findById(userId);
    if (!user || user.role === Role.ADMIN || user.role === Role.AGENT) return;

    const [assignedProducts, activeOrders] = await Promise.all([
      this.manualServiceModel.countDocuments({ assignedSupervisorId: user._id }),
      this.orderModel.countDocuments({
        assignedSupervisorId: user._id,
        status: {
          $nin: [OrderStatus.COMPLETED, OrderStatus.REFUNDED, OrderStatus.REJECTED],
        },
      }),
    ]);

    if (assignedProducts === 0 && activeOrders === 0 && user.role === Role.SUPERVISOR) {
      user.role = Role.USER;
      await user.save();
      this.logger.log(`تم إرجاع المشرف ${user.email} إلى عميل (لا يوجد إسناد)`);
    }
  }

  // ===========================================================================
  // التعويضات والمساعدات
  // ===========================================================================

  private async compensateDuplicateDebit(
    user: UserDocument,
    amount: number,
    existing: VirtualNumberRequestDocument,
  ) {
    try {
      await this.userModel.findByIdAndUpdate(user._id, {
        $inc: { balance: amount },
      });
      await this.transactionModel.create({
        userId: user._id,
        type: TransactionType.REFUND,
        amount,
        balanceBefore: Number((user.balance ?? 0).toFixed(2)),
        balanceAfter: Number(((user.balance ?? 0) + amount).toFixed(2)),
        description: `إرجاع تلقائي لسحب مكرّر لطلب رقم #${existing.requestNumber}`,
        referenceType: 'VirtualNumber',
        referenceId: existing._id.toString(),
        status: TransactionStatus.COMPLETED,
      });
    } catch (err: any) {
      this.logger.error(`Duplicate-debit compensation failed for ${user._id}: ${err.message}`);
      await this.notifyAdminsSafe(
        'تنبيه مالي: سحب مكرر لرقم وهمي غير معوّض',
        `أُعيد إرسال طلب رقم للعميل ${user.name} بمبلغ $${amount.toFixed(2)} وفشل إرجاع السحب الثاني؛ يلزم تدخل يدوي.`,
      );
    }
  }

  private async refundUnpersistedDebit(
    user: UserDocument,
    amount: number,
    cause: any,
  ) {
    this.logger.error(`Virtual number request persist failed: ${cause?.message}`);
    try {
      await this.userModel.findByIdAndUpdate(user._id, { $inc: { balance: amount } });
    } catch (err: any) {
      this.logger.error(`Emergency refund failed for ${user._id}: ${err.message}`);
      await this.notifyAdminsSafe(
        'تنبيه مالي: خصم بلا تعويض (أرقام وهمية)',
        `خُصم $${amount.toFixed(2)} من العميل ${user.name} لفشل حفظ طلب الرقم وفشل إرجاعه تلقائياً؛ يلزم تدخل يدوي.`,
      );
    }
  }

  private async notifyAdminsSafe(title: string, body: string) {
    try {
      await this.notificationsService.createNotification({
        forRole: 'admin',
        title,
        body,
        type: 'virtual_number_alert',
      });
    } catch (err: any) {
      this.logger.warn(`Admin notification failed (${title}): ${err?.message}`);
    }
  }

  private generateRequestNumber(): string {
    const stamp = new Date().toISOString().slice(2, 10).replace(/-/g, '');
    const rand = crypto.randomBytes(3).toString('hex').toUpperCase();
    return `VN-${stamp}-${rand}`;
  }

  // العرض للعميل: الرقم بصيغة دولية والرمز متاح بعد وصوله فقط
  private toView(request: VirtualNumberRequestDocument) {
    const raw = (request as any).toObject?.() ?? request;
    const appMeta = resolveAppMeta(request.service);
    const countryMeta = resolveCountryMeta(request.country);
    return {
      id: request._id.toString(),
      requestNumber: request.requestNumber,
      service: request.service,
      serviceName: request.serviceName || appMeta.name,
      nameAr: appMeta.nameAr,
      nameEn: appMeta.nameEn,
      icon: appMeta.icon,
      country: request.country,
      countryName: request.countryName || countryMeta.name,
      flag: countryMeta.flag,
      operator: isHiddenServerName(request.operator || '')
        ? ''
        : request.operator,
      amount: Number(request.amount) || 0,
      phoneNumber: request.phoneNumber
        ? `+${String(request.phoneNumber).replace(/[^\d]/g, '')}`
        : null,
      smsCode: request.smsCode ?? null,
      smsText: request.smsText ?? null,
      status: request.status,
      isLive: this.isLive(request),
      note: request.note ?? '',
      expiresAt: request.expiresAt ?? null,
      codeReceivedAt: request.codeReceivedAt ?? null,
      refundedAt: request.refundedAt ?? null,
      createdAt: raw.createdAt ?? null,
    };
  }

  private toAdminView(request: VirtualNumberRequestDocument) {
    const user: any = (request as any).userId;
    return {
      ...this.toView(request),
      // الإدارة ترى السبب الداخلي إن وُجد، وإلا ترى رسالة العميل نفسها
      adminNote: request.adminNote || request.note || '',
      cost: Number(request.cost) || 0,
      profit: Number(request.profit) || 0,
      providerRef: request.providerRef ?? '',
      userName: user?.name ?? '',
      customUserId: user?.userId ?? '',
      userEmail: user?.email ?? '',
      userPhone: user?.phone ?? '',
    };
  }
}
