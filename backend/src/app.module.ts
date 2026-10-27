import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { DatabaseModule } from './database/database.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { ProvidersModule } from './modules/providers/providers.module';
import { AppsModule } from './modules/apps/apps.module';
import { ProductsModule } from './modules/products/products.module';
import { OrdersModule } from './modules/orders/orders.module';
import { WalletModule } from './modules/wallet/wallet.module';
import { TopupModule } from './modules/topup/topup.module';
import { CodesModule } from './modules/codes/codes.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { UploadModule } from './modules/upload/upload.module';
import { BannersModule } from './modules/banners/banners.module';
import { AgentModule } from './modules/agent/agent.module';
import { DashboardModule } from './modules/dashboard/dashboard.module';
import { ServiceTemplatesModule } from './modules/service-templates/service-templates.module';
import { ExchangeRatesModule } from './modules/exchange-rates/exchange-rates.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    MongooseModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        uri:
          configService.get<string>('MONGODB_URI') ||
          'mongodb+srv://jihad2jus:l9GrLciVEUvvK8Fd@jihad.8dyvx.mongodb.net/jgo?retryWrites=true&w=majority&appName=jihad',
        serverSelectionTimeoutMS: 3000,
        connectTimeoutMS: 4000,
        retryAttempts: 1,
        retryDelay: 500,
      }),
      inject: [ConfigService],
    }),
    DatabaseModule,
    AuthModule,
    UsersModule,
    ProvidersModule,
    AppsModule,
    ProductsModule,
    OrdersModule,
    WalletModule,
    TopupModule,
    CodesModule,
    NotificationsModule,
    UploadModule,
    BannersModule,
    AgentModule,
    DashboardModule,
    ServiceTemplatesModule,
    ExchangeRatesModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
