import { AppsService } from './apps.service';
export declare class AppsController {
    private readonly appsService;
    constructor(appsService: AppsService);
    getActiveApps(): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/app.schema").AppDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/app.schema").App & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getAllAppsAdmin(): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/app.schema").AppDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/app.schema").App & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getOne(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/app.schema").AppDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/app.schema").App & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    create(createDto: any): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/app.schema").AppDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/app.schema").App & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    update(id: string, updateDto: any): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/app.schema").AppDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/app.schema").App & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/app.schema").AppDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/app.schema").App & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    updateSortOrder(body: {
        items: {
            id: string;
            sortOrder: number;
        }[];
    }): Promise<{
        message: string;
    }>;
    remove(id: string): Promise<{
        message: string;
    }>;
}
