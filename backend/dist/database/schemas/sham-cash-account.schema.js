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
exports.ShamCashAccountSchema = exports.ShamCashAccount = exports.PaymentAccountType = void 0;
const mongoose_1 = require("@nestjs/mongoose");
var PaymentAccountType;
(function (PaymentAccountType) {
    PaymentAccountType["SHAM_CASH"] = "sham_cash";
    PaymentAccountType["BINANCE"] = "binance";
})(PaymentAccountType || (exports.PaymentAccountType = PaymentAccountType = {}));
let ShamCashAccount = class ShamCashAccount {
};
exports.ShamCashAccount = ShamCashAccount;
__decorate([
    (0, mongoose_1.Prop)({ type: String, enum: PaymentAccountType, default: PaymentAccountType.SHAM_CASH, index: true }),
    __metadata("design:type", String)
], ShamCashAccount.prototype, "type", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], ShamCashAccount.prototype, "accountName", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], ShamCashAccount.prototype, "accountId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], ShamCashAccount.prototype, "barcodeUrl", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: true }),
    __metadata("design:type", Boolean)
], ShamCashAccount.prototype, "isActive", void 0);
exports.ShamCashAccount = ShamCashAccount = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], ShamCashAccount);
exports.ShamCashAccountSchema = mongoose_1.SchemaFactory.createForClass(ShamCashAccount);
//# sourceMappingURL=sham-cash-account.schema.js.map