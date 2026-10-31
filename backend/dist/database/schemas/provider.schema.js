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
exports.ProviderSchema = exports.Provider = exports.ProviderType = exports.ProviderStatus = void 0;
const mongoose_1 = require("@nestjs/mongoose");
const product_schema_1 = require("./product.schema");
var ProviderStatus;
(function (ProviderStatus) {
    ProviderStatus["ONLINE"] = "online";
    ProviderStatus["OFFLINE"] = "offline";
    ProviderStatus["ERROR"] = "error";
})(ProviderStatus || (exports.ProviderStatus = ProviderStatus = {}));
var ProviderType;
(function (ProviderType) {
    ProviderType["BAY2GAME"] = "bay2game";
    ProviderType["FOXRELOAD"] = "foxreload";
    ProviderType["FIVESIM"] = "fivesim";
    ProviderType["HEROSMS"] = "herosms";
    ProviderType["DOGESMS"] = "dogesms";
    ProviderType["SMSPOOL"] = "smspool";
    ProviderType["CUSTOM"] = "custom";
})(ProviderType || (exports.ProviderType = ProviderType = {}));
let Provider = class Provider {
};
exports.Provider = Provider;
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], Provider.prototype, "name", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], Provider.prototype, "baseUrl", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], Provider.prototype, "apiKey", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], Provider.prototype, "apiSecret", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: String, enum: ProviderType, default: ProviderType.BAY2GAME }),
    __metadata("design:type", String)
], Provider.prototype, "providerType", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Object, default: {} }),
    __metadata("design:type", Object)
], Provider.prototype, "headers", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: String, enum: ProviderStatus, default: ProviderStatus.OFFLINE }),
    __metadata("design:type", String)
], Provider.prototype, "status", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], Provider.prototype, "lastError", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", Date)
], Provider.prototype, "lastCheckAt", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, default: 0.0 }),
    __metadata("design:type", Number)
], Provider.prototype, "balance", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 'USD' }),
    __metadata("design:type", String)
], Provider.prototype, "currency", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: String, enum: product_schema_1.ProfitMarginType, default: product_schema_1.ProfitMarginType.PERCENTAGE }),
    __metadata("design:type", String)
], Provider.prototype, "profitMarginType", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: Number, default: 10.0 }),
    __metadata("design:type", Number)
], Provider.prototype, "profitMarginValue", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: true }),
    __metadata("design:type", Boolean)
], Provider.prototype, "isActive", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Provider.prototype, "serverLabel", void 0);
exports.Provider = Provider = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], Provider);
exports.ProviderSchema = mongoose_1.SchemaFactory.createForClass(Provider);
//# sourceMappingURL=provider.schema.js.map