import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type ProviderWithdrawalDocument = ProviderWithdrawal & Document;

export enum ProviderWithdrawalStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

@Schema({ timestamps: true })
export class ProviderWithdrawal {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  supervisorId: Types.ObjectId;

  @Prop({ type: Number, required: true, min: 0.01 })
  amount: number;

  @Prop({ trim: true, default: 'sham_cash' })
  method: string;

  @Prop({ required: true, trim: true })
  shamCashAccountName: string;

  @Prop({ required: true, trim: true })
  shamCashAccountId: string;

  @Prop({ trim: true, default: '' })
  notes?: string;

  @Prop({
    type: String,
    enum: ProviderWithdrawalStatus,
    default: ProviderWithdrawalStatus.PENDING,
    index: true,
  })
  status: ProviderWithdrawalStatus;

  @Prop({ trim: true, default: '' })
  adminNote?: string;

  @Prop({ type: Types.ObjectId, ref: 'User' })
  reviewedBy?: Types.ObjectId;

  @Prop()
  reviewedAt?: Date;
}

export const ProviderWithdrawalSchema =
  SchemaFactory.createForClass(ProviderWithdrawal);
