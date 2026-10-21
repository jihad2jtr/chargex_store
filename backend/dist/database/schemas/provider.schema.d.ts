import { Document } from 'mongoose';
export type ProviderDocument = Provider & Document;
export declare enum ProviderStatus {
    ONLINE = "online",
    OFFLINE = "offline",
    ERROR = "error"
}
export declare enum ProviderType {
    BAY2GAME = "bay2game",
    CUSTOM = "custom"
}
export declare class Provider {
    name: string;
    baseUrl: string;
    apiKey: string;
    apiSecret?: string;
    providerType?: ProviderType;
    headers: Record<string, string>;
    status: ProviderStatus;
    lastError?: string;
    lastCheckAt?: Date;
    balance?: number;
    currency?: string;
    isActive: boolean;
}
export declare const ProviderSchema: import("mongoose").Schema<Provider, import("mongoose").Model<Provider, any, any, any, any, any, Provider & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, Provider, Document<unknown, {}, Provider, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    name?: import("mongoose").SchemaDefinitionProperty<string, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    baseUrl?: import("mongoose").SchemaDefinitionProperty<string, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    apiKey?: import("mongoose").SchemaDefinitionProperty<string, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    apiSecret?: import("mongoose").SchemaDefinitionProperty<string | undefined, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    providerType?: import("mongoose").SchemaDefinitionProperty<ProviderType | undefined, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    headers?: import("mongoose").SchemaDefinitionProperty<Record<string, string>, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    status?: import("mongoose").SchemaDefinitionProperty<ProviderStatus, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    lastError?: import("mongoose").SchemaDefinitionProperty<string | undefined, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    lastCheckAt?: import("mongoose").SchemaDefinitionProperty<Date | undefined, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    balance?: import("mongoose").SchemaDefinitionProperty<number | undefined, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    currency?: import("mongoose").SchemaDefinitionProperty<string | undefined, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    isActive?: import("mongoose").SchemaDefinitionProperty<boolean, Provider, Document<unknown, {}, Provider, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Provider & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, Provider>;
