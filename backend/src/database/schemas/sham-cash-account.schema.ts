import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type ShamCashAccountDocument = ShamCashAccount & Document;

export enum PaymentAccountType {
  SHAM_CASH = 'sham_cash',
  BINANCE = 'binance',
}

@Schema({ timestamps: true })
export class ShamCashAccount {
  @Prop({ type: String, enum: PaymentAccountType, default: PaymentAccountType.SHAM_CASH, index: true })
  type: PaymentAccountType;

  @Prop({ required: true, trim: true })
  accountName: string;

  @Prop({ required: true, trim: true })
  accountId: string; // Account number or Binance Pay ID

  @Prop({ required: true, trim: true })
  barcodeUrl: string; // Barcode / QR code image URL

  @Prop({ default: true })
  isActive: boolean;
}

export const ShamCashAccountSchema = SchemaFactory.createForClass(ShamCashAccount);
