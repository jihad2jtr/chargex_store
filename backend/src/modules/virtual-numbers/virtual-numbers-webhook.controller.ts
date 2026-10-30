import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  Headers,
  HttpCode,
  HttpStatus,
  Res,
} from '@nestjs/common';
import { Response } from 'express';
import { VirtualNumbersService } from './virtual-numbers.service';

/**
 * وحدة استقبال إشعارات الويب هوك (Webhooks) لمزودي الأرقام الوهمية:
 * - يدعم مزود Hero-SMS / SMS-Activate (سواء أرسل POST JSON أو GET callback).
 * - يدعم مزود 5sim (إشعارات وصول SMS وحالة الطلب).
 * - هذه الوحدة عامة (Public) وتستقبل طلبات سيرفرات المزودين مباشرة بدون JWT Guard.
 */
@Controller('virtual-numbers/webhook')
export class VirtualNumbersWebhookController {
  constructor(private readonly service: VirtualNumbersService) {}

  /**
   * فحص جاهزية الويب هوك للتأكد من وصول الخوادم للرابط:
   * GET /api/virtual-numbers/webhook/health
   */
  @Get('health')
  checkHealth() {
    return {
      status: 'active',
      timestamp: new Date().toISOString(),
      message: 'Virtual numbers webhook service is online and ready.',
    };
  }

  /**
   * استلام إشعار عام عبر POST (يدعم JSON و Form-URL-Encoded)
   * مثل 5sim أو Hero-SMS أو أي مزود متوافق.
   */
  @Post()
  @HttpCode(HttpStatus.OK)
  async handlePostWebhook(
    @Body() body: any,
    @Query() query: any,
    @Headers() headers: any,
  ) {
    return this.service.processIncomingWebhook(body, query, headers);
  }

  /**
   * استلام إشعار عبر GET:
   * بعض نسخ بروتوكول SMS-Activate تستدعي Callback URL عبر GET مع Query Parameters.
   */
  @Get()
  async handleGetWebhook(
    @Query() query: any,
    @Headers() headers: any,
    @Res() res: Response,
  ) {
    const result = await this.service.processIncomingWebhook({}, query, headers);
    // إذا كان المزود يطلب استجابة نصية صريحة "ACCESS_READY" أو "OK"
    if (query?.format === 'text' || query?.plain === '1') {
      return res.status(200).send(result.success ? 'ACCESS_READY' : 'ERROR');
    }
    return res.status(200).json(result);
  }

  /**
   * مسار مخصص صريح لمزود 5sim:
   * POST /api/virtual-numbers/webhook/fivesim
   */
  @Post('fivesim')
  @HttpCode(HttpStatus.OK)
  async handleFiveSimWebhook(
    @Body() body: any,
    @Query() query: any,
    @Headers() headers: any,
  ) {
    return this.service.processIncomingWebhook(body, query, headers);
  }

  /**
   * مسار مخصص صريح لمزود Hero-SMS / SMS-Activate (POST):
   * POST /api/virtual-numbers/webhook/herosms
   */
  @Post('herosms')
  @HttpCode(HttpStatus.OK)
  async handleHeroSmsPost(
    @Body() body: any,
    @Query() query: any,
    @Headers() headers: any,
  ) {
    return this.service.processIncomingWebhook(body, query, headers);
  }

  /**
   * مسار مخصص صريح لمزود Hero-SMS / SMS-Activate (GET):
   * GET /api/virtual-numbers/webhook/herosms
   */
  @Get('herosms')
  async handleHeroSmsGet(
    @Query() query: any,
    @Headers() headers: any,
    @Res() res: Response,
  ) {
    const result = await this.service.processIncomingWebhook({}, query, headers);
    return res.status(200).send(result.success ? 'ACCESS_READY' : 'ERROR');
  }
}
