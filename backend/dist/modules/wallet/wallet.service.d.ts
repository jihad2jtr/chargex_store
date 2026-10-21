import { Model, Types } from 'mongoose';
import { WalletTransaction, WalletTransactionDocument } from '../../database/schemas/wallet-transaction.schema';
import { UserDocument } from '../../database/schemas/user.schema';
import { NotificationsService } from '../notifications/notifications.service';
export declare class WalletService {
    private transactionModel;
    private userModel;
    private notificationsService;
    constructor(transactionModel: Model<WalletTransactionDocument>, userModel: Model<UserDocument>, notificationsService: NotificationsService);
    getUserBalance(userId: string): Promise<{
        userId: Types.ObjectId;
        customUserId: string | undefined;
        balance: number;
        currency: string;
    }>;
    getUserTransactions(userId: string): Promise<(import("mongoose").Document<unknown, {}, WalletTransactionDocument, {}, import("mongoose").DefaultSchemaOptions> & WalletTransaction & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getAllTransactionsAdmin(): Promise<(import("mongoose").Document<unknown, {}, WalletTransactionDocument, {}, import("mongoose").DefaultSchemaOptions> & WalletTransaction & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    adminAdjustBalance(params: {
        userId: string;
        amount: number;
        description: string;
        adminId: string;
    }): Promise<{
        message: string;
        user: {
            id: Types.ObjectId;
            userId: string | undefined;
            name: string;
            email: string;
            balance: number;
        };
        transaction: import("mongoose").Document<unknown, {}, WalletTransactionDocument, {}, import("mongoose").DefaultSchemaOptions> & WalletTransaction & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
}
