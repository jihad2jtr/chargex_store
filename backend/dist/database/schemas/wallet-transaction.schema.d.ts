import { Document, Types } from 'mongoose';
export type WalletTransactionDocument = WalletTransaction & Document;
export declare enum TransactionType {
    TOPUP = "topup",
    PURCHASE = "purchase",
    REFUND = "refund",
    ADMIN_ADJUSTMENT = "admin_adjustment",
    AGENT_TRANSFER = "agent_transfer"
}
export declare enum TransactionStatus {
    COMPLETED = "completed",
    PENDING = "pending",
    FAILED = "failed"
}
export declare class WalletTransaction {
    userId: Types.ObjectId;
    type: TransactionType;
    amount: number;
    balanceBefore: number;
    balanceAfter: number;
    description: string;
    referenceType?: string;
    referenceId?: string;
    status: TransactionStatus;
}
export declare const WalletTransactionSchema: import("mongoose").Schema<WalletTransaction, import("mongoose").Model<WalletTransaction, any, any, any, any, any, WalletTransaction & {
    _id: Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, WalletTransaction, Document<unknown, {}, WalletTransaction, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<WalletTransaction & {
    _id: Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    userId?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId, WalletTransaction, Document<unknown, {}, WalletTransaction, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<WalletTransaction & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    type?: import("mongoose").SchemaDefinitionProperty<TransactionType, WalletTransaction, Document<unknown, {}, WalletTransaction, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<WalletTransaction & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    amount?: import("mongoose").SchemaDefinitionProperty<number, WalletTransaction, Document<unknown, {}, WalletTransaction, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<WalletTransaction & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    balanceBefore?: import("mongoose").SchemaDefinitionProperty<number, WalletTransaction, Document<unknown, {}, WalletTransaction, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<WalletTransaction & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    balanceAfter?: import("mongoose").SchemaDefinitionProperty<number, WalletTransaction, Document<unknown, {}, WalletTransaction, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<WalletTransaction & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    description?: import("mongoose").SchemaDefinitionProperty<string, WalletTransaction, Document<unknown, {}, WalletTransaction, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<WalletTransaction & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    referenceType?: import("mongoose").SchemaDefinitionProperty<string | undefined, WalletTransaction, Document<unknown, {}, WalletTransaction, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<WalletTransaction & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    referenceId?: import("mongoose").SchemaDefinitionProperty<string | undefined, WalletTransaction, Document<unknown, {}, WalletTransaction, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<WalletTransaction & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    status?: import("mongoose").SchemaDefinitionProperty<TransactionStatus, WalletTransaction, Document<unknown, {}, WalletTransaction, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<WalletTransaction & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, WalletTransaction>;
