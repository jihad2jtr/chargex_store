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
];

@Module({
  imports: [MongooseModule.forFeature(featureModels)],
  exports: [MongooseModule.forFeature(featureModels)],
})
export class DatabaseModule {}
