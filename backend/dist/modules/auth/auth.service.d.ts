import { OnModuleInit } from '@nestjs/common';
import { Model } from 'mongoose';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
export declare class AuthService implements OnModuleInit {
    private userModel;
    private jwtService;
    private configService;
    private readonly logger;
    constructor(userModel: Model<UserDocument>, jwtService: JwtService, configService: ConfigService);
    onModuleInit(): Promise<void>;
    generateUniqueUserId(): Promise<string>;
    ensureUserIds(): Promise<void>;
    seedAdmin(): Promise<void>;
    seedSupervisor(): Promise<void>;
    seedClientUser(): Promise<void>;
    seedAgentUser(): Promise<void>;
    register(registerDto: RegisterDto): Promise<{
        accessToken: string;
        refreshToken: string;
        message: string;
        user: any;
    }>;
    login(loginDto: LoginDto): Promise<{
        accessToken: string;
        refreshToken: string;
        message: string;
        user: any;
    }>;
    refreshToken(dto: RefreshTokenDto): Promise<{
        accessToken: string;
        refreshToken: string;
    }>;
    logout(userId: string): Promise<{
        message: string;
    }>;
    getMe(userId: string): Promise<import("mongoose").Document<unknown, {}, UserDocument, {}, import("mongoose").DefaultSchemaOptions> & User & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    private generateTokens;
}
