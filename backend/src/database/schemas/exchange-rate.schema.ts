import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type ExchangeRateDocument = ExchangeRate & Document;

// سعر صرف العملة — مستند واحد لكل زوج عملات (usdsypd حالياً).
// يُجلب تلقائياً من liranews مرة كل 24 ساعة ويُخزَّن هنا، كي يعتمد التطبيق
// على الخادم وحده ولا يتصل بمصدر خارجي في كل طلب.
@Schema({ timestamps: true })
export class ExchangeRate {
  @Prop({ required: true, trim: true, unique: true, index: true, default: 'usdsypd' })
  pair: string; // زوج العملات: 'usdsypd'

  // سعر 1 دولار بالليرة السورية الجديدة (كما ينشرها المصدر: 143.5 ل.س)
  @Prop({ required: true })
  rate: number;

  // القيمة كما وردت من المصدر حرفياً
  @Prop({ default: 0 })
  rawRate: number;

  @Prop({ default: 0 })
  buy: number; // سعر الشراء عند المصدر

  @Prop({ default: 0 })
  sell: number; // سعر المبيع عند المصدر

  @Prop({ default: 0 })
  previousRate: number; // السعر المخزّن قبل آخر تحديث (لحساب مقدار التغيّر)

  @Prop({ trim: true, default: 'liranews' })
  source: string;

  @Prop({ trim: true, default: '' })
  sourceUrl: string;

  // وقت تحديث السعر في المصدر نفسه
  @Prop()
  sourceUpdatedAt?: Date;

  // وقت آخر جلب ناجح من المصدر
  @Prop()
  fetchedAt?: Date;
}

export const ExchangeRateSchema = SchemaFactory.createForClass(ExchangeRate);
