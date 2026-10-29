import { Model, Types } from 'mongoose';
import { Provider, ProviderDocument, ProviderType } from '../../database/schemas/provider.schema';
import { ProviderProductDocument } from '../../database/schemas/provider-product.schema';
import { Product, ProductDocument } from '../../database/schemas/product.schema';
import { NotificationsService } from '../notifications/notifications.service';
export declare class ProvidersService {
    private providerModel;
    private providerProductModel;
    private productModel;
    private readonly notificationsService;
    private static readonly ORDER_TIMEOUT_MS;
    private static readonly STATUS_TIMEOUT_MS;
    private readonly logger;
    constructor(providerModel: Model<ProviderDocument>, providerProductModel: Model<ProviderProductDocument>, productModel: Model<ProductDocument>, notificationsService: NotificationsService);
    private isTimeoutError;
    private isBay2Game;
    private isFoxReload;
    private isVirtualNumbers;
    private virtualNumberClient;
    private getFoxReloadBaseUrl;
    private getFoxReloadHeaders;
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
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, ProviderDocument, {}, import("mongoose").DefaultSchemaOptions> & Provider & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    private computeSalePrice;
    recalculateProviderPrices(providerId: string): Promise<{
        message: string;
        updated: number;
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
    private static readonly STATUS_TTL_MS;
    private isInsufficientBalanceError;
    private disableForInsufficientBalance;
    ensureReadyForOrder(providerId: string, requiredCost?: number): Promise<ProviderDocument>;
    markProviderFailure(providerId: string, message: string, requiredCost?: number): Promise<void>;
    inspectOrderStatus(providerId: string, reference: string): Promise<{
        state: 'delivered' | 'failed' | 'pending' | 'unknown';
        codes?: string[];
        message?: string;
        raw?: any;
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
    importToProducts(providerProductId: string, appId: string, opts?: {
        name?: string;
        serviceTemplateId?: string;
        quantityLabel?: string;
    }): Promise<import("mongoose").Document<unknown, {}, ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & Product & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    batchImportToProducts(providerProductIds: string[], appId: string, opts?: {
        name?: string;
        serviceTemplateId?: string;
        quantityLabel?: string;
    }): Promise<{
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
        isTimeout?: boolean;
    }>;
    checkOrderStatus(providerId: string, reference: string): Promise<any>;
}
