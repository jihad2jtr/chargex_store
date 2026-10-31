import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { ProfitMarginType } from './product.schema';

export type ProviderDocument = Provider & Document;

export enum ProviderStatus {
  ONLINE = 'online',
  OFFLINE = 'offline',
  ERROR = 'error',
}

export enum ProviderType {
  BAY2GAME = 'bay2game',
  FOXRELOAD = 'foxreload',
  // أرقام التحقق الوهمية (استقبال SMS) — تُستخدم في صفحة «أرقام وهمية»
  FIVESIM = 'fivesim',
  // بديل نفس الغرض ببروتوكول متوافق مع SMS-Activate
  HEROSMS = 'herosms',
  // DogeSMS: REST بلغة طلب/استجابة نظيفة والرقم يصل لاحقاً عبر webhook أو استطلاع
  DOGESMS = 'dogesms',
  // SMSPool: REST يستجيب بأكواد MessagePack والرقم يصل فور الشراء
  SMSPOOL = 'smspool',
  CUSTOM = 'custom',
}

@Schema({ timestamps: true })
export class Provider {
  @Prop({ required: true, trim: true })
  name: string;

  @Prop({ required: true, trim: true })
  baseUrl: string;

  @Prop({ required: true })
  apiKey: string;

  @Prop()
  apiSecret?: string;

  @Prop({ type: String, enum: ProviderType, default: ProviderType.BAY2GAME })
  providerType?: ProviderType;

  @Prop({ type: Object, default: {} })
  headers: Record<string, string>;

  @Prop({ type: String, enum: ProviderStatus, default: ProviderStatus.OFFLINE })
  status: ProviderStatus;

  @Prop()
  lastError?: string;

  @Prop()
  lastCheckAt?: Date;

  @Prop({ type: Number, default: 0.0 })
  balance?: number;

  @Prop({ default: 'USD' })
  currency?: string;

  @Prop({ type: String, enum: ProfitMarginType, default: ProfitMarginType.PERCENTAGE })
  profitMarginType: ProfitMarginType; // نوع هامش الربح المطبّق على كل منتجات هذا المزود

  @Prop({ type: Number, default: 10.0 })
  profitMarginValue: number; // قيمة هامش الربح (نسبة مئوية أو مبلغ ثابت) لكل المزود

  @Prop({ default: true })
  isActive: boolean;

  // الاسم الوهمي الذي يراه العميل لهذا المزود («Server 1») بدل اسمه الحقيقي.
  // يُملأ تلقائياً لمزودي الأرقام ولا يغادر `name` الحقيقي مسارات الإدارة.
  @Prop({ trim: true })
  serverLabel?: string;
}

export const ProviderSchema = SchemaFactory.createForClass(Provider);
