import { Document, Types } from 'mongoose';
export type ShippingCodeDocument = ShippingCode & Document;
export declare class ShippingCode {
    code: string;
    amount: number;
    isUsed: boolean;
    usedBy?: Types.ObjectId;
    usedAt?: Date;
    isActive: boolean;
    createdBy?: Types.ObjectId;
}
export declare const ShippingCodeSchema: import("mongoose").Schema<ShippingCode, import("mongoose").Model<ShippingCode, any, any, any, any, any, ShippingCode & {
    _id: Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, ShippingCode, Document<unknown, {}, ShippingCode, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<ShippingCode & {
    _id: Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    code?: import("mongoose").SchemaDefinitionProperty<string, ShippingCode, Document<unknown, {}, ShippingCode, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShippingCode & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    amount?: import("mongoose").SchemaDefinitionProperty<number, ShippingCode, Document<unknown, {}, ShippingCode, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShippingCode & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    isUsed?: import("mongoose").SchemaDefinitionProperty<boolean, ShippingCode, Document<unknown, {}, ShippingCode, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShippingCode & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    usedBy?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId | undefined, ShippingCode, Document<unknown, {}, ShippingCode, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShippingCode & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    usedAt?: import("mongoose").SchemaDefinitionProperty<Date | undefined, ShippingCode, Document<unknown, {}, ShippingCode, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShippingCode & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    isActive?: import("mongoose").SchemaDefinitionProperty<boolean, ShippingCode, Document<unknown, {}, ShippingCode, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShippingCode & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    createdBy?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId | undefined, ShippingCode, Document<unknown, {}, ShippingCode, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ShippingCode & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, ShippingCode>;
