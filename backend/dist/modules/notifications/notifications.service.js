"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var NotificationsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificationsService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const notification_schema_1 = require("../../database/schemas/notification.schema");
const user_schema_1 = require("../../database/schemas/user.schema");
const role_enum_1 = require("../../common/interfaces/role.enum");
const fcm_service_1 = require("./fcm.service");
let NotificationsService = NotificationsService_1 = class NotificationsService {
    constructor(notificationModel, userModel, fcmService) {
        this.notificationModel = notificationModel;
        this.userModel = userModel;
        this.fcmService = fcmService;
        this.logger = new common_1.Logger(NotificationsService_1.name);
    }
    async saveFcmToken(userId, token) {
        if (!token || !userId)
            return { success: false, message: 'Invalid token or userId' };
        const trimmed = token.trim();
        await this.userModel.findByIdAndUpdate(userId, {
            $addToSet: { fcmTokens: trimmed },
        });
        this.logger.log(`[FCM] Registered device token for user ${userId}`);
        return { success: true, message: 'FCM Token registered successfully' };
    }
    async removeFcmToken(userId, token) {
        if (!token || !userId)
            return { success: false };
        const trimmed = token.trim();
        await this.userModel.findByIdAndUpdate(userId, {
            $pull: { fcmTokens: trimmed },
        });
        this.logger.log(`[FCM] Removed device token for user ${userId}`);
        return { success: true, message: 'FCM Token removed' };
    }
    async createNotification(params) {
        const notif = new this.notificationModel({
            userId: params.userId ? new mongoose_2.Types.ObjectId(params.userId) : undefined,
            forRole: params.forRole || 'user',
            title: params.title,
            body: params.body,
            type: params.type,
            data: params.data || {},
            isRead: false,
        });
        await notif.save();
        let recipientTokens = [];
        if (params.userId) {
            const user = await this.userModel.findById(params.userId);
            if (user && user.fcmTokens) {
                recipientTokens = user.fcmTokens;
            }
        }
        else if (params.forRole === 'admin') {
            const admins = await this.userModel.find({ role: role_enum_1.Role.ADMIN });
            recipientTokens = admins.flatMap((a) => a.fcmTokens || []);
        }
        else if (params.forRole === 'supervisor') {
            const supervisors = await this.userModel.find({ role: role_enum_1.Role.SUPERVISOR });
            recipientTokens = supervisors.flatMap((s) => s.fcmTokens || []);
        }
        else if (params.forRole === 'all') {
            const allUsers = await this.userModel.find({ isActive: true });
            recipientTokens = allUsers.flatMap((u) => u.fcmTokens || []);
        }
        recipientTokens = Array.from(new Set(recipientTokens));
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
            if (fcmResult.invalidTokens && fcmResult.invalidTokens.length > 0) {
                await this.userModel.updateMany({ fcmTokens: { $in: fcmResult.invalidTokens } }, { $pull: { fcmTokens: { $in: fcmResult.invalidTokens } } });
                this.logger.log(`[FCM] Purged ${fcmResult.invalidTokens.length} expired FCM tokens`);
            }
        }
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
    async sendTestPush(userId, title, body) {
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
    async getMyNotifications(userId) {
        return this.notificationModel
            .find({
            $or: [
                { userId: new mongoose_2.Types.ObjectId(userId) },
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
    async markAsRead(id) {
        return this.notificationModel.findByIdAndUpdate(id, { isRead: true }, { new: true });
    }
    async markAllAsRead(userId) {
        await this.notificationModel.updateMany({ userId: new mongoose_2.Types.ObjectId(userId), isRead: false }, { isRead: true });
        return { message: 'تم تحديد جميع الإشعارات كمقروءة' };
    }
};
exports.NotificationsService = NotificationsService;
exports.NotificationsService = NotificationsService = NotificationsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(notification_schema_1.Notification.name)),
    __param(1, (0, mongoose_1.InjectModel)(user_schema_1.User.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model,
        fcm_service_1.FcmService])
], NotificationsService);
//# sourceMappingURL=notifications.service.js.map