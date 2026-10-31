import { Model, Types } from 'mongoose';
import { Product, ProductDocument, ProfitMarginType, ProductType } from '../../database/schemas/product.schema';
import { ProviderProductDocument } from '../../database/schemas/provider-product.schema';
import { ServiceTemplateDocument } from '../../database/schemas/service-template.schema';
import { UsersService } from '../users/users.service';
export declare class ProductsService {
    private productModel;
    private providerProductModel;
    private serviceTemplateModel;
    private readonly usersService;
    private readonly logger;
    constructor(productModel: Model<ProductDocument>, providerProductModel: Model<ProviderProductDocument>, serviceTemplateModel: Model<ServiceTemplateDocument>, usersService: UsersService);
    private deriveFieldsFromTemplate;
    calculateSalePrice(costPrice: number, marginType: ProfitMarginType, marginValue: number): number;
    findByAppUser(appId: string): Promise<{
        availableCodesCount: number;
        inventoryCodes: undefined;
        providerAvailable: boolean;
        appId?: Types.ObjectId;
        virtualNumberAppId?: Types.ObjectId;
        name: string;
        serviceTemplateId?: Types.ObjectId;
        quantityLabel: string;
        kind: string;
        description?: string;
        type: ProductType;
        providerId?: Types.ObjectId;
        providerProductCode?: string;
        costPrice: number;
        profitMarginType: ProfitMarginType;
        profitMarginValue: number;
        salePrice: number;
        previousPrice?: number;
        hasPriceChanged: boolean;
        isActive: boolean;
        requiredFields: string[];
        assignedSupervisorId?: Types.ObjectId;
        estimatedMinutes?: number;
        isSensitive?: boolean;
        sensitiveFields?: string[];
        instructions?: string;
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
    findAllAdmin(appId?: string): Promise<{
        availableCodesCount: number;
        appId?: Types.ObjectId;
        virtualNumberAppId?: Types.ObjectId;
        name: string;
        serviceTemplateId?: Types.ObjectId;
        quantityLabel: string;
        kind: string;
        description?: string;
        type: ProductType;
        providerId?: Types.ObjectId;
        providerProductCode?: string;
        costPrice: number;
        profitMarginType: ProfitMarginType;
        profitMarginValue: number;
        salePrice: number;
        previousPrice?: number;
        hasPriceChanged: boolean;
        isActive: boolean;
        inventoryCodes: string[];
        requiredFields: string[];
        assignedSupervisorId?: Types.ObjectId;
        estimatedMinutes?: number;
        isSensitive?: boolean;
        sensitiveFields?: string[];
        instructions?: string;
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
    findOne(id: string): Promise<import("mongoose").Document<unknown, {}, ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & Product & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    create(createDto: {
        appId: string;
        name: string;
        description?: string;
        type?: ProductType;
        providerId?: string;
        providerProductCode?: string;
        costPrice: number;
        profitMarginType?: ProfitMarginType;
        profitMarginValue?: number;
        isActive?: boolean;
        inventoryCodes?: string[];
        requiredFields?: string[];
        serviceTemplateId?: string;
        quantityLabel?: string;
        kind?: string;
        assignedSupervisorId?: string;
        estimatedMinutes?: number;
        isSensitive?: boolean;
        sensitiveFields?: string[];
        instructions?: string;
    }): Promise<import("mongoose").Document<unknown, {}, ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & Product & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    private deriveFieldsFromTemplateById;
    update(id: string, updateDto: any): Promise<(import("mongoose").Document<unknown, {}, ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & Product & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }) | null>;
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & Product & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    findAssignedToSupervisor(supervisorId: string): Promise<{
        availableCodesCount: number;
        inventoryCodes: undefined;
        appId?: Types.ObjectId;
        virtualNumberAppId?: Types.ObjectId;
        name: string;
        serviceTemplateId?: Types.ObjectId;
        quantityLabel: string;
        kind: string;
        description?: string;
        type: ProductType;
        providerId?: Types.ObjectId;
        providerProductCode?: string;
        costPrice: number;
        profitMarginType: ProfitMarginType;
        profitMarginValue: number;
        salePrice: number;
        previousPrice?: number;
        hasPriceChanged: boolean;
        isActive: boolean;
        requiredFields: string[];
        assignedSupervisorId?: Types.ObjectId;
        estimatedMinutes?: number;
        isSensitive?: boolean;
        sensitiveFields?: string[];
        instructions?: string;
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
    toggleActiveForSupervisor(id: string, supervisorId: string): Promise<import("mongoose").Document<unknown, {}, ProductDocument, {}, import("mongoose").DefaultSchemaOptions> & Product & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    remove(id: string): Promise<{
        message: string;
    }>;
    addCodesToInventory(id: string, codes: string[]): Promise<{
        message: string;
        availableCodesCount: number;
    }>;
    updatePricesFromProviders(): Promise<{
        message: string;
        updatedCount: number;
        totalChecked: number;
    }>;
}
