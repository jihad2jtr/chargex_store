"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var UploadService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.UploadService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const fs_1 = require("fs");
const path_1 = require("path");
let UploadService = UploadService_1 = class UploadService {
    constructor(configService) {
        this.configService = configService;
        this.logger = new common_1.Logger(UploadService_1.name);
        this.uploadDir = (0, path_1.join)(process.cwd(), 'uploads');
        if (!(0, fs_1.existsSync)(this.uploadDir)) {
            (0, fs_1.mkdirSync)(this.uploadDir, { recursive: true });
        }
    }
    publicBaseUrl(req) {
        const configured = this.configService.get('PUBLIC_BASE_URL');
        if (configured && configured.trim().length > 0) {
            return configured.trim().replace(/\/+$/, '');
        }
        if (req) {
            return `${req.protocol}://${req.get('host')}`;
        }
        return '';
    }
    extFrom(mimetype, originalName) {
        const fromName = originalName ? (0, path_1.extname)(originalName).toLowerCase() : '';
        if (/^\.(jpg|jpeg|png|webp|gif)$/.test(fromName)) {
            return fromName === '.jpeg' ? '.jpg' : fromName;
        }
        switch (mimetype) {
            case 'image/png':
                return '.png';
            case 'image/webp':
                return '.webp';
            case 'image/gif':
                return '.gif';
            default:
                return '.jpg';
        }
    }
    async saveToDisk(buffer, ext) {
        const name = `img_${Date.now()}_${Math.random()
            .toString(36)
            .slice(2, 10)}${ext}`;
        await fs_1.promises.writeFile((0, path_1.join)(this.uploadDir, name), buffer);
        return name;
    }
    async uploadImage(file, base64, imageUrl, req) {
        const baseUrl = this.publicBaseUrl(req);
        if (file && file.buffer && file.buffer.length > 0) {
            const ext = this.extFrom(file.mimetype, file.originalname);
            const name = await this.saveToDisk(file.buffer, ext);
            const url = `${baseUrl}/uploads/${name}`;
            this.logger.log(`تم حفظ صورة مرفوعة: ${name} (${file.size} بايت)`);
            return { url, secure_url: url };
        }
        if (base64) {
            const match = /^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/s.exec(base64);
            const mime = match ? match[1] : 'image/jpeg';
            const payload = match ? match[2] : base64;
            try {
                const buffer = Buffer.from(payload, 'base64');
                if (buffer.length === 0)
                    throw new Error('empty');
                const ext = this.extFrom(mime);
                const name = await this.saveToDisk(buffer, ext);
                const url = `${baseUrl}/uploads/${name}`;
                this.logger.log(`تم حفظ صورة base64: ${name}`);
                return { url, secure_url: url };
            }
            catch {
                throw new common_1.BadRequestException('صيغة الصورة غير صالحة');
            }
        }
        if (imageUrl && imageUrl.trim().length > 0) {
            const url = imageUrl.trim();
            return { url, secure_url: url };
        }
        throw new common_1.BadRequestException('لم يتم إرسال أي ملف');
    }
};
exports.UploadService = UploadService;
exports.UploadService = UploadService = UploadService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], UploadService);
//# sourceMappingURL=upload.service.js.map