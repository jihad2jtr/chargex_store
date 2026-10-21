import { WalletService } from './wallet.service';
import { UserDocument } from '../../database/schemas/user.schema';
export declare class WalletController {
    private readonly walletService;
    constructor(walletService: WalletService);
    getMyBalance(user: UserDocument): Promise<{
        userId: import("mongoose").Types.ObjectId;
        customUserId: string | undefined;
        balance: number;
        currency: string;
    }>;
    getMyTransactions(user: UserDocument): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/wallet-transaction.schema").WalletTransactionDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/wallet-transaction.schema").WalletTransaction & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getAllTransactionsAdmin(): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/wallet-transaction.schema").WalletTransactionDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/wallet-transaction.schema").WalletTransaction & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    adjustBalance(admin: UserDocument, body: {
        userId: string;
        amount: number;
        description?: string;
    }): Promise<{
        message: string;
        user: {
            id: import("mongoose").Types.ObjectId;
            userId: string | undefined;
            name: string;
            email: string;
            balance: number;
        };
        transaction: import("mongoose").Document<unknown, {}, import("../../database/schemas/wallet-transaction.schema").WalletTransactionDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/wallet-transaction.schema").WalletTransaction & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
}
