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
exports.OrderSchema = exports.Order = exports.OrderChatMessageSchema = exports.OrderChatMessage = exports.OrderTimelineEventSchema = exports.OrderTimelineEvent = exports.OrderStatus = void 0;
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const product_schema_1 = require("./product.schema");
var OrderStatus;
(function (OrderStatus) {
    OrderStatus["PENDING"] = "pending";
    OrderStatus["ASSIGNED"] = "assigned";
    OrderStatus["ACCEPTED"] = "accepted";
    OrderStatus["IN_PROGRESS"] = "in_progress";
    OrderStatus["INFO_REQUESTED"] = "info_requested";
    OrderStatus["DELIVERED"] = "delivered";
    OrderStatus["REVISION_REQUESTED"] = "revision_requested";
    OrderStatus["DISPUTED"] = "disputed";
    OrderStatus["COMPLETED"] = "completed";
    OrderStatus["REJECTED"] = "rejected";
    OrderStatus["REFUNDED"] = "refunded";
})(OrderStatus || (exports.OrderStatus = OrderStatus = {}));
let OrderTimelineEvent = class OrderTimelineEvent {
};
exports.OrderTimelineEvent = OrderTimelineEvent;
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], OrderTimelineEvent.prototype, "action", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], OrderTimelineEvent.prototype, "title", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], OrderTimelineEvent.prototype, "description", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'User' }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], OrderTimelineEvent.prototype, "performerId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 'النظام' }),
    __metadata("design:type", String)
], OrderTimelineEvent.prototype, "performerName", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 'system' }),
    __metadata("design:type", String)
], OrderTimelineEvent.prototype, "performerRole", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: Date.now }),
    __metadata("design:type", Date)
], OrderTimelineEvent.prototype, "timestamp", void 0);
exports.OrderTimelineEvent = OrderTimelineEvent = __decorate([
    (0, mongoose_1.Schema)({ _id: false })
], OrderTimelineEvent);
exports.OrderTimelineEventSchema = mongoose_1.SchemaFactory.createForClass(OrderTimelineEvent);
let OrderChatMessage = class OrderChatMessage {
};
exports.OrderChatMessage = OrderChatMessage;
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'User', required: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], OrderChatMessage.prototype, "senderId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], OrderChatMessage.prototype, "senderName", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], OrderChatMessage.prototype, "senderRole", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: '' }),
    __metadata("design:type", String)
], OrderChatMessage.prototype, "message", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], OrderChatMessage.prototype, "attachmentUrl", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], OrderChatMessage.prototype, "attachmentName", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], OrderChatMessage.prototype, "attachmentType", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: false }),
    __metadata("design:type", Boolean)
], OrderChatMessage.prototype, "isSensitive", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: Date.now }),
    __metadata("design:type", Date)
], OrderChatMessage.prototype, "createdAt", void 0);
exports.OrderChatMessage = OrderChatMessage = __decorate([
    (0, mongoose_1.Schema)({ _id: true, timestamps: true })
], OrderChatMessage);
exports.OrderChatMessageSchema = mongoose_1.SchemaFactory.createForClass(OrderChatMessage);
let Order = class Order {
};
exports.Order = Order;
__decorate([
    (0, mongoose_1.Prop)({ required: true, unique: true, index: true }),
    __metadata("design:type", String)
], Order.prototype, "orderNumber", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true, unique: true, sparse: true }),
    __metadata("design:type", String)
], Order.prototype, "requestId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'User', required: true, index: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], Order.prototype, "userId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'App', required: true, index: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], Order.prototype, "appId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'Product', required: true, index: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], Order.prototype, "productId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'Provider' }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], Order.prototype, "providerId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: String, enum: product_schema_1.ProductType, required: true, index: true }),
    __metadata("design:type", String)
], Order.prototype, "type", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, required: true }),
    __metadata("design:type", Number)
], Order.prototype, "amount", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, required: true, default: 0.0 }),
    __metadata("design:type", Number)
], Order.prototype, "cost", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, required: true, default: 0.0 }),
    __metadata("design:type", Number)
], Order.prototype, "profit", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: String, enum: OrderStatus, default: OrderStatus.PENDING, index: true }),
    __metadata("design:type", String)
], Order.prototype, "status", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Object, default: {} }),
    __metadata("design:type", Object)
], Order.prototype, "accountInput", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Order.prototype, "adminNotes", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Order.prototype, "deliveredCode", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Order.prototype, "providerReference", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Object, default: {} }),
    __metadata("design:type", Object)
], Order.prototype, "providerResponse", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", Date)
], Order.prototype, "providerSettledAt", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: mongoose_2.Types.ObjectId, ref: 'User', index: true }),
    __metadata("design:type", mongoose_2.Types.ObjectId)
], Order.prototype, "assignedSupervisorId", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, default: 120 }),
    __metadata("design:type", Number)
], Order.prototype, "estimatedMinutes", void 0);
__decorate([
    (0, mongoose_1.Prop)({ index: true }),
    __metadata("design:type", Date)
], Order.prototype, "deadlineAt", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", Date)
], Order.prototype, "acceptedAt", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", Date)
], Order.prototype, "startedAt", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", Date)
], Order.prototype, "deliveredAt", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", Date)
], Order.prototype, "completedAt", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Boolean, default: false }),
    __metadata("design:type", Boolean)
], Order.prototype, "isSensitive", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [String], default: [] }),
    __metadata("design:type", Array)
], Order.prototype, "sensitiveFields", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Order.prototype, "encryptedResultData", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Order.prototype, "resultNotes", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [String], default: [] }),
    __metadata("design:type", Array)
], Order.prototype, "resultAttachments", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Boolean, default: false }),
    __metadata("design:type", Boolean)
], Order.prototype, "isResultPurged", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", Date)
], Order.prototype, "purgedAt", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Order.prototype, "rejectionReason", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Order.prototype, "disputeReason", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Order.prototype, "revisionNotes", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [exports.OrderTimelineEventSchema], default: [] }),
    __metadata("design:type", Array)
], Order.prototype, "timeline", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [exports.OrderChatMessageSchema], default: [] }),
    __metadata("design:type", Array)
], Order.prototype, "chatMessages", void 0);
exports.Order = Order = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], Order);
exports.OrderSchema = mongoose_1.SchemaFactory.createForClass(Order);
exports.OrderSchema.index({ createdAt: -1 });
exports.OrderSchema.index({ status: 1, createdAt: -1 });
exports.OrderSchema.index({ type: 1, createdAt: -1 });
//# sourceMappingURL=order.schema.js.map