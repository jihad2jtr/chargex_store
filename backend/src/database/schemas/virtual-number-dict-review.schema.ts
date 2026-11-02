import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type VirtualNumberDictReviewDocument = VirtualNumberDictReview &
  Document;

// قائمة مراجعة المعجم: بند استورده مزود ولم يستطع النظام التأكد من هويته
// الموحّدة — إما لطابقه أكثر من كيان، أو لتشابه اسمي بلا مطابقة تامة.
// القاعدة: لا دمج خاطئ ولا تكرار؛ الغامض يُنتظر قرار الإدارة (ربط/إنشاء/تجاهل).
@Schema({ timestamps: true })
export class VirtualNumberDictReview {
  // نوع البند: تطبيق أم دولة
  @Prop({ type: String, enum: ['app', 'country'], required: true, index: true })
  kind: 'app' | 'country';

  // مزود البند (قيمة ProviderType) ومعرّفه إن وُجد
  @Prop({ required: true, trim: true })
  providerType: string;

  @Prop({ type: Types.ObjectId, ref: 'Provider', index: true })
  providerId?: Types.ObjectId;

  // ما وصل حرفياً من المزود (رمزه واسمه الأصلي)
  @Prop({ required: true, trim: true })
  rawCode: string;

  @Prop({ trim: true, default: '' })
  rawName: string;

  // المرشّحون من المعجم الحالي الذين قد يعود إليهم هذا البند
  @Prop({ type: [String], default: [] })
  candidateKeys: string[];

  @Prop({
    type: String,
    enum: ['open', 'linked', 'created', 'dismissed'],
    default: 'open',
    index: true,
  })
  status: 'open' | 'linked' | 'created' | 'dismissed';

  // المفتاح الموحّد الذي استقر عليه القرار بعد المعالجة
  @Prop({ trim: true })
  resolvedKey?: string;
}

export const VirtualNumberDictReviewSchema = SchemaFactory.createForClass(
  VirtualNumberDictReview,
);
