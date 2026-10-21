import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): any {
    const hasMongo = !!process.env.MONGODB_URI;
    return {
      status: 'online',
      service: 'JGO Digital Recharge Hub API',
      version: '1.0.0',
      database: hasMongo ? 'configured (MongoDB Atlas)' : 'local / unconfigured',
      timestamp: new Date().toISOString(),
      endpoints: {
        health: '/health',
        auth: '/api/auth/login',
        apps: '/api/apps',
        products: '/api/products',
        providers: '/api/providers',
      },
    };
  }

  getStatusHtml(): string {
    const time = new Date().toLocaleString('ar-SA', { timeZone: 'Asia/Damascus' });
    const hasMongo = !!process.env.MONGODB_URI;
    const mongoStatusText = hasMongo ? 'سحابية متصلة (MongoDB Atlas)' : 'محلية (Localhost)';
    const mongoStatusColor = hasMongo ? '#10B981' : '#F59E0B';

    return `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>خادم JGO السحابي - يعمل بنجاح</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;900&family=JetBrains+Mono:wght@500;700&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: radial-gradient(circle at 50% 0%, #1e1b4b 0%, #090d16 60%, #030712 100%);
      color: #F8FAFC;
      font-family: 'Cairo', system-ui, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px 16px;
    }
    .card {
      background: rgba(15, 23, 42, 0.75);
      border: 1px solid rgba(255, 255, 255, 0.12);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border-radius: 28px;
      max-width: 540px;
      width: 100%;
      padding: 36px 28px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.6), 0 0 40px rgba(241, 130, 35, 0.15);
      text-align: center;
      position: relative;
      overflow: hidden;
    }
    .card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 4px;
      background: linear-gradient(90deg, #F18223, #FBBF24, #10B981);
    }
    .logo-container {
      width: 80px;
      height: 80px;
      background: linear-gradient(135deg, #F18223, #EA580C);
      border-radius: 22px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 20px;
      box-shadow: 0 10px 25px rgba(241, 130, 35, 0.4);
      font-family: 'JetBrains Mono', sans-serif;
      font-size: 26px;
      font-weight: 900;
      color: white;
      letter-spacing: -0.5px;
    }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: rgba(16, 185, 129, 0.12);
      border: 1px solid rgba(16, 185, 129, 0.35);
      color: #34D399;
      padding: 6px 16px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 700;
      margin-bottom: 16px;
    }
    .pulse-dot {
      width: 8px;
      height: 8px;
      background-color: #10B981;
      border-radius: 50%;
      box-shadow: 0 0 12px #10B981;
      animation: pulse 1.8s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(1.3); }
    }
    h1 {
      font-size: 24px;
      font-weight: 900;
      color: #FFFFFF;
      margin-bottom: 8px;
    }
    p.subtitle {
      color: #94A3B8;
      font-size: 14px;
      margin-bottom: 24px;
      line-height: 1.6;
    }
    .info-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 24px;
      text-align: right;
    }
    .info-box {
      background: rgba(30, 41, 59, 0.6);
      border: 1px solid rgba(255, 255, 255, 0.06);
      padding: 12px 14px;
      border-radius: 14px;
    }
    .info-label {
      font-size: 11px;
      color: #64748B;
      font-weight: 600;
      margin-bottom: 4px;
    }
    .info-value {
      font-size: 13px;
      color: #F1F5F9;
      font-weight: 700;
      font-family: 'JetBrains Mono', monospace;
    }
    .api-links {
      display: flex;
      gap: 10px;
      justify-content: center;
      flex-wrap: wrap;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 10px 18px;
      border-radius: 12px;
      font-size: 13px;
      font-weight: 700;
      text-decoration: none;
      transition: all 0.2s ease;
    }
    .btn-primary {
      background: #F18223;
      color: white;
    }
    .btn-primary:hover {
      background: #d96f15;
      transform: translateY(-1px);
    }
    .btn-secondary {
      background: rgba(255, 255, 255, 0.08);
      color: #CBD5E1;
      border: 1px solid rgba(255, 255, 255, 0.1);
    }
    .btn-secondary:hover {
      background: rgba(255, 255, 255, 0.14);
      color: white;
    }
    .footer {
      margin-top: 24px;
      font-size: 11px;
      color: #64748B;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo-container">JGO</div>
    <br>
    <div class="status-badge">
      <div class="pulse-dot"></div>
      خادم الـ API يعمل بنجاح أونلاين
    </div>
    <h1>بوابة خادم JGO السحابية</h1>
    <p class="subtitle">السيرفر الخلفي متصل وجاهز لاستقبال طلبات تطبيق الهاتف والمستخدمين بالكامل.</p>
    
    <div class="info-grid">
      <div class="info-box">
        <div class="info-label">حالة النظام</div>
        <div class="info-value" style="color: #34D399;">ONLINE (مستقر)</div>
      </div>
      <div class="info-box">
        <div class="info-label">إصدار الـ API</div>
        <div class="info-value">v1.0.0 (Production)</div>
      </div>
      <div class="info-box" style="grid-column: span 2;">
        <div class="info-label">قاعدة البيانات</div>
        <div class="info-value" style="color: ${mongoStatusColor};">${mongoStatusText}</div>
      </div>
    </div>

    <div class="api-links">
      <a href="/api/apps" class="btn btn-primary" target="_blank">فحص التطبيقات (GET /api/apps)</a>
      <a href="/health" class="btn btn-secondary" target="_blank">بيانات الفحص JSON</a>
    </div>

    <div class="footer">
      JGO Digital Recharge Hub • ${time}
    </div>
  </div>
</body>
</html>`;
  }
}
