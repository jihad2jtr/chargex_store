import { Controller, Get, UseGuards } from '@nestjs/common';
import { DashboardService } from './dashboard.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/interfaces/role.enum';

@Controller('dashboard')
@UseGuards(JwtAuthGuard, RolesGuard)
export class DashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  /** إحصاءات لوحة تحكم الأدمن (مؤشرات اليوم/الأمس، المعلّق، المتأخر، آخر 7 أيام، صحة النظام) */
  @Get('admin')
  @Roles(Role.ADMIN)
  async getAdminStats() {
    return this.dashboardService.getAdminStats();
  }

  /** عدّادات خفيفة (معلّقة) لتحديث اللوحة بدون تحميل القوائم الكاملة */
  @Get('admin/pending-counts')
  @Roles(Role.ADMIN)
  async getPendingCounts() {
    return this.dashboardService.getPendingCounts();
  }
}
