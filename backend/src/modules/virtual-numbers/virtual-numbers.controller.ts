import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { VirtualNumbersService } from './virtual-numbers.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/interfaces/role.enum';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserDocument } from '../../database/schemas/user.schema';

@Controller('virtual-numbers')
@UseGuards(JwtAuthGuard)
export class VirtualNumbersController {
  constructor(private readonly service: VirtualNumbersService) {}

  // --- 1. العميل: كتالوج الأرقام وطلب رقم واستقبال الرمز ---

  @Get('options')
  async getOptions() {
    return this.service.getOptions();
  }

  @Post('request')
  async requestNumber(
    @CurrentUser() user: UserDocument,
    @Body()
    body: {
      // productId هو المسار الجديد: الدولة نفسها قد تُباع من أكثر من سيرفر
      productId?: string;
      service?: string;
      country?: string;
      operator?: string;
      // معادلة إعادة المحاولة بعد انقطاع الاستجابة (idempotency)
      clientRequestId?: string;
    },
  ) {
    return this.service.requestNumber({
      userId: user._id.toString(),
      productId: body.productId,
      service: body.service,
      country: body.country,
      operator: body.operator,
      clientRequestId: body.clientRequestId,
    });
  }

  @Get('my')
  async getMyRequests(@CurrentUser() user: UserDocument) {
    return this.service.getMyRequests(user._id.toString());
  }

  @Get('my/:id')
  async getMyRequest(
    @CurrentUser() user: UserDocument,
    @Param('id') id: string,
    @Query('refresh') refresh?: string,
  ) {
    return this.service.getMyRequest(
      user._id.toString(),
      id,
      refresh !== '0',
    );
  }

  // إغلاق الرقم: بعد وصول الرمز يُنهى الطلب، وقبله يُلغى ويُرجع المبلغ
  @Post(':id/close')
  async closeMyRequest(
    @CurrentUser() user: UserDocument,
    @Param('id') id: string,
    @Body('reason') reason?: string,
  ) {
    return this.service.closeMyRequest(user._id.toString(), id, reason);
  }

  // --- 2. الإدارة: المتابعة والإيقاف اليدوي والمزامنة ---

  @Get('admin/requests')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async getAdminRequests(
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('limit') limit?: string,
  ) {
    const parsed = Number(limit);
    return this.service.getAdminRequests({
      status,
      search,
      limit: Number.isFinite(parsed) && parsed > 0 ? parsed : undefined,
    });
  }

  @Get('admin/stats')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async getAdminStats() {
    return this.service.getAdminStats();
  }

  @Post('admin/sync-catalog')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async syncCatalog() {
    return this.service.syncCatalog();
  }

  @Post('admin/check-provider')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async checkProvider() {
    return this.service.adminCheckProvider();
  }

  // تشغيل يدوي للمسح الدوري (انتهاء المهل واستقبال الرموز)
  @Post('admin/sweep')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async runSweep() {
    return this.service.runSweepNow();
  }

  @Post('admin/:id/cancel')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async adminCancel(
    @Param('id') id: string,
    @CurrentUser() user: UserDocument,
    @Body('reason') reason?: string,
  ) {
    return this.service.adminCancelRequest(id, user._id.toString(), reason);
  }

  @Post('admin/:id/finish')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async adminFinish(@Param('id') id: string, @Body('reason') reason?: string) {
    return this.service.adminFinishRequest(id, reason);
  }

  // --- 3. الإدارة: المُنتقَى (تطبيقات الأرقام ودولها) ---

  @Get('admin/apps')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async listApps() {
    return this.service.listAdminApps();
  }

  @Post('admin/apps')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async createApp(@Body() body: any) {
    return this.service.createApp(body);
  }

  // مُسرِّع التنسيق: إنشاء تطبيق لكل خدمة في الكتالوج لم تُضَف بعد
  @Post('admin/apps/bulk')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async bulkApps(@Body() body: { providerId?: string }) {
    return this.service.bulkCreateApps(body?.providerId);
  }

  @Patch('admin/apps/:id')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async updateApp(@Param('id') id: string, @Body() body: any) {
    return this.service.updateApp(id, body);
  }

  @Patch('admin/apps/:id/toggle')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async toggleApp(@Param('id') id: string) {
    return this.service.toggleApp(id);
  }

  @Delete('admin/apps/:id')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async deleteApp(@Param('id') id: string) {
    return this.service.deleteApp(id);
  }

  // كتالوج المزود مُثري بالمُنتقَى (لتصفح الدول وإضافتها إلى التطبيقات)
  @Get('admin/catalog')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async adminCatalog(@Query('providerId') providerId?: string) {
    return this.service.getAdminCatalog(providerId);
  }

  @Post('admin/catalog/add-countries')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async addCountries(
    @Body()
    body: {
      appId: string;
      providerId?: string;
      countries: Array<{
        code: string;
        name?: string;
        cost?: number;
        count?: number;
        operators?: Array<{ code: string; name: string }>;
      }>;
    },
  ) {
    return this.service.addCountriesToApp(body);
  }

  @Patch('admin/products/:id/toggle')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async toggleProduct(@Param('id') id: string) {
    return this.service.toggleProduct(id);
  }

  @Delete('admin/products/:id')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async removeProduct(@Param('id') id: string) {
    return this.service.removeProduct(id);
  }

  // --- 3.1 الإدارة: مراقبة جودة الأرقام لكل سيرفر ---

  @Get('admin/quality')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async getAdminQuality(
    @Query('bucket') bucket?: string,
    @Query('providerId') providerId?: string,
    @Query('search') search?: string,
  ) {
    return this.service.getAdminQuality({ bucket, providerId, search });
  }

  @Get('admin/quality/:productId/events')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async getQualityEvents(
    @Param('productId') productId: string,
    @Query('limit') limit?: string,
  ) {
    const parsed = Number(limit);
    return this.service.getProductQualityEvents(
      productId,
      Number.isFinite(parsed) && parsed > 0 ? parsed : undefined,
    );
  }

  // إعادة التفعيل تصفّر الفشل المتتالي وحده وتُبقي التاريخ للوحة
  @Post('admin/quality/:productId/reactivate')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async reactivateProduct(
    @Param('productId') productId: string,
    @CurrentUser() user: UserDocument,
    @Body('note') note?: string,
  ) {
    return this.service.reactivateProduct(productId, note, user.name || '');
  }

  // --- 4. خدمات الأرقام اليدوية (تفعيل مضمون) ---

  @Get('admin/manual-services')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async listAdminManualServices() {
    return this.service.listAdminManualServices();
  }

  @Post('admin/manual-services')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async createManualService(@Body() body: any) {
    return this.service.createManualService(body);
  }

  @Patch('admin/manual-services/:id')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async updateManualService(
    @Param('id') id: string,
    @Body() body: any,
  ) {
    return this.service.updateManualService(id, body);
  }

  @Patch('admin/manual-services/:id/toggle')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async toggleManualService(@Param('id') id: string) {
    return this.service.toggleManualService(id);
  }

  @Delete('admin/manual-services/:id')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async deleteManualService(@Param('id') id: string) {
    return this.service.deleteManualService(id);
  }
}
