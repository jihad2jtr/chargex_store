"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TopupModule = void 0;
const common_1 = require("@nestjs/common");
const topup_service_1 = require("./topup.service");
const topup_controller_1 = require("./topup.controller");
const database_module_1 = require("../../database/database.module");
const wallet_module_1 = require("../wallet/wallet.module");
const notifications_module_1 = require("../notifications/notifications.module");
let TopupModule = class TopupModule {
};
exports.TopupModule = TopupModule;
exports.TopupModule = TopupModule = __decorate([
    (0, common_1.Module)({
        imports: [database_module_1.DatabaseModule, wallet_module_1.WalletModule, notifications_module_1.NotificationsModule],
        controllers: [topup_controller_1.TopupController],
        providers: [topup_service_1.TopupService],
        exports: [topup_service_1.TopupService],
    })
], TopupModule);
//# sourceMappingURL=topup.module.js.map