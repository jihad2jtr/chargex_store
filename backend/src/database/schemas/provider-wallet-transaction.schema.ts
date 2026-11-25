import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type ProviderWalletTransactionDocument = ProviderWalletTransaction &
  Document;

export enum ProviderWalletTxType {
  EARNING = 'earning',
  TRANSFER_TO_MAIN = 'transfer_to_main',
  WITHDRAWAL_HOLD = 'withdrawal_hold',
  WITHDRAWAL_REFUND = 'withdrawal_refund',
  ADMIN_ADJUST = 'admin_adjust',
}

@Schema({ timestamps: true })
export class ProviderWalletTransaction {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  supervisorId: Types.ObjectId;

  @Prop({ type: String, enum: ProviderWalletTxType, required: true, index: true })
  type: ProviderWalletTxType;

  @Prop({ type: Number, required: true })
  amount: number;

  @Prop({ type: Number, required: true })
  balanceBefore: number;

  @Prop({ type: Number, required: true })
  balanceAfter: number;

  @Prop({ type: Number, default: 0 })
  adminProfit?: number;

  @Prop({ required: true, trim: true })
  description: string;

  @Prop({ trim: true })
  referenceId?: string;
}

export const ProviderWalletTransactionSchema = SchemaFactory.createForClass(
  ProviderWalletTransaction,
);
