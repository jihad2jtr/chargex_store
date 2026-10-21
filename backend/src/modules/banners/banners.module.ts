import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { BannersService } from './banners.service';
import { BannersController } from './banners.controller';

@Module({
  imports: [DatabaseModule],
  controllers: [BannersController],
  providers: [BannersService],
  exports: [BannersService],
})
export class BannersModule {}
