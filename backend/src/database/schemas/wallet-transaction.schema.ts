import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type WalletTransactionDocument = WalletTransaction & Document;

export enum TransactionType {
  TOPUP = 'topup',
  PURCHASE = 'purchase',
  REFUND = 'refund',
  ADMIN_ADJUSTMENT = 'admin_adjustment',
  AGENT_TRANSFER = 'agent_transfer',
}

export enum TransactionStatus {
  COMPLETED = 'completed',
  PENDING = 'pending',
  FAILED = 'failed',
}

@Schema({ timestamps: true })
export class WalletTransaction {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ type: String, enum: TransactionType, required: true, index: true })
  type: TransactionType;

  @Prop({ type: Number, required: true })
  amount: number; // positive for topup/refund, negative for purchase

  @Prop({ type: Number, required: true })
  balanceBefore: number;

  @Prop({ type: Number, required: true })
  balanceAfter: number;

  @Prop({ required: true, trim: true })
  description: string;

  @Prop({ trim: true })
  referenceType?: string; // 'Order', 'ShippingCode', 'ShamCash', 'Binance', 'Admin'

  @Prop({ trim: true })
  referenceId?: string;

  @Prop({ type: String, enum: TransactionStatus, default: TransactionStatus.COMPLETED })
  status: TransactionStatus;
}

export const WalletTransactionSchema = SchemaFactory.createForClass(WalletTransaction);
