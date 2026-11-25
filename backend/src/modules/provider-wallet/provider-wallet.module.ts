import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ProviderWalletController } from './provider-wallet.controller';
import { ProviderWalletService } from './provider-wallet.service';

@Module({
  imports: [DatabaseModule, NotificationsModule],
  controllers: [ProviderWalletController],
  providers: [ProviderWalletService],
  exports: [ProviderWalletService],
})
export class ProviderWalletModule {}
