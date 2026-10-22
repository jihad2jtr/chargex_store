import {
  BadRequestException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { existsSync, mkdirSync, promises as fs } from 'fs';
import { extname, join } from 'path';

@Injectable()
export class UploadService {
  private readonly logger = new Logger(UploadService.name);

  /** مجلد تخزين الصور المرفوعة على القرص */
  private readonly uploadDir = join(process.cwd(), 'uploads');

  constructor(private configService: ConfigService) {
    if (!existsSync(this.uploadDir)) {
      mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  /** الرابط العام الأساسي (يُخصَّص من PUBLIC_BASE_URL أو من الطلب نفسه) */
  private publicBaseUrl(req?: any): string {
    const configured = this.configService.get<string>('PUBLIC_BASE_URL');
    if (configured && configured.trim().length > 0) {
      return configured.trim().replace(/\/+$/, '');
    }
    if (req) {
      return `${req.protocol}://${req.get('host')}`;
    }
    return '';
  }

  private extFrom(mimetype?: string, originalName?: string): string {
    const fromName = originalName ? extname(originalName).toLowerCase() : '';
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

  /** يكتب الملف على القرص ويعيد اسمه */
  private async saveToDisk(buffer: Buffer, ext: string): Promise<string> {
    const name = `img_${Date.now()}_${Math.random()
      .toString(36)
      .slice(2, 10)}${ext}`;
    await fs.writeFile(join(this.uploadDir, name), buffer);
    return name;
  }

  /**
   * حفظ صورة مرفوعة وإعادة رابطها العام.
   * يدعم: ملف multipart، أو base64 (data URI أو خام)، أو رابط خارجي جاهز.
   */
  async uploadImage(
    file: any,
    base64?: string,
    imageUrl?: string,
    req?: any,
  ): Promise<{ url: string; secure_url: string }> {
    const baseUrl = this.publicBaseUrl(req);

    // 1) ملف multipart
    if (file && file.buffer && file.buffer.length > 0) {
      const ext = this.extFrom(file.mimetype, file.originalname);
      const name = await this.saveToDisk(file.buffer, ext);
      const url = `${baseUrl}/uploads/${name}`;
      this.logger.log(`تم حفظ صورة مرفوعة: ${name} (${file.size} بايت)`);
      return { url, secure_url: url };
    }

    // 2) base64
    if (base64) {
      const match = /^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/s.exec(base64);
      const mime = match ? match[1] : 'image/jpeg';
      const payload = match ? match[2] : base64;
      try {
        const buffer = Buffer.from(payload, 'base64');
        if (buffer.length === 0) throw new Error('empty');
        const ext = this.extFrom(mime);
        const name = await this.saveToDisk(buffer, ext);
        const url = `${baseUrl}/uploads/${name}`;
        this.logger.log(`تم حفظ صورة base64: ${name}`);
        return { url, secure_url: url };
      } catch {
        throw new BadRequestException('صيغة الصورة غير صالحة');
      }
    }

    // 3) رابط خارجي جاهز
    if (imageUrl && imageUrl.trim().length > 0) {
      const url = imageUrl.trim();
      return { url, secure_url: url };
    }

    throw new BadRequestException('لم يتم إرسال أي ملف');
  }
}
