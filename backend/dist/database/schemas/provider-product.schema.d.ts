import { Document, Types } from 'mongoose';
export type ProviderProductDocument = ProviderProduct & Document;
export declare class ProviderProduct {
    providerId: Types.ObjectId;
    providerProductCode: string;
    name: string;
    category?: string;
    costPrice: number;
    currency: string;
    inStock: boolean;
    rawDetails: Record<string, any>;
}
export declare const ProviderProductSchema: import("mongoose").Schema<ProviderProduct, import("mongoose").Model<ProviderProduct, any, any, any, any, any, ProviderProduct & {
    _id: Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, ProviderProduct, Document<unknown, {}, ProviderProduct, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<ProviderProduct & {
    _id: Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    providerId?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId, ProviderProduct, Document<unknown, {}, ProviderProduct, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ProviderProduct & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    providerProductCode?: import("mongoose").SchemaDefinitionProperty<string, ProviderProduct, Document<unknown, {}, ProviderProduct, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ProviderProduct & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    name?: import("mongoose").SchemaDefinitionProperty<string, ProviderProduct, Document<unknown, {}, ProviderProduct, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ProviderProduct & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    category?: import("mongoose").SchemaDefinitionProperty<string | undefined, ProviderProduct, Document<unknown, {}, ProviderProduct, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ProviderProduct & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    costPrice?: import("mongoose").SchemaDefinitionProperty<number, ProviderProduct, Document<unknown, {}, ProviderProduct, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ProviderProduct & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    currency?: import("mongoose").SchemaDefinitionProperty<string, ProviderProduct, Document<unknown, {}, ProviderProduct, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ProviderProduct & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    inStock?: import("mongoose").SchemaDefinitionProperty<boolean, ProviderProduct, Document<unknown, {}, ProviderProduct, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ProviderProduct & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    rawDetails?: import("mongoose").SchemaDefinitionProperty<Record<string, any>, ProviderProduct, Document<unknown, {}, ProviderProduct, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<ProviderProduct & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, ProviderProduct>;
