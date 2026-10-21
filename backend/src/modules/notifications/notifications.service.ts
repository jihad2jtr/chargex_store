import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Notification, NotificationDocument } from '../../database/schemas/notification.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Role } from '../../common/interfaces/role.enum';
import { FcmService } from './fcm.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectModel(Notification.name) private notificationModel: Model<NotificationDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private readonly fcmService: FcmService,
  ) {}

  /**
   * Save / Register Device FCM Token for a user
   */
  async saveFcmToken(userId: string, token: string) {
    if (!token || !userId) return { success: false, message: 'Invalid token or userId' };
    const trimmed = token.trim();

    await this.userModel.findByIdAndUpdate(userId, {
      $addToSet: { fcmTokens: trimmed },
    });
    this.logger.log(`[FCM] Registered device token for user ${userId}`);
    return { success: true, message: 'FCM Token registered successfully' };
  }

  /**
   * Remove Device FCM Token on logout
   */
  async removeFcmToken(userId: string, token: string) {
    if (!token || !userId) return { success: false };
    const trimmed = token.trim();

    await this.userModel.findByIdAndUpdate(userId, {
      $pull: { fcmTokens: trimmed },
    });
    this.logger.log(`[FCM] Removed device token for user ${userId}`);
    return { success: true, message: 'FCM Token removed' };
  }

  /**
   * Create in-app Notification and dispatch real-time FCM Push
   */
  async createNotification(params: {
    userId?: string;
    forRole?: 'all' | 'admin' | 'user' | 'supervisor';
    title: string;
    body: string;
    type: string;
    data?: Record<string, any>;
  }) {
    // 1. Save in Database
    const notif = new this.notificationModel({
      userId: params.userId ? new Types.ObjectId(params.userId) : undefined,
      forRole: params.forRole || 'user',
      title: params.title,
      body: params.body,
      type: params.type,
      data: params.data || {},
      isRead: false,
    });
    await notif.save();

    // 2. Collect Recipient FCM Tokens
    let recipientTokens: string[] = [];

    if (params.userId) {
      const user = await this.userModel.findById(params.userId);
      if (user && user.fcmTokens) {
        recipientTokens = user.fcmTokens;
      }
    } else if (params.forRole === 'admin') {
      const admins = await this.userModel.find({ role: Role.ADMIN });
      recipientTokens = admins.flatMap((a) => a.fcmTokens || []);
    } else if (params.forRole === 'supervisor') {
      const supervisors = await this.userModel.find({ role: Role.SUPERVISOR });
      recipientTokens = supervisors.flatMap((s) => s.fcmTokens || []);
    } else if (params.forRole === 'all') {
      const allUsers = await this.userModel.find({ isActive: true });
      recipientTokens = allUsers.flatMap((u) => u.fcmTokens || []);
    }

    // Deduplicate tokens
    recipientTokens = Array.from(new Set(recipientTokens));

    // 3. Dispatch FCM Push Notification
    if (recipientTokens.length > 0) {
      const fcmResult = await this.fcmService.sendToTokens(recipientTokens, {
        title: params.title,
        body: params.body,
        data: {
          notificationId: notif._id.toString(),
          type: params.type,
          forRole: params.forRole || 'user',
          ...(params.data || {}),
        },
      });

      // 4. Auto-clean invalid or expired tokens
      if (fcmResult.invalidTokens && fcmResult.invalidTokens.length > 0) {
        await this.userModel.updateMany(
          { fcmTokens: { $in: fcmResult.invalidTokens } },
          { $pull: { fcmTokens: { $in: fcmResult.invalidTokens } } },
        );
        this.logger.log(`[FCM] Purged ${fcmResult.invalidTokens.length} expired FCM tokens`);
      }
    }

    // Also dispatch to 'all' topic if broadcast
    if (params.forRole === 'all') {
      await this.fcmService.sendToTopic('all', {
        title: params.title,
        body: params.body,
        data: {
          notificationId: notif._id.toString(),
          type: params.type,
        },
      });
    }

    return notif;
  }

  /**
   * Send a test push notification to a specific user
   */
  async sendTestPush(userId: string, title?: string, body?: string) {
    return this.createNotification({
      userId,
      title: title || 'اختبار إشعارات ChargeX 🚀',
      body: body || 'إشعار تجريبي للتأكد من وصول رسائل Firebase بنجاح إلى جهازك!',
      type: 'test_notification',
      data: {
        timestamp: new Date().toISOString(),
      },
    });
  }

  async getMyNotifications(userId: string) {
    return this.notificationModel
      .find({
        $or: [
          { userId: new Types.ObjectId(userId) },
          { forRole: 'all' },
        ],
      })
      .sort({ createdAt: -1 })
      .limit(50);
  }

  async getAdminNotifications() {
    return this.notificationModel
      .find({
        $or: [{ forRole: 'admin' }, { forRole: 'all' }],
      })
      .sort({ createdAt: -1 })
      .limit(50);
  }

  async markAsRead(id: string) {
    return this.notificationModel.findByIdAndUpdate(id, { isRead: true }, { new: true });
  }

  async markAllAsRead(userId: string) {
    await this.notificationModel.updateMany(
      { userId: new Types.ObjectId(userId), isRead: false },
      { isRead: true },
    );
    return { message: 'تم تحديد جميع الإشعارات كمقروءة' };
  }
}
