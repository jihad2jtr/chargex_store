import { Model, Types } from 'mongoose';
import { App, AppDocument } from '../../database/schemas/app.schema';
import { ProductDocument } from '../../database/schemas/product.schema';
import { ProviderDocument } from '../../database/schemas/provider.schema';
export declare class AppsService {
    private appModel;
    private productModel;
    private providerModel;
    constructor(appModel: Model<AppDocument>, productModel: Model<ProductDocument>, providerModel: Model<ProviderDocument>);
    findActive(): Promise<(import("mongoose").Document<unknown, {}, AppDocument, {}, import("mongoose").DefaultSchemaOptions> & App & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    private hasActiveProducts;
    findAllAdmin(): Promise<(import("mongoose").Document<unknown, {}, AppDocument, {}, import("mongoose").DefaultSchemaOptions> & App & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    findOne(id: string): Promise<import("mongoose").Document<unknown, {}, AppDocument, {}, import("mongoose").DefaultSchemaOptions> & App & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    private assertUniqueName;
    create(createDto: {
        name: string;
        iconUrl: string;
        sortOrder?: number;
        category?: string;
        description?: string;
        isActive?: boolean;
    }): Promise<import("mongoose").Document<unknown, {}, AppDocument, {}, import("mongoose").DefaultSchemaOptions> & App & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    update(id: string, updateDto: any): Promise<import("mongoose").Document<unknown, {}, AppDocument, {}, import("mongoose").DefaultSchemaOptions> & App & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, AppDocument, {}, import("mongoose").DefaultSchemaOptions> & App & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    updateSortOrder(items: {
        id: string;
        sortOrder: number;
    }[]): Promise<{
        message: string;
    }>;
    remove(id: string): Promise<{
        message: string;
    }>;
}
