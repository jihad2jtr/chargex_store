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
exports.BannerSchema = exports.Banner = void 0;
const mongoose_1 = require("@nestjs/mongoose");
let Banner = class Banner {
};
exports.Banner = Banner;
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], Banner.prototype, "title", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true, default: '' }),
    __metadata("design:type", String)
], Banner.prototype, "description", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], Banner.prototype, "imageUrl", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 'topup', trim: true }),
    __metadata("design:type", String)
], Banner.prototype, "actionType", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], Banner.prototype, "actionValue", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: true, index: true }),
    __metadata("design:type", Boolean)
], Banner.prototype, "isActive", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0, index: true }),
    __metadata("design:type", Number)
], Banner.prototype, "sortOrder", void 0);
exports.Banner = Banner = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], Banner);
exports.BannerSchema = mongoose_1.SchemaFactory.createForClass(Banner);
//# sourceMappingURL=banner.schema.js.map