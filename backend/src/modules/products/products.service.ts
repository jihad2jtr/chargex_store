import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Product, ProductDocument, ProfitMarginType, ProductType } from '../../database/schemas/product.schema';
import { ProviderProduct, ProviderProductDocument } from '../../database/schemas/provider-product.schema';

@Injectable()
export class ProductsService {
  private readonly logger = new Logger(ProductsService.name);

  constructor(
    @InjectModel(Product.name) private productModel: Model<ProductDocument>,
    @InjectModel(ProviderProduct.name) private providerProductModel: Model<ProviderProductDocument>,
  ) {}

  // Calculate final sale price based on cost and profit margin
  calculateSalePrice(costPrice: number, marginType: ProfitMarginType, marginValue: number): number {
    if (marginType === ProfitMarginType.PERCENTAGE) {
      return Number((costPrice * (1 + marginValue / 100)).toFixed(2));
    }
    return Number((costPrice + marginValue).toFixed(2));
  }

  // User: active products under an app
  async findByAppUser(appId: string) {
    const products = await this.productModel
      .find({ appId: new Types.ObjectId(appId), isActive: true })
      .populate('providerId', 'name status')
      .populate('assignedSupervisorId', 'name role')
      .sort({ salePrice: 1 });

    return products.map((prod) => {
      const obj = prod.toObject();
      return {
        ...obj,
        availableCodesCount: obj.inventoryCodes ? obj.inventoryCodes.length : 0,
        inventoryCodes: undefined, // Don't expose actual secret codes to client list!
      };
    });
  }

  // Admin: all products under an app or system-wide
  async findAllAdmin(appId?: string) {
    const filter: any = {};
    if (appId) {
      filter.appId = new Types.ObjectId(appId);
    }
    const products = await this.productModel
      .find(filter)
      .populate('appId', 'name iconUrl')
      .populate('providerId', 'name status')
      .populate('assignedSupervisorId', 'name role email')
      .sort({ createdAt: -1 });

    return products.map((prod) => {
      const obj = prod.toObject();
      return {
        ...obj,
        availableCodesCount: obj.inventoryCodes ? obj.inventoryCodes.length : 0,
      };
    });
  }

  async findOne(id: string) {
    const product = await this.productModel
      .findById(id)
      .populate('appId', 'name iconUrl')
      .populate('providerId', 'name status')
      .populate('assignedSupervisorId', 'name role email');
    if (!product) throw new NotFoundException('المنتج غير موجود');
    return product;
  }

  async create(createDto: {
    appId: string;
    name: string;
    description?: string;
    type?: ProductType;
    providerId?: string;
    providerProductCode?: string;
    costPrice: number;
    profitMarginType?: ProfitMarginType;
    profitMarginValue?: number;
    isActive?: boolean;
    inventoryCodes?: string[];
    requiredFields?: string[];
    assignedSupervisorId?: string;
    estimatedMinutes?: number;
    isSensitive?: boolean;
    sensitiveFields?: string[];
    instructions?: string;
  }) {
    const marginType = createDto.profitMarginType || ProfitMarginType.PERCENTAGE;
    const marginValue = createDto.profitMarginValue !== undefined ? createDto.profitMarginValue : 10;
    const salePrice = this.calculateSalePrice(createDto.costPrice, marginType, marginValue);

    const product = new this.productModel({
      ...createDto,
      appId: new Types.ObjectId(createDto.appId),
      providerId: createDto.providerId ? new Types.ObjectId(createDto.providerId) : undefined,
      assignedSupervisorId: createDto.assignedSupervisorId ? new Types.ObjectId(createDto.assignedSupervisorId) : undefined,
      estimatedMinutes: createDto.estimatedMinutes || 120,
      isSensitive: createDto.isSensitive || false,
      sensitiveFields: createDto.sensitiveFields || [],
      instructions: createDto.instructions,
      profitMarginType: marginType,
      profitMarginValue: marginValue,
      salePrice,
      hasPriceChanged: false,
      isActive: createDto.isActive !== undefined ? createDto.isActive : true,
      inventoryCodes: createDto.inventoryCodes || [],
      requiredFields: createDto.requiredFields && createDto.requiredFields.length > 0
        ? createDto.requiredFields
        : ['Player ID'],
    });

    return product.save();
  }

  async update(id: string, updateDto: any) {
    const product = await this.findOne(id);

    if (updateDto.costPrice !== undefined || updateDto.profitMarginValue !== undefined || updateDto.profitMarginType !== undefined) {
      const cost = updateDto.costPrice !== undefined ? updateDto.costPrice : product.costPrice;
      const marginType = updateDto.profitMarginType || product.profitMarginType;
      const marginVal = updateDto.profitMarginValue !== undefined ? updateDto.profitMarginValue : product.profitMarginValue;
      updateDto.salePrice = this.calculateSalePrice(cost, marginType, marginVal);
    }

    if (updateDto.appId) updateDto.appId = new Types.ObjectId(updateDto.appId);
    if (updateDto.providerId) updateDto.providerId = new Types.ObjectId(updateDto.providerId);
    if (updateDto.assignedSupervisorId !== undefined) {
      updateDto.assignedSupervisorId = updateDto.assignedSupervisorId && Types.ObjectId.isValid(updateDto.assignedSupervisorId)
        ? new Types.ObjectId(updateDto.assignedSupervisorId)
        : null;
    }

    const updated = await this.productModel.findByIdAndUpdate(id, updateDto, { new: true });
    return updated;
  }

  async toggleActive(id: string) {
    const product = await this.productModel.findById(id);
    if (!product) throw new NotFoundException('المنتج غير موجود');
    product.isActive = !product.isActive;
    await product.save();
    return this.findOne(id);
  }

  async remove(id: string) {
    const product = await this.productModel.findByIdAndDelete(id);
    if (!product) throw new NotFoundException('المنتج غير موجود');
    return { message: 'تم حذف المنتج بنجاح' };
  }

  // Add codes to stock inventory (e.g. Google Play cards)
  async addCodesToInventory(id: string, codes: string[]) {
    const product = await this.findOne(id);
    if (product.type !== ProductType.CODES) {
      throw new BadRequestException('هذا المنتج ليس من نوع أكواد رقمية');
    }
    product.inventoryCodes.push(...codes.map((c) => c.trim()).filter((c) => c.length > 0));
    await product.save();
    return {
      message: `تم إضافة ${codes.length} كود إلى المخزون بنجاح`,
      availableCodesCount: product.inventoryCodes.length,
    };
  }

  // Update prices from providers:
  // Pulls current prices from provider, if cost changes -> updates cost, sets previousPrice dimmed, recalculates sale price!
  async updatePricesFromProviders() {
    const products = await this.productModel.find({
      type: ProductType.DIRECT_API,
      providerId: { $exists: true, $ne: null },
      providerProductCode: { $exists: true, $ne: null },
    });

    let updatedCount = 0;
    for (const prod of products) {
      // Find latest provider product price
      const providerProd = await this.providerProductModel.findOne({
        providerId: prod.providerId,
        providerProductCode: prod.providerProductCode,
      });

      if (providerProd && providerProd.costPrice !== prod.costPrice) {
        const oldSalePrice = prod.salePrice;
        const newCostPrice = providerProd.costPrice;
        const newSalePrice = this.calculateSalePrice(newCostPrice, prod.profitMarginType, prod.profitMarginValue);

        prod.previousPrice = oldSalePrice;
        prod.costPrice = newCostPrice;
        prod.salePrice = newSalePrice;
        prod.hasPriceChanged = true;
        await prod.save();
        updatedCount++;
      }
    }

    return {
      message: `تم فحص وتحديث أسعار ${updatedCount} منتج من المزودين بنجاح`,
      updatedCount,
      totalChecked: products.length,
    };
  }
}
