import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Role } from '../../common/interfaces/role.enum';
import { UserDocument } from '../../database/schemas/user.schema';
import { ProviderWalletService } from './provider-wallet.service';

@Controller('provider-wallet')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ProviderWalletController {
  constructor(private readonly service: ProviderWalletService) {}

  @Get('me')
  @Roles(Role.SUPERVISOR, Role.ADMIN, Role.USER)
  async myWallet(@CurrentUser() user: UserDocument) {
    return this.service.getMySummary(user._id.toString());
  }

  @Patch('sham-cash')
  @Roles(Role.SUPERVISOR, Role.ADMIN)
  async updateShamCash(
    @CurrentUser() user: UserDocument,
    @Body() body: { accountName: string; accountId: string },
  ) {
    return this.service.updateShamCashAccount(user._id.toString(), body);
  }

  @Post('transfer-to-main')
  @Roles(Role.SUPERVISOR, Role.ADMIN, Role.USER)
  async transferToMain(
    @CurrentUser() user: UserDocument,
    @Body('amount') amount: number,
  ) {
    return this.service.transferToMainBalance(user._id.toString(), Number(amount));
  }

  @Post('withdrawals')
  @Roles(Role.SUPERVISOR, Role.ADMIN)
  async requestWithdrawal(
    @CurrentUser() user: UserDocument,
    @Body() body: { amount: number; notes?: string },
  ) {
    return this.service.requestWithdrawal(user._id.toString(), {
      amount: Number(body.amount),
      notes: body.notes,
    });
  }

  @Get('admin/overview')
  @Roles(Role.ADMIN)
  async adminOverview(@Query('status') status?: string) {
    return this.service.getAdminOverview(status);
  }

  @Post('admin/withdrawals/:id/approve')
  @Roles(Role.ADMIN)
  async approve(
    @Param('id') id: string,
    @CurrentUser() admin: UserDocument,
    @Body('adminNote') adminNote?: string,
  ) {
    return this.service.approveWithdrawal(id, admin, adminNote);
  }

  @Post('admin/withdrawals/:id/reject')
  @Roles(Role.ADMIN)
  async reject(
    @Param('id') id: string,
    @CurrentUser() admin: UserDocument,
    @Body('adminNote') adminNote?: string,
  ) {
    return this.service.rejectWithdrawal(id, admin, adminNote);
  }
}
