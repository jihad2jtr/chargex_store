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
exports.AppSchema = exports.App = exports.AppType = void 0;
const mongoose_1 = require("@nestjs/mongoose");
var AppType;
(function (AppType) {
    AppType["GAME"] = "game";
    AppType["APP"] = "app";
    AppType["SERVICE"] = "service";
})(AppType || (exports.AppType = AppType = {}));
let App = class App {
};
exports.App = App;
__decorate([
    (0, mongoose_1.Prop)({ required: true, trim: true }),
    __metadata("design:type", String)
], App.prototype, "name", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], App.prototype, "nameAr", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], App.prototype, "nameEn", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: String, enum: AppType, default: AppType.GAME }),
    __metadata("design:type", String)
], App.prototype, "appType", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], App.prototype, "iconUrl", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: true, index: true }),
    __metadata("design:type", Boolean)
], App.prototype, "isActive", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0, index: true }),
    __metadata("design:type", Number)
], App.prototype, "sortOrder", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], App.prototype, "category", void 0);
__decorate([
    (0, mongoose_1.Prop)({ trim: true }),
    __metadata("design:type", String)
], App.prototype, "description", void 0);
exports.App = App = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], App);
exports.AppSchema = mongoose_1.SchemaFactory.createForClass(App);
//# sourceMappingURL=app.schema.js.map