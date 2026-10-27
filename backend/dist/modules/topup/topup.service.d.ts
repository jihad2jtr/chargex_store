import { Model, Types } from 'mongoose';
import { ShamCashAccount, ShamCashAccountDocument, PaymentAccountType } from '../../database/schemas/sham-cash-account.schema';
import { ManualOrder, ManualOrderDocument, ManualOrderStatus } from '../../database/schemas/manual-order.schema';
import { ShippingCodeDocument } from '../../database/schemas/shipping-code.schema';
import { TopupMethodDocument } from '../../database/schemas/topup-method.schema';
import { UserDocument } from '../../database/schemas/user.schema';
import { WalletTransactionDocument } from '../../database/schemas/wallet-transaction.schema';
import { WalletService } from '../wallet/wallet.service';
import { NotificationsService } from '../notifications/notifications.service';
export declare class TopupService {
    private accountModel;
    private manualOrderModel;
    private codeModel;
    private topupMethodModel;
    private userModel;
    private transactionModel;
    private walletService;
    private notificationsService;
    private readonly logger;
    constructor(accountModel: Model<ShamCashAccountDocument>, manualOrderModel: Model<ManualOrderDocument>, codeModel: Model<ShippingCodeDocument>, topupMethodModel: Model<TopupMethodDocument>, userModel: Model<UserDocument>, transactionModel: Model<WalletTransactionDocument>, walletService: WalletService, notificationsService: NotificationsService);
    getActiveAccounts(type?: PaymentAccountType): Promise<(import("mongoose").Document<unknown, {}, ShamCashAccountDocument, {}, import("mongoose").DefaultSchemaOptions> & ShamCashAccount & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getAllAccountsAdmin(type?: PaymentAccountType): Promise<(import("mongoose").Document<unknown, {}, ShamCashAccountDocument, {}, import("mongoose").DefaultSchemaOptions> & ShamCashAccount & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    createAccount(data: {
        type: PaymentAccountType;
        accountName: string;
        accountId: string;
        barcodeUrl: string;
    }): Promise<import("mongoose").Document<unknown, {}, ShamCashAccountDocument, {}, import("mongoose").DefaultSchemaOptions> & ShamCashAccount & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    updateAccount(id: string, updateData: any): Promise<import("mongoose").Document<unknown, {}, ShamCashAccountDocument, {}, import("mongoose").DefaultSchemaOptions> & ShamCashAccount & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    toggleAccountActive(id: string): Promise<import("mongoose").Document<unknown, {}, ShamCashAccountDocument, {}, import("mongoose").DefaultSchemaOptions> & ShamCashAccount & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    deleteAccount(id: string): Promise<{
        message: string;
    }>;
    submitTopupRequest(params: {
        userId: string;
        type: 'sham_cash' | 'binance' | 'id_recharge';
        amount: number;
        details: Record<string, any>;
        receiptImageUrl?: string;
    }): Promise<{
        message: string;
        manualOrder: import("mongoose").Document<unknown, {}, ManualOrderDocument, {}, import("mongoose").DefaultSchemaOptions> & ManualOrder & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    getManualOrders(status?: ManualOrderStatus): Promise<(import("mongoose").Document<unknown, {}, ManualOrderDocument, {}, import("mongoose").DefaultSchemaOptions> & ManualOrder & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getMyTopupRequests(userId: string): Promise<any[]>;
    getAdminTopupLog(limit?: number): Promise<any[]>;
    private legacyIdTopupFilter;
    private mergeTopupLog;
    createIdTopup(params: {
        userId: string;
        amount: number;
        description?: string;
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
        entry: import("mongoose").Document<unknown, {}, ManualOrderDocument, {}, import("mongoose").DefaultSchemaOptions> & ManualOrder & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    approveTopup(id: string, adminId: string, approvedAmount?: number, notes?: string): Promise<{
        message: string;
        manualOrder: import("mongoose").Document<unknown, {}, ManualOrderDocument, {}, import("mongoose").DefaultSchemaOptions> & ManualOrder & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    rejectTopup(id: string, adminId: string, notes: string): Promise<{
        message: string;
        manualOrder: import("mongoose").Document<unknown, {}, ManualOrderDocument, {}, import("mongoose").DefaultSchemaOptions> & ManualOrder & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
}
