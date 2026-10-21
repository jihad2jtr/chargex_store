import { Document } from 'mongoose';
export type TopupMethodDocument = TopupMethod & Document;
export declare enum TopupType {
    ID_RECHARGE = "id_recharge",
    SHAM_CASH = "sham_cash",
    BINANCE = "binance",
    SHIPPING_CODE = "shipping_code"
}
export declare class TopupMethod {
    type: TopupType;
    title: string;
    description?: string;
    isActive: boolean;
    instructions?: string;
}
export declare const TopupMethodSchema: import("mongoose").Schema<TopupMethod, import("mongoose").Model<TopupMethod, any, any, any, any, any, TopupMethod & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, TopupMethod, Document<unknown, {}, TopupMethod, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<TopupMethod & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    type?: import("mongoose").SchemaDefinitionProperty<TopupType, TopupMethod, Document<unknown, {}, TopupMethod, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<TopupMethod & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    title?: import("mongoose").SchemaDefinitionProperty<string, TopupMethod, Document<unknown, {}, TopupMethod, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<TopupMethod & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    description?: import("mongoose").SchemaDefinitionProperty<string | undefined, TopupMethod, Document<unknown, {}, TopupMethod, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<TopupMethod & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    isActive?: import("mongoose").SchemaDefinitionProperty<boolean, TopupMethod, Document<unknown, {}, TopupMethod, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<TopupMethod & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    instructions?: import("mongoose").SchemaDefinitionProperty<string | undefined, TopupMethod, Document<unknown, {}, TopupMethod, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<TopupMethod & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, TopupMethod>;
