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
var ProductsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProductsService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const product_schema_1 = require("../../database/schemas/product.schema");
const provider_product_schema_1 = require("../../database/schemas/provider-product.schema");
const service_template_schema_1 = require("../../database/schemas/service-template.schema");
const users_service_1 = require("../users/users.service");
let ProductsService = ProductsService_1 = class ProductsService {
    constructor(productModel, providerProductModel, serviceTemplateModel, usersService) {
        this.productModel = productModel;
        this.providerProductModel = providerProductModel;
        this.serviceTemplateModel = serviceTemplateModel;
        this.usersService = usersService;
        this.logger = new common_1.Logger(ProductsService_1.name);
    }
    deriveFieldsFromTemplate(tpl) {
        const fields = tpl.fields || [];
        const requiredFields = fields.filter((f) => f.required).map((f) => f.label);
        const sensitiveFields = fields
            .filter((f) => f.isSensitive || f.type === service_template_schema_1.ServiceFieldType.PASSWORD)
            .map((f) => f.label);
        return { requiredFields, sensitiveFields };
    }
    calculateSalePrice(costPrice, marginType, marginValue) {
        if (marginType === product_schema_1.ProfitMarginType.PERCENTAGE) {
            return Number((costPrice * (1 + marginValue / 100)).toFixed(2));
        }
        return Number((costPrice + marginValue).toFixed(2));
    }
    async findByAppUser(appId) {
        const products = await this.productModel
            .find({ appId: new mongoose_2.Types.ObjectId(appId), isActive: true })
            .populate('providerId', 'name status isActive')
            .populate('assignedSupervisorId', 'name role')
            .populate('serviceTemplateId')
            .sort({ salePrice: 1 });
        return products
            .filter((prod) => {
            const provider = prod.providerId;
            return !provider || provider.isActive !== false;
        })
            .map((prod) => {
            const obj = prod.toObject();
            const provider = obj.providerId;
            return {
                ...obj,
                availableCodesCount: obj.inventoryCodes ? obj.inventoryCodes.length : 0,
                inventoryCodes: undefined,
                providerAvailable: !provider || (provider.isActive !== false && provider.status === 'online'),
            };
        });
    }
    async findAllAdmin(appId) {
        const filter = {};
        if (appId) {
            filter.appId = new mongoose_2.Types.ObjectId(appId);
        }
        const products = await this.productModel
            .find(filter)
            .populate('appId', 'name iconUrl')
            .populate('providerId', 'name status')
            .populate('assignedSupervisorId', 'name role email')
            .populate('serviceTemplateId')
            .sort({ createdAt: -1 });
        return products.map((prod) => {
            const obj = prod.toObject();
            return {
                ...obj,
                availableCodesCount: obj.inventoryCodes ? obj.inventoryCodes.length : 0,
            };
        });
    }
    async findOne(id) {
        const product = await this.productModel
            .findById(id)
            .populate('appId', 'name iconUrl')
            .populate('providerId', 'name status')
            .populate('assignedSupervisorId', 'name role email')
            .populate('serviceTemplateId');
        if (!product)
            throw new common_1.NotFoundException('المنتج غير موجود');
        return product;
    }
    async create(createDto) {
        const marginType = createDto.profitMarginType || product_schema_1.ProfitMarginType.PERCENTAGE;
        const marginValue = createDto.profitMarginValue !== undefined ? createDto.profitMarginValue : 10;
        const salePrice = this.calculateSalePrice(createDto.costPrice, marginType, marginValue);
        const templateId = createDto.serviceTemplateId && mongoose_2.Types.ObjectId.isValid(createDto.serviceTemplateId)
            ? new mongoose_2.Types.ObjectId(createDto.serviceTemplateId)
            : undefined;
        let requiredFields = createDto.requiredFields || [];
        let sensitiveFields = createDto.sensitiveFields || [];
        let isSensitive = createDto.isSensitive || false;
        if (templateId) {
            const derived = await this.deriveFieldsFromTemplateById(templateId);
            if (derived) {
                if (derived.requiredFields.length > 0)
                    requiredFields = derived.requiredFields;
                if (derived.sensitiveFields.length > 0) {
                    sensitiveFields = derived.sensitiveFields;
                    isSensitive = true;
                }
            }
        }
        if (requiredFields.length === 0)
            requiredFields = ['Player ID'];
        const product = new this.productModel({
            ...createDto,
            appId: new mongoose_2.Types.ObjectId(createDto.appId),
            providerId: createDto.providerId ? new mongoose_2.Types.ObjectId(createDto.providerId) : undefined,
            assignedSupervisorId: createDto.assignedSupervisorId ? new mongoose_2.Types.ObjectId(createDto.assignedSupervisorId) : undefined,
            serviceTemplateId: templateId,
            quantityLabel: createDto.quantityLabel || '',
            kind: (createDto.kind || '').trim() || 'quantity',
            estimatedMinutes: createDto.estimatedMinutes || 120,
            isSensitive,
            sensitiveFields,
            instructions: createDto.instructions,
            profitMarginType: marginType,
            profitMarginValue: marginValue,
            salePrice,
            hasPriceChanged: false,
            isActive: createDto.isActive !== undefined ? createDto.isActive : true,
            inventoryCodes: createDto.inventoryCodes || [],
            requiredFields,
        });
        const saved = await product.save();
        if (saved.assignedSupervisorId) {
            await this.usersService.reconcileSupervisorRole(saved.assignedSupervisorId);
        }
        return saved;
    }
    async deriveFieldsFromTemplateById(templateId) {
        const tpl = await this.serviceTemplateModel.findById(templateId);
        if (!tpl)
            return null;
        return this.deriveFieldsFromTemplate(tpl);
    }
    async update(id, updateDto) {
        const product = await this.findOne(id);
        const previousSupervisorId = product.assignedSupervisorId
            ? product.assignedSupervisorId._id?.toString() ??
                product.assignedSupervisorId.toString()
            : null;
        if (updateDto.costPrice !== undefined || updateDto.profitMarginValue !== undefined || updateDto.profitMarginType !== undefined) {
            const cost = updateDto.costPrice !== undefined ? updateDto.costPrice : product.costPrice;
            const marginType = updateDto.profitMarginType || product.profitMarginType;
            const marginVal = updateDto.profitMarginValue !== undefined ? updateDto.profitMarginValue : product.profitMarginValue;
            updateDto.salePrice = this.calculateSalePrice(cost, marginType, marginVal);
        }
        if (updateDto.appId)
            updateDto.appId = new mongoose_2.Types.ObjectId(updateDto.appId);
        if (updateDto.kind !== undefined) {
            updateDto.kind = (updateDto.kind || '').toString().trim() || 'quantity';
        }
        if (updateDto.providerId)
            updateDto.providerId = new mongoose_2.Types.ObjectId(updateDto.providerId);
        if (updateDto.serviceTemplateId !== undefined) {
            updateDto.serviceTemplateId = updateDto.serviceTemplateId && mongoose_2.Types.ObjectId.isValid(updateDto.serviceTemplateId)
                ? new mongoose_2.Types.ObjectId(updateDto.serviceTemplateId)
                : null;
        }
        if (updateDto.assignedSupervisorId !== undefined) {
            updateDto.assignedSupervisorId = updateDto.assignedSupervisorId && mongoose_2.Types.ObjectId.isValid(updateDto.assignedSupervisorId)
                ? new mongoose_2.Types.ObjectId(updateDto.assignedSupervisorId)
                : null;
        }
        if (updateDto.serviceTemplateId) {
            const derived = await this.deriveFieldsFromTemplateById(updateDto.serviceTemplateId);
            if (derived) {
                if (derived.requiredFields.length > 0)
                    updateDto.requiredFields = derived.requiredFields;
                if (derived.sensitiveFields.length > 0) {
                    updateDto.sensitiveFields = derived.sensitiveFields;
                    updateDto.isSensitive = true;
                }
            }
        }
        const updated = await this.productModel.findByIdAndUpdate(id, updateDto, { new: true });
        if (updateDto.assignedSupervisorId !== undefined) {
            const newSupervisorId = updated?.assignedSupervisorId?.toString() ?? null;
            if (previousSupervisorId && previousSupervisorId !== newSupervisorId) {
                await this.usersService.reconcileSupervisorRole(previousSupervisorId);
            }
            if (newSupervisorId) {
                await this.usersService.reconcileSupervisorRole(newSupervisorId);
            }
        }
        return updated;
    }
    async toggleActive(id) {
        const product = await this.productModel.findById(id);
        if (!product)
            throw new common_1.NotFoundException('المنتج غير موجود');
        product.isActive = !product.isActive;
        await product.save();
        return this.findOne(id);
    }
    async findAssignedToSupervisor(supervisorId) {
        const products = await this.productModel
            .find({ assignedSupervisorId: new mongoose_2.Types.ObjectId(supervisorId) })
            .populate('appId', 'name iconUrl')
            .populate('providerId', 'name status isActive')
            .populate('serviceTemplateId')
            .sort({ isActive: -1, salePrice: 1 });
        return products.map((prod) => {
            const obj = prod.toObject();
            return {
                ...obj,
                availableCodesCount: obj.inventoryCodes ? obj.inventoryCodes.length : 0,
                inventoryCodes: undefined,
            };
        });
    }
    async toggleActiveForSupervisor(id, supervisorId) {
        const product = await this.productModel.findById(id);
        if (!product)
            throw new common_1.NotFoundException('الخدمة غير موجودة');
        if (!product.assignedSupervisorId ||
            product.assignedSupervisorId.toString() !== supervisorId) {
            throw new common_1.ForbiddenException('هذه الخدمة غير مسندة إليك');
        }
        product.isActive = !product.isActive;
        await product.save();
        return this.findOne(id);
    }
    async remove(id) {
        const product = await this.productModel.findByIdAndDelete(id);
        if (!product)
            throw new common_1.NotFoundException('المنتج غير موجود');
        return { message: 'تم حذف المنتج بنجاح' };
    }
    async addCodesToInventory(id, codes) {
        const product = await this.findOne(id);
        if (product.type !== product_schema_1.ProductType.CODES) {
            throw new common_1.BadRequestException('هذا المنتج ليس من نوع أكواد رقمية');
        }
        product.inventoryCodes.push(...codes.map((c) => c.trim()).filter((c) => c.length > 0));
        await product.save();
        return {
            message: `تم إضافة ${codes.length} كود إلى المخزون بنجاح`,
            availableCodesCount: product.inventoryCodes.length,
        };
    }
    async updatePricesFromProviders() {
        const products = await this.productModel.find({
            type: product_schema_1.ProductType.DIRECT_API,
            providerId: { $exists: true, $ne: null },
            providerProductCode: { $exists: true, $ne: null },
        });
        let updatedCount = 0;
        for (const prod of products) {
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
};
exports.ProductsService = ProductsService;
exports.ProductsService = ProductsService = ProductsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(product_schema_1.Product.name)),
    __param(1, (0, mongoose_1.InjectModel)(provider_product_schema_1.ProviderProduct.name)),
    __param(2, (0, mongoose_1.InjectModel)(service_template_schema_1.ServiceTemplate.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        users_service_1.UsersService])
], ProductsService);
//# sourceMappingURL=products.service.js.map