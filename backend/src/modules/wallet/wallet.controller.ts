import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { WalletService } from './wallet.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserDocument } from '../../database/schemas/user.schema';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/interfaces/role.enum';

@Controller('wallet')
@UseGuards(JwtAuthGuard)
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get('balance')
  async getMyBalance(@CurrentUser() user: UserDocument) {
    return this.walletService.getUserBalance(user._id.toString());
  }

  @Get('transactions')
  async getMyTransactions(@CurrentUser() user: UserDocument) {
    return this.walletService.getUserTransactions(user._id.toString());
  }

  @Get('admin/transactions')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async getAllTransactionsAdmin() {
    return this.walletService.getAllTransactionsAdmin();
  }

  // Admin ID Top-up: Admin recharges user balance directly
  @Post('admin/adjust-balance')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async adjustBalance(
    @CurrentUser() admin: UserDocument,
    @Body() body: { userId: string; amount: number; description?: string },
  ) {
    return this.walletService.adminAdjustBalance({
      userId: body.userId,
      amount: Number(body.amount),
      description: body.description || 'شحن عبر معرف الحساب (ID)',
      adminId: admin._id.toString(),
    });
  }
}
