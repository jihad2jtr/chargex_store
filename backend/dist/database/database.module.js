"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DatabaseModule = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const user_schema_1 = require("./schemas/user.schema");
const provider_schema_1 = require("./schemas/provider.schema");
const app_schema_1 = require("./schemas/app.schema");
const product_schema_1 = require("./schemas/product.schema");
const provider_product_schema_1 = require("./schemas/provider-product.schema");
const order_schema_1 = require("./schemas/order.schema");
const wallet_transaction_schema_1 = require("./schemas/wallet-transaction.schema");
const topup_method_schema_1 = require("./schemas/topup-method.schema");
const sham_cash_account_schema_1 = require("./schemas/sham-cash-account.schema");
const shipping_code_schema_1 = require("./schemas/shipping-code.schema");
const manual_order_schema_1 = require("./schemas/manual-order.schema");
const notification_schema_1 = require("./schemas/notification.schema");
const banner_schema_1 = require("./schemas/banner.schema");
const service_template_schema_1 = require("./schemas/service-template.schema");
const exchange_rate_schema_1 = require("./schemas/exchange-rate.schema");
const virtual_number_request_schema_1 = require("./schemas/virtual-number-request.schema");
const virtual_number_catalog_schema_1 = require("./schemas/virtual-number-catalog.schema");
const virtual_number_app_schema_1 = require("./schemas/virtual-number-app.schema");
const virtual_number_product_schema_1 = require("./schemas/virtual-number-product.schema");
const featureModels = [
    { name: user_schema_1.User.name, schema: user_schema_1.UserSchema },
    { name: provider_schema_1.Provider.name, schema: provider_schema_1.ProviderSchema },
    { name: app_schema_1.App.name, schema: app_schema_1.AppSchema },
    { name: product_schema_1.Product.name, schema: product_schema_1.ProductSchema },
    { name: provider_product_schema_1.ProviderProduct.name, schema: provider_product_schema_1.ProviderProductSchema },
    { name: order_schema_1.Order.name, schema: order_schema_1.OrderSchema },
    { name: wallet_transaction_schema_1.WalletTransaction.name, schema: wallet_transaction_schema_1.WalletTransactionSchema },
    { name: topup_method_schema_1.TopupMethod.name, schema: topup_method_schema_1.TopupMethodSchema },
    { name: sham_cash_account_schema_1.ShamCashAccount.name, schema: sham_cash_account_schema_1.ShamCashAccountSchema },
    { name: shipping_code_schema_1.ShippingCode.name, schema: shipping_code_schema_1.ShippingCodeSchema },
    { name: manual_order_schema_1.ManualOrder.name, schema: manual_order_schema_1.ManualOrderSchema },
    { name: notification_schema_1.Notification.name, schema: notification_schema_1.NotificationSchema },
    { name: banner_schema_1.Banner.name, schema: banner_schema_1.BannerSchema },
    { name: service_template_schema_1.ServiceTemplate.name, schema: service_template_schema_1.ServiceTemplateSchema },
    { name: exchange_rate_schema_1.ExchangeRate.name, schema: exchange_rate_schema_1.ExchangeRateSchema },
    { name: virtual_number_request_schema_1.VirtualNumberRequest.name, schema: virtual_number_request_schema_1.VirtualNumberRequestSchema },
    { name: virtual_number_catalog_schema_1.VirtualNumberCatalog.name, schema: virtual_number_catalog_schema_1.VirtualNumberCatalogSchema },
    { name: virtual_number_app_schema_1.VirtualNumberApp.name, schema: virtual_number_app_schema_1.VirtualNumberAppSchema },
    { name: virtual_number_product_schema_1.VirtualNumberProduct.name, schema: virtual_number_product_schema_1.VirtualNumberProductSchema },
];
let DatabaseModule = class DatabaseModule {
};
exports.DatabaseModule = DatabaseModule;
exports.DatabaseModule = DatabaseModule = __decorate([
    (0, common_1.Module)({
        imports: [mongoose_1.MongooseModule.forFeature(featureModels)],
        exports: [mongoose_1.MongooseModule.forFeature(featureModels)],
    })
], DatabaseModule);
//# sourceMappingURL=database.module.js.map