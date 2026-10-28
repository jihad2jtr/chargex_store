import { ProductsService } from './products.service';
import { UserDocument } from '../../database/schemas/user.schema';
export declare class ProductsController {
    private readonly productsService;
    constructor(productsService: ProductsService);
    getByApp(appId: string): Promise<{
        availableCodesCount: number;
        inventoryCodes: undefined;
        providerAvailable: boolean;
        appId: import("mongoose").Types.ObjectId;
        name: string;
        serviceTemplateId?: import("mongoose").Types.ObjectId;
        quantityLabel: string;
        kind: string;
        description?: string;
        type: import("../../database/schemas/product.schema").ProductType;
        providerId?: import("mongoose").Types.ObjectId;
        providerProductCode?: string;
        costPrice: number;
        profitMarginType: import("../../database/schemas/product.schema").ProfitMarginType;
        profitMarginValue: number;
        salePrice: number;
        previousPrice?: number;
        hasPriceChanged: boolean;
        isActive: boolean;
        requiredFields: string[];
        assignedSupervisorId?: import("mongoose").Types.ObjectId;
        estimatedMinutes?: number;
        isSensitive?: boolean;
        sensitiveFields?: string[];
        instructions?: string;
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
    getAllAdmin(appId?: string): Promise<{
        availableCodesCount: number;
        appId: import("mongoose").Types.ObjectId;
        name: string;
        serviceTemplateId?: import("mongoose").Types.ObjectId;
        quantityLabel: string;
        kind: string;
        description?: string;
        type: import("../../database/schemas/product.schema").ProductType;
        providerId?: import("mongoose").Types.ObjectId;
        providerProductCode?: string;
        costPrice: number;
        profitMarginType: import("../../database/schemas/product.schema").ProfitMarginType;
        profitMarginValue: number;
        salePrice: number;
        previousPrice?: number;
        hasPriceChanged: boolean;
        isActive: boolean;
        inventoryCodes: string[];
        requiredFields: string[];
        assignedSupervisorId?: import("mongoose").Types.ObjectId;
        estimatedMinutes?: number;
        isSensitive?: boolean;
        sensitiveFields?: string[];
        instructions?: string;
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
    syncProviderPrices(): Promise<{
        message: string;
        updatedCount: number;
        totalChecked: number;
    }>;
    getMyAssigned(user: UserDocument): Promise<{
        availableCodesCount: number;
        inventoryCodes: undefined;
        appId: import("mongoose").Types.ObjectId;
        name: string;
        serviceTemplateId?: import("mongoose").Types.ObjectId;
        quantityLabel: string;
        kind: string;
        description?: string;
        type: import("../../database/schemas/product.schema").ProductType;
        providerId?: import("mongoose").Types.ObjectId;
        providerProductCode?: string;
        costPrice: number;
        profitMarginType: import("../../database/schemas/product.schema").ProfitMarginType;
        profitMarginValue: number;
        salePrice: number;
        previousPrice?: number;
        hasPriceChanged: boolean;
        isActive: boolean;
        requiredFields: string[];
        assignedSupervisorId?: import("mongoose").Types.ObjectId;
        estimatedMinutes?: number;
        isSensitive?: boolean;
        sensitiveFields?: string[];
        instructions?: string;
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
    toggleMyService(id: string, user: UserDocument): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/product.schema").ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/product.schema").Product & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    getOne(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/product.schema").ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/product.schema").Product & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    create(createDto: any): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/product.schema").ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/product.schema").Product & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    update(id: string, updateDto: any): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/product.schema").ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/product.schema").Product & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }) | null>;
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/product.schema").ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/product.schema").Product & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    addCodesToInventory(id: string, body: {
        codes: string[];
    }): Promise<{
        message: string;
        availableCodesCount: number;
    }>;
    remove(id: string): Promise<{
        message: string;
    }>;
}
