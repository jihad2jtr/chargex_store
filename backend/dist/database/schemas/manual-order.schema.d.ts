import { Document, Types } from 'mongoose';
export type ManualOrderDocument = ManualOrder & Document;
export declare enum ManualOrderStatus {
    PENDING = "pending",
    APPROVED = "approved",
    REJECTED = "rejected"
}
export declare class ManualOrder {
    userId: Types.ObjectId;
    orderId?: Types.ObjectId;
    type: string;
    amount: number;
    details: Record<string, any>;
    receiptImageUrl?: string;
    status: ManualOrderStatus;
    adminNotes?: string;
    processedBy?: Types.ObjectId;
    processedAt?: Date;
}
export declare const ManualOrderSchema: import("mongoose").Schema<ManualOrder, import("mongoose").Model<ManualOrder, any, any, any, any, any, ManualOrder & {
    _id: Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, ManualOrder, Document<unknown, {}, ManualOrder, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<ManualOrder & {
    _id: Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    userId?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId, ManualOrder, Document<unknown, {}, ManualOrder, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ManualOrder & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    orderId?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId | undefined, ManualOrder, Document<unknown, {}, ManualOrder, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ManualOrder & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    type?: import("mongoose").SchemaDefinitionProperty<string, ManualOrder, Document<unknown, {}, ManualOrder, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ManualOrder & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    amount?: import("mongoose").SchemaDefinitionProperty<number, ManualOrder, Document<unknown, {}, ManualOrder, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ManualOrder & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    details?: import("mongoose").SchemaDefinitionProperty<Record<string, any>, ManualOrder, Document<unknown, {}, ManualOrder, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ManualOrder & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    receiptImageUrl?: import("mongoose").SchemaDefinitionProperty<string | undefined, ManualOrder, Document<unknown, {}, ManualOrder, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ManualOrder & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    status?: import("mongoose").SchemaDefinitionProperty<ManualOrderStatus, ManualOrder, Document<unknown, {}, ManualOrder, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ManualOrder & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    adminNotes?: import("mongoose").SchemaDefinitionProperty<string | undefined, ManualOrder, Document<unknown, {}, ManualOrder, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ManualOrder & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    processedBy?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId | undefined, ManualOrder, Document<unknown, {}, ManualOrder, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ManualOrder & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    processedAt?: import("mongoose").SchemaDefinitionProperty<Date | undefined, ManualOrder, Document<unknown, {}, ManualOrder, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ManualOrder & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, ManualOrder>;
