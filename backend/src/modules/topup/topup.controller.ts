import { Controller, Get, Post, Put, Delete, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { TopupService } from './topup.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/interfaces/role.enum';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserDocument } from '../../database/schemas/user.schema';
import { PaymentAccountType } from '../../database/schemas/sham-cash-account.schema';
import { ManualOrderStatus } from '../../database/schemas/manual-order.schema';

@Controller('topup')
export class TopupController {
  constructor(private readonly topupService: TopupService) {}

  // Client: get active payment accounts (Sham Cash or Binance)
  @Get('accounts')
  async getActiveAccounts(@Query('type') type?: PaymentAccountType) {
    return this.topupService.getActiveAccounts(type);
  }

  // Client: submit topup request
  @Post('request')
  @UseGuards(JwtAuthGuard)
  async submitTopupRequest(
    @CurrentUser() user: UserDocument,
    @Body() body: { type: 'sham_cash' | 'binance' | 'id_recharge'; amount: number; details: Record<string, any>; receiptImageUrl?: string },
  ) {
    return this.topupService.submitTopupRequest({
      userId: user._id.toString(),
      type: body.type,
      amount: Number(body.amount),
      details: body.details,
      receiptImageUrl: body.receiptImageUrl,
    });
  }

  // Client: view their own requests
  @Get('my-requests')
  @UseGuards(JwtAuthGuard)
  async getMyRequests(@CurrentUser() user: UserDocument) {
    return this.topupService.getMyTopupRequests(user._id.toString());
  }

  // Admin: manage payment accounts
  @Get('admin/accounts')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async getAllAccountsAdmin(@Query('type') type?: PaymentAccountType) {
    return this.topupService.getAllAccountsAdmin(type);
  }

  @Post('admin/accounts')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async createAccount(@Body() body: any) {
    return this.topupService.createAccount(body);
  }

  @Put('admin/accounts/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async updateAccount(@Param('id') id: string, @Body() body: any) {
    return this.topupService.updateAccount(id, body);
  }

  @Patch('admin/accounts/:id/toggle')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async toggleAccountActive(@Param('id') id: string) {
    return this.topupService.toggleAccountActive(id);
  }

  @Delete('admin/accounts/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async deleteAccount(@Param('id') id: string) {
    return this.topupService.deleteAccount(id);
  }

  // Admin: view all manual topup requests
  @Get('admin/requests')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async getManualOrders(@Query('status') status?: ManualOrderStatus) {
    return this.topupService.getManualOrders(status);
  }

  // Admin: approve request
  @Post('admin/requests/:id/approve')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async approveTopup(
    @Param('id') id: string,
    @CurrentUser() admin: UserDocument,
    @Body() body: { approvedAmount?: number; notes?: string },
  ) {
    return this.topupService.approveTopup(id, admin._id.toString(), body.approvedAmount, body.notes);
  }

  // Admin: reject request
  @Post('admin/requests/:id/reject')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async rejectTopup(
    @Param('id') id: string,
    @CurrentUser() admin: UserDocument,
    @Body() body: { notes: string },
  ) {
    return this.topupService.rejectTopup(id, admin._id.toString(), body.notes);
  }
}
