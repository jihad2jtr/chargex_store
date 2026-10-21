import { Document } from 'mongoose';
export type ShamCashAccountDocument = ShamCashAccount & Document;
export declare enum PaymentAccountType {
    SHAM_CASH = "sham_cash",
    BINANCE = "binance"
}
export declare class ShamCashAccount {
    type: PaymentAccountType;
    accountName: string;
    accountId: string;
    barcodeUrl: string;
    isActive: boolean;
}
export declare const ShamCashAccountSchema: import("mongoose").Schema<ShamCashAccount, import("mongoose").Model<ShamCashAccount, any, any, any, any, any, ShamCashAccount & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, ShamCashAccount, Document<unknown, {}, ShamCashAccount, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<ShamCashAccount & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    type?: import("mongoose").SchemaDefinitionProperty<PaymentAccountType, ShamCashAccount, Document<unknown, {}, ShamCashAccount, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShamCashAccount & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    accountName?: import("mongoose").SchemaDefinitionProperty<string, ShamCashAccount, Document<unknown, {}, ShamCashAccount, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShamCashAccount & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    accountId?: import("mongoose").SchemaDefinitionProperty<string, ShamCashAccount, Document<unknown, {}, ShamCashAccount, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShamCashAccount & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    barcodeUrl?: import("mongoose").SchemaDefinitionProperty<string, ShamCashAccount, Document<unknown, {}, ShamCashAccount, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShamCashAccount & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    isActive?: import("mongoose").SchemaDefinitionProperty<boolean, ShamCashAccount, Document<unknown, {}, ShamCashAccount, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShamCashAccount & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, ShamCashAccount>;
