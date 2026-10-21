import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type TopupMethodDocument = TopupMethod & Document;

export enum TopupType {
  ID_RECHARGE = 'id_recharge',
  SHAM_CASH = 'sham_cash',
  BINANCE = 'binance',
  SHIPPING_CODE = 'shipping_code',
}

@Schema({ timestamps: true })
export class TopupMethod {
  @Prop({ type: String, enum: TopupType, required: true, unique: true, index: true })
  type: TopupType;

  @Prop({ required: true, trim: true })
  title: string;

  @Prop({ trim: true })
  description?: string;

  @Prop({ default: true })
  isActive: boolean;

  @Prop({ trim: true })
  instructions?: string;
}

export const TopupMethodSchema = SchemaFactory.createForClass(TopupMethod);
