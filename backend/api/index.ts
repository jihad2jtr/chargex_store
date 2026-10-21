import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from '../src/app.module';

let cachedServer: any;

async function bootstrapServer() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  });

  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );

  app.setGlobalPrefix('api', {
    exclude: ['/', 'health'],
  });

  await app.init();
  return app.getHttpAdapter().getInstance();
}

export default async function handler(req: any, res: any) {
  try {
    if (!cachedServer) {
      cachedServer = await bootstrapServer();
    }
    return cachedServer(req, res);
  } catch (error: any) {
    console.error('CRITICAL: Serverless initialization error:', error);
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.status(500).send(`
      <!DOCTYPE html>
      <html lang="ar" dir="rtl">
      <head>
        <meta charset="utf-8">
        <title>تنبيه في تشغيل خادم JGO</title>
        <style>
          body { font-family: system-ui, sans-serif; background: #0F172A; color: #F8FAFC; padding: 40px 20px; text-align: center; }
          .card { max-width: 500px; margin: 0 auto; background: #1E293B; border-radius: 20px; padding: 30px; border: 1px solid rgba(239, 68, 68, 0.4); }
          h2 { color: #F87171; margin-bottom: 12px; }
          p { color: #94A3B8; font-size: 14px; line-height: 1.6; margin-bottom: 20px; }
          .error-box { background: rgba(0,0,0,0.4); padding: 12px; border-radius: 10px; font-family: monospace; font-size: 12px; color: #FCA5A5; text-align: left; direction: ltr; word-break: break-all; }
        </style>
      </head>
      <body>
        <div class="card">
          <h2>⚠️ تنبيه في الاتصال بقاعدة البيانات</h2>
          <p>السيرفر يعمل ولكن تعذر الاتصال بـ MongoDB Atlas. يرجى التأكد من إضافة <code>0.0.0.0/0</code> في قائمة IP Whitelist داخل MongoDB Atlas.</p>
          <div class="error-box">${error?.message || error}</div>
        </div>
      </body>
      </html>
    `);
  }
}
