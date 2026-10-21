import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type BannerDocument = Banner & Document;

@Schema({ timestamps: true })
export class Banner {
  @Prop({ required: true, trim: true })
  title: string;

  @Prop({ trim: true, default: '' })
  description: string;

  @Prop({ required: true })
  imageUrl: string;

  @Prop({ default: 'topup', trim: true })
  actionType: string; // 'none' | 'topup' | 'app' | 'url'

  @Prop({ trim: true })
  actionValue?: string; // appId or external URL if actionType is 'app' or 'url'

  @Prop({ default: true, index: true })
  isActive: boolean;

  @Prop({ default: 0, index: true })
  sortOrder: number;
}

export const BannerSchema = SchemaFactory.createForClass(Banner);
