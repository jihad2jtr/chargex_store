import { Controller, Get, Req, Res } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getRoot(@Req() req: any, @Res() res: any) {
    const acceptHeader: string = req.headers['accept'] || '';
    if (acceptHeader.includes('text/html')) {
      return res.type('text/html').send(this.appService.getStatusHtml());
    }
    return res.json(this.appService.getHello());
  }

  @Get('health')
  getHealth() {
    return this.appService.getHello();
  }
}
