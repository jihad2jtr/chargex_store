import { Controller, Get, Post, Delete, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { CodesService } from './codes.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/interfaces/role.enum';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserDocument } from '../../database/schemas/user.schema';

@Controller('codes')
@UseGuards(JwtAuthGuard)
export class CodesController {
  constructor(private readonly codesService: CodesService) {}

  // User: Verify recharge code validity without redeeming
  @Post('verify')
  async verifyCode(@Body() body: { code: string }) {
    return this.codesService.verifyCode(body.code);
  }

  // User: Redeem recharge code
  @Post('redeem')
  async redeemCode(@CurrentUser() user: UserDocument, @Body() body: { code: string }) {
    return this.codesService.redeemCode(body.code, user._id.toString());
  }

  // Admin: Generate codes
  @Post('admin/generate')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async generateCodes(
    @CurrentUser() admin: UserDocument,
    @Body() body: { amount: number; count?: number },
  ) {
    return this.codesService.generateCodes({
      amount: Number(body.amount),
      count: Number(body.count || 1),
      adminId: admin._id.toString(),
    });
  }

  // Admin: Get all codes
  @Get('admin/all')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async getAllCodes(@Query() query: { isUsed?: string; isActive?: string }) {
    return this.codesService.getAllCodes({
      isUsed: query.isUsed !== undefined ? query.isUsed === 'true' : undefined,
      isActive: query.isActive !== undefined ? query.isActive === 'true' : undefined,
    });
  }

  // Admin: Toggle active
  @Patch('admin/:id/toggle')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async toggleActive(@Param('id') id: string) {
    return this.codesService.toggleActive(id);
  }

  // Admin: Delete code
  @Delete('admin/:id')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async remove(@Param('id') id: string) {
    return this.codesService.remove(id);
  }
}
