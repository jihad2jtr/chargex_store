import { Controller, Get, Post, Delete, Patch, Param, Body, UseGuards } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserDocument } from '../../database/schemas/user.schema';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/interfaces/role.enum';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get('my')
  async getMyNotifications(@CurrentUser() user: UserDocument) {
    return this.notificationsService.getMyNotifications(user._id.toString());
  }

  @Get('admin')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  async getAdminNotifications() {
    return this.notificationsService.getAdminNotifications();
  }

  @Post('fcm-token')
  async saveFcmToken(
    @CurrentUser() user: UserDocument,
    @Body('token') token: string,
  ) {
    return this.notificationsService.saveFcmToken(user._id.toString(), token);
  }

  @Delete('fcm-token')
  async removeFcmToken(
    @CurrentUser() user: UserDocument,
    @Body('token') token: string,
  ) {
    return this.notificationsService.removeFcmToken(user._id.toString(), token);
  }

  @Post('test-push')
  async sendTestPush(
    @CurrentUser() user: UserDocument,
    @Body('userId') targetUserId?: string,
    @Body('title') title?: string,
    @Body('body') body?: string,
  ) {
    const recipient = targetUserId || user._id.toString();
    return this.notificationsService.sendTestPush(recipient, title, body);
  }

  @Patch(':id/read')
  async markAsRead(@Param('id') id: string) {
    return this.notificationsService.markAsRead(id);
  }

  @Patch('read-all')
  async markAllAsRead(@CurrentUser() user: UserDocument) {
    return this.notificationsService.markAllAsRead(user._id.toString());
  }
}
