import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { json, urlencoded } from 'express';
import { join } from 'path';
import { AppModule } from './app.module';

// وضع التشغيل المباشر (تطوير محلي، VPS، Docker)
async function bootstrap() {
  const logger = new Logger('JGOBootstrap');
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bodyParser: false,
  });

  // رفع حد جسم الطلب لاستيعاب الصور المرفوعة
  app.use(json({ limit: '10mb' }));
  app.use(urlencoded({ extended: true, limit: '10mb' }));

  app.useStaticAssets(join(process.cwd(), 'uploads'), { prefix: '/uploads/' });

  // دعم مسار الويب هوك مع أو بدون بادئة /api لضمان استقبال إشعارات المزودين في الحالتين
  app.use((req: any, _res: any, next: any) => {
    if (req.url && req.url.startsWith('/virtual-numbers/webhook')) {
      req.url = '/api' + req.url;
    }
    next();
  });

  // Enable CORS for Flutter Web, Mobile, and Desktop
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  // Enable request body validation
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );

  // Set Global Prefix
  app.setGlobalPrefix('api', {
    exclude: ['/', 'health'],
  });

  const port = process.env.PORT || 3000;
  await app.listen(port, '0.0.0.0');
  logger.log(`🚀 JGO Backend Server running on: http://0.0.0.0:${port}/api`);
}

if (typeof require !== 'undefined' && require.main === module) {
  bootstrap();
}
