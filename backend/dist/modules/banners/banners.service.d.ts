import { Model } from 'mongoose';
import { Banner, BannerDocument } from '../../database/schemas/banner.schema';
export declare class BannersService {
    private bannerModel;
    constructor(bannerModel: Model<BannerDocument>);
    findActive(): Promise<(import("mongoose").Document<unknown, {}, BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    findAllAdmin(): Promise<(import("mongoose").Document<unknown, {}, BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    findOne(id: string): Promise<import("mongoose").Document<unknown, {}, BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    create(data: {
        title: string;
        description?: string;
        imageUrl: string;
        actionType?: string;
        actionValue?: string;
        isActive?: boolean;
        sortOrder?: number;
    }): Promise<import("mongoose").Document<unknown, {}, BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    update(id: string, data: any): Promise<import("mongoose").Document<unknown, {}, BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    toggleActive(id: string): Promise<import("mongoose").Document<unknown, {}, BannerDocument, {}, import("mongoose").DefaultSchemaOptions> & Banner & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
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
