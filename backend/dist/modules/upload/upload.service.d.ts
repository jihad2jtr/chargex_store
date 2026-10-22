import { ConfigService } from '@nestjs/config';
export declare class UploadService {
    private configService;
    private readonly logger;
    private readonly uploadDir;
    constructor(configService: ConfigService);
    private publicBaseUrl;
    private extFrom;
    private saveToDisk;
    uploadImage(file: any, base64?: string, imageUrl?: string, req?: any): Promise<{
        url: string;
        secure_url: string;
    }>;
}
