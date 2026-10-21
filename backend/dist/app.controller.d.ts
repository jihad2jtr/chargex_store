import { AppService } from './app.service';
export declare class AppController {
    private readonly appService;
    constructor(appService: AppService);
    getRoot(req: any, res: any): any;
    getHealth(): any;
}
