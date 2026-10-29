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
} from '../../database/schemas/product.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import {
  WalletTransaction,
  WalletTransactionDocument,
  TransactionStatus,
  TransactionType,
} from '../../database/schemas/wallet-transaction.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { HEROSMS_DEFAULT_ENDPOINT } from './herosms.client';
import { VirtualNumberClient, VirtualNumberHandle } from './virtual-number-client';
import {
  VIRTUAL_NUMBER_PROVIDER_TYPES,
  createVirtualNumberClient,
} from './virtual-number-clients';

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
      countries: any[];
      fromPrice: number;
    }> = [];

    for (const app of apps) {
      const svc = byService.get(app.serviceCode);
      if (!svc) continue; // الخدمة غابت عن كتالوج المزود الحالي: لا تُعرض
      const catalogByCountry = new Map(
        (svc.countries ?? []).map((c) => [c.code, c]),
      );

      const countries = (productsByApp.get(app._id.toString()) ?? [])
        .map((product) => {
          // السعر من الكتالوج الحيّ إن وُجدت الدولة، وإلا من لقطة المنتج
          const live = catalogByCountry.get(product.countryCode);
          const cost = Number(live?.cost ?? product.cost) || 0;
          const salePrice = this.computeSalePrice(cost, marginType, marginValue);
          return {
            code: product.countryCode,
            name: live?.name || product.countryName || product.countryCode,
            cost,
            count: live?.count ?? product.count ?? 0,
            operators: live?.operators ?? product.operators ?? [],
            salePrice,
          };
        })
        .filter((country) => country.salePrice > 0)
        .sort((a, b) => a.salePrice - b.salePrice);

      if (countries.length === 0) continue; // تطبيق بلا دولة مفعّلة بسعر صالح
      out.push({
        code: app.serviceCode,
        name: app.name || svc.name || app.serviceCode,
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

    const counts = await this.productModel.aggregate<{
      _id: Types.ObjectId;
      total: number;
      active: number;
    }>([
      {
        $match: {
          appId: { $in: apps.map((a) => a._id) },
        },
      },
      {
        $group: {
          _id: '$appId',
          total: { $sum: 1 },
          active: {
            $sum: { $cond: [{ $eq: ['$isActive', true] }, 1, 0] },
          },
        },
      },
    ]);
    const countMap = new Map(counts.map((c) => [c._id.toString(), c]));

    return apps.map((app) => {
      const stat = countMap.get(app._id.toString());
      return {
        id: app._id.toString(),
        name: app.name,
        iconUrl: app.iconUrl ?? '',
        serviceCode: app.serviceCode,
        isActive: app.isActive !== false,
        sortOrder: app.sortOrder ?? 0,
        productCount: stat?.total ?? 0,
        activeProductCount: stat?.active ?? 0,
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
      await this.appModel.create({
        name: svc.name || svc.code,
        serviceCode: svc.code,
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
        return {
          code: svc.code,
          name: svc.name,
          countryCount: (svc.countries ?? []).length,
          appId: app ? app._id.toString() : null,
          appName: app?.name ?? '',
          appActive: app ? app.isActive !== false : false,
          countries: (svc.countries ?? []).map((c) => {
            const product = productByKey.get(`${svc.code}|${c.code}`);
            const cost = Number(c.cost) || 0;
            return {
              code: c.code,
              name: c.name,
              cost,
              count: c.count ?? 0,
              operators: c.operators ?? [],
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
    return {
      id: request._id.toString(),
      requestNumber: request.requestNumber,
      service: request.service,
      serviceName: request.serviceName,
      country: request.country,
      countryName: request.countryName,
      operator: request.operator,
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
