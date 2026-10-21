import { Model, Types } from 'mongoose';
import { Notification, NotificationDocument } from '../../database/schemas/notification.schema';
import { UserDocument } from '../../database/schemas/user.schema';
import { FcmService } from './fcm.service';
export declare class NotificationsService {
    private notificationModel;
    private userModel;
    private readonly fcmService;
    private readonly logger;
    constructor(notificationModel: Model<NotificationDocument>, userModel: Model<UserDocument>, fcmService: FcmService);
    saveFcmToken(userId: string, token: string): Promise<{
        success: boolean;
        message: string;
    }>;
    removeFcmToken(userId: string, token: string): Promise<{
        success: boolean;
        message?: undefined;
    } | {
        success: boolean;
        message: string;
    }>;
    createNotification(params: {
        userId?: string;
        forRole?: 'all' | 'admin' | 'user' | 'supervisor';
        title: string;
        body: string;
        type: string;
        data?: Record<string, any>;
    }): Promise<import("mongoose").Document<unknown, {}, NotificationDocument, {}, import("mongoose").DefaultSchemaOptions> & Notification & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    sendTestPush(userId: string, title?: string, body?: string): Promise<import("mongoose").Document<unknown, {}, NotificationDocument, {}, import("mongoose").DefaultSchemaOptions> & Notification & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    getMyNotifications(userId: string): Promise<(import("mongoose").Document<unknown, {}, NotificationDocument, {}, import("mongoose").DefaultSchemaOptions> & Notification & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getAdminNotifications(): Promise<(import("mongoose").Document<unknown, {}, NotificationDocument, {}, import("mongoose").DefaultSchemaOptions> & Notification & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    markAsRead(id: string): Promise<(import("mongoose").Document<unknown, {}, NotificationDocument, {}, import("mongoose").DefaultSchemaOptions> & Notification & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }) | null>;
    markAllAsRead(userId: string): Promise<{
        message: string;
    }>;
}
