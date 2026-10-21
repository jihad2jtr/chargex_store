import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type ShippingCodeDocument = ShippingCode & Document;

@Schema({ timestamps: true })
export class ShippingCode {
  @Prop({ required: true, unique: true, uppercase: true, trim: true, index: true })
  code: string;

  @Prop({ type: Number, required: true, min: 0.1 })
  amount: number; // Value in USD

  @Prop({ default: false, index: true })
  isUsed: boolean;

  @Prop({ type: Types.ObjectId, ref: 'User' })
  usedBy?: Types.ObjectId;

  @Prop()
  usedAt?: Date;

  @Prop({ default: true, index: true })
  isActive: boolean;

  @Prop({ type: Types.ObjectId, ref: 'User' })
  createdBy?: Types.ObjectId;
}

export const ShippingCodeSchema = SchemaFactory.createForClass(ShippingCode);
