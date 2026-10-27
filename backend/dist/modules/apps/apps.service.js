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
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppsService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const app_schema_1 = require("../../database/schemas/app.schema");
const product_schema_1 = require("../../database/schemas/product.schema");
let AppsService = class AppsService {
    constructor(appModel, productModel) {
        this.appModel = appModel;
        this.productModel = productModel;
    }
    async findActive() {
        return this.appModel.find({ isActive: true }).sort({ sortOrder: 1, createdAt: -1 });
    }
    async findAllAdmin() {
        return this.appModel.find().sort({ sortOrder: 1, createdAt: -1 });
    }
    async findOne(id) {
        const app = await this.appModel.findById(id);
        if (!app)
            throw new common_1.NotFoundException('الخدمة / التطبيق غير موجود');
        return app;
    }
    async assertUniqueName(name, excludeId) {
        const trimmed = (name || '').trim();
        if (!trimmed)
            throw new common_1.BadRequestException('اسم التطبيق مطلوب');
        const escaped = trimmed.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const query = {
            name: { $regex: `^\\s*${escaped}\\s*$`, $options: 'i' },
        };
        if (excludeId)
            query._id = { $ne: excludeId };
        const existing = await this.appModel.exists(query);
        if (existing) {
            throw new common_1.BadRequestException('يوجد تطبيق مسجّل بنفس الاسم بالفعل — لا يُسمح بالتكرار');
        }
    }
    async create(createDto) {
        await this.assertUniqueName(createDto.name);
        const app = new this.appModel({
            ...createDto,
            isActive: createDto.isActive !== undefined ? createDto.isActive : true,
            sortOrder: createDto.sortOrder || 0,
        });
        return app.save();
    }
    async update(id, updateDto) {
        if (updateDto?.name !== undefined) {
            await this.assertUniqueName(updateDto.name, id);
        }
        const app = await this.appModel.findByIdAndUpdate(id, updateDto, { new: true });
        if (!app)
            throw new common_1.NotFoundException('الخدمة / التطبيق غير موجود');
        return app;
    }
    async toggleActive(id) {
        const app = await this.findOne(id);
        app.isActive = !app.isActive;
        return app.save();
    }
    async updateSortOrder(items) {
        const operations = items.map((item) => this.appModel.findByIdAndUpdate(item.id, { sortOrder: item.sortOrder }));
        await Promise.all(operations);
        return { message: 'تم تحديث ترتيب التطبيقات بنجاح' };
    }
    async remove(id) {
        const app = await this.appModel.findByIdAndDelete(id);
        if (!app)
            throw new common_1.NotFoundException('الخدمة / التطبيق غير موجود');
        await this.productModel.deleteMany({ appId: app._id });
        return { message: 'تم حذف التطبيق والمنتجات التابعة له بنجاح' };
    }
};
exports.AppsService = AppsService;
exports.AppsService = AppsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(app_schema_1.App.name)),
    __param(1, (0, mongoose_1.InjectModel)(product_schema_1.Product.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model])
], AppsService);
//# sourceMappingURL=apps.service.js.map