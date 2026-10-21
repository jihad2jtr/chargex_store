"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const mongoose_1 = require("@nestjs/mongoose");
const database_module_1 = require("./database/database.module");
const auth_module_1 = require("./modules/auth/auth.module");
const users_module_1 = require("./modules/users/users.module");
const providers_module_1 = require("./modules/providers/providers.module");
const apps_module_1 = require("./modules/apps/apps.module");
const products_module_1 = require("./modules/products/products.module");
const orders_module_1 = require("./modules/orders/orders.module");
const wallet_module_1 = require("./modules/wallet/wallet.module");
const topup_module_1 = require("./modules/topup/topup.module");
const codes_module_1 = require("./modules/codes/codes.module");
const notifications_module_1 = require("./modules/notifications/notifications.module");
const upload_module_1 = require("./modules/upload/upload.module");
const banners_module_1 = require("./modules/banners/banners.module");
const agent_module_1 = require("./modules/agent/agent.module");
const app_controller_1 = require("./app.controller");
const app_service_1 = require("./app.service");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({
                isGlobal: true,
                envFilePath: '.env',
            }),
            mongoose_1.MongooseModule.forRootAsync({
                imports: [config_1.ConfigModule],
                useFactory: async (configService) => ({
                    uri: configService.get('MONGODB_URI') ||
                        'mongodb+srv://jihad2jus:l9GrLciVEUvvK8Fd@jihad.8dyvx.mongodb.net/jgo?retryWrites=true&w=majority&appName=jihad',
                    serverSelectionTimeoutMS: 3000,
                    connectTimeoutMS: 4000,
                    retryAttempts: 1,
                    retryDelay: 500,
                }),
                inject: [config_1.ConfigService],
            }),
            database_module_1.DatabaseModule,
            auth_module_1.AuthModule,
            users_module_1.UsersModule,
            providers_module_1.ProvidersModule,
            apps_module_1.AppsModule,
            products_module_1.ProductsModule,
            orders_module_1.OrdersModule,
            wallet_module_1.WalletModule,
            topup_module_1.TopupModule,
            codes_module_1.CodesModule,
            notifications_module_1.NotificationsModule,
            upload_module_1.UploadModule,
            banners_module_1.BannersModule,
            agent_module_1.AgentModule,
        ],
        controllers: [app_controller_1.AppController],
        providers: [app_service_1.AppService],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map