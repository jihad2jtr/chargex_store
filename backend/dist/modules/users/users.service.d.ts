import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Role } from '../../common/interfaces/role.enum';
import { ProductDocument } from '../../database/schemas/product.schema';
import { OrderDocument } from '../../database/schemas/order.schema';
export declare class UsersService {
    private userModel;
    private productModel;
    private orderModel;
    private readonly logger;
    constructor(userModel: Model<UserDocument>, productModel: Model<ProductDocument>, orderModel: Model<OrderDocument>);
    findAll(): Promise<(import("mongoose").Document<unknown, {}, UserDocument, {}, import("mongoose").DefaultSchemaOptions> & User & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    findOne(id: string): Promise<import("mongoose").Document<unknown, {}, UserDocument, {}, import("mongoose").DefaultSchemaOptions> & User & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    search(query: string): Promise<(import("mongoose").Document<unknown, {}, UserDocument, {}, import("mongoose").DefaultSchemaOptions> & User & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, UserDocument, {}, import("mongoose").DefaultSchemaOptions> & User & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    reconcileSupervisorRole(userId: string | Types.ObjectId): Promise<(import("mongoose").Document<unknown, {}, UserDocument, {}, import("mongoose").DefaultSchemaOptions> & User & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }) | null>;
    updateRole(id: string, role: string): Promise<{
        message: string;
        user: {
            _id: Types.ObjectId;
            name: string;
            email: string;
            role: Role;
        };
    }>;
    updateDetails(id: string, dto: {
        name?: string;
        email?: string;
        phone?: string;
    }): Promise<{
        message: string;
        user: {
            _id: Types.ObjectId;
            userId: string | undefined;
            name: string;
            email: string;
            phone: string | undefined;
            role: Role;
            balance: number;
            isActive: boolean;
        };
    }>;
}
