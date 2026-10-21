import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { initializeApp, cert, getApps, App, applicationDefault } from 'firebase-admin/app';
import { getMessaging, MulticastMessage } from 'firebase-admin/messaging';
import * as fs from 'fs';
import * as path from 'path';

export interface FcmPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string;
}

export interface FcmSendResult {
  successCount: number;
  failureCount: number;
  invalidTokens: string[];
}

@Injectable()
export class FcmService implements OnModuleInit {
  private readonly logger = new Logger(FcmService.name);
  private firebaseApp: App | null = null;
  private isConfigured = false;

  onModuleInit() {
    this.initFirebase();
  }

  private initFirebase() {
    try {
      const existingApps = getApps();
      if (existingApps.length > 0) {
        this.firebaseApp = existingApps[0];
        this.isConfigured = true;
        this.logger.log('Firebase Admin already initialized.');
        return;
      }

      // 1. Check for Service Account JSON in Environment Variable
      const envServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
      if (envServiceAccount) {
        let credentialObj: any;
        try {
          credentialObj = JSON.parse(envServiceAccount);
        } catch {
          // If it's a file path
          if (fs.existsSync(envServiceAccount)) {
            credentialObj = JSON.parse(fs.readFileSync(envServiceAccount, 'utf8'));
          }
        }

        if (credentialObj) {
          this.firebaseApp = initializeApp({
            credential: cert(credentialObj),
          });
          this.isConfigured = true;
          this.logger.log(
            `Firebase Admin initialized successfully from FIREBASE_SERVICE_ACCOUNT (Project: ${credentialObj.project_id || 'custom'})`,
          );
          return;
        }
      }

      // 2. Check for serviceAccountKey.json file in project root or current working dir
      const searchPaths = [
        path.join(process.cwd(), 'firebase-service-account.json'),
        path.join(process.cwd(), 'serviceAccountKey.json'),
        path.join(process.cwd(), '..', 'firebase-service-account.json'),
      ];

      for (const p of searchPaths) {
        if (fs.existsSync(p)) {
          const serviceAccount = JSON.parse(fs.readFileSync(p, 'utf8'));
          this.firebaseApp = initializeApp({
            credential: cert(serviceAccount),
          });
          this.isConfigured = true;
          this.logger.log(
            `Firebase Admin initialized successfully from file: ${p} (Project: ${serviceAccount.project_id})`,
          );
          return;
        }
      }

      // 3. Check for GOOGLE_APPLICATION_CREDENTIALS
      if (
        process.env.GOOGLE_APPLICATION_CREDENTIALS &&
        fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)
      ) {
        this.firebaseApp = initializeApp({
          credential: applicationDefault(),
        });
        this.isConfigured = true;
        this.logger.log('Firebase Admin initialized with applicationDefault credentials.');
        return;
      }

      this.logger.warn(
        '⚠️ Firebase Service Account not found. FcmService running in Dev/Simulation Mode. Push notifications will be logged and dispatched when credentials are provided in firebase-service-account.json or FIREBASE_SERVICE_ACCOUNT env var.',
      );
    } catch (error: any) {
      this.logger.error(`Failed to initialize Firebase Admin: ${error?.message || error}`);
    }
  }

  /**
   * Check if Firebase is connected with real credentials
   */
  get hasActiveCredentials(): boolean {
    return this.isConfigured && this.firebaseApp !== null;
  }

  /**
   * Send notification to a list of device FCM tokens
   */
  async sendToTokens(tokens: string[], payload: FcmPayload): Promise<FcmSendResult> {
    const validTokens = (tokens || []).filter((t) => t && typeof t === 'string' && t.trim().length > 0);

    if (validTokens.length === 0) {
      return { successCount: 0, failureCount: 0, invalidTokens: [] };
    }

    // Clean data payload: all values must be strings for FCM
    const sanitizedData: Record<string, string> = {};
    if (payload.data) {
      for (const [key, val] of Object.entries(payload.data)) {
        sanitizedData[key] = typeof val === 'string' ? val : JSON.stringify(val);
      }
    }

    if (!this.hasActiveCredentials) {
      this.logger.log(
        `[FCM Push (Simulation)] Target: ${validTokens.length} devices | Title: "${payload.title}" | Body: "${payload.body}" | Data: ${JSON.stringify(sanitizedData)}`,
      );
      return {
        successCount: validTokens.length,
        failureCount: 0,
        invalidTokens: [],
      };
    }

    const invalidTokens: string[] = [];
    let successCount = 0;
    let failureCount = 0;

    try {
      const message: MulticastMessage = {
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

      const messaging = getMessaging(this.firebaseApp!);
      const response = await messaging.sendEachForMulticast(message);
      successCount = response.successCount;
      failureCount = response.failureCount;

      this.logger.log(
        `[FCM Push Sent] Success: ${successCount}, Failed: ${failureCount} for "${payload.title}"`,
      );

      // Collect invalid tokens that should be removed
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errCode = resp.error?.code;
          if (
            errCode === 'messaging/invalid-registration-token' ||
            errCode === 'messaging/registration-token-not-registered'
          ) {
            invalidTokens.push(validTokens[idx]);
          }
        }
      });
    } catch (error: any) {
      this.logger.error(`Error sending FCM multicast: ${error?.message || error}`);
      failureCount = validTokens.length;
    }

    return { successCount, failureCount, invalidTokens };
  }

  /**
   * Send notification to a topic (e.g. 'all', 'announcements')
   */
  async sendToTopic(topic: string, payload: FcmPayload): Promise<boolean> {
    const sanitizedData: Record<string, string> = {};
    if (payload.data) {
      for (const [key, val] of Object.entries(payload.data)) {
        sanitizedData[key] = typeof val === 'string' ? val : JSON.stringify(val);
      }
    }

    if (!this.hasActiveCredentials) {
      this.logger.log(
        `[FCM Topic (Simulation)] Topic: /topics/${topic} | Title: "${payload.title}" | Body: "${payload.body}"`,
      );
      return true;
    }

    try {
      const messaging = getMessaging(this.firebaseApp!);
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
    } catch (error: any) {
      this.logger.error(`Failed to send topic push: ${error?.message || error}`);
      return false;
    }
  }
}
