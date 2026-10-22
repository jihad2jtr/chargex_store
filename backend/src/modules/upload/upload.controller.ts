import {
  Body,
  Controller,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { UploadService } from './upload.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Controller('upload')
@UseGuards(JwtAuthGuard)
export class UploadController {
  constructor(private readonly uploadService: UploadService) {}

  // يقبل ملفاً بصيغة multipart (الحقل: file) أو base64 أو رابطاً خارجياً
  @Post('image')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
    }),
  )
  async uploadImage(
    @UploadedFile() file: any,
    @Body() body: { base64?: string; imageUrl?: string },
    @Req() req: any,
  ) {
    return this.uploadService.uploadImage(
      file,
      body?.base64,
      body?.imageUrl,
      req,
    );
  }
}
