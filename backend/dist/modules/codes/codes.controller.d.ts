import { CodesService } from './codes.service';
import { UserDocument } from '../../database/schemas/user.schema';
export declare class CodesController {
    private readonly codesService;
    constructor(codesService: CodesService);
    verifyCode(body: {
        code: string;
    }): Promise<{
        valid: boolean;
        message: string;
        amount?: undefined;
    } | {
        valid: boolean;
        amount: number;
        message: string;
    }>;
    redeemCode(user: UserDocument, body: {
        code: string;
    }): Promise<{
        message: string;
        amountAdded: number;
        newBalance: number;
    }>;
    generateCodes(admin: UserDocument, body: {
        amount: number;
        count?: number;
    }): Promise<{
        message: string;
        codes: import("../../database/schemas/shipping-code.schema").ShippingCodeDocument[];
    }>;
    getAllCodes(query: {
        isUsed?: string;
        isActive?: string;
    }): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/shipping-code.schema").ShippingCodeDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/shipping-code.schema").ShippingCode & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/shipping-code.schema").ShippingCodeDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/shipping-code.schema").ShippingCode & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    remove(id: string): Promise<{
        message: string;
    }>;
}
