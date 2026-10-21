import { OnModuleInit } from '@nestjs/common';
export interface FcmPayload {
    title: string;
    body: string;
    data?: Record<string, string>;
    imageUrl?: string;
}
export interface FcmSendResult {
    successCount: number;
    failureCount: number;
    invalidTokens: string[];
}
export declare class FcmService implements OnModuleInit {
    private readonly logger;
    private firebaseApp;
    private isConfigured;
    onModuleInit(): void;
    private initFirebase;
    get hasActiveCredentials(): boolean;
    sendToTokens(tokens: string[], payload: FcmPayload): Promise<FcmSendResult>;
    sendToTopic(topic: string, payload: FcmPayload): Promise<boolean>;
}
