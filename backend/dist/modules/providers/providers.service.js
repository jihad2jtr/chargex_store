"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
var ProvidersService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProvidersService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const axios_1 = __importDefault(require("axios"));
const provider_schema_1 = require("../../database/schemas/provider.schema");
const provider_product_schema_1 = require("../../database/schemas/provider-product.schema");
const product_schema_1 = require("../../database/schemas/product.schema");
const notifications_service_1 = require("../notifications/notifications.service");
const virtual_number_clients_1 = require("../virtual-numbers/virtual-number-clients");
let ProvidersService = ProvidersService_1 = class ProvidersService {
    constructor(providerModel, providerProductModel, productModel, notificationsService) {
        this.providerModel = providerModel;
        this.providerProductModel = providerProductModel;
        this.productModel = productModel;
        this.notificationsService = notificationsService;
        this.logger = new common_1.Logger(ProvidersService_1.name);
    }
    isTimeoutError(err) {
        if (!err)
            return false;
        const code = err.code || '';
        return (code === 'ECONNABORTED' ||
            code === 'ETIMEDOUT' ||
            code === 'ERR_CANCELED' ||
            /timeout/i.test(err.message || ''));
    }
    isBay2Game(provider) {
        return (provider.providerType === provider_schema_1.ProviderType.BAY2GAME ||
            provider.baseUrl?.toLowerCase().includes('bay2game') ||
            provider.name?.toLowerCase().includes('bay2game'));
    }
    isFoxReload(provider) {
        return (provider.providerType === provider_schema_1.ProviderType.FOXRELOAD ||
            provider.baseUrl?.toLowerCase().includes('foxreload') ||
            provider.name?.toLowerCase().includes('foxreload'));
    }
    isVirtualNumbers(provider) {
        return (0, virtual_number_clients_1.isVirtualNumberProvider)(provider);
    }
    virtualNumberClient(provider) {
        return (0, virtual_number_clients_1.createVirtualNumberClient)({
            baseUrl: provider.baseUrl,
            apiKey: provider.apiKey,
            providerType: provider.providerType,
            name: provider.name,
        });
    }
    getFoxReloadBaseUrl(provider) {
        const raw = (provider.baseUrl || '').trim().replace(/\/+$/, '');
        if (!raw || (raw.includes('foxreload.com') && !raw.includes('public-api.foxreload.com'))) {
            return 'https://public-api.foxreload.com';
        }
        return raw;
    }
    getFoxReloadHeaders(provider) {
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
    async findOne(id) {
        const provider = await this.providerModel.findById(id);
        if (!provider)
            throw new common_1.NotFoundException('المزود غير موجود');
        return provider;
    }
    async create(createDto) {
        const isBay = createDto.providerType === provider_schema_1.ProviderType.BAY2GAME ||
            createDto.baseUrl?.toLowerCase().includes('bay2game') ||
            createDto.name?.toLowerCase().includes('bay2game');
        const isFox = createDto.providerType === provider_schema_1.ProviderType.FOXRELOAD ||
            createDto.baseUrl?.toLowerCase().includes('foxreload') ||
            createDto.name?.toLowerCase().includes('foxreload');
        const virtualType = (0, virtual_number_clients_1.detectVirtualNumberType)(createDto);
        const resolvedType = isBay
            ? provider_schema_1.ProviderType.BAY2GAME
            : isFox
                ? provider_schema_1.ProviderType.FOXRELOAD
                : virtualType ?? (createDto.providerType || provider_schema_1.ProviderType.CUSTOM);
        const provider = new this.providerModel({
            ...createDto,
            providerType: resolvedType,
            status: provider_schema_1.ProviderStatus.OFFLINE,
            isActive: true,
        });
        await provider.save();
        try {
            await this.checkStatus(provider._id.toString());
        }
        catch (e) {
            this.logger.warn(`Initial status check for new provider failed: ${e.message}`);
        }
        return provider;
    }
    async update(id, updateDto) {
        const provider = await this.providerModel.findByIdAndUpdate(id, updateDto, { new: true });
        if (!provider)
            throw new common_1.NotFoundException('المزود غير موجود');
        const marginChanged = updateDto.profitMarginType !== undefined || updateDto.profitMarginValue !== undefined;
        if (marginChanged) {
            await this.recalculateProviderPrices(id);
        }
        return provider;
    }
    async toggleActive(id) {
        const provider = await this.findOne(id);
        const nextActive = provider.isActive === false;
        provider.isActive = nextActive;
        if (!nextActive) {
            provider.lastError = provider.lastError || 'أُوقف المزود يدوياً من الإدارة';
            await provider.save();
            return provider;
        }
        provider.lastError = undefined;
        await provider.save();
        try {
            return await this.checkStatus(id);
        }
        catch (err) {
            this.logger.warn(`Post-enable status check failed for ${provider.name}: ${err.message}`);
            return provider;
        }
    }
    computeSalePrice(costPrice, marginType, marginValue) {
        const cost = Number(costPrice) || 0;
        const margin = Number(marginValue) || 0;
        const price = marginType === product_schema_1.ProfitMarginType.FIXED ? cost + margin : cost * (1 + margin / 100);
        return Math.round(price * 100) / 100;
    }
    async recalculateProviderPrices(providerId) {
        const provider = await this.findOne(providerId);
        const marginType = provider.profitMarginType ?? product_schema_1.ProfitMarginType.PERCENTAGE;
        const marginValue = provider.profitMarginValue ?? 0;
        const products = await this.productModel.find({
            providerId: new mongoose_2.Types.ObjectId(providerId),
        });
        for (const product of products) {
            const newSalePrice = this.computeSalePrice(product.costPrice, marginType, marginValue);
            if (newSalePrice !== product.salePrice) {
                product.profitMarginType = marginType;
                product.profitMarginValue = marginValue;
                product.salePrice = newSalePrice;
                await product.save();
            }
        }
        return { message: 'تم تحديث أسعار منتجات المزود وفق هامش الربح الجديد', updated: products.length };
    }
    async remove(id) {
        const provider = await this.providerModel.findByIdAndDelete(id);
        if (!provider)
            throw new common_1.NotFoundException('المزود غير موجود');
        await this.providerProductModel.deleteMany({ providerId: provider._id });
        return { message: 'تم حذف المزود بنجاح' };
    }
    async checkStatus(id) {
        const provider = await this.findOne(id);
        provider.lastCheckAt = new Date();
        try {
            if (this.isBay2Game(provider)) {
                const url = `${provider.baseUrl.replace(/\/+$/, '')}/profile`;
                const response = await axios_1.default.get(url, {
                    params: { api_key: provider.apiKey },
                    timeout: ProvidersService_1.STATUS_TIMEOUT_MS,
                });
                if (response.data && (response.data.status === 'success' || response.data.status === 'SUCCESS')) {
                    provider.status = provider_schema_1.ProviderStatus.ONLINE;
                    provider.balance = typeof response.data.user?.balance === 'number' ? response.data.user.balance : 0;
                    provider.lastError = undefined;
                }
                else {
                    provider.status = provider_schema_1.ProviderStatus.ERROR;
                    provider.lastError = response.data?.message || 'فشل التحقق من حساب المزود';
                }
            }
            else if (this.isFoxReload(provider)) {
                const baseUrl = this.getFoxReloadBaseUrl(provider);
                const headers = this.getFoxReloadHeaders(provider);
                const [meRes, balRes] = await Promise.all([
                    axios_1.default.get(`${baseUrl}/api/access/me`, { headers, timeout: ProvidersService_1.STATUS_TIMEOUT_MS }),
                    axios_1.default
                        .get(`${baseUrl}/api/access/me/balances/`, { headers, timeout: ProvidersService_1.STATUS_TIMEOUT_MS })
                        .catch(() => null),
                ]);
                if (meRes.data && meRes.data.isActive !== false) {
                    let currentBalance = 0;
                    if (balRes && Array.isArray(balRes.data) && balRes.data.length > 0) {
                        const usdBal = balRes.data.find((b) => (b.currency || '').toLowerCase() === 'usd') || balRes.data[0];
                        currentBalance = parseFloat(usdBal.amount ?? usdBal.balance ?? '0') || 0;
                    }
                    provider.balance = currentBalance;
                    provider.status = provider_schema_1.ProviderStatus.ONLINE;
                    provider.lastError = undefined;
                }
                else {
                    provider.status = provider_schema_1.ProviderStatus.ERROR;
                    provider.lastError = 'حساب المزود غير نشط أو مفتاح API غير صالح';
                }
            }
            else if (this.isVirtualNumbers(provider)) {
                const profile = await this.virtualNumberClient(provider).getProfile();
                provider.balance = profile.balance;
                provider.status = provider_schema_1.ProviderStatus.ONLINE;
                provider.lastError = undefined;
            }
            else {
                await axios_1.default.get(provider.baseUrl, {
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
                provider.status = provider_schema_1.ProviderStatus.ONLINE;
                provider.lastError = undefined;
            }
        }
        catch (error) {
            provider.status = provider_schema_1.ProviderStatus.ERROR;
            provider.lastError = error.response?.data?.message || error.message || 'فشل الاتصال بالمزود';
        }
        await provider.save();
        return provider;
    }
    isInsufficientBalanceError(message) {
        const msg = (message || '').toLowerCase();
        if (!msg)
            return false;
        return (/insufficient\s+(balance|credit|funds|money)/.test(msg) ||
            /not\s+enough\s+(balance|credit|funds|money)/.test(msg) ||
            /(balance|credit|funds)\s+(is\s+)?(too\s+)?(low|empty|zero|exhausted|depleted)/.test(msg) ||
            /(no|without)\s+(available\s+)?(balance|credit|funds)/.test(msg) ||
            /out\s+of\s+(balance|credit|funds)/.test(msg) ||
            /رصيد\s*(المزود|غير|لا|منخفض|صفر)/.test(msg));
    }
    async disableForInsufficientBalance(provider, reason) {
        const updated = await this.providerModel.findOneAndUpdate({ _id: provider._id, isActive: { $ne: false } }, { $set: { isActive: false, status: provider_schema_1.ProviderStatus.ERROR, lastError: reason } }, { new: true });
        if (!updated)
            return;
        this.logger.warn(`Provider ${updated.name} auto-disabled: ${reason}`);
        try {
            await this.notificationsService.createNotification({
                forRole: 'admin',
                title: 'إيقاف مزود تلقائياً: الرصيد غير كافٍ',
                body: `أُوقف المزود "${updated.name}" تلقائياً بعد تعذّر تنفيذ طلب بسبب الرصيد (${reason}). أعد شحن رصيده ثم فعّله من إدارة المزودين.`,
                type: 'provider_alert',
            });
        }
        catch (err) {
            this.logger.warn(`Provider auto-disable notification failed: ${err?.message}`);
        }
    }
    async ensureReadyForOrder(providerId, requiredCost = 0) {
        let provider;
        try {
            provider = await this.findOne(providerId);
        }
        catch {
            throw new common_1.BadRequestException('خدمة هذا المنتج غير متاحة حالياً، ولم يتم خصم أي مبلغ من رصيدك');
        }
        if (provider.isActive === false) {
            throw new common_1.BadRequestException('خدمة هذا المنتج غير متاحة حالياً، ولم يتم خصم أي مبلغ من رصيدك');
        }
        const lastCheck = provider.lastCheckAt ? new Date(provider.lastCheckAt).getTime() : 0;
        if (!lastCheck || Date.now() - lastCheck > ProvidersService_1.STATUS_TTL_MS) {
            try {
                provider = await this.checkStatus(providerId);
            }
            catch (err) {
                this.logger.warn(`Readiness check for provider ${provider.name} failed: ${err.message}`);
            }
        }
        if (provider.status !== provider_schema_1.ProviderStatus.ONLINE) {
            throw new common_1.BadRequestException('مزوّد الخدمة غير متاح حالياً، ولم يتم خصم أي مبلغ من رصيدك. يرجى المحاولة لاحقاً');
        }
        const balance = typeof provider.balance === 'number' ? provider.balance : 0;
        if (requiredCost > 0 && balance < requiredCost) {
            await this.disableForInsufficientBalance(provider, `الرصيد $${balance.toFixed(2)} أقل من تكلفة الطلب $${requiredCost.toFixed(2)}`).catch((err) => this.logger.warn(`Provider auto-disable failed: ${err.message}`));
            throw new common_1.BadRequestException('ضغط على السيرفر الرجاء المحاولة لا حقاً');
        }
        return provider;
    }
    async markProviderFailure(providerId, message, requiredCost = 0) {
        const insufficientSignal = this.isInsufficientBalanceError(message);
        try {
            await this.providerModel.updateOne({ _id: providerId }, { $set: { lastError: message } });
        }
        catch (err) {
            this.logger.warn(`Could not persist provider failure: ${err.message}`);
        }
        this.checkStatus(providerId)
            .then((refreshed) => {
            const balance = typeof refreshed.balance === 'number' ? refreshed.balance : 0;
            const drained = requiredCost > 0 && balance < requiredCost;
            if (!insufficientSignal && !drained)
                return;
            return this.disableForInsufficientBalance(refreshed, insufficientSignal
                ? `المزود أبلغ عن نفاد الرصيد: ${message}`
                : `الرصيد $${balance.toFixed(2)} أقل من تكلفة الطلب $${requiredCost.toFixed(2)}`);
        })
            .catch((err) => this.logger.warn(`Background provider status refresh failed: ${err.message}`));
    }
    async inspectOrderStatus(providerId, reference) {
        const provider = await this.findOne(providerId);
        const raw = await this.checkOrderStatus(providerId, reference);
        if (raw?.isTransportError) {
            return { state: 'unknown', message: raw?.message, raw };
        }
        const rawStatus = String(raw?.status ?? raw?.state ?? '').toLowerCase();
        if (this.isBay2Game(provider)) {
            const codes = [raw?.code, raw?.delivered_code, raw?.serial]
                .filter((c) => typeof c === 'string' && c.trim().length > 0)
                .map((c) => c.trim());
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
    async getProviderCategories(providerId) {
        const provider = await this.findOne(providerId);
        if (this.isBay2Game(provider)) {
            try {
                const url = `${provider.baseUrl.replace(/\/+$/, '')}/categories`;
                const res = await axios_1.default.get(url, {
                    params: { api_key: provider.apiKey },
                    timeout: 15000,
                });
                if (res.data && res.data.categories) {
                    return res.data.categories;
                }
            }
            catch (err) {
                this.logger.error(`Error fetching Bay2Game categories: ${err.message}`);
                throw new common_1.BadRequestException('تعذر جلب فئات الألعاب من المزود: ' + (err.response?.data?.message || err.message));
            }
        }
        else if (this.isFoxReload(provider)) {
            try {
                const baseUrl = this.getFoxReloadBaseUrl(provider);
                const headers = this.getFoxReloadHeaders(provider);
                const rootSections = [
                    '019e9ca5-0403-70b3-90d5-e9641f64b76b',
                    '019ea790-779d-7fd3-9ed7-976a410ab182',
                    '4740cefd-c9eb-4291-93dc-fad5cb24c855',
                    'c53e27b8-a213-47b9-b05d-1b2472c95483',
                    '019ea76e-b2f0-7de2-833c-9ec599ab7233',
                ];
                const sectionResponses = await Promise.all(rootSections.map((secId) => axios_1.default
                    .get(`${baseUrl}/api/categories/`, {
                    headers,
                    params: { parentId: secId, limit: 100 },
                    timeout: 15000,
                })
                    .catch(() => ({ data: { items: [] } }))));
                let allGames = [];
                for (const resp of sectionResponses) {
                    const items = resp.data?.items || [];
                    allGames = allGames.concat(items);
                }
                const inStockGames = allGames.filter((g) => (g.inStockCount || 0) > 0);
                return inStockGames.map((g) => ({
                    game_code: g.id,
                    name: g.name,
                    image_url: g.imagePath || g.thumbnailPath,
                    in_stock_count: g.inStockCount,
                    game_fields: ['userid', 'serverid'],
                    hasProducts: g.hasProducts,
                }));
            }
            catch (err) {
                this.logger.error(`Error fetching FoxReload categories: ${err.message}`);
                throw new common_1.BadRequestException('تعذر جلب فئات الألعاب من المزود: ' + (err.response?.data?.detail || err.message));
            }
        }
        return [];
    }
    async syncProviderProducts(providerId, gameCodes) {
        const provider = await this.findOne(providerId);
        let totalSynced = 0;
        if (this.isBay2Game(provider)) {
            try {
                const baseUrl = provider.baseUrl.replace(/\/+$/, '');
                const catRes = await axios_1.default.get(`${baseUrl}/categories`, {
                    params: { api_key: provider.apiKey },
                    timeout: 15000,
                });
                const categories = catRes.data?.categories || [];
                const targetCats = (gameCodes && gameCodes.length > 0)
                    ? categories.filter((c) => gameCodes.includes(c.game_code))
                    : categories;
                for (const cat of targetCats) {
                    try {
                        const prodRes = await axios_1.default.get(`${baseUrl}/products`, {
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
                            await this.providerProductModel.findOneAndUpdate({
                                providerId: provider._id,
                                providerProductCode: productCode,
                            }, {
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
                            }, { upsert: true, new: true });
                            totalSynced++;
                        }
                    }
                    catch (itemErr) {
                        this.logger.warn(`Failed to sync game products for ${cat.game_code}: ${itemErr.message}`);
                    }
                }
                await this.checkStatus(provider._id.toString());
                return {
                    message: `تمت مزامنة ${totalSynced} منتج من المزود بنجاح`,
                    syncedCount: totalSynced,
                };
            }
            catch (err) {
                this.logger.error(`Error in syncProviderProducts: ${err.message}`);
                throw new common_1.BadRequestException('فشل في مزامنة المنتجات من المزود: ' + (err.response?.data?.message || err.message));
            }
        }
        else if (this.isFoxReload(provider)) {
            try {
                const baseUrl = this.getFoxReloadBaseUrl(provider);
                const headers = this.getFoxReloadHeaders(provider);
                const catList = await this.getProviderCategories(providerId);
                let targetGames = [];
                if (gameCodes && gameCodes.length > 0) {
                    targetGames = catList.filter((c) => gameCodes.includes(c.game_code));
                }
                else {
                    await this.providerProductModel.deleteMany({
                        providerId: provider._id,
                        category: { $in: ['FoxReload', 'Fox - WW', 'Fox - CIS', 'Fox - MENA', 'Fox - EU', 'Fox - NA', 'عام'] },
                    });
                    const popularKeywords = [
                        'pubg', 'free fire', 'duty', 'brawl', 'roblox', 'fc', 'fifa', 'itunes', 'google',
                        'steam', 'playstation', 'xbox', 'razer', 'telegram', 'discord', '8 ball pool', 'blood strike'
                    ];
                    const popularGames = catList.filter((g) => popularKeywords.some((kw) => (g.name || '').toLowerCase().includes(kw)));
                    const otherGames = catList.filter((g) => !popularKeywords.some((kw) => (g.name || '').toLowerCase().includes(kw)));
                    targetGames = [...popularGames, ...otherGames.slice(0, 35)];
                }
                for (const game of targetGames) {
                    try {
                        let productsToSync = [];
                        if (game.hasProducts) {
                            const prodRes = await axios_1.default.get(`${baseUrl}/api/products/`, {
                                headers,
                                params: { categoryId: game.game_code, limit: 100 },
                                timeout: 15000,
                            });
                            const items = prodRes.data?.items || [];
                            for (const it of items) {
                                productsToSync.push({ item: it });
                            }
                        }
                        else {
                            const subRes = await axios_1.default.get(`${baseUrl}/api/categories/`, {
                                headers,
                                params: { parentId: game.game_code, limit: 100 },
                                timeout: 10000,
                            });
                            const subItems = subRes.data?.items || [];
                            for (const sub of subItems) {
                                if (sub.hasProducts) {
                                    const subProdRes = await axios_1.default.get(`${baseUrl}/api/products/`, {
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
                            if (subName &&
                                subName.toLowerCase() !== 'global' &&
                                !productName.toLowerCase().includes(subName.toLowerCase())) {
                                productName = `${item.name} (${subName})`;
                            }
                            const costPrice = parseFloat(item.price) || 0;
                            const inStock = (item.quantity ?? 0) > 0 || item.deliveryType === 'direct_topup';
                            await this.providerProductModel.findOneAndUpdate({
                                providerId: provider._id,
                                providerProductCode: productCode,
                            }, {
                                providerId: provider._id,
                                providerProductCode: productCode,
                                name: productName,
                                category: game.name,
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
                            }, { upsert: true, new: true });
                            totalSynced++;
                        }
                    }
                    catch (itemErr) {
                        this.logger.warn(`Failed to sync FoxReload products for ${game.name}: ${itemErr.message}`);
                    }
                }
                await this.checkStatus(provider._id.toString());
                return {
                    message: `تمت مزامنة ${totalSynced} منتج عبر ${targetGames.length} لعبة وتطبيق من FoxReload بنجاح`,
                    syncedCount: totalSynced,
                };
            }
            catch (err) {
                this.logger.error(`Error in syncProviderProducts (FoxReload): ${err.message}`);
                throw new common_1.BadRequestException('فشل في مزامنة المنتجات من مزود FoxReload: ' + (err.response?.data?.detail || err.message));
            }
        }
        return { message: 'لا تدعم هذه الفئة المزامنة التلقائية للمزود الحالي', syncedCount: 0 };
    }
    async getProviderProducts(providerId, category) {
        const filter = { providerId: new mongoose_2.Types.ObjectId(providerId) };
        if (category)
            filter.category = category;
        let products = await this.providerProductModel.find(filter).sort({ category: 1, costPrice: 1 });
        if (products.length === 0) {
            const provider = await this.findOne(providerId);
            if (this.isBay2Game(provider) || this.isFoxReload(provider)) {
                this.logger.log(`Initial sync for provider ${provider.name}...`);
                await this.syncProviderProducts(providerId);
                products = await this.providerProductModel.find(filter).sort({ category: 1, costPrice: 1 });
            }
            else {
                await this.seedMockProviderProducts(providerId);
                products = await this.providerProductModel.find(filter).sort({ category: 1, costPrice: 1 });
            }
        }
        const importedCodes = await this.productModel.distinct('providerProductCode', {
            providerId: new mongoose_2.Types.ObjectId(providerId),
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
    async seedMockProviderProducts(providerId) {
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
                providerId: new mongoose_2.Types.ObjectId(providerId),
                ...item,
                currency: 'USD',
                inStock: true,
            });
        }
    }
    async importToProducts(providerProductId, appId, opts = {}) {
        const item = await this.providerProductModel.findById(providerProductId);
        if (!item)
            throw new common_1.NotFoundException('منتج المزود غير موجود');
        const costPrice = item.costPrice;
        const provider = await this.providerModel.findById(item.providerId);
        const marginType = provider?.profitMarginType ?? product_schema_1.ProfitMarginType.PERCENTAGE;
        const marginValue = provider?.profitMarginValue ?? 0;
        const salePrice = this.computeSalePrice(costPrice, marginType, marginValue);
        const gameFields = item.rawDetails?.game_fields || [];
        let requiredFields = ['Player ID'];
        if (gameFields.includes('userid') && gameFields.includes('serverid')) {
            requiredFields = ['Player ID', 'Server/Zone ID'];
        }
        else if (gameFields.length > 0) {
            requiredFields = gameFields.map((f) => (f === 'userid' ? 'Player ID' : f === 'serverid' ? 'Server/Zone ID' : f));
        }
        const newProduct = new this.productModel({
            appId: new mongoose_2.Types.ObjectId(appId),
            name: opts.name?.trim() ? opts.name.trim() : item.name,
            description: item.category,
            type: product_schema_1.ProductType.DIRECT_API,
            providerId: item.providerId,
            providerProductCode: item.providerProductCode,
            serviceTemplateId: opts.serviceTemplateId && mongoose_2.Types.ObjectId.isValid(opts.serviceTemplateId)
                ? new mongoose_2.Types.ObjectId(opts.serviceTemplateId)
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
    async batchImportToProducts(providerProductIds, appId, opts = {}) {
        const results = [];
        for (const id of providerProductIds) {
            try {
                const prod = await this.importToProducts(id, appId, opts);
                results.push(prod);
            }
            catch (err) {
                this.logger.warn(`Failed to import provider product ${id}: ${err.message}`);
            }
        }
        return {
            message: `تم استيراد ${results.length} من أصل ${providerProductIds.length} منتج بنجاح إلى الكتالوج`,
            importedCount: results.length,
            products: results,
        };
    }
    async executeOrder(providerId, params) {
        const provider = await this.findOne(providerId);
        if (this.isBay2Game(provider)) {
            const url = `${provider.baseUrl.replace(/\/+$/, '')}/create_order`;
            try {
                const payload = {
                    api_key: provider.apiKey,
                    product_code: params.productCode,
                    game_user_id: params.gameUserId,
                    reference: params.reference,
                };
                if (params.gameZoneId) {
                    payload.game_zone_id = params.gameZoneId;
                }
                this.logger.log(`Executing Bay2Game order for reference ${params.reference}, product: ${params.productCode}, user: ${params.gameUserId}`);
                let response;
                try {
                    response = await axios_1.default.post(url, payload, {
                        headers: { 'Content-Type': 'application/json' },
                        timeout: ProvidersService_1.ORDER_TIMEOUT_MS,
                    });
                }
                catch (postErr) {
                    const methodRejected = [404, 405, 501].includes(postErr.response?.status);
                    if (methodRejected) {
                        response = await axios_1.default.get(url, {
                            params: payload,
                            timeout: ProvidersService_1.ORDER_TIMEOUT_MS,
                        });
                    }
                    else {
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
                }
                else {
                    return {
                        success: false,
                        message: data?.message || 'فشل تنفيذ الطلب لدى المزود',
                        raw: data,
                    };
                }
            }
            catch (error) {
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
        }
        else if (this.isFoxReload(provider)) {
            const baseUrl = this.getFoxReloadBaseUrl(provider);
            const headers = this.getFoxReloadHeaders(provider);
            const url = `${baseUrl}/api/orders/`;
            try {
                const notePayload = {};
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
                const orderBody = {
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
                const response = await axios_1.default.post(url, orderBody, {
                    headers,
                    timeout: ProvidersService_1.ORDER_TIMEOUT_MS,
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
                    this.checkStatus(provider._id.toString()).catch(() => { });
                    const codes = item?.externalData || [];
                    return {
                        success: true,
                        transactionId: data.id,
                        balanceAfter: provider.balance,
                        message: codes.length > 0 ? `تم استلام الكود: ${codes.join(', ')}` : 'تم إرسال الطلب وتنفيذه بنجاح عبر FoxReload',
                        raw: data,
                    };
                }
                else {
                    return {
                        success: false,
                        message: data?.detail || 'فشل تنفيذ الطلب لدى مزود FoxReload',
                        raw: data,
                    };
                }
            }
            catch (error) {
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
        return {
            success: true,
            transactionId: params.reference,
            message: 'تم تنفيذ الطلب بنجاح (المزود العام)',
        };
    }
    async checkOrderStatus(providerId, reference) {
        const provider = await this.findOne(providerId);
        if (this.isBay2Game(provider)) {
            const url = `${provider.baseUrl.replace(/\/+$/, '')}/check_order`;
            try {
                const res = await axios_1.default.get(url, {
                    params: {
                        api_key: provider.apiKey,
                        reference,
                    },
                    timeout: 10000,
                });
                return res.data;
            }
            catch (err) {
                return {
                    status: 'error',
                    isTransportError: true,
                    message: err.response?.data?.message || err.message,
                };
            }
        }
        else if (this.isFoxReload(provider)) {
            const baseUrl = this.getFoxReloadBaseUrl(provider);
            const headers = this.getFoxReloadHeaders(provider);
            try {
                const res = await axios_1.default.get(`${baseUrl}/api/orders/${reference}`, {
                    headers,
                    timeout: 10000,
                });
                return res.data;
            }
            catch (err) {
                return {
                    status: 'error',
                    isTransportError: true,
                    message: err.response?.data?.detail || err.message,
                };
            }
        }
        return { status: 'unknown', message: 'فحص الحالة غير مدعوم لهذا المزود' };
    }
};
exports.ProvidersService = ProvidersService;
ProvidersService.ORDER_TIMEOUT_MS = 12_000;
ProvidersService.STATUS_TIMEOUT_MS = 8_000;
ProvidersService.STATUS_TTL_MS = 10 * 60 * 1000;
exports.ProvidersService = ProvidersService = ProvidersService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(provider_schema_1.Provider.name)),
    __param(1, (0, mongoose_1.InjectModel)(provider_product_schema_1.ProviderProduct.name)),
    __param(2, (0, mongoose_1.InjectModel)(product_schema_1.Product.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        notifications_service_1.NotificationsService])
], ProvidersService);
//# sourceMappingURL=providers.service.js.map