import { Model, Types } from 'mongoose';
import { ShippingCode, ShippingCodeDocument } from '../../database/schemas/shipping-code.schema';
import { UserDocument } from '../../database/schemas/user.schema';
import { WalletService } from '../wallet/wallet.service';
import { NotificationsService } from '../notifications/notifications.service';
export declare class CodesService {
    private codeModel;
    private userModel;
    private walletService;
    private notificationsService;
    constructor(codeModel: Model<ShippingCodeDocument>, userModel: Model<UserDocument>, walletService: WalletService, notificationsService: NotificationsService);
    private generateRandomCode;
    private generateBatchId;
    generateCodes(params: {
        amount: number;
        count: number;
        adminId: string;
        note?: string;
    }): Promise<{
        message: string;
        batchId: string;
        batchNote: string | undefined;
        codes: ShippingCodeDocument[];
    }>;
    getAllCodes(filter?: {
        isUsed?: boolean;
        isActive?: boolean;
    }): Promise<(import("mongoose").Document<unknown, {}, ShippingCodeDocument, {}, import("mongoose").DefaultSchemaOptions> & ShippingCode & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, ShippingCodeDocument, {}, import("mongoose").DefaultSchemaOptions> & ShippingCode & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    remove(id: string): Promise<{
        message: string;
    }>;
    redeemCode(codeString: string, userId: string): Promise<{
        message: string;
        amountAdded: number;
        newBalance: number;
    }>;
    verifyCode(codeString: string): Promise<{
        valid: boolean;
        message: string;
        amount?: undefined;
    } | {
        valid: boolean;
        amount: number;
        message: string;
    }>;
}
