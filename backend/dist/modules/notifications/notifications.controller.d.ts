import { NotificationsService } from './notifications.service';
import { UserDocument } from '../../database/schemas/user.schema';
export declare class NotificationsController {
    private readonly notificationsService;
    constructor(notificationsService: NotificationsService);
    getMyNotifications(user: UserDocument): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/notification.schema").NotificationDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/notification.schema").Notification & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getAdminNotifications(): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/notification.schema").NotificationDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/notification.schema").Notification & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    saveFcmToken(user: UserDocument, token: string): Promise<{
        success: boolean;
        message: string;
    }>;
    removeFcmToken(user: UserDocument, token: string): Promise<{
        success: boolean;
        message?: undefined;
    } | {
        success: boolean;
        message: string;
    }>;
    sendTestPush(user: UserDocument, targetUserId?: string, title?: string, body?: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/notification.schema").NotificationDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/notification.schema").Notification & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    markAsRead(id: string): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/notification.schema").NotificationDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/notification.schema").Notification & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }) | null>;
    markAllAsRead(user: UserDocument): Promise<{
        message: string;
    }>;
}
