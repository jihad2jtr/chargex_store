import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { ServiceTemplatesService } from './service-templates.service';
import { ServiceTemplatesController } from './service-templates.controller';

@Module({
  imports: [DatabaseModule],
  controllers: [ServiceTemplatesController],
  providers: [ServiceTemplatesService],
  exports: [ServiceTemplatesService],
})
export class ServiceTemplatesModule {}
