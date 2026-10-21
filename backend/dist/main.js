"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = handler;
const core_1 = require("@nestjs/core");
const common_1 = require("@nestjs/common");
const app_module_1 = require("./app.module");
let cachedServer;
async function bootstrapServer() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    app.enableCors({
        origin: '*',
        methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
        credentials: true,
    });
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: false,
    }));
    app.setGlobalPrefix('api', {
        exclude: ['/', 'health'],
    });
    await app.init();
    return app.getHttpAdapter().getInstance();
}
async function handler(req, res) {
    if (!cachedServer) {
        cachedServer = await bootstrapServer();
    }
    return cachedServer(req, res);
}
async function bootstrap() {
    const logger = new common_1.Logger('JGOBootstrap');
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    app.enableCors({
        origin: '*',
        methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
        credentials: true,
    });
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: false,
    }));
    app.setGlobalPrefix('api', {
        exclude: ['/', 'health'],
    });
    const port = process.env.PORT || 3000;
    await app.listen(port, '0.0.0.0');
    logger.log(`🚀 JGO Backend Server running on: http://0.0.0.0:${port}/api`);
}
if (!process.env.VERCEL) {
    bootstrap();
}
//# sourceMappingURL=main.js.map