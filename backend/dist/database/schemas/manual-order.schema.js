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
exports.ManualOrderSchema = exports.ManualOrder = exports.ManualOrderStatus = void 0;
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
var ManualOrderStatus;
(function (ManualOrderStatus) {
    ManualOrderStatus["PENDING"] = "pending";
    ManualOrderStatus["APPROVED"] = "approved";
    ManualOrderStatus["REJECTED"] = "rejected";
})(ManualOrderStatus || (exports.ManualOrderStatus = ManualOrderStatus = {}));
let ManualOrder = class ManualOrder {
};
exports.ManualOrder = ManualOrder;
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'User', required: true, index: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], ManualOrder.prototype, "userId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'Order' }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], ManualOrder.prototype, "orderId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], ManualOrder.prototype, "type", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, required: true }),
    __metadata("design:type", Number)
], ManualOrder.prototype, "amount", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Object, default: {} }),
    __metadata("design:type", Object)
], ManualOrder.prototype, "details", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], ManualOrder.prototype, "receiptImageUrl", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: String, enum: ManualOrderStatus, default: ManualOrderStatus.PENDING, index: true }),
    __metadata("design:type", String)
], ManualOrder.prototype, "status", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], ManualOrder.prototype, "adminNotes", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'User' }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], ManualOrder.prototype, "processedBy", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", Date)
], ManualOrder.prototype, "processedAt", void 0);
exports.ManualOrder = ManualOrder = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], ManualOrder);
exports.ManualOrderSchema = mongoose_1.SchemaFactory.createForClass(ManualOrder);
//# sourceMappingURL=manual-order.schema.js.map