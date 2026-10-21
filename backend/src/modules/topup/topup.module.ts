import { Module } from '@nestjs/common';
import { TopupService } from './topup.service';
import { TopupController } from './topup.controller';
import { DatabaseModule } from '../../database/database.module';
import { WalletModule } from '../wallet/wallet.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [DatabaseModule, WalletModule, NotificationsModule],
  controllers: [TopupController],
  providers: [TopupService],
  exports: [TopupService],
})
export class TopupModule {}
