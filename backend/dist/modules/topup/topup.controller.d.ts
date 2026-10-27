import { TopupService } from './topup.service';
import { UserDocument } from '../../database/schemas/user.schema';
import { PaymentAccountType } from '../../database/schemas/sham-cash-account.schema';
import { ManualOrderStatus } from '../../database/schemas/manual-order.schema';
export declare class TopupController {
    private readonly topupService;
    constructor(topupService: TopupService);
    getActiveAccounts(type?: PaymentAccountType): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/sham-cash-account.schema").ShamCashAccountDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/sham-cash-account.schema").ShamCashAccount & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    submitTopupRequest(user: UserDocument, body: {
        type: 'sham_cash' | 'binance' | 'id_recharge';
        amount: number;
        details: Record<string, any>;
        receiptImageUrl?: string;
    }): Promise<{
        message: string;
        manualOrder: import("mongoose").Document<unknown, {}, import("../../database/schemas/manual-order.schema").ManualOrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/manual-order.schema").ManualOrder & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    getMyRequests(user: UserDocument): Promise<any[]>;
    getAllAccountsAdmin(type?: PaymentAccountType): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/sham-cash-account.schema").ShamCashAccountDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/sham-cash-account.schema").ShamCashAccount & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    createAccount(body: any): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/sham-cash-account.schema").ShamCashAccountDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/sham-cash-account.schema").ShamCashAccount & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    updateAccount(id: string, body: any): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/sham-cash-account.schema").ShamCashAccountDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/sham-cash-account.schema").ShamCashAccount & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    toggleAccountActive(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/sham-cash-account.schema").ShamCashAccountDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/sham-cash-account.schema").ShamCashAccount & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    deleteAccount(id: string): Promise<{
        message: string;
    }>;
    getManualOrders(status?: ManualOrderStatus): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/manual-order.schema").ManualOrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/manual-order.schema").ManualOrder & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getAdminTopupLog(): Promise<any[]>;
    createIdTopup(admin: UserDocument, body: {
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
        entry: import("mongoose").Document<unknown, {}, import("../../database/schemas/manual-order.schema").ManualOrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/manual-order.schema").ManualOrder & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    approveTopup(id: string, admin: UserDocument, body: {
        approvedAmount?: number;
        notes?: string;
    }): Promise<{
        message: string;
        manualOrder: import("mongoose").Document<unknown, {}, import("../../database/schemas/manual-order.schema").ManualOrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/manual-order.schema").ManualOrder & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    rejectTopup(id: string, admin: UserDocument, body: {
        notes: string;
    }): Promise<{
        message: string;
        manualOrder: import("mongoose").Document<unknown, {}, import("../../database/schemas/manual-order.schema").ManualOrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/manual-order.schema").ManualOrder & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
}
