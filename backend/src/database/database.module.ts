import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { User, UserSchema } from './schemas/user.schema';
import { Provider, ProviderSchema } from './schemas/provider.schema';
import { App, AppSchema } from './schemas/app.schema';
import { Product, ProductSchema } from './schemas/product.schema';
import { ProviderProduct, ProviderProductSchema } from './schemas/provider-product.schema';
import { Order, OrderSchema } from './schemas/order.schema';
import { WalletTransaction, WalletTransactionSchema } from './schemas/wallet-transaction.schema';
import { TopupMethod, TopupMethodSchema } from './schemas/topup-method.schema';
import { ShamCashAccount, ShamCashAccountSchema } from './schemas/sham-cash-account.schema';
import { ShippingCode, ShippingCodeSchema } from './schemas/shipping-code.schema';
import { ManualOrder, ManualOrderSchema } from './schemas/manual-order.schema';
import { Notification, NotificationSchema } from './schemas/notification.schema';
import { Banner, BannerSchema } from './schemas/banner.schema';
import { ServiceTemplate, ServiceTemplateSchema } from './schemas/service-template.schema';
import { ExchangeRate, ExchangeRateSchema } from './schemas/exchange-rate.schema';
import {
  VirtualNumberRequest,
  VirtualNumberRequestSchema,
} from './schemas/virtual-number-request.schema';
import {
  VirtualNumberCatalog,
  VirtualNumberCatalogSchema,
} from './schemas/virtual-number-catalog.schema';
import {
  VirtualNumberApp,
  VirtualNumberAppSchema,
} from './schemas/virtual-number-app.schema';
import {
  VirtualNumberProduct,
  VirtualNumberProductSchema,
} from './schemas/virtual-number-product.schema';
import {
  VirtualNumberQualityEvent,
  VirtualNumberQualityEventSchema,
} from './schemas/virtual-number-quality-event.schema';

const featureModels = [
  { name: User.name, schema: UserSchema },
  { name: Provider.name, schema: ProviderSchema },
  { name: App.name, schema: AppSchema },
  { name: Product.name, schema: ProductSchema },
  { name: ProviderProduct.name, schema: ProviderProductSchema },
  { name: Order.name, schema: OrderSchema },
  { name: WalletTransaction.name, schema: WalletTransactionSchema },
  { name: TopupMethod.name, schema: TopupMethodSchema },
  { name: ShamCashAccount.name, schema: ShamCashAccountSchema },
  { name: ShippingCode.name, schema: ShippingCodeSchema },
  { name: ManualOrder.name, schema: ManualOrderSchema },
  { name: Notification.name, schema: NotificationSchema },
  { name: Banner.name, schema: BannerSchema },
  { name: ServiceTemplate.name, schema: ServiceTemplateSchema },
  { name: ExchangeRate.name, schema: ExchangeRateSchema },
  { name: VirtualNumberRequest.name, schema: VirtualNumberRequestSchema },
  { name: VirtualNumberCatalog.name, schema: VirtualNumberCatalogSchema },
  { name: VirtualNumberApp.name, schema: VirtualNumberAppSchema },
  { name: VirtualNumberProduct.name, schema: VirtualNumberProductSchema },
  {
    name: VirtualNumberQualityEvent.name,
    schema: VirtualNumberQualityEventSchema,
  },
];

@Module({
  imports: [MongooseModule.forFeature(featureModels)],
  exports: [MongooseModule.forFeature(featureModels)],
})
export class DatabaseModule {}
