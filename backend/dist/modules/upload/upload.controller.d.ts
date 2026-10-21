import { UploadService } from './upload.service';
export declare class UploadController {
    private readonly uploadService;
    constructor(uploadService: UploadService);
    uploadImage(body: {
        base64?: string;
        imageUrl?: string;
    }): Promise<{
        url: string;
        secure_url: string;
    }>;
}
