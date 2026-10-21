import { BannersService } from './banners.service';
export declare class BannersController {
    private readonly bannersService;
    constructor(bannersService: BannersService);
    getActive(): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/banner.schema").BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/banner.schema").Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getAllAdmin(): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/banner.schema").BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/banner.schema").Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getOne(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/banner.schema").BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/banner.schema").Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    create(createDto: any): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/banner.schema").BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/banner.schema").Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    update(id: string, updateDto: any): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/banner.schema").BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/banner.schema").Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/banner.schema").BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/banner.schema").Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    remove(id: string): Promise<{
        message: string;
    }>;
}
