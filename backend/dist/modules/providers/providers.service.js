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
let ProvidersService = ProvidersService_1 = class ProvidersService {
    constructor(providerModel, providerProductModel, productModel) {
        this.providerModel = providerModel;
        this.providerProductModel = providerProductModel;
        this.productModel = productModel;
        this.logger = new common_1.Logger(ProvidersService_1.name);
    }
    isBay2Game(provider) {
        return (provider.providerType === provider_schema_1.ProviderType.BAY2GAME ||
            provider.baseUrl?.toLowerCase().includes('bay2game') ||
            provider.name?.toLowerCase().includes('bay2game'));
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
        const provider = new this.providerModel({
            ...createDto,
            providerType: isBay ? provider_schema_1.ProviderType.BAY2GAME : (createDto.providerType || provider_schema_1.ProviderType.CUSTOM),
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
        return provider;
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
                    timeout: 10000,
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
        return { message: 'لا تدعم هذه الفئة المزامنة التلقائية للمزود الحالي', syncedCount: 0 };
    }
    async getProviderProducts(providerId, category) {
        const filter = { providerId: new mongoose_2.Types.ObjectId(providerId) };
        if (category)
            filter.category = category;
        let products = await this.providerProductModel.find(filter).sort({ category: 1, costPrice: 1 });
        if (products.length === 0) {
            const provider = await this.findOne(providerId);
            if (this.isBay2Game(provider)) {
                this.logger.log(`Initial sync for Bay2Game provider ${provider.name}...`);
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
    async importToProducts(providerProductId, appId, marginType, marginValue) {
        const item = await this.providerProductModel.findById(providerProductId);
        if (!item)
            throw new common_1.NotFoundException('منتج المزود غير موجود');
        const costPrice = item.costPrice;
        const resolvedMarginType = marginType ?? product_schema_1.ProfitMarginType.PERCENTAGE;
        const resolvedMarginValue = marginValue ?? 0;
        const salePrice = costPrice;
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
            name: item.name,
            description: item.category,
            type: product_schema_1.ProductType.DIRECT_API,
            providerId: item.providerId,
            providerProductCode: item.providerProductCode,
            costPrice,
            profitMarginType: resolvedMarginType,
            profitMarginValue: resolvedMarginValue,
            salePrice,
            isActive: true,
            requiredFields,
        });
        await newProduct.save();
        return newProduct;
    }
    async batchImportToProducts(providerProductIds, appId, marginType, marginValue) {
        const results = [];
        for (const id of providerProductIds) {
            try {
                const prod = await this.importToProducts(id, appId, marginType, marginValue);
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
                        timeout: 25000,
                    });
                }
                catch (postErr) {
                    if (postErr.response?.status === 405 || !postErr.response) {
                        response = await axios_1.default.get(url, { params: payload, timeout: 25000 });
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
                const errMsg = error.response?.data?.message || error.message || 'حدث خطأ أثناء الاتصال بمزود الخدمة';
                this.logger.error(`Bay2Game executeOrder error: ${errMsg}`);
                return {
                    success: false,
                    message: errMsg,
                    raw: error.response?.data,
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
                    message: err.response?.data?.message || err.message,
                };
            }
        }
        return { status: 'unknown', message: 'فحص الحالة غير مدعوم لهذا المزود' };
    }
};
exports.ProvidersService = ProvidersService;
exports.ProvidersService = ProvidersService = ProvidersService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(provider_schema_1.Provider.name)),
    __param(1, (0, mongoose_1.InjectModel)(provider_product_schema_1.ProviderProduct.name)),
    __param(2, (0, mongoose_1.InjectModel)(product_schema_1.Product.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model])
], ProvidersService);
//# sourceMappingURL=providers.service.js.map