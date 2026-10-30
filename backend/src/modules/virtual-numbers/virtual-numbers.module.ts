import { Module } from '@nestjs/common';
import { VirtualNumbersService } from './virtual-numbers.service';
import { VirtualNumbersController } from './virtual-numbers.controller';
import { VirtualNumbersWebhookController } from './virtual-numbers-webhook.controller';
import { DatabaseModule } from '../../database/database.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [DatabaseModule, NotificationsModule],
  controllers: [VirtualNumbersController, VirtualNumbersWebhookController],
  providers: [VirtualNumbersService],
  exports: [VirtualNumbersService],
})
export class VirtualNumbersModule {}
