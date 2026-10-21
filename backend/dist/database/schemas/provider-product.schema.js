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
exports.ProviderProductSchema = exports.ProviderProduct = void 0;
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
let ProviderProduct = class ProviderProduct {
};
exports.ProviderProduct = ProviderProduct;
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'Provider', required: true, index: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], ProviderProduct.prototype, "providerId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], ProviderProduct.prototype, "providerProductCode", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], ProviderProduct.prototype, "name", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], ProviderProduct.prototype, "category", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, required: true, default: 0.0 }),
    __metadata("design:type", Number)
], ProviderProduct.prototype, "costPrice", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 'USD' }),
    __metadata("design:type", String)
], ProviderProduct.prototype, "currency", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: true }),
    __metadata("design:type", Boolean)
], ProviderProduct.prototype, "inStock", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Object, default: {} }),
    __metadata("design:type", Object)
], ProviderProduct.prototype, "rawDetails", void 0);
exports.ProviderProduct = ProviderProduct = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], ProviderProduct);
exports.ProviderProductSchema = mongoose_1.SchemaFactory.createForClass(ProviderProduct);
//# sourceMappingURL=provider-product.schema.js.map