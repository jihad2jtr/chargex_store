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
exports.ShippingCodeSchema = exports.ShippingCode = void 0;
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
let ShippingCode = class ShippingCode {
};
exports.ShippingCode = ShippingCode;
__decorate([
    (0, mongoose_1.Prop)({ required: true, unique: true, uppercase: true, trim: true, index: true }),
    __metadata("design:type", String)
], ShippingCode.prototype, "code", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, required: true, min: 0.1 }),
    __metadata("design:type", Number)
], ShippingCode.prototype, "amount", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: false, index: true }),
    __metadata("design:type", Boolean)
], ShippingCode.prototype, "isUsed", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'User' }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], ShippingCode.prototype, "usedBy", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", Date)
], ShippingCode.prototype, "usedAt", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: true, index: true }),
    __metadata("design:type", Boolean)
], ShippingCode.prototype, "isActive", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'User' }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], ShippingCode.prototype, "createdBy", void 0);
exports.ShippingCode = ShippingCode = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], ShippingCode);
exports.ShippingCodeSchema = mongoose_1.SchemaFactory.createForClass(ShippingCode);
//# sourceMappingURL=shipping-code.schema.js.map