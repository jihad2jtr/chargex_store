import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type VirtualNumberQualityEventDocument =
  VirtualNumberQualityEvent & Document;

// نتائج الشراء كما تُحتسب في تقييم الجودة.
// SUCCESS وFAILED وحدهما «محتسبان» في نسبة وصول الأكواد؛ أما البقية فتُسجَّل في
// السجل بلا أثر على العدّاد المتتالي: الإلغاء ونفاد المخزون والانقطاع ليست دليلاً
// على أن المزود لم يوصل الرمز.
export enum VirtualNumberOutcome {
  SUCCESS = 'success',
  FAILED = 'failed',
  CANCELLED = 'cancelled',
  OUT_OF_STOCK = 'out_of_stock',
  PENDING = 'pending',
  // النظام أوقف المنتج تلقائياً لبلوغ عتبة الفشل المتتالي
  AUTO_DISABLED = 'auto_disabled',
  // حدث إداري: أعادت الإدارة تفعيل المنتج بعد مراجعة
  REACTIVATED = 'reactivated',
}

// من أين جاء القرار، حتى لا يُحتسب انقطاع الشبكة فشلاً على المزود:
// request  : تعذّر تجهيز الرقم لحظة الشراء
// sync     : فحص حالة طلب حيّ (من صفحة العميل أو من المزامنة)
// sweep    : المسح الدوري حسم طلباً انتهت مهلته بلا رمز
// webhook  : أخبرنا المزود بالنتيجة
// client   : أغلق العميل طلبه بنفسه
// admin    : أوقفت الإدارة الطلب
// system   : قرار من النظام نفسه (إيقاف تلقائي، إعادة تفعيل إدارية مسجلة)
export type VirtualNumberOutcomeSource =
  | 'request'
  | 'sync'
  | 'sweep'
  | 'webhook'
  | 'client'
  | 'admin'
  | 'system';

// سجل أحداث جودة المنتج: غير محدود ولا يُضغط، لأن اللوحة تعرض منه أسباب الفشل
// وتاريخها. العدّادات على وثيقة المنتج هي المختصرة للسرد السريع.
@Schema({ timestamps: { createdAt: true, updatedAt: false } })
export class VirtualNumberQualityEvent {
  @Prop({
    type: Types.ObjectId,
    ref: 'VirtualNumberProduct',
    required: true,
    index: true,
  })
  productId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'Provider', required: true, index: true })
  providerId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'VirtualNumberApp', required: true })
  appId: Types.ObjectId;

  @Prop({ trim: true, default: '' })
  countryCode: string;

  @Prop({ type: String, enum: VirtualNumberOutcome, required: true })
  outcome: VirtualNumberOutcome;

  // هل دخل هذا الحدث في نسبة وصول الأكواد؟ لا يُحتسب إلا SUCCESS وFAILED
  @Prop({ default: false, index: true })
  counted: boolean;

  @Prop({ trim: true, default: '' })
  requestNumber: string;

  @Prop({ type: Types.ObjectId, ref: 'VirtualNumberRequest' })
  requestId?: Types.ObjectId;

  // سبب نصي قصير («انتهت مهلة الانتظار بلا رمز»، «نفاد المخزون» ...)
  @Prop({ trim: true, default: '' })
  reason: string;

  // نوع صريح مطلوب: اتحاد TypeScript وحده لا يكفي لـ reflect-metadata، وإلا
  // يفشل الاستيراد كله بـ «Cannot determine a type ... field»
  @Prop({ type: String, trim: true, default: 'sync' })
  source: VirtualNumberOutcomeSource;
}

export const VirtualNumberQualityEventSchema = SchemaFactory.createForClass(
  VirtualNumberQualityEvent,
);

// ورقة تفاصيل المنتج: أحداثه بالزمن، وفلترة اللوحة للمحتسَب حسب النتيجة
VirtualNumberQualityEventSchema.index({ productId: 1, createdAt: -1 });
VirtualNumberQualityEventSchema.index({ counted: 1, outcome: 1 });
