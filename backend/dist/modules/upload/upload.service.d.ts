import { ConfigService } from '@nestjs/config';
export declare class UploadService {
    private configService;
    private readonly logger;
    constructor(configService: ConfigService);
    uploadImage(file: any): Promise<{
        url: string;
        secure_url: string;
    }>;
}
