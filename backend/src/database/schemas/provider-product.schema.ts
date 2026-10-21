import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type ProviderProductDocument = ProviderProduct & Document;

@Schema({ timestamps: true })
export class ProviderProduct {
  @Prop({ type: Types.ObjectId, ref: 'Provider', required: true, index: true })
  providerId: Types.ObjectId;

  @Prop({ required: true, trim: true })
  providerProductCode: string;

  @Prop({ required: true, trim: true })
  name: string;

  @Prop({ trim: true })
  category?: string;

  @Prop({ type: Number, required: true, default: 0.0 })
  costPrice: number;

  @Prop({ default: 'USD' })
  currency: string;

  @Prop({ default: true })
  inStock: boolean;

  @Prop({ type: Object, default: {} })
  rawDetails: Record<string, any>;
}

export const ProviderProductSchema = SchemaFactory.createForClass(ProviderProduct);
