import { Model, Types } from 'mongoose';
import { Provider, ProviderDocument, ProviderType } from '../../database/schemas/provider.schema';
import { ProviderProductDocument } from '../../database/schemas/provider-product.schema';
import { Product, ProductDocument, ProfitMarginType } from '../../database/schemas/product.schema';
export declare class ProvidersService {
    private providerModel;
    private providerProductModel;
    private productModel;
    private readonly logger;
    constructor(providerModel: Model<ProviderDocument>, providerProductModel: Model<ProviderProductDocument>, productModel: Model<ProductDocument>);
    private isBay2Game;
    findAll(): Promise<(import("mongoose").Document<unknown, {}, ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & Provider & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    findOne(id: string): Promise<import("mongoose").Document<unknown, {}, ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & Provider & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    create(createDto: {
        name: string;
        baseUrl: string;
        apiKey: string;
        apiSecret?: string;
        headers?: Record<string, string>;
        providerType?: ProviderType;
    }): Promise<import("mongoose").Document<unknown, {}, ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & Provider & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    update(id: string, updateDto: any): Promise<import("mongoose").Document<unknown, {}, ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & Provider & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    remove(id: string): Promise<{
        message: string;
    }>;
    checkStatus(id: string): Promise<import("mongoose").Document<unknown, {}, ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & Provider & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    getProviderCategories(providerId: string): Promise<any>;
    syncProviderProducts(providerId: string, gameCodes?: string[]): Promise<{
        message: string;
        syncedCount: number;
    }>;
    getProviderProducts(providerId: string, category?: string): Promise<{
        isImported: boolean;
        providerId: Types.ObjectId;
        providerProductCode: string;
        name: string;
        category?: string;
        costPrice: number;
        currency: string;
        inStock: boolean;
        rawDetails: Record<string, any>;
        _id: Types.ObjectId;
        $locals: Record<string, unknown>;
        $op: "save" | "validate" | "remove" | null;
        $where: Record<string, unknown>;
        baseModelName?: string;
        collection: import("mongoose").Collection;
        db: import("mongoose").Connection;
        errors?: import("mongoose").Error.ValidationError;
        isNew: boolean;
        schema: import("mongoose").Schema;
        __v: number;
    }[]>;
    seedMockProviderProducts(providerId: string): Promise<void>;
    importToProducts(providerProductId: string, appId: string, marginType?: ProfitMarginType, marginValue?: number): Promise<import("mongoose").Document<unknown, {}, ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & Product & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    batchImportToProducts(providerProductIds: string[], appId: string, marginType: ProfitMarginType, marginValue: number): Promise<{
        message: string;
        importedCount: number;
        products: (import("mongoose").Document<unknown, {}, ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & Product & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        })[];
    }>;
    executeOrder(providerId: string, params: {
        productCode: string;
        gameUserId: string;
        gameZoneId?: string;
        reference: string;
    }): Promise<{
        success: boolean;
        transactionId?: string;
        balanceAfter?: number;
        message: string;
        raw?: any;
    }>;
    checkOrderStatus(providerId: string, reference: string): Promise<any>;
}
