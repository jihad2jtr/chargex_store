import { UploadService } from './upload.service';
export declare class UploadController {
    private readonly uploadService;
    constructor(uploadService: UploadService);
    uploadImage(file: any, body: {
        base64?: string;
        imageUrl?: string;
    }, req: any): Promise<{
        url: string;
        secure_url: string;
    }>;
}
