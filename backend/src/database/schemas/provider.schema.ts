import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type ProviderDocument = Provider & Document;

export enum ProviderStatus {
  ONLINE = 'online',
  OFFLINE = 'offline',
  ERROR = 'error',
}

export enum ProviderType {
  BAY2GAME = 'bay2game',
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

  @Prop({ default: true })
  isActive: boolean;
}

export const ProviderSchema = SchemaFactory.createForClass(Provider);
