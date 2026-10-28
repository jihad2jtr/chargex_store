import { ProvidersService } from './providers.service';
export declare class ProvidersController {
    private readonly providersService;
    constructor(providersService: ProvidersService);
    findAll(): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/provider.schema").ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/provider.schema").Provider & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    create(createDto: any): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/provider.schema").ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/provider.schema").Provider & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    findOne(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/provider.schema").ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/provider.schema").Provider & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    update(id: string, updateDto: any): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/provider.schema").ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/provider.schema").Provider & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    remove(id: string): Promise<{
        message: string;
    }>;
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/provider.schema").ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/provider.schema").Provider & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    checkStatus(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/provider.schema").ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/provider.schema").Provider & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    getProviderProducts(id: string): Promise<{
        isImported: boolean;
        providerId: import("mongoose").Types.ObjectId;
        providerProductCode: string;
        name: string;
        category?: string;
        costPrice: number;
        currency: string;
        inStock: boolean;
        rawDetails: Record<string, any>;
        _id: import("mongoose").Types.ObjectId;
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
    getProviderCategories(id: string): Promise<any>;
    syncProviderProducts(id: string, body: {
        gameCodes?: string[];
    }): Promise<{
        message: string;
        syncedCount: number;
    }>;
    checkOrderStatus(id: string, reference: string): Promise<any>;
    importProduct(providerId: string, body: {
        providerProductId: string;
        appId: string;
        name?: string;
        serviceTemplateId?: string;
        quantityLabel?: string;
    }): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/product.schema").ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/product.schema").Product & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    batchImport(providerId: string, body: {
        providerProductIds: string[];
        appId: string;
        name?: string;
        serviceTemplateId?: string;
        quantityLabel?: string;
    }): Promise<{
        message: string;
        importedCount: number;
        products: (import("mongoose").Document<unknown, {}, import("../../database/schemas/product.schema").ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/product.schema").Product & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        })[];
    }>;
    recalculatePrices(id: string): Promise<{
        message: string;
        updated: number;
    }>;
}
