import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import axios from 'axios';
import { Provider, ProviderDocument, ProviderStatus, ProviderType } from '../../database/schemas/provider.schema';
import { ProviderProduct, ProviderProductDocument } from '../../database/schemas/provider-product.schema';
import { Product, ProductDocument, ProfitMarginType, ProductType } from '../../database/schemas/product.schema';

@Injectable()
export class ProvidersService {
  private readonly logger = new Logger(ProvidersService.name);

  // No default filter — sync ALL categories from provider unless specific gameCodes are given

  constructor(
    @InjectModel(Provider.name) private providerModel: Model<ProviderDocument>,
    @InjectModel(ProviderProduct.name) private providerProductModel: Model<ProviderProductDocument>,
    @InjectModel(Product.name) private productModel: Model<ProductDocument>,
  ) {}

  private isBay2Game(provider: ProviderDocument): boolean {
    return (
      provider.providerType === ProviderType.BAY2GAME ||
      provider.baseUrl?.toLowerCase().includes('bay2game') ||
      provider.name?.toLowerCase().includes('bay2game')
    );
  }

  async findAll() {
    return this.providerModel.find().sort({ createdAt: -1 });
  }

  async findOne(id: string) {
    const provider = await this.providerModel.findById(id);
    if (!provider) throw new NotFoundException('المزود غير موجود');
    return provider;
  }

  async create(createDto: {
    name: string;
    baseUrl: string;
    apiKey: string;
    apiSecret?: string;
    headers?: Record<string, string>;
    providerType?: ProviderType;
  }) {
    const isBay =
      createDto.providerType === ProviderType.BAY2GAME ||
      createDto.baseUrl?.toLowerCase().includes('bay2game') ||
      createDto.name?.toLowerCase().includes('bay2game');

    const provider = new this.providerModel({
      ...createDto,
      providerType: isBay ? ProviderType.BAY2GAME : (createDto.providerType || ProviderType.CUSTOM),
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
    return provider;
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
          timeout: 10000,
        });

        if (response.data && (response.data.status === 'success' || response.data.status === 'SUCCESS')) {
          provider.status = ProviderStatus.ONLINE;
          provider.balance = typeof response.data.user?.balance === 'number' ? response.data.user.balance : 0;
          provider.lastError = undefined;
        } else {
          provider.status = ProviderStatus.ERROR;
          provider.lastError = response.data?.message || 'فشل التحقق من حساب المزود';
        }
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
    }

    return { message: 'لا تدعم هذه الفئة المزامنة التلقائية للمزود الحالي', syncedCount: 0 };
  }

  async getProviderProducts(providerId: string, category?: string) {
    const filter: any = { providerId: new Types.ObjectId(providerId) };
    if (category) filter.category = category;

    let products = await this.providerProductModel.find(filter).sort({ category: 1, costPrice: 1 });

    if (products.length === 0) {
      const provider = await this.findOne(providerId);
      if (this.isBay2Game(provider)) {
        // Auto-run initial sync for Bay2Game
        this.logger.log(`Initial sync for Bay2Game provider ${provider.name}...`);
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
    marginType?: ProfitMarginType,
    marginValue?: number,
  ) {
    const item = await this.providerProductModel.findById(providerProductId);
    if (!item) throw new NotFoundException('منتج المزود غير موجود');

    const costPrice = item.costPrice;
    // Margin is configured later from the admin dashboard — import with 0 margin by default
    const resolvedMarginType = marginType ?? ProfitMarginType.PERCENTAGE;
    const resolvedMarginValue = marginValue ?? 0;
    const salePrice = costPrice; // No markup at import time

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
      name: item.name,
      description: item.category,
      type: ProductType.DIRECT_API,
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

  async batchImportToProducts(
    providerProductIds: string[],
    appId: string,
    marginType: ProfitMarginType,
    marginValue: number,
  ) {
    const results = [];
    for (const id of providerProductIds) {
      try {
        const prod = await this.importToProducts(id, appId, marginType, marginValue);
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
            timeout: 25000,
          });
        } catch (postErr: any) {
          // If 405 Method Not Allowed or similar, try GET with query params
          if (postErr.response?.status === 405 || !postErr.response) {
            response = await axios.get(url, { params: payload, timeout: 25000 });
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
        const errMsg = error.response?.data?.message || error.message || 'حدث خطأ أثناء الاتصال بمزود الخدمة';
        this.logger.error(`Bay2Game executeOrder error: ${errMsg}`);
        return {
          success: false,
          message: errMsg,
          raw: error.response?.data,
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
          message: err.response?.data?.message || err.message,
        };
      }
    }

    return { status: 'unknown', message: 'فحص الحالة غير مدعوم لهذا المزود' };
  }
}

