import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type ManualOrderDocument = ManualOrder & Document;

export enum ManualOrderStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

@Schema({ timestamps: true })
export class ManualOrder {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'Order' })
  orderId?: Types.ObjectId;

  @Prop({ required: true, trim: true })
  type: string; // 'manual_service' | 'sham_cash_topup' | 'binance_topup' | 'id_topup'

  @Prop({ type: Number, required: true })
  amount: number; // in USD

  @Prop({ type: Object, default: {} })
  details: Record<string, any>; // account ID, player ID, transaction hash, sender account

  @Prop({ trim: true })
  receiptImageUrl?: string; // Receipt screenshot uploaded via Cloudinary

  @Prop({ type: String, enum: ManualOrderStatus, default: ManualOrderStatus.PENDING, index: true })
  status: ManualOrderStatus;

  @Prop({ trim: true })
  adminNotes?: string; // Acceptance note or rejection reason

  @Prop({ type: Types.ObjectId, ref: 'User' })
  processedBy?: Types.ObjectId;

  @Prop()
  processedAt?: Date;
}

export const ManualOrderSchema = SchemaFactory.createForClass(ManualOrder);
