import { Document } from 'mongoose';
export type AppDocument = App & Document;
export declare enum AppType {
    GAME = "game",
    APP = "app",
    SERVICE = "service",
    SUBSCRIPTION = "subscription"
}
export declare class App {
    name: string;
    nameAr?: string;
    nameEn?: string;
    appType?: AppType;
    iconUrl: string;
    isActive: boolean;
    sortOrder: number;
    category?: string;
    description?: string;
}
export declare const AppSchema: import("mongoose").Schema<App, import("mongoose").Model<App, any, any, any, any, any, App & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, App, Document<unknown, {}, App, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<App & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    name?: import("mongoose").SchemaDefinitionProperty<string, App, Document<unknown, {}, App, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<App & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    nameAr?: import("mongoose").SchemaDefinitionProperty<string | undefined, App, Document<unknown, {}, App, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<App & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    nameEn?: import("mongoose").SchemaDefinitionProperty<string | undefined, App, Document<unknown, {}, App, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<App & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    appType?: import("mongoose").SchemaDefinitionProperty<AppType | undefined, App, Document<unknown, {}, App, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<App & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    iconUrl?: import("mongoose").SchemaDefinitionProperty<string, App, Document<unknown, {}, App, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<App & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    isActive?: import("mongoose").SchemaDefinitionProperty<boolean, App, Document<unknown, {}, App, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<App & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    sortOrder?: import("mongoose").SchemaDefinitionProperty<number, App, Document<unknown, {}, App, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<App & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    category?: import("mongoose").SchemaDefinitionProperty<string | undefined, App, Document<unknown, {}, App, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<App & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    description?: import("mongoose").SchemaDefinitionProperty<string | undefined, App, Document<unknown, {}, App, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<App & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, App>;
