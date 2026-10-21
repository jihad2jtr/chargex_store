import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type AppDocument = App & Document;

export enum AppType {
  GAME = 'game',
  APP = 'app',
  SERVICE = 'service',
}

@Schema({ timestamps: true })
export class App {
  @Prop({ required: true, trim: true })
  name: string;

  @Prop({ trim: true })
  nameAr?: string; // Arabic display name

  @Prop({ trim: true })
  nameEn?: string; // English display name

  @Prop({ type: String, enum: AppType, default: AppType.GAME })
  appType?: AppType; // Type: game / app / service

  @Prop({ required: true })
  iconUrl: string; // Square image URL or 'builtin:<key>'

  @Prop({ default: true, index: true })
  isActive: boolean;

  @Prop({ default: 0, index: true })
  sortOrder: number;

  @Prop({ trim: true })
  category?: string;

  @Prop({ trim: true })
  description?: string;
}

export const AppSchema = SchemaFactory.createForClass(App);
