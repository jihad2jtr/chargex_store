import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): any {
    return {
      status: 'online',
      service: 'JGO Digital Hub API',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
    };
  }
}
