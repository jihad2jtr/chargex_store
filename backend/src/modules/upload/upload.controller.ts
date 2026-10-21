import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { UploadService } from './upload.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Controller('upload')
@UseGuards(JwtAuthGuard)
export class UploadController {
  constructor(private readonly uploadService: UploadService) {}

  @Post('image')
  async uploadImage(@Body() body: { base64?: string; imageUrl?: string }) {
    if (body.imageUrl) {
      return { url: body.imageUrl, secure_url: body.imageUrl };
    }
    if (body.base64) {
      return { url: body.base64, secure_url: body.base64 };
    }
    return { url: '', secure_url: '' };
  }
}
