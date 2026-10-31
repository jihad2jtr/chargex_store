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
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProductSchema = exports.Product = exports.ProfitMarginType = exports.ProductType = void 0;
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
var ProductType;
(function (ProductType) {
    ProductType["DIRECT_API"] = "direct_api";
    ProductType["CODES"] = "codes";
    ProductType["MANUAL"] = "manual";
})(ProductType || (exports.ProductType = ProductType = {}));
var ProfitMarginType;
(function (ProfitMarginType) {
    ProfitMarginType["PERCENTAGE"] = "percentage";
    ProfitMarginType["FIXED"] = "fixed";
})(ProfitMarginType || (exports.ProfitMarginType = ProfitMarginType = {}));
let Product = class Product {
};
exports.Product = Product;
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'App', index: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], Product.prototype, "appId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'VirtualNumberApp', index: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], Product.prototype, "virtualNumberAppId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], Product.prototype, "name", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'ServiceTemplate', index: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], Product.prototype, "serviceTemplateId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true, default: '' }),
    __metadata("design:type", String)
], Product.prototype, "quantityLabel", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true, default: 'quantity', index: true }),
    __metadata("design:type", String)
], Product.prototype, "kind", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Product.prototype, "description", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: String, enum: ProductType, default: ProductType.DIRECT_API, index: true }),
    __metadata("design:type", String)
], Product.prototype, "type", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'Provider', index: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], Product.prototype, "providerId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Product.prototype, "providerProductCode", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, required: true, default: 0.0 }),
    __metadata("design:type", Number)
], Product.prototype, "costPrice", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: String, enum: ProfitMarginType, default: ProfitMarginType.PERCENTAGE }),
    __metadata("design:type", String)
], Product.prototype, "profitMarginType", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, default: 10.0 }),
    __metadata("design:type", Number)
], Product.prototype, "profitMarginValue", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, required: true, default: 0.0 }),
    __metadata("design:type", Number)
], Product.prototype, "salePrice", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number }),
    __metadata("design:type", Number)
], Product.prototype, "previousPrice", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Boolean, default: false }),
    __metadata("design:type", Boolean)
], Product.prototype, "hasPriceChanged", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: true, index: true }),
    __metadata("design:type", Boolean)
], Product.prototype, "isActive", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [String], default: [] }),
    __metadata("design:type", Array)
], Product.prototype, "inventoryCodes", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [String], default: ['Player ID'] }),
    __metadata("design:type", Array)
], Product.prototype, "requiredFields", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'User', index: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], Product.prototype, "assignedSupervisorId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, default: 120 }),
    __metadata("design:type", Number)
], Product.prototype, "estimatedMinutes", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Boolean, default: false }),
    __metadata("design:type", Boolean)
], Product.prototype, "isSensitive", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [String], default: [] }),
    __metadata("design:type", Array)
], Product.prototype, "sensitiveFields", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Product.prototype, "instructions", void 0);
exports.Product = Product = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], Product);
exports.ProductSchema = mongoose_1.SchemaFactory.createForClass(Product);
//# sourceMappingURL=product.schema.js.map