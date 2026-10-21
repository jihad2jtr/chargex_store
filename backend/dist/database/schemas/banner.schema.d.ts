import { Document } from 'mongoose';
export type BannerDocument = Banner & Document;
export declare class Banner {
    title: string;
    description: string;
    imageUrl: string;
    actionType: string;
    actionValue?: string;
    isActive: boolean;
    sortOrder: number;
}
export declare const BannerSchema: import("mongoose").Schema<Banner, import("mongoose").Model<Banner, any, any, any, any, any, Banner & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, Banner, Document<unknown, {}, Banner, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<Banner & {
    _id: import("mongoose").Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    title?: import("mongoose").SchemaDefinitionProperty<string, Banner, Document<unknown, {}, Banner, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Banner & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    description?: import("mongoose").SchemaDefinitionProperty<string, Banner, Document<unknown, {}, Banner, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Banner & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    imageUrl?: import("mongoose").SchemaDefinitionProperty<string, Banner, Document<unknown, {}, Banner, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Banner & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    actionType?: import("mongoose").SchemaDefinitionProperty<string, Banner, Document<unknown, {}, Banner, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Banner & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    actionValue?: import("mongoose").SchemaDefinitionProperty<string | undefined, Banner, Document<unknown, {}, Banner, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Banner & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    isActive?: import("mongoose").SchemaDefinitionProperty<boolean, Banner, Document<unknown, {}, Banner, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Banner & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    sortOrder?: import("mongoose").SchemaDefinitionProperty<number, Banner, Document<unknown, {}, Banner, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Banner & {
        _id: import("mongoose").Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, Banner>;
