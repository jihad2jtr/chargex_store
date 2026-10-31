import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import axios from 'axios';
import { Provider, ProviderDocument, ProviderStatus, ProviderType } from '../../database/schemas/provider.schema';
import { ProviderProduct, ProviderProductDocument } from '../../database/schemas/provider-product.schema';
import { Product, ProductDocument, ProfitMarginType, ProductType } from '../../database/schemas/product.schema';
import { NotificationsService } from '../notifications/notifications.service';
import {
  VIRTUAL_NUMBER_PROVIDER_TYPES,
  createVirtualNumberClient,
  detectVirtualNumberType,
  isVirtualNumberProvider,
} from '../virtual-numbers/virtual-number-clients';

@Injectable()
export class ProvidersService {
  // Timeouts stay well below the serverless function limit so a slow provider
  // always reaches our own error handling instead of being killed by the platform
  private static readonly ORDER_TIMEOUT_MS = 12_000;
  private static readonly STATUS_TIMEOUT_MS = 8_000;
  private readonly logger = new Logger(ProvidersService.name);

  // No default filter — sync ALL categories from provider unless specific gameCodes are given

  constructor(
    @InjectModel(Provider.name) private providerModel: Model<ProviderDocument>,
    @InjectModel(ProviderProduct.name) private providerProductModel: Model<ProviderProductDocument>,
    @InjectModel(Product.name) private productModel: Model<ProductDocument>,
    private readonly notificationsService: NotificationsService,
  ) {}

  private isTimeoutError(err: any): boolean {
    if (!err) return false;
    const code = err.code || '';
    return (
      code === 'ECONNABORTED' ||
      code === 'ETIMEDOUT' ||
      code === 'ERR_CANCELED' ||
      /timeout/i.test(err.message || '')
    );
  }

  private isBay2Game(provider: ProviderDocument): boolean {
    return (
      provider.providerType === ProviderType.BAY2GAME ||
      provider.baseUrl?.toLowerCase().includes('bay2game') ||
      provider.name?.toLowerCase().includes('bay2game')
    );
  }

  private isFoxReload(provider: ProviderDocument): boolean {
    return (
      provider.providerType === ProviderType.FOXRELOAD ||
      provider.baseUrl?.toLowerCase().includes('foxreload') ||
      provider.name?.toLowerCase().includes('foxreload')
    );
  }

  // مزود أرقام التحقق الوهمية (5sim أو Hero-SMS) — تُخدم صفحة «أرقام وهمية»
  private isVirtualNumbers(provider: ProviderDocument): boolean {
    return isVirtualNumberProvider(provider);
  }

  private virtualNumberClient(provider: ProviderDocument) {
    // المصنع نفسه الذي تستخدمه صفحة الأرقام: لا تتفرّع قاعدة البروتوكول هنا
    return createVirtualNumberClient({
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      providerType: provider.providerType,
      name: provider.name,
    });
  }

  private getFoxReloadBaseUrl(provider: ProviderDocument): string {
    const raw = (provider.baseUrl || '').trim().replace(/\/+$/, '');
    if (!raw || (raw.includes('foxreload.com') && !raw.includes('public-api.foxreload.com'))) {
      return 'https://public-api.foxreload.com';
    }
    return raw;
  }

  private getFoxReloadHeaders(provider: ProviderDocument) {
    return {
      'X-API-Key': provider.apiKey,
      'X-Currency': 'usd',
      'X-Language': 'en',
      'Content-Type': 'application/json',
      ...(provider.headers || {}),
    };
  }

  async findAll() {
    return this.providerModel.find().sort({ createdAt: -1 });
  }

  async findOne(id: string) {
    const provider = await this.providerModel.findById(id);
    if (!provider) throw new NotFoundException('المزود غير موجود');
    return provider;
  }

  /**
   * الاسم الوهمي التالي للسيرفر: «Server N» بترتيب مزودي الأرقام، مع تجاوز أي
   * رقم مأخوذ حتى لا يشترك سيرفران في الاسم الذي يراه العميل.
   */
  private async nextServerLabel(): Promise<string> {
    const existing = await this.providerModel
      .find({ providerType: { $in: VIRTUAL_NUMBER_PROVIDER_TYPES } })
      .select('serverLabel')
      .lean();
    const taken = new Set(
      existing.map((p: any) => String(p.serverLabel || '').trim().toLowerCase()),
    );
    let next = existing.length + 1;
    while (taken.has(`server ${next}`)) next += 1;
    return `Server ${next}`;
  }

  async create(createDto: {
    name: string;
    baseUrl: string;
    apiKey: string;
    apiSecret?: string;
    headers?: Record<string, string>;
    providerType?: ProviderType;
    serverLabel?: string;
  }) {
    const isBay =
      createDto.providerType === ProviderType.BAY2GAME ||
      createDto.baseUrl?.toLowerCase().includes('bay2game') ||
      createDto.name?.toLowerCase().includes('bay2game');

    const isFox =
      createDto.providerType === ProviderType.FOXRELOAD ||
      createDto.baseUrl?.toLowerCase().includes('foxreload') ||
      createDto.name?.toLowerCase().includes('foxreload');

    // مزودو الأرقام الوهمية بنوعيهم (5sim / Hero-SMS) يُحدَّد نوعهم بالاسم أو الرابط
    const virtualType = detectVirtualNumberType(createDto);

    const resolvedType = isBay
      ? ProviderType.BAY2GAME
      : isFox
      ? ProviderType.FOXRELOAD
      : virtualType ?? (createDto.providerType || ProviderType.CUSTOM);

    // مزود أرقام التحقق يأخذ اسم سيرفر وهمي تلقائياً: هذا الاسم وحده ما يُعرض
    // على العميل، أما `name` الحقيقي فلا يغادر واجهات الإدارة
    const isNumbersProvider = VIRTUAL_NUMBER_PROVIDER_TYPES.includes(resolvedType);
    const serverLabel =
      (createDto.serverLabel || '').trim() ||
      (isNumbersProvider ? await this.nextServerLabel() : '');

    const provider = new this.providerModel({
      ...createDto,
      serverLabel,
      providerType: resolvedType,
      status: ProviderStatus.OFFLINE,
      isActive: true,
    });
    await provider.save();

    // Check status and update initial balance right away
    try {
      await this.checkStatus(provider._id.toString());
    } catch (e: any) {
      this.logger.warn(`Initial status check for new provider failed: ${e.message}`);
    }

    return provider;
  }

  async update(id: string, updateDto: any) {
    const provider = await this.providerModel.findByIdAndUpdate(id, updateDto, { new: true });
    if (!provider) throw new NotFoundException('المزود غير موجود');

    // هامش الربح على مستوى المزود: أي تعديل يُعاد حساب أسعار بيع كل منتجاته
    const marginChanged =
      updateDto.profitMarginType !== undefined || updateDto.profitMarginValue !== undefined;
    if (marginChanged) {
      await this.recalculateProviderPrices(id);
    }

    return provider;
  }

  // زر الإيقاف/التفعيل اليدوي: الإيقاف يُخفي كل التطبيقات والمنتجات المرتبطة به
  async toggleActive(id: string) {
    const provider = await this.findOne(id);
    // السجلات القديمة قد لا تحمل الحقل أصلاً — تُعتبر مفعّلة كي يعمل زر الإيقاف
    const nextActive = provider.isActive === false;
    provider.isActive = nextActive;

    if (!nextActive) {
      provider.lastError = provider.lastError || 'أُوقف المزود يدوياً من الإدارة';
      await provider.save();
      return provider;
    }

    provider.lastError = undefined;
    await provider.save();

    // التفعيل يتبعه فحص فوري كي لا يعود مزود بلا رصيد إلى واجهة العملاء
    try {
      return await this.checkStatus(id);
    } catch (err: any) {
      this.logger.warn(`Post-enable status check failed for ${provider.name}: ${err.message}`);
      return provider;
    }
  }

  /** حساب سعر البيع من سعر التكلفة حسب هامش ربح المزود */
  private computeSalePrice(
    costPrice: number,
    marginType: ProfitMarginType,
    marginValue: number,
  ): number {
    const cost = Number(costPrice) || 0;
    const margin = Number(marginValue) || 0;
    const price =
      marginType === ProfitMarginType.FIXED ? cost + margin : cost * (1 + margin / 100);
    return Math.round(price * 100) / 100;
  }

  /** إعادة حساب أسعار البيع لكل منتجات المزود وفق هامشه الحالي */
  async recalculateProviderPrices(providerId: string) {
    const provider = await this.findOne(providerId);
    const marginType = provider.profitMarginType ?? ProfitMarginType.PERCENTAGE;
    const marginValue = provider.profitMarginValue ?? 0;

    const products = await this.productModel.find({
      providerId: new Types.ObjectId(providerId),
    });

    for (const product of products) {
      const newSalePrice = this.computeSalePrice(
        product.costPrice,
        marginType,
        marginValue,
      );
      if (newSalePrice !== product.salePrice) {
        product.profitMarginType = marginType;
        product.profitMarginValue = marginValue;
        product.salePrice = newSalePrice;
        await product.save();
      }
    }

    return { message: 'تم تحديث أسعار منتجات المزود وفق هامش الربح الجديد', updated: products.length };
  }

  async remove(id: string) {
    const provider = await this.providerModel.findByIdAndDelete(id);
    if (!provider) throw new NotFoundException('المزود غير موجود');
    await this.providerProductModel.deleteMany({ providerId: provider._id });
    return { message: 'تم حذف المزود بنجاح' };
  }

  async checkStatus(id: string) {
    const provider = await this.findOne(id);
    provider.lastCheckAt = new Date();

    try {
      if (this.isBay2Game(provider)) {
        // Bay2Game Profile endpoint: GET /profile?api_key=...
        const url = `${provider.baseUrl.replace(/\/+$/, '')}/profile`;
        const response = await axios.get(url, {
          params: { api_key: provider.apiKey },
          timeout: ProvidersService.STATUS_TIMEOUT_MS,
        });

        if (response.data && (response.data.status === 'success' || response.data.status === 'SUCCESS')) {
          provider.status = ProviderStatus.ONLINE;
          provider.balance = typeof response.data.user?.balance === 'number' ? response.data.user.balance : 0;
          provider.lastError = undefined;
        } else {
          provider.status = ProviderStatus.ERROR;
          provider.lastError = response.data?.message || 'فشل التحقق من حساب المزود';
        }
      } else if (this.isFoxReload(provider)) {
        const baseUrl = this.getFoxReloadBaseUrl(provider);
        const headers = this.getFoxReloadHeaders(provider);

        // 1. Verify access & account (account + balances are fetched in parallel)
        const [meRes, balRes] = await Promise.all([
          axios.get(`${baseUrl}/api/access/me`, { headers, timeout: ProvidersService.STATUS_TIMEOUT_MS }),
          axios
            .get(`${baseUrl}/api/access/me/balances/`, { headers, timeout: ProvidersService.STATUS_TIMEOUT_MS })
            .catch(() => null),
        ]);

        if (meRes.data && meRes.data.isActive !== false) {
          // 2. Balances
          let currentBalance = 0;
          if (balRes && Array.isArray(balRes.data) && balRes.data.length > 0) {
            const usdBal = balRes.data.find((b: any) => (b.currency || '').toLowerCase() === 'usd') || balRes.data[0];
            currentBalance = parseFloat(usdBal.amount ?? usdBal.balance ?? '0') || 0;
          }
          provider.balance = currentBalance;
          provider.status = ProviderStatus.ONLINE;
          provider.lastError = undefined;
        } else {
          provider.status = ProviderStatus.ERROR;
          provider.lastError = 'حساب المزود غير نشط أو مفتاح API غير صالح';
        }
      } else if (this.isVirtualNumbers(provider)) {
        // الأرقام الوهمية: رصيد الحساب لدى المزود نفسه (أيّاً كان بروتوكوله)
        const profile = await this.virtualNumberClient(provider).getProfile();
        provider.balance = profile.balance;
        provider.status = ProviderStatus.ONLINE;
        provider.lastError = undefined;
      } else {
        // Generic provider healthcheck fallback
        await axios.get(provider.baseUrl, {
          headers: {
            Authorization: `Bearer ${provider.apiKey}`,
            'X-API-KEY': provider.apiKey,
            ...(provider.headers || {}),
          },
          timeout: 5000,
        }).catch((err) => {
          if (err.response && (err.response.status === 401 || err.response.status === 200 || err.response.status === 404)) {
            return { status: 200, data: err.response.data };
          }
          throw err;
        });

        provider.status = ProviderStatus.ONLINE;
        provider.lastError = undefined;
      }
    } catch (error: any) {
      provider.status = ProviderStatus.ERROR;
      provider.lastError = error.response?.data?.message || error.message || 'فشل الاتصال بالمزود';
    }

    await provider.save();
    return provider;
  }

  // --- Guardrails consumed by the order pipeline ---

  // Maximum age of a stored provider status before it is refreshed on demand
  private static readonly STATUS_TTL_MS = 10 * 60 * 1000;

  // رسالة المزود قد تشير لنفاد الرصيد حتى دون رمز خطأ صريح
  private isInsufficientBalanceError(message?: string): boolean {
    const msg = (message || '').toLowerCase();
    if (!msg) return false;
    return (
      /insufficient\s+(balance|credit|funds|money)/.test(msg) ||
      /not\s+enough\s+(balance|credit|funds|money)/.test(msg) ||
      /(balance|credit|funds)\s+(is\s+)?(too\s+)?(low|empty|zero|exhausted|depleted)/.test(msg) ||
      /(no|without)\s+(available\s+)?(balance|credit|funds)/.test(msg) ||
      /out\s+of\s+(balance|credit|funds)/.test(msg) ||
      /رصيد\s*(المزود|غير|لا|منخفض|صفر)/.test(msg)
    );
  }

  // إيقاف المزود تلقائياً عند نفاد رصيده: الشرط أن يكون ما زال مفعّلاً،
  // كي لا يتكرر الإشعار مع كل محاولة شراء لاحقة
  private async disableForInsufficientBalance(provider: ProviderDocument, reason: string) {
    const updated = await this.providerModel.findOneAndUpdate(
      // $ne: false كي تُشمل السجلات القديمة التي لا تحمل الحقل أصلاً
      { _id: provider._id, isActive: { $ne: false } },
      { $set: { isActive: false, status: ProviderStatus.ERROR, lastError: reason } },
      { new: true },
    );
    if (!updated) return; // كان موقوفاً مسبقاً — لا تكرار للإشعار

    this.logger.warn(`Provider ${updated.name} auto-disabled: ${reason}`);
    try {
      await this.notificationsService.createNotification({
        forRole: 'admin',
        title: 'إيقاف مزود تلقائياً: الرصيد غير كافٍ',
        body: `أُوقف المزود "${updated.name}" تلقائياً بعد تعذّر تنفيذ طلب بسبب الرصيد (${reason}). أعد شحن رصيده ثم فعّله من إدارة المزودين.`,
        type: 'provider_alert',
      });
    } catch (err: any) {
      this.logger.warn(`Provider auto-disable notification failed: ${err?.message}`);
    }
  }

  // Fail fast — before any money is deducted — when a provider cannot serve the order
  async ensureReadyForOrder(providerId: string, requiredCost = 0): Promise<ProviderDocument> {
    let provider: ProviderDocument;
    try {
      provider = await this.findOne(providerId);
    } catch {
      // A deleted/unreachable provider record must never surface as a scary error to the buyer
      throw new BadRequestException('خدمة هذا المنتج غير متاحة حالياً، ولم يتم خصم أي مبلغ من رصيدك');
    }

    if (provider.isActive === false) {
      throw new BadRequestException('خدمة هذا المنتج غير متاحة حالياً، ولم يتم خصم أي مبلغ من رصيدك');
    }

    const lastCheck = provider.lastCheckAt ? new Date(provider.lastCheckAt).getTime() : 0;
    if (!lastCheck || Date.now() - lastCheck > ProvidersService.STATUS_TTL_MS) {
      try {
        provider = await this.checkStatus(providerId);
      } catch (err: any) {
        this.logger.warn(`Readiness check for provider ${provider.name} failed: ${err.message}`);
      }
    }

    if (provider.status !== ProviderStatus.ONLINE) {
      throw new BadRequestException(
        'مزوّد الخدمة غير متاح حالياً، ولم يتم خصم أي مبلغ من رصيدك. يرجى المحاولة لاحقاً',
      );
    }

    const balance = typeof provider.balance === 'number' ? provider.balance : 0;
    if (requiredCost > 0 && balance < requiredCost) {
      // نفاد رصيد المزود = إيقاف فوري له فتختفي كل تطبيقاته المرتبطة من المتجر
      await this.disableForInsufficientBalance(
        provider,
        `الرصيد $${balance.toFixed(2)} أقل من تكلفة الطلب $${requiredCost.toFixed(2)}`,
      ).catch((err: any) =>
        this.logger.warn(`Provider auto-disable failed: ${err.message}`),
      );
      // رسالة تمويه في حال نفاد رصيد المزود
      throw new BadRequestException(
        'ضغط على السيرفر الرجاء المحاولة لا حقاً',
      );
    }

    return provider;
  }

  // Persist the provider-side failure reason and refresh its status/balance in the background
  async markProviderFailure(providerId: string, message: string, requiredCost = 0) {
    const insufficientSignal = this.isInsufficientBalanceError(message);

    try {
      await this.providerModel.updateOne({ _id: providerId }, { $set: { lastError: message } });
    } catch (err: any) {
      this.logger.warn(`Could not persist provider failure: ${err.message}`);
    }

    this.checkStatus(providerId)
      .then((refreshed) => {
        const balance = typeof refreshed.balance === 'number' ? refreshed.balance : 0;
        const drained = requiredCost > 0 && balance < requiredCost;
        if (!insufficientSignal && !drained) return;

        return this.disableForInsufficientBalance(
          refreshed,
          insufficientSignal
            ? `المزود أبلغ عن نفاد الرصيد: ${message}`
            : `الرصيد $${balance.toFixed(2)} أقل من تكلفة الطلب $${requiredCost.toFixed(2)}`,
        );
      })
      .catch((err: any) =>
        this.logger.warn(`Background provider status refresh failed: ${err.message}`),
      );
  }

  // Normalized view over any provider's order status (used for reconciliation)
  async inspectOrderStatus(
    providerId: string,
    reference: string,
  ): Promise<{
    state: 'delivered' | 'failed' | 'pending' | 'unknown';
    codes?: string[];
    message?: string;
    raw?: any;
  }> {
    const provider = await this.findOne(providerId);
    const raw = await this.checkOrderStatus(providerId, reference);

    // A transport/HTTP problem is NOT a provider-declared failure
    if (raw?.isTransportError) {
      return { state: 'unknown', message: raw?.message, raw };
    }

    const rawStatus = String(raw?.status ?? raw?.state ?? '').toLowerCase();

    if (this.isBay2Game(provider)) {
      const codes = [raw?.code, raw?.delivered_code, raw?.serial]
        .filter((c: any) => typeof c === 'string' && c.trim().length > 0)
        .map((c: string) => c.trim());

      if (['success', 'completed', 'delivered', 'done'].includes(rawStatus)) {
        return { state: 'delivered', codes, message: raw?.message, raw };
      }
      if (['failed', 'error', 'cancelled', 'canceled', 'refunded', 'rejected'].includes(rawStatus)) {
        return { state: 'failed', message: raw?.message || 'أبلغ المزوّد عن فشل الطلب', raw };
      }
      if (['pending', 'processing', 'in_progress', 'waiting'].includes(rawStatus)) {
        return { state: 'pending', raw };
      }
      return { state: 'unknown', raw };
    }

    if (this.isFoxReload(provider)) {
      const item = raw?.items?.[0];
      const fulfillment = String(item?.fulfillmentStatus ?? '').toLowerCase();
      const codes = Array.isArray(item?.externalData) ? item.externalData.map(String) : [];

      if (rawStatus === 'cancelled' || fulfillment === 'failed') {
        return {
          state: 'failed',
          message: raw?.cancelReason || item?.error || 'أبلغ المزوّد عن فشل الطلب',
          raw,
        };
      }
      if (fulfillment === 'fulfilled' || rawStatus === 'completed') {
        return { state: 'delivered', codes, message: 'تم تنفيذ الطلب لدى المزوّد', raw };
      }
      return { state: raw ? 'pending' : 'unknown', raw };
    }

    return { state: 'unknown', raw };
  }

  // Retrieve available game categories from provider
  async getProviderCategories(providerId: string) {
    const provider = await this.findOne(providerId);

    if (this.isBay2Game(provider)) {
      try {
        const url = `${provider.baseUrl.replace(/\/+$/, '')}/categories`;
        const res = await axios.get(url, {
          params: { api_key: provider.apiKey },
          timeout: 15000,
        });

        if (res.data && res.data.categories) {
          return res.data.categories;
        }
      } catch (err: any) {
        this.logger.error(`Error fetching Bay2Game categories: ${err.message}`);
        throw new BadRequestException('تعذر جلب فئات الألعاب من المزود: ' + (err.response?.data?.message || err.message));
      }
    } else if (this.isFoxReload(provider)) {
      try {
        const baseUrl = this.getFoxReloadBaseUrl(provider);
        const headers = this.getFoxReloadHeaders(provider);

        // Core sections in FoxReload catalog
        const rootSections = [
          '019e9ca5-0403-70b3-90d5-e9641f64b76b', // In-Game Top-Ups
          '019ea790-779d-7fd3-9ed7-976a410ab182', // Game Currency (Codes)
          '4740cefd-c9eb-4291-93dc-fad5cb24c855', // App Stores
          'c53e27b8-a213-47b9-b05d-1b2472c95483', // Gift Cards
          '019ea76e-b2f0-7de2-833c-9ec599ab7233', // Subscriptions & Digital Services
        ];

        const sectionResponses = await Promise.all(
          rootSections.map((secId) =>
            axios
              .get(`${baseUrl}/api/categories/`, {
                headers,
                params: { parentId: secId, limit: 100 },
                timeout: 15000,
              })
              .catch(() => ({ data: { items: [] } })),
          ),
        );

        let allGames: any[] = [];
        for (const resp of sectionResponses) {
          const items = resp.data?.items || [];
          allGames = allGames.concat(items);
        }

        // Filter games that have stock
        const inStockGames = allGames.filter((g: any) => (g.inStockCount || 0) > 0);

        return inStockGames.map((g: any) => ({
          game_code: g.id,
          name: g.name,
          image_url: g.imagePath || g.thumbnailPath,
          in_stock_count: g.inStockCount,
          game_fields: ['userid', 'serverid'],
          hasProducts: g.hasProducts,
        }));
      } catch (err: any) {
        this.logger.error(`Error fetching FoxReload categories: ${err.message}`);
        throw new BadRequestException('تعذر جلب فئات الألعاب من المزود: ' + (err.response?.data?.detail || err.message));
      }
    }

    return [];
  }

  // Sync real products from provider
  async syncProviderProducts(providerId: string, gameCodes?: string[]) {
    const provider = await this.findOne(providerId);
    let totalSynced = 0;

    if (this.isBay2Game(provider)) {
      try {
        const baseUrl = provider.baseUrl.replace(/\/+$/, '');
        // 1. Fetch categories
        const catRes = await axios.get(`${baseUrl}/categories`, {
          params: { api_key: provider.apiKey },
          timeout: 15000,
        });

        const categories = catRes.data?.categories || [];
        // If specific gameCodes are provided, filter; otherwise sync ALL categories
        const targetCats = (gameCodes && gameCodes.length > 0)
          ? categories.filter((c: any) => gameCodes.includes(c.game_code))
          : categories;

        // 2. Fetch products for target games
        for (const cat of targetCats) {
          try {
            const prodRes = await axios.get(`${baseUrl}/products`, {
              params: {
                api_key: provider.apiKey,
                game_code: cat.game_code,
              },
              timeout: 15000,
            });

            const products = prodRes.data?.products || [];
            for (const item of products) {
              const productCode = item.product_code || String(item.id);
              const productName = `${cat.name} - ${item.name}`;
              const costPrice = Number(item.sell_price) || 0;

              await this.providerProductModel.findOneAndUpdate(
                {
                  providerId: provider._id,
                  providerProductCode: productCode,
                },
                {
                  providerId: provider._id,
                  providerProductCode: productCode,
                  name: productName,
                  category: cat.name,
                  costPrice,
                  currency: 'USD',
                  inStock: item.status === 'active',
                  rawDetails: {
                    game_code: cat.game_code,
                    game_name: cat.name,
                    game_fields: cat.game_fields || ['userid'],
                    image_url: cat.image_url,
                    supplier_type: item.supplier_type,
                    original_name: item.name,
                  },
                },
                { upsert: true, new: true },
              );
              totalSynced++;
            }
          } catch (itemErr: any) {
            this.logger.warn(`Failed to sync game products for ${cat.game_code}: ${itemErr.message}`);
          }
        }

        // Also refresh provider balance
        await this.checkStatus(provider._id.toString());

        return {
          message: `تمت مزامنة ${totalSynced} منتج من المزود بنجاح`,
          syncedCount: totalSynced,
        };
      } catch (err: any) {
        this.logger.error(`Error in syncProviderProducts: ${err.message}`);
        throw new BadRequestException('فشل في مزامنة المنتجات من المزود: ' + (err.response?.data?.message || err.message));
      }
    } else if (this.isFoxReload(provider)) {
      try {
        const baseUrl = this.getFoxReloadBaseUrl(provider);
        const headers = this.getFoxReloadHeaders(provider);

        // Fetch categories to get the game objects
        const catList = await this.getProviderCategories(providerId);

        let targetGames: any[] = [];
        if (gameCodes && gameCodes.length > 0) {
          targetGames = catList.filter((c: any) => gameCodes.includes(c.game_code));
        } else {
          // Clean up old wrongly categorized products
          await this.providerProductModel.deleteMany({
            providerId: provider._id,
            category: { $in: ['FoxReload', 'Fox - WW', 'Fox - CIS', 'Fox - MENA', 'Fox - EU', 'Fox - NA', 'عام'] },
          });

          // Sort games to prioritize popular titles
          const popularKeywords = [
            'pubg', 'free fire', 'duty', 'brawl', 'roblox', 'fc', 'fifa', 'itunes', 'google',
            'steam', 'playstation', 'xbox', 'razer', 'telegram', 'discord', '8 ball pool', 'blood strike'
          ];

          const popularGames = catList.filter((g: any) =>
            popularKeywords.some((kw) => (g.name || '').toLowerCase().includes(kw)),
          );
          const otherGames = catList.filter((g: any) =>
            !popularKeywords.some((kw) => (g.name || '').toLowerCase().includes(kw)),
          );

          // Take all popular games + first 35 others (~50 games total)
          targetGames = [...popularGames, ...otherGames.slice(0, 35)];
        }

        for (const game of targetGames) {
          try {
            let productsToSync: { item: any; subName?: string }[] = [];

            if (game.hasProducts) {
              const prodRes = await axios.get(`${baseUrl}/api/products/`, {
                headers,
                params: { categoryId: game.game_code, limit: 100 },
                timeout: 15000,
              });
              const items = prodRes.data?.items || [];
              for (const it of items) {
                productsToSync.push({ item: it });
              }
            } else {
              // Fetch subcategories (regions or packages)
              const subRes = await axios.get(`${baseUrl}/api/categories/`, {
                headers,
                params: { parentId: game.game_code, limit: 100 },
                timeout: 10000,
              });
              const subItems = subRes.data?.items || [];
              for (const sub of subItems) {
                if (sub.hasProducts) {
                  const subProdRes = await axios.get(`${baseUrl}/api/products/`, {
                    headers,
                    params: { categoryId: sub.id, limit: 100 },
                    timeout: 15000,
                  });
                  const items = subProdRes.data?.items || [];
                  for (const it of items) {
                    productsToSync.push({ item: it, subName: sub.name });
                  }
                }
              }
            }

            for (const { item, subName } of productsToSync) {
              const productCode = item.id;
              let productName = item.name;
              if (
                subName &&
                subName.toLowerCase() !== 'global' &&
                !productName.toLowerCase().includes(subName.toLowerCase())
              ) {
                productName = `${item.name} (${subName})`;
              }
              const costPrice = parseFloat(item.price) || 0;
              const inStock = (item.quantity ?? 0) > 0 || item.deliveryType === 'direct_topup';

              await this.providerProductModel.findOneAndUpdate(
                {
                  providerId: provider._id,
                  providerProductCode: productCode,
                },
                {
                  providerId: provider._id,
                  providerProductCode: productCode,
                  name: productName,
                  category: game.name, // The actual Game / App Name!
                  costPrice,
                  currency: 'USD',
                  inStock,
                  rawDetails: {
                    game_code: game.game_code,
                    game_name: game.name,
                    sub_name: subName,
                    deliveryType: item.deliveryType,
                    isService: item.isService,
                    requiredNoteFields: item.requiredNoteFields || [],
                    game_fields: item.isService ? ['Player ID'] : [],
                    attributes: item.attributes,
                    userGuide: item.userGuide,
                    original_name: item.name,
                    image_url: game.image_url,
                  },
                },
                { upsert: true, new: true },
              );
              totalSynced++;
            }
          } catch (itemErr: any) {
            this.logger.warn(`Failed to sync FoxReload products for ${game.name}: ${itemErr.message}`);
          }
        }

        await this.checkStatus(provider._id.toString());
        return {
          message: `تمت مزامنة ${totalSynced} منتج عبر ${targetGames.length} لعبة وتطبيق من FoxReload بنجاح`,
          syncedCount: totalSynced,
        };
      } catch (err: any) {
        this.logger.error(`Error in syncProviderProducts (FoxReload): ${err.message}`);
        throw new BadRequestException('فشل في مزامنة المنتجات من مزود FoxReload: ' + (err.response?.data?.detail || err.message));
      }
    }

    return { message: 'لا تدعم هذه الفئة المزامنة التلقائية للمزود الحالي', syncedCount: 0 };
  }

  async getProviderProducts(providerId: string, category?: string) {
    const filter: any = { providerId: new Types.ObjectId(providerId) };
    if (category) filter.category = category;

    let products = await this.providerProductModel.find(filter).sort({ category: 1, costPrice: 1 });

    if (products.length === 0) {
      const provider = await this.findOne(providerId);
      if (this.isBay2Game(provider) || this.isFoxReload(provider)) {
        // Auto-run initial sync for provider
        this.logger.log(`Initial sync for provider ${provider.name}...`);
        await this.syncProviderProducts(providerId);
        products = await this.providerProductModel.find(filter).sort({ category: 1, costPrice: 1 });
      } else {
        await this.seedMockProviderProducts(providerId);
        products = await this.providerProductModel.find(filter).sort({ category: 1, costPrice: 1 });
      }
    }

    // Check which provider products are already imported in catalog
    const importedCodes = await this.productModel.distinct('providerProductCode', {
      providerId: new Types.ObjectId(providerId),
    });
    const importedSet = new Set(importedCodes.filter(Boolean));

    return products.map((p) => {
      const obj = p.toObject();
      return {
        ...obj,
        isImported: importedSet.has(p.providerProductCode),
      };
    });
  }

  async seedMockProviderProducts(providerId: string) {
    const sampleItems = [
      { providerProductCode: 'PUBG-60', name: '60 UC PUBG Mobile', category: 'PUBG Mobile', costPrice: 0.95 },
      { providerProductCode: 'PUBG-325', name: '325 UC PUBG Mobile', category: 'PUBG Mobile', costPrice: 4.70 },
      { providerProductCode: 'PUBG-660', name: '660 UC PUBG Mobile', category: 'PUBG Mobile', costPrice: 9.30 },
      { providerProductCode: 'FF-100', name: '100 + 10 Diamonds Free Fire', category: 'Free Fire', costPrice: 0.88 },
      { providerProductCode: 'FF-530', name: '530 + 53 Diamonds Free Fire', category: 'Free Fire', costPrice: 4.45 },
      { providerProductCode: 'TK-1000', name: '1000 TikTok Coins', category: 'TikTok', costPrice: 11.20 },
      { providerProductCode: 'GP-10', name: 'Google Play $10 US', category: 'Google Play', costPrice: 9.60 },
    ];

    for (const item of sampleItems) {
      await this.providerProductModel.create({
        providerId: new Types.ObjectId(providerId),
        ...item,
        currency: 'USD',
        inStock: true,
      });
    }
  }

  async importToProducts(
    providerProductId: string,
    appId: string,
    opts: {
      name?: string;
      serviceTemplateId?: string;
      quantityLabel?: string;
    } = {},
  ) {
    const item = await this.providerProductModel.findById(providerProductId);
    if (!item) throw new NotFoundException('منتج المزود غير موجود');

    const costPrice = item.costPrice;

    // هامش الربح يُقرأ من إعدادات المزود (وليس من المنتج)
    const provider = await this.providerModel.findById(item.providerId);
    const marginType = provider?.profitMarginType ?? ProfitMarginType.PERCENTAGE;
    const marginValue = provider?.profitMarginValue ?? 0;
    const salePrice = this.computeSalePrice(costPrice, marginType, marginValue);

    // Determine requiredFields dynamically from rawDetails.game_fields if available
    const gameFields: string[] = item.rawDetails?.game_fields || [];
    let requiredFields = ['Player ID'];
    if (gameFields.includes('userid') && gameFields.includes('serverid')) {
      requiredFields = ['Player ID', 'Server/Zone ID'];
    } else if (gameFields.length > 0) {
      requiredFields = gameFields.map((f) => (f === 'userid' ? 'Player ID' : f === 'serverid' ? 'Server/Zone ID' : f));
    }

    const newProduct = new this.productModel({
      appId: new Types.ObjectId(appId),
      name: opts.name?.trim() ? opts.name.trim() : item.name,
      description: item.category,
      type: ProductType.DIRECT_API,
      providerId: item.providerId,
      providerProductCode: item.providerProductCode,
      serviceTemplateId:
        opts.serviceTemplateId && Types.ObjectId.isValid(opts.serviceTemplateId)
          ? new Types.ObjectId(opts.serviceTemplateId)
          : undefined,
      quantityLabel: opts.quantityLabel?.trim() || '',
      costPrice,
      profitMarginType: marginType,
      profitMarginValue: marginValue,
      salePrice,
      isActive: true,
      requiredFields,
    });

    await newProduct.save();
    return newProduct;
  }

  async batchImportToProducts(
    providerProductIds: string[],
    appId: string,
    opts: {
      name?: string;
      serviceTemplateId?: string;
      quantityLabel?: string;
    } = {},
  ) {
    const results = [];
    for (const id of providerProductIds) {
      try {
        // في الاستيراد الجماعي يُطبَّق الاسم فقط إن حُدِّد، وإلا يُترك لكل باقة اسمها
        const prod = await this.importToProducts(id, appId, opts);
        results.push(prod);
      } catch (err: any) {
        this.logger.warn(`Failed to import provider product ${id}: ${err.message}`);
      }
    }
    return {
      message: `تم استيراد ${results.length} من أصل ${providerProductIds.length} منتج بنجاح إلى الكتالوج`,
      importedCount: results.length,
      products: results,
    };
  }

  // --- Real-time Order Execution via Provider API ---
  async executeOrder(
    providerId: string,
    params: {
      productCode: string;
      gameUserId: string;
      gameZoneId?: string;
      reference: string;
    },
  ): Promise<{
    success: boolean;
    transactionId?: string;
    balanceAfter?: number;
    message: string;
    raw?: any;
    // انقطاع المهلة لا يعني فشلاً مؤكداً: الطلب قد يكون نُفّذ لدى المزود،
    // والمستهلك (OrdersService) يُبقيه قيد المصالحة بدل الاسترجاع الأعمى
    isTimeout?: boolean;
  }> {
    const provider = await this.findOne(providerId);

    if (this.isBay2Game(provider)) {
      const url = `${provider.baseUrl.replace(/\/+$/, '')}/create_order`;

      try {
        const payload: Record<string, any> = {
          api_key: provider.apiKey,
          product_code: params.productCode,
          game_user_id: params.gameUserId,
          reference: params.reference,
        };
        if (params.gameZoneId) {
          payload.game_zone_id = params.gameZoneId;
        }

        this.logger.log(`Executing Bay2Game order for reference ${params.reference}, product: ${params.productCode}, user: ${params.gameUserId}`);

        // Try POST first, fallback to GET if needed
        let response: any;
        try {
          response = await axios.post(url, payload, {
            headers: { 'Content-Type': 'application/json' },
            timeout: ProvidersService.ORDER_TIMEOUT_MS,
          });
        } catch (postErr: any) {
          // Fall back to GET only when the provider explicitly rejects the method.
          // On a timeout/network error we must NOT send a second request: the first
          // one may already have been executed by the provider (duplicate fulfilment).
          const methodRejected = [404, 405, 501].includes(postErr.response?.status);
          if (methodRejected) {
            response = await axios.get(url, {
              params: payload,
              timeout: ProvidersService.ORDER_TIMEOUT_MS,
            });
          } else {
            throw postErr;
          }
        }

        const data = response.data;
        if (data && (data.status === 'SUCCESS' || data.status === 'success')) {
          if (typeof data.balance_after === 'number') {
            provider.balance = data.balance_after;
            await provider.save();
          }

          return {
            success: true,
            transactionId: data.reference || params.reference,
            balanceAfter: data.balance_after,
            message: data.message || 'تم تنفيذ الطلب بنجاح لدى المزود',
            raw: data,
          };
        } else {
          return {
            success: false,
            message: data?.message || 'فشل تنفيذ الطلب لدى المزود',
            raw: data,
          };
        }
      } catch (error: any) {
        const errMsg = this.isTimeoutError(error)
          ? 'انتهت مهلة الاستجابة من مزود الخدمة'
          : error.response?.data?.message || error.message || 'حدث خطأ أثناء الاتصال بمزود الخدمة';
        this.logger.error(`Bay2Game executeOrder error: ${errMsg}`);
        return {
          success: false,
          message: errMsg,
          raw: error.response?.data,
          isTimeout: this.isTimeoutError(error),
        };
      }
    } else if (this.isFoxReload(provider)) {
      const baseUrl = this.getFoxReloadBaseUrl(provider);
      const headers = this.getFoxReloadHeaders(provider);
      const url = `${baseUrl}/api/orders/`;

      try {
        const notePayload: Record<string, any> = {};
        if (params.gameUserId) {
          notePayload.login = params.gameUserId;
          notePayload.account_id = params.gameUserId;
          notePayload.userId = params.gameUserId;
          notePayload.player_id = params.gameUserId;
        }
        if (params.gameZoneId) {
          notePayload.zoneId = params.gameZoneId;
          notePayload.server_id = params.gameZoneId;
        }

        const orderBody: Record<string, any> = {
          items: [
            {
              itemId: params.productCode,
              quantity: 1,
              ...(Object.keys(notePayload).length > 0 ? { note: notePayload } : {}),
            },
          ],
          idempotencyKey: params.reference,
        };

        this.logger.log(`Executing FoxReload order for ref ${params.reference}, product: ${params.productCode}`);

        const response = await axios.post(url, orderBody, {
          headers,
          timeout: ProvidersService.ORDER_TIMEOUT_MS,
        });

        const data = response.data;
        if (data && data.id) {
          const item = data.items && data.items[0];
          const isFailed = data.status === 'cancelled' || (item && item.fulfillmentStatus === 'failed');

          if (isFailed) {
            const failReason = data.cancelReason || item?.error || 'فشل تنفيذ الطلب لدى مزود FoxReload';
            return {
              success: false,
              message: failReason,
              raw: data,
            };
          }

          // Refresh provider balance in background
          this.checkStatus(provider._id.toString()).catch(() => {});

          const codes = item?.externalData || [];
          return {
            success: true,
            transactionId: data.id,
            balanceAfter: provider.balance,
            message: codes.length > 0 ? `تم استلام الكود: ${codes.join(', ')}` : 'تم إرسال الطلب وتنفيذه بنجاح عبر FoxReload',
            raw: data,
          };
        } else {
          return {
            success: false,
            message: data?.detail || 'فشل تنفيذ الطلب لدى مزود FoxReload',
            raw: data,
          };
        }
      } catch (error: any) {
        const errMsg = this.isTimeoutError(error)
          ? 'انتهت مهلة الاستجابة من مزود الخدمة'
          : error.response?.data?.detail || error.response?.data?.message || error.message || 'حدث خطأ أثناء الاتصال بمزود FoxReload';
        this.logger.error(`FoxReload executeOrder error: ${errMsg}`);
        return {
          success: false,
          message: errMsg,
          raw: error.response?.data,
          isTimeout: this.isTimeoutError(error),
        };
      }
    }

    // Generic mock provider execution
    return {
      success: true,
      transactionId: params.reference,
      message: 'تم تنفيذ الطلب بنجاح (المزود العام)',
    };
  }

  // Check specific order status from provider
  async checkOrderStatus(providerId: string, reference: string) {
    const provider = await this.findOne(providerId);

    if (this.isBay2Game(provider)) {
      const url = `${provider.baseUrl.replace(/\/+$/, '')}/check_order`;
      try {
        const res = await axios.get(url, {
          params: {
            api_key: provider.apiKey,
            reference,
          },
          timeout: 10000,
        });
        return res.data;
      } catch (err: any) {
        return {
          status: 'error',
          isTransportError: true,
          message: err.response?.data?.message || err.message,
        };
      }
    } else if (this.isFoxReload(provider)) {
      const baseUrl = this.getFoxReloadBaseUrl(provider);
      const headers = this.getFoxReloadHeaders(provider);
      try {
        const res = await axios.get(`${baseUrl}/api/orders/${reference}`, {
          headers,
          timeout: 10000,
        });
        return res.data;
      } catch (err: any) {
        return {
          status: 'error',
          isTransportError: true,
          message: err.response?.data?.detail || err.message,
        };
      }
    }

    return { status: 'unknown', message: 'فحص الحالة غير مدعوم لهذا المزود' };
  }
}

