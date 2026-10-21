import { UsersService } from './users.service';
import { Role } from '../../common/interfaces/role.enum';
export declare class UsersController {
    private readonly usersService;
    constructor(usersService: UsersService);
    findAll(): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/user.schema").UserDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/user.schema").User & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    search(query: string): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/user.schema").UserDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/user.schema").User & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    findSupervisors(): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/user.schema").UserDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/user.schema").User & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    createSupervisor(body: {
        name: string;
        email: string;
        password: string;
        phone?: string;
    }): Promise<{
        message: string;
        supervisor: {
            _id: import("mongoose").Types.ObjectId;
            userId: string | undefined;
            name: string;
            email: string;
            phone: string | undefined;
            role: Role;
        };
    }>;
    updateRole(id: string, role: string): Promise<{
        message: string;
        user: {
            _id: import("mongoose").Types.ObjectId;
            name: string;
            email: string;
            role: Role;
        };
    }>;
    findOne(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/user.schema").UserDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/user.schema").User & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/user.schema").UserDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/user.schema").User & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
}
