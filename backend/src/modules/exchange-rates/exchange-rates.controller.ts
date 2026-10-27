import { BadRequestException, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ExchangeRatesService } from './exchange-rates.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/interfaces/role.enum';

@Controller('exchange-rates')
export class ExchangeRatesController {
  constructor(private readonly exchangeRatesService: ExchangeRatesService) {}

  // Public: التطبيق يقرأ سعر الصرف المحفوظ (ويُجلب تلقائياً إن لم يوجد)
  @Get('current')
  async getCurrent() {
    try {
      const data = await this.exchangeRatesService.getCurrent();
      return data ?? this.unavailable();
    } catch {
      // المصدر متوقف ولا يوجد سعر محفوظ: نعيد rate = 0 كي لا يتعطل التطبيق
      return this.unavailable();
    }
  }

  // Public: نفس الاستجابة بدون اللاحقة /current
  @Get()
  async getRate() {
    return this.getCurrent();
  }

  // Admin: جلب فوري من المصدر بغض النظر عن وقت آخر تحديث
  @Post('refresh')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async refresh() {
    try {
      return await this.exchangeRatesService.refresh();
    } catch (error) {
      throw new BadRequestException(
        `تعذر جلب سعر الصرف من المصدر: ${(error as Error).message}`,
      );
    }
  }

  private unavailable() {
    return {
      pair: 'usdsypd',
      rate: 0,
      buy: 0,
      sell: 0,
      previousRate: null,
      change: 0,
      changePercent: 0,
      source: 'liranews',
      stale: true,
      available: false,
    };
  }
}
