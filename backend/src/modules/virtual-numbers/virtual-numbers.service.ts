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
  VirtualNumberOutcome,
  VirtualNumberOutcomeSource,
  VirtualNumberQualityEvent,
  VirtualNumberQualityEventDocument,
} from '../../database/schemas/virtual-number-quality-event.schema';
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
import {
  Order,
  OrderDocument,
  OrderStatus,
} from '../../database/schemas/order.schema';
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
import {
  classifyOutcome,
  resolveFailThreshold,
  OUTCOME_COUNTER_FIELD,
} from './virtual-number-quality';
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
// مدة صلاحية اسم السيرفر في الذاكرة: كل عرض طلب يحتاجه، وإعادة قراءته لكل
// طلب استعلام زائد على مزود لا يتغير اسمه إلا من اللوحة
const PROVIDER_META_TTL_MS = 60 * 1000;

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
  // اسم السيرفر الوهمي + الاسم الحقيقي لكل مزود، سارية `PROVIDER_META_TTL_MS`
  private readonly providerMetaCache = new Map<
    string,
    { label: string; name: string; at: number }
  >();

  constructor(
    @InjectModel(VirtualNumberRequest.name)
    private readonly requestModel: Model<VirtualNumberRequestDocument>,
    @InjectModel(VirtualNumberCatalog.name)
    private readonly catalogModel: Model<VirtualNumberCatalogDocument>,
    @InjectModel(VirtualNumberApp.name)
    private readonly appModel: Model<VirtualNumberAppDocument>,
    @InjectModel(VirtualNumberProduct.name)
    private readonly productModel: Model<VirtualNumberProductDocument>,
    // سجل أحداث الجودة: يُكتب منه كل نتيجة شراء، وتقرأ منه اللوحة أسباب الفشل
    @InjectModel(VirtualNumberQualityEvent.name)
    private readonly qualityEventModel: Model<VirtualNumberQualityEventDocument>,
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

    // ترحيل هوية المنتج إلى (تطبيق + مزود + دولة): بلا إسقاط الفهرس القديم
    // ستظل إضافة نفس الدولة من مزود ثانٍ تفشل بصمت، وهو جوهر تعدد المزودين.
    // الفواصل هنا محلية تماماً (لا طلبات شبكة) فلا تُعلّق الإقلاع.
    void this.healProductIdentity()
      .then(() => this.dropLegacyProductIndex())
      .catch((err: any) =>
        this.logger.warn(`Virtual numbers migration skipped: ${err?.message}`),
      );
  }

  /**
   * يُكمل ما ينقص وثائق ما قبل تعدد المزودين: providerId على المنتج (كان اختيارياً)
   * وappKey على التطبيق، والأسماء الوهمية لمزودي الأرقام.
   * لا يمسّ ما هو معبأ أصلاً، فيُمكن إعادة التشغيل بلا أثر.
   */
  private async healProductIdentity() {
    const numberProviders = await this.providerModel
      .find({ providerType: { $in: VIRTUAL_NUMBER_PROVIDER_TYPES } })
      .sort({ createdAt: 1 });

    // اسم وهمي لكل مزود أرقام: اللوحة تعدّله، والعميل لا يرى غيره
    let index = 0;
    for (const provider of numberProviders) {
      index += 1;
      if (!(provider as any).serverLabel) {
        await this.providerModel.updateOne(
          { _id: provider._id },
          { $set: { serverLabel: `Server ${index}` } },
        );
        (provider as any).serverLabel = `Server ${index}`;
      }
    }

    // التطبيق بلا appKey = كي لا يبقى منطقياً واحداً عبر المزودين
    const apps = await this.appModel.find({});
    for (const app of apps) {
      if (app.appKey) continue;
      const key = resolveAppMeta(
        app.serviceCode,
        app.providerId
          ? numberProviders.find((p) => p._id.equals(app.providerId))
              ?.providerType
          : undefined,
      ).key;
      if (!key) continue;
      await this.appModel.updateOne(
        { _id: app._id },
        { $set: { appKey: key } },
      );
      app.appKey = key;
    }

    // المزود الوحيد يُنسب لكل منتجاته؛ ومع أكثر من مزود لا يُخمَّن، فتُترك
    // للوحة (تُنشأ المنتجات الجديدة به حتماً) حتى لا تُنسب لفاسد فتُقيَّم عليه
    const sole = numberProviders.length === 1 ? numberProviders[0] : null;
    if (!sole) return;
    // {field: null} في Mongo يطابق الحقل الغائب أيضاً، فلا حاجة لـ $in
    await this.productModel.updateMany(
      { providerId: null },
      { $set: { providerId: sole._id } },
    );
  }

  /**
   * يسقط الفهرس الفريد القديم {appId, countryCode} إن بقي من إصدار سابق.
   * Mongoose لا يحذف الفهارس القديمة من تلقاء نفسه، فالفهرس العتيق سيستمر في
   * رفض الدولة نفسها من مزود ثانٍ ولو تغيّر تعريف المخطط. تُقرأ الفهارس من
   * المجموعة الحيّة لا من المخطط، لأن المخطط أصبح يصف الفهرس الجديد.
   */
  private async dropLegacyProductIndex() {
    const live: Array<{
      name?: string;
      unique?: boolean;
      key?: Record<string, any>;
    }> = await this.productModel.collection.indexes().catch(() => []);

    const legacy = live.filter(
      (idx) =>
        idx.unique === true &&
        Object.keys(idx.key ?? {}).join(',') === 'appId,countryCode',
    );
    if (legacy.length === 0) return;

    for (const idx of legacy) {
      const name = idx.name ?? 'appId_1_countryCode_1';
      await this.productModel.collection.dropIndex(name).catch((err: any) => {
        // «not found» نتيجة مقبولة: الفهرس أُسقط في إقلاع سابق
        this.logger.warn(
          `Legacy product index ${name} not dropped: ${err?.message}`,
        );
      });
    }
    this.logger.log(
      `Dropped ${legacy.length} legacy virtual-number product unique index(es)`,
    );
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
   * كل مزودي الأرقام النشطين: العرض للعميل صار متعدداً، فواتساب-الفلبين قد يأتي
   * من سيرفرين وعرضان مستقلان يظهران معاً بلا دمج ولا اختيار أرخص.
   * لا سجلات مفعّلة → مفاتيح env كما كان؛ وأما السجلات الموقوفة كلها فتبقى بلا
   * مزود نشط فتُبلَّغ الصفحة بـ providerStopped وتُخفى الأرقام.
   */
  private async resolveActiveProviders(): Promise<ProviderDocument[]> {
    const filter = {
      providerType: { $in: VIRTUAL_NUMBER_PROVIDER_TYPES },
      isActive: { $ne: false },
    };
    const found = await this.providerModel.find(filter).sort({ createdAt: 1 });
    if (found.length > 0) return found;

    const configured = await this.providerModel.findOne({
      providerType: { $in: VIRTUAL_NUMBER_PROVIDER_TYPES },
    });
    if (configured) return []; // اللوحة أوقفتهم كلها: لا التفاف بمفاتيح env

    const fromEnv = this.buildEnvProvider();
    return fromEnv ? [fromEnv] : [];
  }

  /**
   * خيارات الأرقام المعروضة للعميل: تُقرأ من التخزين المحلي وإن تجاوز مهلته,
   * ويُجلب الجديد من المزود عند الغياب فقط حتى لا تتعطل الصفحة بتعطل مزود واحد.
   * المرجع المنتجاتُ لا الكتالوج: لكل تطبيق مفعّل دوله المفعّلة غير الموقوفة
   * جودةً، وتحتها عروض كل مزود يبيعها — كل عرض بسعره ومخزونه ومشغّلاته.
   */
  async getOptions() {
    const providers = await this.resolveActiveProviders();
    if (providers.length === 0) {
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
            type:
              stoppedProvider.profitMarginType ?? ProfitMarginType.PERCENTAGE,
            value: stoppedProvider.profitMarginValue ?? 0,
          },
          services: [],
          // «تفعيل مضمون» يُنفّذه المشرف بلا مزود، فيبقى معروضاً ولو توقّف المزود
          manualServices: await this.safeManualServices(),
          syncedAt: null,
        };
      }
    }

    const ids = providers.map((p) => p._id);
    let catalogs = await this.catalogModel.find({ providerId: { $in: ids } });

    // أي كتالوج غائب أو قديم يُجدَّد، وكل مزود في فرع مستقل: تعطل مزود لا
    // يُعطّل الصفحة ولا يمسح كتالوج أخيه، بل تبقى لقطة منتجاته تُسعّر العرض
    const staleIds = providers
      .filter((p) => {
        const catalog = catalogs.find((c) => c.providerId?.equals(p._id));
        return (
          !catalog ||
          !catalog.fetchedAt ||
          Date.now() - new Date(catalog.fetchedAt).getTime() > CATALOG_TTL_MS
        );
      })
      .map((p) => String(p._id));

    if (staleIds.length > 0) {
      await Promise.allSettled(
        providers
          .filter((p) => staleIds.includes(String(p._id)))
          .map((p) =>
            this.syncCatalog(p).catch((err: any) => {
              this.logger.warn(
                `Virtual numbers catalog refresh failed for ${p.name}: ${err.message}`,
              );
            }),
          ),
      );
      catalogs = await this.catalogModel.find({ providerId: { $in: ids } });
    }

    const services = await this.buildCuratedServices(providers, catalogs);
    const syncedAt =
      catalogs
        .map((c) => (c.fetchedAt ? new Date(c.fetchedAt).getTime() : 0))
        .sort((a, b) => b - a)[0] ?? null;

    return {
      available: services.length > 0,
      // هوية المزود وأخطاؤه الداخلية للإدارة فقط: payload العميل يحمل مؤشر إتاحة
      // بلا أسماء ولا رسائل مزودين، حتى لا يُستنتج من الشاشة مورد الخدمة
      providerOnline: providers.some((p) => p.status === ProviderStatus.ONLINE),
      waitMinutes: this.waitTtlMinutes(),
      // الكتالوج مُنتقًى: تُبلغ الصفحة الإدارةَ بعدّة التطبيقات كي تعرف إن كان
      // عليها تنسيق المنتجات قبل أن تظهر أي أرقام للعملاء
      curated: await this.appModel.countDocuments({}),
      // الهامش لم يعد واحداً: كل عرض يحمل سعره المحسوب بهامش مزوده، وهذا الحقل
      // يبقى للعرض فقط (مزود واحد على الأقل) كي لا تنكسر واجهات قديمة تقرأه
      margin: {
        type: providers[0]?.profitMarginType ?? ProfitMarginType.PERCENTAGE,
        value: providers[0]?.profitMarginValue ?? 0,
      },
      services,
      // القسم الأول في صفحة الأرقام: خدمات التفعيل المضمون (يدوية بمشرف)
      manualServices: await this.safeManualServices(),
      syncedAt,
    };
  }

  /**
   * قسم «تفعيل مضمون» زائد على قائمة الأرقام: تعذّر قراءته (مرجع مكسور أو خطأ
   * عرض) يترك القسم فارغاً ولا يُسقط صفحة الأرقام كلها في 500.
   */
  private async safeManualServices() {
    try {
      return await this.listActiveManualServices();
    } catch (err: any) {
      this.logger.warn(`Guaranteed manual services skipped: ${err.message}`);
      return [];
    }
  }

  /**
   * يَبني قائمة العميل من المُنتقى فقط، وعبر كل المزودين: التطبيقات تُجمَّع
   * بمفتاحها المنطقي (واتساب تطبيق واحد وإن اختلف رمزه لدى مزودين)، وتحتها
   * الدول مجمّعة برمزها القانوني، وكل دولة تحمل عروض مزوديها مستقلة.
   *
   * كل عرض يقرأ تكلفته ومخزونه ومشغّلاته من كتالوج مزوده الحيّ؛ وإن غاب الكتالوج
   * يرجع إلى لقطة المنتج — فيبقى العرض معروضاً بسعره ولو تعطل المزود مؤقتاً.
   */
  private async buildCuratedServices(
    providers: ProviderDocument[],
    catalogs: VirtualNumberCatalogDocument[],
  ) {
    const apps = await this.appModel
      .find({ isActive: true })
      .sort({ sortOrder: 1, createdAt: -1 });
    if (apps.length === 0) return [];

    // الموقوف جودةً لا يُعرض للعميل ولا يُباع، لكن يبقى في اللوحة بمحاسبة مزوده وحده
    const products = await this.productModel.find({
      appId: { $in: apps.map((a) => a._id) },
      isActive: true,
      autoDisabled: { $ne: true },
    });
    if (products.length === 0) return [];

    const providersById = new Map(providers.map((p) => [String(p._id), p]));
    const catalogsByProvider = new Map(
      catalogs.map((c) => [String(c.providerId), c.services ?? []]),
    );
    const appsById = new Map(apps.map((a) => [String(a._id), a]));

    // appId منطقي → رمز دولة قانوني → عروض
    const appGroups = new Map<
      string,
      { apps: VirtualNumberAppDocument[]; countries: Map<string, any[]> }
    >();

    for (const product of products) {
      const app = appsById.get(String(product.appId));
      const provider = providersById.get(String(product.providerId));
      if (!app || !provider) continue; // منتج لمزود موقوف: لا يُعرض ولا يُباع

      const appKey =
        app.appKey ||
        resolveAppMeta(app.serviceCode, provider.providerType).key ||
        app.serviceCode;
      const cMeta = resolveCountryMeta(
        product.countryCode || product.countryName,
        provider.providerType,
      );
      // التجميع برمز الدولة كما لدى المزود لا بالرمز القانوني من المعجم: الرموز
      // تتقاطع بين المزودين (٢٠ مصر عند 5sim ومولدوفا عند Hero-SMS)، فتوحيدَها
      // كان يدمج دولتين مختلفتين في صف واحد
      const countryKey = (
        product.countryCode ||
        product.countryName ||
        ''
      ).trim();

      // كتالوج هذا المزود بالذات، ودولته عنده برمزها الأصلي لا برمز غيره
      const services = catalogsByProvider.get(String(provider._id)) ?? [];
      const svc = services.find((s) => s.code === product.serviceCode);
      const live = (svc?.countries ?? []).find(
        (c) => c.code === product.countryCode,
      );

      const cost = Number(live?.cost ?? product.cost) || 0;
      const salePrice = this.computeSalePrice(
        cost,
        provider.profitMarginType ?? ProfitMarginType.PERCENTAGE,
        provider.profitMarginValue ?? 0,
      );
      if (salePrice <= 0) continue; // بلا سعر صالح: لا يُعرض ولا يُباع

      const offer = {
        productId: String(product._id),
        providerId: String(provider._id),
        // الاسم الوهمي وحده يذهب للعميل؛ اسم المزود الحقيقي لا يغادر اللوحة
        serverLabel: (provider as any).serverLabel || 'Server',
        service: product.serviceCode,
        country: product.countryCode,
        countryName: live?.name || product.countryName || cMeta.name,
        cost,
        salePrice,
        count: live?.count ?? product.count ?? 0,
        operators: visibleOperators(live?.operators ?? product.operators),
      };

      const group = appGroups.get(appKey) ?? {
        apps: [],
        countries: new Map<string, any[]>(),
      };
      if (!group.apps.some((a) => String(a._id) === String(app._id))) {
        group.apps.push(app);
      }
      const list = group.countries.get(countryKey) ?? [];
      if (!list.some((o) => o.productId === offer.productId)) list.push(offer);
      group.countries.set(countryKey, list);
      appGroups.set(appKey, group);
    }

    const out: Array<Record<string, any>> = [];
    for (const [, group] of appGroups) {
      // التطبيق الممثل هو أقدم تطبيق منطقي في الترتيب: اسمه وأيقونته ورمزه
      // للواجهة القديمة (service/country)، والعروض تُباع بمعرّف منتجها
      const app = group.apps[0];
      const repProvider =
        providersById.get(String(app.providerId)) ?? providers[0];
      const appMeta = resolveAppMeta(
        app.serviceCode,
        repProvider?.providerType,
      );
      const repCatalog = catalogsByProvider.get(String(repProvider?._id)) ?? [];
      const repSvc = repCatalog.find((s) => s.code === app.serviceCode);

      const countries = [...group.countries.entries()]
        .map(([code, offers]) => {
          const cheapest = offers.reduce(
            (best, o) => (o.salePrice < best.salePrice ? o : best),
            offers[0],
          );
          const owner = providersById.get(cheapest.providerId);
          const meta = resolveCountryMeta(code, owner?.providerType);
          return {
            code,
            name:
              cheapest.countryName ||
              offers.map((o) => o.countryName).find(Boolean) ||
              meta.name,
            nameAr: meta.nameAr,
            nameEn: meta.nameEn,
            flag: meta.flag,
            iso: meta.iso,
            // الحقول القديمة = أرخص عرض، فتبقى الواجهات التي لا تعرف offers تعمل
            cost: cheapest.cost,
            salePrice: cheapest.salePrice,
            count: cheapest.count,
            operators: cheapest.operators,
            // العرض للعميل: بطاقات مستقلة، بلا دمج ولا اختيار أرخص تلقائي
            offers,
          };
        })
        .filter((country) => country.salePrice > 0)
        .sort((a, b) => a.salePrice - b.salePrice);

      if (countries.length === 0) continue; // تطبيق بلا دولة مفعّلة بسعر صالح
      out.push({
        code: app.serviceCode,
        name: app.name || (repSvc as any)?.name || appMeta.name,
        nameAr: (repSvc as any)?.nameAr || appMeta.nameAr,
        nameEn: (repSvc as any)?.nameEn || appMeta.nameEn,
        icon: app.iconUrl || (repSvc as any)?.icon || appMeta.icon,
        herosmsCode: (repSvc as any)?.herosmsCode || appMeta.herosmsCode,
        fivesimCode: (repSvc as any)?.fivesimCode || appMeta.fivesimCode,
        countries,
        // «من $X»: أقل عروض التطبيق كلها، والترتيب الحالي يبقى عاملاً
        fromPrice: Math.min(...countries.map((c) => c.salePrice)),
      });
    }

    return out.sort((a, b) => a.fromPrice - b.fromPrice);
  }

  /**
   * مزامنة الكتالوج: بلا وسيط تمرّ على كل مزود أرقام نشط (اللوحة تُحدّث السيرفرات
   * كلها بزر واحد)، ومع مزود مُمرَّر تُزامنه وحده (زر داخل صفحة المزود ومسار
   * التجديد التلقائي في getOptions).
   */
  async syncCatalog(providerInput?: ProviderDocument) {
    if (providerInput) return this.syncProviderCatalog(providerInput);

    let targets: ProviderDocument[] = [];
    try {
      targets = await this.resolveActiveProviders();
    } catch (err: any) {
      this.logger.warn(`Catalog fan-out found no provider: ${err?.message}`);
    }
    if (targets.length === 0) {
      // لا مزود مسجل إطلاقاً: fallback البيئة يحفظ سلوك الإطلاق القديم
      targets = [await this.resolveProvider()];
    }

    const settled = await Promise.allSettled(
      targets.map((provider) => this.syncProviderCatalog(provider)),
    );
    const results = targets.map((provider, i) => {
      const outcome = settled[i];
      return outcome.status === 'fulfilled'
        ? {
            providerId: provider._id.toString(),
            serverLabel: provider.serverLabel || '',
            serviceCount: outcome.value.serviceCount,
            error: '',
          }
        : {
            providerId: provider._id.toString(),
            serverLabel: provider.serverLabel || '',
            serviceCount: 0,
            error: (outcome.reason as any)?.message || 'تعذر جلب القائمة',
          };
    });
    const synced = results.filter((r) => r.serviceCount > 0);
    const serviceCount = synced.reduce((sum, r) => sum + r.serviceCount, 0);

    if (synced.length === 0) {
      // كل المزودين أخفقوا: نفس سلوك الخطأ السابق حتى يرى المدير السبب
      throw new BadRequestException(
        results[0].error || 'تعذر جلب القائمة من المزود',
      );
    }

    return {
      message:
        targets.length > 1
          ? `تم تحديث قائمة الأرقام (${serviceCount} خدمة من ${synced.length}/${targets.length} سيرفر)`
          : `تم تحديث قائمة الأرقام (${serviceCount} خدمة)`,
      serviceCount,
      providers: results,
    };
  }

  /** مزامنة كتالوج مزود واحد وتخزينه */
  private async syncProviderCatalog(provider: ProviderDocument) {
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
    const raw = Number(
      this.configService.get<string>('VIRTUAL_NUMBER_TTL_MINUTES'),
    );
    return Number.isFinite(raw) && raw > 0
      ? Math.min(raw, 60)
      : DEFAULT_WAIT_TTL_MINUTES;
  }

  // ===========================================================================
  // طلب رقم (خصم المحفظة ثم طلب المزود)
  // ===========================================================================

  async requestNumber(params: {
    userId: string;
    service?: string;
    country?: string;
    operator?: string;
    clientRequestId?: string;
    // معرّف المنتج (تطبيق+دولة+مزود): المسار الجديد للعرض المتعدد، حيث لا تكفي
    // الخدمة والدولة لتحديد المزود لأن نفس الدولة قد تُباع من سيرفرين
    productId?: string;
  }) {
    const user = await this.userModel.findById(params.userId);
    if (!user) throw new NotFoundException('المستخدم غير موجود');

    const cleanService = (params.service || '').trim();
    const cleanCountry = (params.country || '').trim();
    const cleanProductId = (params.productId || '').trim();

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

    const unavailable = new BadRequestException(
      'هذه الخدمة أو الدولة غير متاحة حالياً',
    );

    let provider: ProviderDocument;
    let product: VirtualNumberProductDocument | null = null;
    let service = cleanService;
    let country = cleanCountry;

    if (cleanProductId) {
      // المنتج هو وحدة البيع: مزوده وهامشه ورموزه تُؤخذ منه هو، لا من مزود مُحال
      if (!Types.ObjectId.isValid(cleanProductId)) throw unavailable;
      product = await this.productModel
        .findById(cleanProductId)
        .catch(() => null);
      if (
        !product ||
        product.isActive === false ||
        product.autoDisabled === true
      ) {
        throw unavailable;
      }
      const [app, found] = await Promise.all([
        this.appModel.findById(product.appId).catch(() => null),
        this.providerModel.findById(product.providerId).catch(() => null),
      ]);
      // التطبيق مفعّل والمزود نشط: وإلا فالعرض صار قديماً ولا يُباع
      if (!app || app.isActive !== true || !found || found.isActive === false) {
        throw unavailable;
      }
      provider = found;
      // الرمز المُرسَل للمزود هو رمز هذا المزود الأصلي، لا رمز التطبيق
      service = product.serviceCode;
      country = product.countryCode;
    } else {
      // المسار القديم (خدمة+دولة) يبقى أثناء الإطلاق: المزود يُحال كما كان
      if (!cleanService || !cleanCountry) {
        throw new BadRequestException('يرجى اختيار الخدمة والدولة أولاً');
      }
      provider = await this.resolveProvider();
      product = await this.assertCurated(cleanService, cleanCountry);
    }

    if (provider.isActive === false) {
      throw new BadRequestException(
        'خدمة الأرقام الوهمية متوقفة حالياً، ولم يتم خصم أي مبلغ من رصيدك',
      );
    }

    const picked = await this.pickPrice(provider, service, country);
    const { cost, salePrice, serviceName, countryName } = picked;

    // رصيد المزود يجب أن يغطي التكلفة قبل المساس بمحفظة العميل
    await this.ensureProviderFunded(provider, cost);

    const requestNumber = this.generateRequestNumber();
    const cleanRequestId =
      typeof params.clientRequestId === 'string' &&
      params.clientRequestId.trim()
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
        // المنتج يُخلَّد على الطلب: هو عقدة تسجيل الجودة، وكتالوج المزود قد يتغير
        productId: product?._id,
        service,
        serviceName,
        country,
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
            request: await this.viewForClient(existing),
            newBalance: Number(
              ((await this.userModel.findById(user._id))?.balance ?? 0).toFixed(
                2,
              ),
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
        description: `تفعيل رقم وهمي (${serviceName || service})`,
        referenceType: 'VirtualNumber',
        referenceId: request._id.toString(),
        status: TransactionStatus.COMPLETED,
      });
    } catch (ledgerErr: any) {
      // المال سُحب والدفتر لم يسجّل: نُرجعه فوراً ونُغلق الطلب
      this.logger.error(
        `Virtual number ledger entry failed for ${requestNumber}: ${ledgerErr.message}`,
      );
      await this.refundRequest(
        request,
        'تعذر تسجيل الحركة المالية، تم إرجاع المبلغ',
      );
      throw new BadRequestException(
        'تعذر إتمام العملية، لم يتم خصم أي مبلغ من رصيدك',
      );
    }

    // طلب الرقم من المزود: الفشل يُرجع المال فوراً (لم يستفد العميل من شيء)
    const client = this.clientFor(provider);
    let number: VirtualNumberHandle;
    try {
      number = await client.requestNumber({
        // رمزا هذا المزود الأصليان، لا ما أرسله العميل: المنتج قد يحمل 'wa' بينما
        // أرسل العميل رمز التطبيق 'whatsapp'
        service,
        country,
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
        // تُسجَّل قبل الإرجاع وتُنتظر: النص الخام من المزود هو وحده ما يميّز نفاد
        // المخزون عن غيره، والإرجاع لن يسجّل نتيجة ثانية بعدها (المطالبة حُسمت).
        await this.recordOutcome(request, 'request', reason).catch(
          () => undefined,
        );
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
      `العميل ${user.name} فعّل رقم #${requestNumber} لخدمة ${serviceName || service} بمبلغ $${salePrice.toFixed(2)}`,
    );

    return {
      message: 'تم تجهيز الرقم، أدخله في التطبيق المطلوب وسيصل الرمز تلقائياً',
      request: await this.viewForClient(request),
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

    let entry = this.findCatalogEntry(
      catalog?.services ?? [],
      service,
      country,
    );
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
        this.logger.warn(
          `Virtual numbers readiness check failed: ${err.message}`,
        ),
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
  async syncRequest(
    request: VirtualNumberRequestDocument,
  ): Promise<VirtualNumberRequestDocument> {
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
      // الرمز وصل: تُسجَّل النتيجة الآن ولا تُؤجَّل للإغلاق، كي لا ينتظر المنتج
      // إغلاق نافذة القراءة كي يُكافأ بتصفير فشله المتتالي
      this.recordOutcomeSafe(request, 'sync');

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
        undefined,
        { source: 'sync' },
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
    this.logger.log(
      `Virtual numbers webhook received: ${JSON.stringify(data).slice(0, 300)}`,
    );

    // 1. استخراج معرف المزود (providerRef)
    const rawRef =
      data.order_id ??
      data.orderId ??
      data.activationId ??
      data.id ??
      data.providerRef ??
      data.ref ??
      data.orderNumber;
    const providerRef =
      rawRef !== undefined && rawRef !== null ? String(rawRef).trim() : '';

    // 2. استخراج رقم الهاتف إن وجد
    const rawPhone = data.phone ?? data.phoneNumber ?? data.phone_number;
    const phoneDigits = rawPhone ? digitsOnly(String(rawPhone)) : '';

    if (!providerRef && !phoneDigits) {
      this.logger.warn(
        'Webhook ignored: missing order_id/activationId and phone number',
      );
      return {
        success: false,
        message: 'Missing order_id or phone number in payload',
      };
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

    let smsCode = pickStringValue(data, [
      'code',
      'smsCode',
      'passcode',
      'otp',
      'pin',
    ]);
    if (!smsCode && smsText) {
      smsCode = extractVerificationCode(smsText) || null;
    }

    // 5. التحقق من حالات الإلغاء أو انتهاء الصلاحية من طرف المزود
    const actionOrStatus = String(
      data.status ?? data.action ?? data.state ?? '',
    ).toUpperCase();
    const isCancelled =
      /CANCEL|TIMEOUT|EXPIRE|BANNED|ACCESS_CANCEL|STATUS_CANCEL/i.test(
        actionOrStatus,
      );

    if (isCancelled) {
      if (this.isLive(request)) {
        await this.refundRequest(
          request,
          'أُلغي الرقم من طرف مزود الأرقام (Webhook)، وتم إرجاع المبلغ إلى محفظتك',
          VirtualNumberStatus.EXPIRED,
          undefined,
          { source: 'webhook' },
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
      // أسرع دليل على وصول الرمز هو ويب هوك المزود: يُسجَّل فوراً ولا يُنتظر الفحص
      this.recordOutcomeSafe(request, 'webhook');

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
    return this.viewForClient(synced);
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
      await Promise.all(live.map((r) => this.syncRequest(r).catch(() => r)));
    }

    return Promise.all(mine.map((r) => this.viewForClient(r)));
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
        undefined,
        'client',
      );
    }
    return this.cancelRequest(
      request,
      reason || 'ألغى العميل الطلب قبل وصول الرمز',
      VirtualNumberStatus.CANCELLED,
      { source: 'client' },
    );
  }

  private async finishRequest(
    request: VirtualNumberRequestDocument,
    note: string,
    adminNote?: string,
    source: VirtualNumberOutcomeSource = 'sync',
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
    // الرمز وصل أصلاً = نجاح؛ ورفض بلا رمز (إغلاق إداري يدوي) يُحسب بلغته
    this.recordOutcomeSafe(request, source);
    return {
      message: 'تم إغلاق الرقم بنجاح',
      request: await this.viewForClient(request),
    };
  }

  /** إلغاء مع إرجاع المبلغ (تُستدعى من العميل ومن المسح الدوري ومن الإدارة) */
  private async cancelRequest(
    request: VirtualNumberRequestDocument,
    note: string,
    status: VirtualNumberStatus = VirtualNumberStatus.CANCELLED,
    // خيارات بدل مواضع متتالية: نسيان source كان سيحسب إلغاء العميل فشلاً على المزود
    options: {
      notifyUser?: boolean;
      adminNote?: string;
      source?: VirtualNumberOutcomeSource;
    } = {},
  ) {
    const { notifyUser = true, adminNote, source = 'sweep' } = options;
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
      {
        source,
        // سجل الجودة الإداري يحتاج سبباً مقروءاً: `note` عبارة عربية مؤلَّفة داخلياً
        // لا نص خطأ مزود خام، فتصلح سبباً في سجل الأحداث بلا كشف مورد الخدمة
        reason: note,
      },
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
      request: await this.viewForClient(request),
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
    // سياق الجودة منفصل عن `reason`: هذا يُكتب للعميل على الطلب، فلا يكون نص
    // خطأ المزود الخام الذي قد يكشف موارده. يُمرَّر وحده عند الحاجة للتصنيف.
    quality?: { source?: VirtualNumberOutcomeSource; reason?: string },
  ): Promise<boolean> {
    const qualitySource = quality?.source ?? 'request';
    const qualityReason = quality?.reason ?? '';
    if (request.refundedAt) return true; // أُرجع سابقاً
    if (request.amount <= 0) {
      request.status = status;
      request.note = reason;
      request.adminNote = adminNote;
      request.closedAt = request.closedAt ?? new Date();
      await request.save().catch(() => undefined);
      this.recordOutcomeSafe(request, qualitySource, qualityReason);
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

    // الطلب أُغلق مالياً: تُسجَّل نتيجته على جودة المنتج. المطالبة الذرّية داخل
    // recordOutcome مستقلة عن هذه، فلا تكرار إن سبقت حملة أخرى الإرجاع.
    this.recordOutcomeSafe(request, qualitySource, qualityReason);

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

    const balanceAfter = Number(
      (credited?.balance ?? request.amount).toFixed(2),
    );
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
  // الجودة: تسجيل النتيجة على المنتج والإيقاف التلقائي
  // ===========================================================================

  /** عتبة الفشل المتتالي من البيئة، وافتراضها 3 */
  private failThreshold(): number {
    return resolveFailThreshold(
      this.configService.get<string>('VIRTUAL_NUMBER_FAIL_THRESHOLD'),
    );
  }

  /**
   * المنتج الذي يُقيَّم هذا الطلب: يُقرأ من productId المُخلَّد على الطلب لحظة
   * الشراء، وأما طلبات ما قبل تعدد المزودين فتُنسب بهوية المزود+رمز الخدمة+الدولة.
   */
  private async resolveQualityProduct(
    request: VirtualNumberRequestDocument,
  ): Promise<VirtualNumberProductDocument | null> {
    if (request.productId) {
      return this.productModel.findById(request.productId).catch(() => null);
    }
    if (!request.providerId) return null;
    return this.productModel
      .findOne({
        providerId: request.providerId,
        serviceCode: request.service,
        countryCode: request.country,
      })
      .catch(() => null);
  }

  /**
   * تسجّل نتيجة شراء واحدة على منتجها، مرة واحدة لكل طلب مهما تعددت المصادر:
   * المسح الدوري والويب هوك وإغلاق العميل قد تصل إلى نفس الطلب متزامنة. المطالبة
   * الذرّية على qualityOutcome (نفس نمط refundedAt في الإرجاع) هي التي تضمن ذلك.
   *
   * الفشل المتتالي يزيد عند FAILED المؤكد وحده، ويصفِر عند SUCCESS؛ أما النتائج
   * غير المحتسبة (إلغاء، نفاد مخزون، انقطاع) فتُسجَّل في السجل بلا أثر على التقييم.
   * بلوغ العتبة يوقف وثيقة المنتج وحدها، فلا يمسّ المنتج المطابق لدى مزود آخر.
   */
  private async recordOutcome(
    request: VirtualNumberRequestDocument,
    source: VirtualNumberOutcomeSource,
    reason = '',
  ): Promise<void> {
    const { outcome, counted } = classifyOutcome(request, source, reason);

    // {field: null} في Mongo يطابق الحقل الغائب أيضاً، فلا يحتاج ترحيلاً سابقاً
    const claimed = await this.requestModel
      .findOneAndUpdate(
        { _id: request._id, qualityOutcome: null },
        { $set: { qualityOutcome: outcome, qualityRecordedAt: new Date() } },
        { new: true },
      )
      .catch(() => null);
    if (!claimed) return; // سبقها مصدر آخر: لا ازدواج في التقييم

    const product = await this.resolveQualityProduct(request);
    if (!product) {
      // لا منتج يُنسب إليه (بيانات قديمة أو منتج حُذف): النتيجة تُترك بلا عدّادات
      // وبلا حدث، لأن سجل الأحداث مربوط بمنتج.
      this.logger.warn(
        `Quality outcome ${outcome} for #${request.requestNumber} has no matching product`,
      );
      return;
    }

    const counterField = OUTCOME_COUNTER_FIELD[outcome];
    const inc: Record<string, number> = { 'quality.totalOrders': 1 };
    if (counterField) inc[`quality.${counterField}`] = 1;
    // غير المحتسب لا يزيد ولا يصفّر العدّاد المتتالي: لا يُعاقَب مزود على إلغاء
    // عميل، ولا يُكافأ بتصفير رصيده حين انقطع الاتصال.
    if (outcome === VirtualNumberOutcome.FAILED) {
      inc['quality.consecutiveFailures'] = 1;
    } else if (outcome === VirtualNumberOutcome.SUCCESS) {
      inc['quality.consecutiveFailures'] = -Number(
        product.quality?.consecutiveFailures || 0,
      );
    }

    // $inc مع {new: true} يعيد الوثيقة بعد الزيادة: هي ما يُقارَن بالعتبة، فلا
    // قراءة ثم كتابة متنافستان تُضلل بلوغ العتبة تحت التزامن.
    const updated = await this.productModel
      .findOneAndUpdate({ _id: product._id }, { $inc: inc }, { new: true })
      .catch((err: any) => {
        this.logger.error(
          `Quality counters failed for product ${product._id}: ${err?.message}`,
        );
        return null;
      });
    if (!updated) return;

    const consecutive = Number(updated.quality?.consecutiveFailures) || 0;
    const threshold = this.failThreshold();
    let stopped = false;
    if (
      outcome === VirtualNumberOutcome.FAILED &&
      consecutive >= threshold &&
      !updated.autoDisabled
    ) {
      stopped = true;
      await this.productModel
        .updateOne(
          { _id: updated._id },
          {
            $set: {
              autoDisabled: true,
              isActive: false,
              disabledAt: new Date(),
              disabledReason: `${consecutive} فشل متتالي مؤكد في وصول الأكواد`,
            },
          },
        )
        .catch(() => undefined);

      const provider = await this.providerModel
        .findById(updated.providerId)
        .catch(() => null);
      await this.notifyAdminsSafe(
        'إيقاف تلقائي لمنتج أرقام وهمية',
        `أُوقف «${provider?.serverLabel || 'سيرفر'}» لتطبيق ${updated.serviceCode} في دولة ${updated.countryName || updated.countryCode} بعد ${consecutive} فشل متتالي مؤكد. يعاد تفعيله من لوحة مراقبة الجودة.`,
      );
    }

    await this.qualityEventModel
      .create({
        productId: updated._id,
        providerId: updated.providerId,
        appId: updated.appId,
        countryCode: updated.countryCode,
        outcome,
        counted,
        requestNumber: request.requestNumber,
        requestId: request._id,
        reason: reason || '',
        source,
      })
      .catch((err: any) =>
        this.logger.warn(`Quality event insert failed: ${err?.message}`),
      );

    if (stopped) {
      // حدث الإيقاف وحده في السجل: اللوحة تعرض «أُوقف تلقائياً» لا فشلاً خامساً
      await this.qualityEventModel
        .create({
          productId: updated._id,
          providerId: updated.providerId,
          appId: updated.appId,
          countryCode: updated.countryCode,
          outcome: VirtualNumberOutcome.AUTO_DISABLED,
          counted: false,
          requestNumber: request.requestNumber,
          requestId: request._id,
          reason: `إيقاف تلقائي بعد ${consecutive} فشل متتالي مؤكد`,
          source: 'system',
        })
        .catch(() => undefined);
    }
  }

  /** لا يُسقط المسار المالي ولا مسار العميل: الجودة فرع، والمال أصل */
  private recordOutcomeSafe(
    request: VirtualNumberRequestDocument,
    source: VirtualNumberOutcomeSource,
    reason = '',
  ): void {
    void this.recordOutcome(request, source, reason).catch((err: any) =>
      this.logger.warn(
        `Quality recording failed for ${request.requestNumber}: ${err?.message}`,
      ),
    );
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
        status: {
          $in: [VirtualNumberStatus.PENDING, VirtualNumberStatus.WAITING],
        },
        expiresAt: { $lte: now },
      });
      for (const request of expired) {
        await this.cancelRequest(
          request,
          `انتهت مهلة انتظار رمز التحقق (${this.waitTtlMinutes()} دقيقة) دون وصول رسالة`,
          VirtualNumberStatus.EXPIRED,
          { source: 'sweep' },
        ).catch((err: any) =>
          this.logger.warn(
            `Expiry sweep failed for ${request.requestNumber}: ${err.message}`,
          ),
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
          undefined,
          'sweep',
        ).catch((err: any) =>
          this.logger.warn(
            `Finish sweep failed for ${request.requestNumber}: ${err.message}`,
          ),
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
          this.logger.warn(
            `Live sweep failed for ${request.requestNumber}: ${err.message}`,
          ),
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

  async getAdminRequests(
    params: { status?: string; search?: string; limit?: number } = {},
  ) {
    const filter: Record<string, any> = {};
    if (params.status && params.status !== 'all') filter.status = params.status;

    const limit = Math.min(Math.max(params.limit ?? 100, 1), 300);
    const rows = await this.requestModel
      .find(filter)
      .populate('userId', 'name email phone userId')
      .sort({ createdAt: -1 })
      .limit(limit);

    const term = (params.search || '').trim().toLowerCase();
    // الإدارة ترى اسم المزود الحقيقي: تُقرأ بيانات المزودات مرة واحدة للمجموعة
    const metas = await Promise.all(
      rows.map((r) => this.providerMetaFor(r.providerId)),
    );
    const adminRows = rows.map((r, i) => this.toAdminView(r, metas[i]));
    if (!term) return adminRows;

    return adminRows.filter((row) =>
      [
        row.requestNumber,
        row.userEmail,
        row.userPhone,
        row.customUserId,
        row.phoneNumber,
        row.serviceName,
        row.service,
        row.countryName,
      ]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(term)),
    );
  }

  async getAdminStats() {
    type StatusRow = {
      _id: string;
      count: number;
      amount: number;
      cost: number;
    };
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

    const byStatus: Record<
      string,
      { count: number; amount: number; cost: number }
    > = {};
    let total = 0;
    let revenue = 0;
    let spend = 0;
    for (const row of rows) {
      byStatus[row._id] = {
        count: row.count,
        amount: row.amount,
        cost: row.cost,
      };
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
      {
        adminNote: `${reason || 'ألغته الإدارة الرقمَ وأرجعت المبلغ للعميل'} (بواسطة الإدارة ${adminId})`,
        source: 'admin',
      },
    );
    return result;
  }

  /** الأدمن: إغلاق رقم بعد تأكيد تسليم الرمز */
  async adminFinishRequest(id: string, reason?: string) {
    const request = await this.requestModel.findById(id);
    if (!request) throw new NotFoundException('الطلب غير موجود');
    if (!this.isLive(request))
      throw new BadRequestException('الطلب مغلق بالفعل');
    return this.finishRequest(
      request,
      'تم إغلاق الرقم بعد استلام رمز التحقق',
      reason || 'أغلقت الإدارة الطلب بعد استلام الرمز',
      'admin',
    );
  }

  /** حالة اتصال المزود كما تراها الإدارة (زر الفحص في اللوحة) */
  async adminCheckProvider() {
    const provider = await this.resolveProvider();
    const profile = await this.refreshProviderBalance(provider);
    const catalog = await this.catalogModel.findOne({
      providerId: provider._id,
    });
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
    // المنتج الموقوف جودةً لا يُباع: نفس رسالة غياب الخدمة كي لا يكشف للعميل
    // أن هذا السيرفر تحديداً متوقف
    const product = await this.productModel.findOne({
      appId: app._id,
      countryCode: country,
      isActive: true,
      autoDisabled: { $ne: true },
    });
    if (!product) {
      throw new BadRequestException('هذه الخدمة أو الدولة غير متاحة حالياً');
    }
    return product as VirtualNumberProductDocument;
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
      .select(
        'appId providerId countryCode countryName isActive autoDisabled quality',
      )
      .lean();

    // الدولة تُوسم باسم سيرفرها: اللوحة تعرض نفس الاسم الذي يراه العميل
    const productProviderIds = [
      ...new Set(
        allProducts.map((p) => String(p.providerId ?? '')).filter(Boolean),
      ),
    ];
    const productProviders =
      productProviderIds.length > 0
        ? await this.providerModel.find({ _id: { $in: productProviderIds } })
        : [];
    const serverLabelById = new Map<string, string>(
      productProviders.map((p) => [String(p._id), String(p.serverLabel || '')]),
    );

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
          id: p._id.toString(),
          code: p.countryCode,
          name: p.countryName || p.countryCode,
          active: p.isActive !== false,
          providerId: p.providerId ? String(p.providerId) : '',
          serverLabel: serverLabelById.get(String(p.providerId ?? '')) || '',
          // حالة الجودة تُوسم بها الدولة حتى تعرف اللوحة أي سيرفر يُوقف الآن
          autoDisabled: p.autoDisabled === true,
          consecutiveFailures: Number(p.quality?.consecutiveFailures ?? 0),
          totalOrders: Number(p.quality?.totalOrders ?? 0),
          success: Number(p.quality?.success ?? 0),
          failure: Number(p.quality?.failure ?? 0),
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
    // خدمات «تفعيل مضمون» المرتبطة بالتطبيق تُوقَف: المرجع يبقى محفوراً في
    // الطلبات، والحذف بلا إيقاف يخلّف خدمة بمرجع ميت تُعطل خيارات العميل
    const stopped = await this.manualServiceModel.updateMany(
      {
        type: ProductType.MANUAL,
        virtualNumberAppId: app._id,
        isActive: true,
      },
      { $set: { isActive: false } },
    );
    await app.deleteOne();
    return {
      message: 'تم حذف التطبيق ودوله المرتبطة',
      stoppedManualServices: stopped?.modifiedCount ?? 0,
    };
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

    // كل المنتجات الحالية مفهرسة بمفتاح مزود|خدمة|دولة: الدولة نفسها من مزود
    // آخر منتجٌ مستقل، فلا تُوسم «مُنتقاة» في كتالوج هذا المزود لمجرد أن مزوداً
    // غيرها يبيعها
    const providerKey = String(provider._id);
    const products = await this.productModel.find({});
    const productByKey = new Map<string, VirtualNumberProductDocument>();
    for (const p of products) {
      productByKey.set(
        `${String(p.providerId ?? '')}|${p.serviceCode}|${p.countryCode}`,
        p,
      );
    }

    const marginType = provider.profitMarginType ?? ProfitMarginType.PERCENTAGE;
    const marginValue = provider.profitMarginValue ?? 0;

    return {
      provider: {
        id: provider._id.toString(),
        name: provider.name,
        status: provider.status,
        // الاسم الوهمي: تُوسَم به دول هذا الكتالوج في اللوحة كما تُعرض للعميل
        serverLabel: String(provider.serverLabel || ''),
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
            const product = productByKey.get(
              `${providerKey}|${svc.code}|${c.code}`,
            );
            const cost = Number(c.cost) || 0;
            const cMeta = resolveCountryMeta(
              c.code || c.name,
              provider?.providerType,
            );
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
              // حالة الجودة تُوسم بها الدولة في صفحة الانتقاء نفسها
              productAutoDisabled: product
                ? product.autoDisabled === true
                : false,
              productConsecutiveFailures: product
                ? Number(product.quality?.consecutiveFailures ?? 0)
                : 0,
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
    // المنتج بلا مزود لا معنى له مع متعدّد السيرفرات: يُؤخذ من الطلب ثم من
    // التطبيق ثم من المزود الوحيد المسجَّل، وإلا يُطلب تحديد السيرفر صراحة
    let targetProviderId: Types.ObjectId | null = null;
    if (dto.providerId && Types.ObjectId.isValid(dto.providerId)) {
      targetProviderId = new Types.ObjectId(dto.providerId);
    } else if (
      app.providerId &&
      Types.ObjectId.isValid(String(app.providerId))
    ) {
      targetProviderId = new Types.ObjectId(String(app.providerId));
    }
    if (!targetProviderId) {
      const active = await this.resolveActiveProviders().catch(() => []);
      if (active.length !== 1) {
        throw new BadRequestException(
          'حدّد السيرفر قبل إضافة الدولة: هذا التطبيق يُباع من أكثر من سيرفر',
        );
      }
      targetProviderId = active[0]._id;
    }

    for (const c of countries) {
      const code = (c.code || '').trim();
      if (!code) continue;
      // التكرار يُقاس على (تطبيق + سيرفر + دولة): نفس الدولة من سيرفر آخر منتجٌ
      // جديدٌ كامل العدّادات لا نسخة معدّلة مما يوجد
      const exists = await this.productModel.exists({
        appId: app._id,
        providerId: targetProviderId,
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
        providerId: targetProviderId,
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
    if (product.isActive === false) {
      // التفعيل اليدوي قرار إداري باستئناف البيع: يجب أن يصفّر المتتالي وإلا
      // أوقفه أول فشل جديد فوراً لأن عدّاده ما زال محمّلاً بالتاريخ
      await this.enableProductQuality(product);
      return {
        isActive: true,
        autoDisabled: false,
        message: 'تم تفعيل الدولة',
      };
    }
    product.isActive = false;
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
  // مراقبة الجودة: عدّادات المنتجات وسجل أحداثها وإعادة تفعيلها
  // ===========================================================================

  /** سلة المنتج: موقوف جودةً أولاً، ثم تحت المراقبة، ثم نشط */
  private qualityBucket(product: VirtualNumberProductDocument): string {
    if (product.autoDisabled === true) return 'disabled';
    if (Number(product.quality?.consecutiveFailures ?? 0) >= 1)
      return 'watching';
    return 'active';
  }

  /**
   * لوحة مراقبة الجودة: صف لكل منتج (مزود + تطبيق + دولة) بعداداته الحيّة.
   * الملخص يُحسب على كامل المجموعة قبل تطبيق السلة والبحث، فتعرف اللوحة حجم
   * كل سلّة مهما كان المرشّح المعروض.
   */
  async getAdminQuality(
    params: { bucket?: string; providerId?: string; search?: string } = {},
  ) {
    const filter: Record<string, any> = {};
    if (params.providerId) {
      if (!Types.ObjectId.isValid(params.providerId)) {
        return {
          summary: { all: 0, active: 0, watching: 0, disabled: 0 },
          rows: [],
        };
      }
      filter.providerId = new Types.ObjectId(params.providerId);
    }

    const products = await this.productModel
      .find(filter)
      .sort({ createdAt: -1 });

    const appIds = [...new Set(products.map((p) => String(p.appId)))];
    const providerIds = [
      ...new Set(
        products.map((p) => String(p.providerId ?? '')).filter(Boolean),
      ),
    ];
    const [apps, providers] = await Promise.all([
      appIds.length > 0
        ? this.appModel.find({ _id: { $in: appIds } })
        : ([] as VirtualNumberAppDocument[]),
      providerIds.length > 0
        ? this.providerModel.find({ _id: { $in: providerIds } })
        : ([] as ProviderDocument[]),
    ]);
    const appsById = new Map<string, any>(
      apps.map((a) => [String(a._id), a] as [string, any]),
    );
    const providersById = new Map<string, any>(
      providers.map((p) => [String(p._id), p] as [string, any]),
    );

    const rows = products.map((product) => {
      const q: any = product.quality ?? {};
      const success = Number(q.success ?? 0);
      const failure = Number(q.failure ?? 0);
      // النسبة على المحتسب وحده: الإلغاء ونفاد المخزون والمعلّق لا تُحسب ضد المزود
      const counted = success + failure;
      const provider = providersById.get(String(product.providerId));
      const app = appsById.get(String(product.appId));
      const appMeta = resolveAppMeta(
        product.serviceCode || app?.serviceCode || '',
      );
      const countryMeta = resolveCountryMeta(product.countryCode);
      return {
        productId: product._id.toString(),
        bucket: this.qualityBucket(product),
        providerId: provider ? String(provider._id) : '',
        // الاسم الوهمي هو ما يراه العميل، والاسم الحقيقي يبقى في اللوحة فقط
        serverLabel: String(provider?.serverLabel || ''),
        providerName: String(provider?.name || ''),
        providerMissing: !provider,
        providerActive: provider ? provider.isActive !== false : false,
        appId: app ? String(app._id) : String(product.appId ?? ''),
        appName: String(app?.name || appMeta.name),
        appIcon: String(app?.iconUrl || appMeta.icon),
        serviceCode: product.serviceCode,
        countryCode: product.countryCode,
        countryName: String(product.countryName || countryMeta.name),
        flag: countryMeta.flag,
        isActive: product.isActive !== false,
        autoDisabled: product.autoDisabled === true,
        totalOrders: Number(q.totalOrders ?? 0),
        success,
        failure,
        cancelled: Number(q.cancelled ?? 0),
        outOfStock: Number(q.outOfStock ?? 0),
        pending: Number(q.pending ?? 0),
        consecutiveFailures: Number(q.consecutiveFailures ?? 0),
        codeRate: counted > 0 ? Number((success / counted).toFixed(3)) : null,
        disabledAt: product.disabledAt ?? null,
        disabledReason: String(product.disabledReason ?? ''),
        disabledBy: String(product.disabledBy ?? ''),
      };
    });

    const summary = {
      all: rows.length,
      active: rows.filter((r) => r.bucket === 'active').length,
      watching: rows.filter((r) => r.bucket === 'watching').length,
      disabled: rows.filter((r) => r.bucket === 'disabled').length,
    };

    const bucket = ['active', 'watching', 'disabled'].includes(
      params.bucket || '',
    )
      ? (params.bucket as string)
      : 'all';
    const term = (params.search || '').trim().toLowerCase();
    const rank: Record<string, number> = {
      disabled: 0,
      watching: 1,
      active: 2,
    };

    const filtered = rows
      .filter((row) => bucket === 'all' || row.bucket === bucket)
      .filter(
        (row) =>
          !term ||
          [
            row.serverLabel,
            row.providerName,
            row.appName,
            row.countryName,
            row.countryCode,
            row.serviceCode,
          ]
            .filter(Boolean)
            .some((value) => String(value).toLowerCase().includes(term)),
      )
      .sort(
        (a, b) =>
          rank[a.bucket] - rank[b.bucket] ||
          b.consecutiveFailures - a.consecutiveFailures ||
          b.totalOrders - a.totalOrders,
      );

    return { summary, rows: filtered };
  }

  /** سجل أحداث منتج: أسباب النتائج الخام + آخر طلباته لعله يكتشف نمطاً */
  async getProductQualityEvents(productId: string, limit = 50) {
    if (!Types.ObjectId.isValid(productId)) {
      throw new NotFoundException('المنتج غير موجود');
    }
    const oid = new Types.ObjectId(productId);
    const product = await this.productModel.findById(oid).catch(() => null);
    if (!product) throw new NotFoundException('المنتج غير موجود');

    const capped = Math.min(Math.max(Math.trunc(limit) || 50, 1), 200);
    const [events, requests, provider, app] = await Promise.all([
      this.qualityEventModel
        .find({ productId: oid })
        .sort({ createdAt: -1 })
        .limit(capped),
      this.requestModel
        .find({ productId: oid })
        .sort({ createdAt: -1 })
        .limit(capped),
      this.providerMetaFor(product.providerId),
      this.appModel.findById(product.appId).catch(() => null),
    ]);
    const q: any = product.quality ?? {};

    return {
      product: {
        productId: product._id.toString(),
        serverLabel: provider.label,
        providerName: provider.name,
        appName: String(app?.name || ''),
        serviceCode: product.serviceCode,
        countryCode: product.countryCode,
        countryName: String(product.countryName || ''),
        isActive: product.isActive !== false,
        autoDisabled: product.autoDisabled === true,
        consecutiveFailures: Number(q.consecutiveFailures ?? 0),
        totalOrders: Number(q.totalOrders ?? 0),
        success: Number(q.success ?? 0),
        failure: Number(q.failure ?? 0),
        cancelled: Number(q.cancelled ?? 0),
        outOfStock: Number(q.outOfStock ?? 0),
        pending: Number(q.pending ?? 0),
        disabledAt: product.disabledAt ?? null,
        disabledReason: String(product.disabledReason ?? ''),
        disabledBy: String(product.disabledBy ?? ''),
      },
      events: events.map((e) => ({
        id: e._id.toString(),
        outcome: e.outcome,
        // `counted` هي الفيصل: الحدث غير المحتسب لا يغيّر تقييم المزود
        counted: e.counted === true,
        source: e.source,
        reason: String(e.reason || ''),
        requestNumber: String(e.requestNumber || ''),
        requestId: e.requestId ? e.requestId.toString() : '',
        createdAt: (e as any).createdAt ?? null,
      })),
      requests: requests.map((r) => ({
        id: r._id.toString(),
        requestNumber: r.requestNumber,
        status: r.status,
        phoneNumber: String(r.phoneNumber || ''),
        operator: String(r.operator || ''),
        amount: Number(r.amount) || 0,
        // وصول الرمز هو ما يفرّق الفشل عن النجاح، لا حالة الطلب وحدها
        hasCode: Boolean(r.smsCode),
        smsCode: r.smsCode ?? null,
        qualityOutcome: r.qualityOutcome ?? null,
        createdAt: (r as any).createdAt ?? null,
        closedAt: r.closedAt ?? null,
      })),
    };
  }

  /**
   * يرفع الإيقاف الجودةي عن منتج ويصفّر متتالي الفشل وحده — العدّادات التاريخية
   * تبقى لأن فشل الأمس حقيقة موثقة حتى لو أصلحته الإدارة اليوم.
   */
  private async enableProductQuality(
    product: VirtualNumberProductDocument,
    actorName = '',
    note?: string,
  ) {
    const wasBlocked =
      product.autoDisabled === true || product.isActive === false;
    const updated = await this.productModel.findOneAndUpdate(
      { _id: product._id },
      {
        $set: {
          'quality.consecutiveFailures': 0,
          autoDisabled: false,
          isActive: true,
          disabledAt: null,
          disabledReason: null,
          disabledBy: null,
        },
      },
      { new: true },
    );
    if (wasBlocked) {
      await this.qualityEventModel
        .create({
          productId: product._id,
          providerId: product.providerId,
          appId: product.appId,
          countryCode: product.countryCode,
          outcome: VirtualNumberOutcome.REACTIVATED,
          counted: false,
          requestNumber: '',
          reason:
            note?.trim() ||
            (actorName
              ? `أعادت الإدارة ${actorName} تفعيل المنتج`
              : 'أعادت الإدارة تفعيل المنتج'),
          source: 'admin' as VirtualNumberOutcomeSource,
        })
        .catch((err: any) =>
          this.logger.warn(
            `Quality reactivation event failed: ${err?.message}`,
          ),
        );
    }
    return updated ?? product;
  }

  /** إعادة تفعيل يدوية من اللوحة: تصفّر المتتالي وتُبقي كل العدّادات */
  async reactivateProduct(productId: string, note?: string, actorName = '') {
    if (!Types.ObjectId.isValid(productId)) {
      throw new NotFoundException('المنتج غير موجود');
    }
    const product = await this.productModel
      .findById(new Types.ObjectId(productId))
      .catch(() => null);
    if (!product) throw new NotFoundException('المنتج غير موجود');

    const wasAutoDisabled = product.autoDisabled === true;
    await this.enableProductQuality(product, actorName, note);
    return {
      message: wasAutoDisabled
        ? 'أُعيد تفعيل المنتج وصفّرت عدّادات الفشل المتتالي'
        : 'صفّرت عدّادات الفشل المتتالي للمنتج',
      productId: product._id.toString(),
      autoDisabled: false,
      isActive: true,
      consecutiveFailures: 0,
    };
  }

  // ===========================================================================
  // خدمات الأرقام اليدوية (تفعيل مضمون) — القسم الأول في صفحة أرقام العميل
  // الخدمة منتج (type=manual) بلا تطبيق متجر، بل مرتبطة بتطبيق أرقام؛ وطلبها
  // يمر عبر /orders نفسه فيسلك مسار الخدمات اليدوية: مشرف مُسند، محفظة ذرّية
  //، عمل في مساحة المشرف، وظهر في «طلباتي».
  // ===========================================================================

  private manualServiceView(service: any, apps: Map<string, any> = new Map()) {
    const app = apps.get(
      String(
        service.virtualNumberAppId?._id ?? service.virtualNumberAppId ?? '',
      ),
    );
    return {
      id: service._id.toString(),
      name: service.name,
      description: service.description ?? '',
      instructions: service.instructions ?? '',
      price: Number(service.salePrice) || 0,
      requiredFields: service.requiredFields ?? [],
      estimatedMinutes: service.estimatedMinutes ?? 120,
      isActive: service.isActive !== false,
      appId: app
        ? app._id.toString()
        : String(service.virtualNumberAppId ?? ''),
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

    const views: Array<Record<string, any>> = [];
    for (const service of services) {
      const app = service.virtualNumberAppId as any;
      // حذف التطبيق يُبقي المرجع في المنتج اليدوي فيرجع populate بـ null: البطاقة
      // تكون بلا اسم ولا أيقونة، وطلبها لا يُسلَّم لمشرف، فتُخفى عن العميل وتبقى
      // في قائمة الإدارة كي تُعاد تربيتها بتطبيق آخر
      if (!app?._id) {
        this.logger.warn(
          `Manual service ${service._id} references a deleted virtual number app`,
        );
        continue;
      }
      if (app.isActive === false) continue;
      views.push(
        this.manualServiceView(service, new Map([[String(app._id), app]])),
      );
    }
    return views;
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

    const open = await this.orderModel.aggregate<{
      serviceId: string;
      count: number;
    }>([
      {
        $match: {
          virtualNumberAppId: { $exists: true, $ne: null },
          status: {
            $nin: [
              OrderStatus.COMPLETED,
              OrderStatus.REFUNDED,
              OrderStatus.REJECTED,
            ],
          },
        },
      },
      { $group: { _id: '$productId', count: { $sum: 1 } } },
      { $project: { serviceId: { $toString: '$_id' }, count: 1 } },
    ]);
    const openByService = new Map(
      open.map((row) => [row.serviceId, row.count]),
    );

    return services.map((s: any) => ({
      ...this.manualServiceView(
        s,
        new Map([[String(s.virtualNumberAppId?._id), s.virtualNumberAppId]]),
      ),
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
      service.sensitiveFields = service.isSensitive
        ? service.requiredFields
        : [];
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
    if (
      previousSupervisorId &&
      previousSupervisorId !== supervisorId?.toString()
    ) {
      await this.reconcileSupervisorRole(
        new Types.ObjectId(previousSupervisorId),
      );
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
        $nin: [
          OrderStatus.COMPLETED,
          OrderStatus.REFUNDED,
          OrderStatus.REJECTED,
        ],
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
      this.manualServiceModel.countDocuments({
        assignedSupervisorId: user._id,
      }),
      this.orderModel.countDocuments({
        assignedSupervisorId: user._id,
        status: {
          $nin: [
            OrderStatus.COMPLETED,
            OrderStatus.REFUNDED,
            OrderStatus.REJECTED,
          ],
        },
      }),
    ]);

    if (
      assignedProducts === 0 &&
      activeOrders === 0 &&
      user.role === Role.SUPERVISOR
    ) {
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
      this.logger.error(
        `Duplicate-debit compensation failed for ${user._id}: ${err.message}`,
      );
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
    this.logger.error(
      `Virtual number request persist failed: ${cause?.message}`,
    );
    try {
      await this.userModel.findByIdAndUpdate(user._id, {
        $inc: { balance: amount },
      });
    } catch (err: any) {
      this.logger.error(
        `Emergency refund failed for ${user._id}: ${err.message}`,
      );
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

  /**
   * بيانات المزود لأغراض العرض فقط: `label` الوهمي الذي يُسمح للعميل برؤيته،
   * و`name` الحقيقي الذي لا يغادر واجهات الإدارة. يُخزَّن مؤقتاً لأن كل طلب
   * معروض يحتاجه والمزود لا يُبدَّل اسمه إلا من اللوحة.
   */
  private async providerMetaFor(
    providerId: any,
  ): Promise<{ label: string; name: string }> {
    const empty = { label: '', name: '' };
    if (!providerId) return empty;
    const key = String(providerId);
    const cached = this.providerMetaCache.get(key);
    if (cached && Date.now() - cached.at < PROVIDER_META_TTL_MS) return cached;

    let provider: any = null;
    try {
      provider = await this.providerModel.findById(key);
    } catch (err: any) {
      this.logger.warn(`Provider meta lookup failed: ${err?.message}`);
      return empty;
    }
    const meta = {
      label: String(provider?.serverLabel || '').trim(),
      name: String(provider?.name || '').trim(),
      at: Date.now(),
    };
    this.providerMetaCache.set(key, meta);
    return meta;
  }

  // العرض للعميل: الرقم بصيغة دولية والرمز متاح بعد وصوله فقط
  private toView(
    request: VirtualNumberRequestDocument,
    // الاسم الوهمي للسيرفر: يُقرأ من مزود الطلب، فلا يعرف العميل مزوّده أبداً
    serverLabel = '',
  ) {
    const raw = (request as any).toObject?.() ?? request;
    const appMeta = resolveAppMeta(request.service);
    const countryMeta = resolveCountryMeta(request.country);
    return {
      id: request._id.toString(),
      requestNumber: request.requestNumber,
      productId: request.productId ? request.productId.toString() : null,
      serverLabel,
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

  /** عرض طلب للعميل مع اسم السيرفر الوهمي لمزوده */
  private async viewForClient(request: VirtualNumberRequestDocument) {
    const meta = await this.providerMetaFor(request.providerId);
    return this.toView(request, meta.label);
  }

  private toAdminView(
    request: VirtualNumberRequestDocument,
    meta: { label: string; name: string } = { label: '', name: '' },
  ) {
    const user: any = (request as any).userId;
    return {
      ...this.toView(request, meta.label),
      // الإدارة ترى المزود الحقيقي ومعرّف المنتج لأن تقييم الجودة يخصّ مزوداً بعينه
      providerId: request.providerId ? request.providerId.toString() : '',
      providerName: meta.name,
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
