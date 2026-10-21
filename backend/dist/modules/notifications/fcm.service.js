"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var FcmService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.FcmService = void 0;
const common_1 = require("@nestjs/common");
const app_1 = require("firebase-admin/app");
const messaging_1 = require("firebase-admin/messaging");
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
let FcmService = FcmService_1 = class FcmService {
    constructor() {
        this.logger = new common_1.Logger(FcmService_1.name);
        this.firebaseApp = null;
        this.isConfigured = false;
    }
    onModuleInit() {
        this.initFirebase();
    }
    initFirebase() {
        try {
            const existingApps = (0, app_1.getApps)();
            if (existingApps.length > 0) {
                this.firebaseApp = existingApps[0];
                this.isConfigured = true;
                this.logger.log('Firebase Admin already initialized.');
                return;
            }
            const envServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
            if (envServiceAccount) {
                let credentialObj;
                try {
                    credentialObj = JSON.parse(envServiceAccount);
                }
                catch {
                    if (fs.existsSync(envServiceAccount)) {
                        credentialObj = JSON.parse(fs.readFileSync(envServiceAccount, 'utf8'));
                    }
                }
                if (credentialObj) {
                    this.firebaseApp = (0, app_1.initializeApp)({
                        credential: (0, app_1.cert)(credentialObj),
                    });
                    this.isConfigured = true;
                    this.logger.log(`Firebase Admin initialized successfully from FIREBASE_SERVICE_ACCOUNT (Project: ${credentialObj.project_id || 'custom'})`);
                    return;
                }
            }
            const searchPaths = [
                path.join(process.cwd(), 'firebase-service-account.json'),
                path.join(process.cwd(), 'serviceAccountKey.json'),
                path.join(process.cwd(), '..', 'firebase-service-account.json'),
            ];
            for (const p of searchPaths) {
                if (fs.existsSync(p)) {
                    const serviceAccount = JSON.parse(fs.readFileSync(p, 'utf8'));
                    this.firebaseApp = (0, app_1.initializeApp)({
                        credential: (0, app_1.cert)(serviceAccount),
                    });
                    this.isConfigured = true;
                    this.logger.log(`Firebase Admin initialized successfully from file: ${p} (Project: ${serviceAccount.project_id})`);
                    return;
                }
            }
            if (process.env.GOOGLE_APPLICATION_CREDENTIALS &&
                fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
                this.firebaseApp = (0, app_1.initializeApp)({
                    credential: (0, app_1.applicationDefault)(),
                });
                this.isConfigured = true;
                this.logger.log('Firebase Admin initialized with applicationDefault credentials.');
                return;
            }
            this.logger.warn('⚠️ Firebase Service Account not found. FcmService running in Dev/Simulation Mode. Push notifications will be logged and dispatched when credentials are provided in firebase-service-account.json or FIREBASE_SERVICE_ACCOUNT env var.');
        }
        catch (error) {
            this.logger.error(`Failed to initialize Firebase Admin: ${error?.message || error}`);
        }
    }
    get hasActiveCredentials() {
        return this.isConfigured && this.firebaseApp !== null;
    }
    async sendToTokens(tokens, payload) {
        const validTokens = (tokens || []).filter((t) => t && typeof t === 'string' && t.trim().length > 0);
        if (validTokens.length === 0) {
            return { successCount: 0, failureCount: 0, invalidTokens: [] };
        }
        const sanitizedData = {};
        if (payload.data) {
            for (const [key, val] of Object.entries(payload.data)) {
                sanitizedData[key] = typeof val === 'string' ? val : JSON.stringify(val);
            }
        }
        if (!this.hasActiveCredentials) {
            this.logger.log(`[FCM Push (Simulation)] Target: ${validTokens.length} devices | Title: "${payload.title}" | Body: "${payload.body}" | Data: ${JSON.stringify(sanitizedData)}`);
            return {
                successCount: validTokens.length,
                failureCount: 0,
                invalidTokens: [],
            };
        }
        const invalidTokens = [];
        let successCount = 0;
        let failureCount = 0;
        try {
            const message = {
                tokens: validTokens,
                notification: {
                    title: payload.title,
                    body: payload.body,
                    imageUrl: payload.imageUrl,
                },
                data: sanitizedData,
                android: {
                    priority: 'high',
                    notification: {
                        sound: 'default',
                        channelId: 'chargex_notifications',
                        priority: 'high',
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: 'default',
                            badge: 1,
                        },
                    },
                },
            };
            const messaging = (0, messaging_1.getMessaging)(this.firebaseApp);
            const response = await messaging.sendEachForMulticast(message);
            successCount = response.successCount;
            failureCount = response.failureCount;
            this.logger.log(`[FCM Push Sent] Success: ${successCount}, Failed: ${failureCount} for "${payload.title}"`);
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    const errCode = resp.error?.code;
                    if (errCode === 'messaging/invalid-registration-token' ||
                        errCode === 'messaging/registration-token-not-registered') {
                        invalidTokens.push(validTokens[idx]);
                    }
                }
            });
        }
        catch (error) {
            this.logger.error(`Error sending FCM multicast: ${error?.message || error}`);
            failureCount = validTokens.length;
        }
        return { successCount, failureCount, invalidTokens };
    }
    async sendToTopic(topic, payload) {
        const sanitizedData = {};
        if (payload.data) {
            for (const [key, val] of Object.entries(payload.data)) {
                sanitizedData[key] = typeof val === 'string' ? val : JSON.stringify(val);
            }
        }
        if (!this.hasActiveCredentials) {
            this.logger.log(`[FCM Topic (Simulation)] Topic: /topics/${topic} | Title: "${payload.title}" | Body: "${payload.body}"`);
            return true;
        }
        try {
            const messaging = (0, messaging_1.getMessaging)(this.firebaseApp);
            await messaging.send({
                topic,
                notification: {
                    title: payload.title,
                    body: payload.body,
                    imageUrl: payload.imageUrl,
                },
                data: sanitizedData,
            });
            this.logger.log(`[FCM Topic Push Sent] Topic: ${topic} - Title: "${payload.title}"`);
            return true;
        }
        catch (error) {
            this.logger.error(`Failed to send topic push: ${error?.message || error}`);
            return false;
        }
    }
};
exports.FcmService = FcmService;
exports.FcmService = FcmService = FcmService_1 = __decorate([
    (0, common_1.Injectable)()
], FcmService);
//# sourceMappingURL=fcm.service.js.map