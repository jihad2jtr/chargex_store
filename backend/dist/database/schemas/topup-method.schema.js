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
exports.TopupMethodSchema = exports.TopupMethod = exports.TopupType = void 0;
const mongoose_1 = require("@nestjs/mongoose");
var TopupType;
(function (TopupType) {
    TopupType["ID_RECHARGE"] = "id_recharge";
    TopupType["SHAM_CASH"] = "sham_cash";
    TopupType["BINANCE"] = "binance";
    TopupType["SHIPPING_CODE"] = "shipping_code";
})(TopupType || (exports.TopupType = TopupType = {}));
let TopupMethod = class TopupMethod {
};
exports.TopupMethod = TopupMethod;
__decorate([
    (0, mongoose_1.Prop)({ type: String, enum: TopupType, required: true, unique: true, index: true }),
    __metadata("design:type", String)
], TopupMethod.prototype, "type", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], TopupMethod.prototype, "title", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], TopupMethod.prototype, "description", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: true }),
    __metadata("design:type", Boolean)
], TopupMethod.prototype, "isActive", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], TopupMethod.prototype, "instructions", void 0);
exports.TopupMethod = TopupMethod = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], TopupMethod);
exports.TopupMethodSchema = mongoose_1.SchemaFactory.createForClass(TopupMethod);
//# sourceMappingURL=topup-method.schema.js.map