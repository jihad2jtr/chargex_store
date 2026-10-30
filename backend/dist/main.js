"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const core_1 = require("@nestjs/core");
const common_1 = require("@nestjs/common");
const express_1 = require("express");
const path_1 = require("path");
const app_module_1 = require("./app.module");
async function bootstrap() {
    const logger = new common_1.Logger('JGOBootstrap');
    const app = await core_1.NestFactory.create(app_module_1.AppModule, {
        bodyParser: false,
    });
    app.use((0, express_1.json)({ limit: '10mb' }));
    app.use((0, express_1.urlencoded)({ extended: true, limit: '10mb' }));
    app.useStaticAssets((0, path_1.join)(process.cwd(), 'uploads'), { prefix: '/uploads/' });
    app.use((req, _res, next) => {
        if (req.url && req.url.startsWith('/virtual-numbers/webhook')) {
            req.url = '/api' + req.url;
        }
        next();
    });
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
if (typeof require !== 'undefined' && require.main === module) {
    bootstrap();
}
//# sourceMappingURL=main.js.map