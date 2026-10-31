import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type VirtualNumberRequestDocument = VirtualNumberRequest & Document;

// مسار طلب الرقم الوهمي:
// pending  : الخصم تم ولم يُستلم رقم بعد من المزود
// waiting  : الرقم مستلم والعميل يستخدمه، بانتظار رسالة التحقق
// received : وصل رمز التحقق (يُسلَّم للعميل تلقائياً)
// completed: أُغلق الطلب بعد استلام الرمز (أو أنهى العميل مهلته بنجاح)
// cancelled: ألغاه العميل قبل وصول الرمز (يُرجع المبلغ)
// expired  : انتهت مهلة الانتظار بلا رمز (يُلغى لدى المزود ويُرجع المبلغ)
// failed   : تعذّر طلب الرقم من المزود (يُرجع المبلغ)
// الحالات الثلاث الأخيرة مغلقة؛ والإرجاع يُقاس بـ refundedAt لا بالحالة
export enum VirtualNumberStatus {
  PENDING = 'pending',
  WAITING = 'waiting',
  RECEIVED = 'received',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
  EXPIRED = 'expired',
  FAILED = 'failed',
}

// الحالات التي لا تزال «حيّة» وتحجز رصيد المزود وتمنع طلباً جديداً
export const ACTIVE_VIRTUAL_NUMBER_STATUSES: VirtualNumberStatus[] = [
  VirtualNumberStatus.PENDING,
  VirtualNumberStatus.WAITING,
  VirtualNumberStatus.RECEIVED,
];

@Schema({ timestamps: true })
export class VirtualNumberRequest {
  @Prop({ required: true, unique: true, index: true })
  requestNumber: string; // VN-YYMMDD-XXXX

  // معرّف إرسال العميل لمعادلة إعادة المحاولة بعد انقطاع الاستجابة (idempotency)
  @Prop({ trim: true, unique: true, sparse: true })
  clientRequestId?: string;

  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  userId: Types.ObjectId;

  // مستند المزود (Provider) الذي طُلب الرقم من خلاله
  @Prop({ type: Types.ObjectId, ref: 'Provider', index: true })
  providerId?: Types.ObjectId;

  // --- ما يختاره العميل من كتالوج المزود ---
  @Prop({ required: true, trim: true, index: true })
  service: string; // رمز الخدمة لدى المزود: telgr / whats / discord ...

  @Prop({ trim: true, default: '' })
  serviceName: string; // الاسم المعروض (Telegram)

  @Prop({ required: true, trim: true })
  country: string; // رمز الدولة لدى المزود: '0' / 'uk' ...

  @Prop({ trim: true, default: '' })
  countryName: string; // اسم الدولة المعروض

  @Prop({ trim: true, default: '' })
  operator: string; // رمز المشغّل (أي مشغّل حين يكون فارغاً)

  // المنتج (تطبيق+دولة+مزود) الذي بيع فعلاً: عقدة تسجيل الجودة. يُخلَّد على الطلب
  // لأن كتالوج المزود قد يتغير بعدها.
  @Prop({ type: Types.ObjectId, ref: 'VirtualNumberProduct', index: true })
  productId?: Types.ObjectId;

  // --- المال: يُحاسَب العميل من رصيد محفظته بالدولار ---
  @Prop({ type: Number, required: true, default: 0 })
  amount: number; // سعر البيع للعميل (تكلفة المزود + هامش ربح المزود)

  @Prop({ type: Number, required: true, default: 0 })
  cost: number; // تكلفة المزود لحظة الطلب

  @Prop({ type: Number, required: true, default: 0 })
  profit: number; // صافي الربح

  // --- ما يعيده المزود ---
  @Prop({ trim: true })
  providerRef?: string; // معرّف الطلب لدى مزود الأرقام لإلغاء الرقم أو فحص حالته

  @Prop({ trim: true })
  phoneNumber?: string; // الرقم الكامل كما سُلّم للعميل

  // رسالة SMS الكاملة الواردة (تُخزَّن مؤقتاً لحين إقفال الطلب)
  @Prop({ trim: true })
  smsText?: string;

  @Prop({ trim: true })
  smsCode?: string; // الرمز المستخرج من الرسالة

  @Prop({
    type: String,
    enum: VirtualNumberStatus,
    default: VirtualNumberStatus.PENDING,
    index: true,
  })
  status: VirtualNumberStatus;

  @Prop()
  codeReceivedAt?: Date;

  @Prop()
  closedAt?: Date;

  // وقت إرجاع المبلغ للعميل — وجوده يعني أن الإرجاع وقع، فلا يتكرر في المسح الدوري
  @Prop()
  refundedAt?: Date;

  // النتيجة التي سُجّلت في جودة المنتج: وجودها يعني أن التسجيل وقع، فلا يتكرر
  // (نفس نمط refundedAt — المسح الدوري والويب هوك وإغلاق العميل قد تسبق بعضها)
  @Prop({ trim: true })
  qualityOutcome?: string;

  @Prop()
  qualityRecordedAt?: Date;

  // مهلة الانتظار: بعدها يُلغى الرقم لدى المزود ويُرجع المبلغ تلقائياً
  @Prop({ index: true })
  expiresAt?: Date;

  @Prop({ trim: true })
  note?: string; // رسالة تُعرض للعميل: عبارة عامة بلا أسماء مزودين ولا تفاصيل ربط

  // سبب الإلغاء/الإغلاق الداخلي ومن نفّذه: للإدارة وحدها، فلا يخرج في payload
  // العميل لأن حرّاس الإدخال قد يكتبون فيه أسماء المزودين وملاحظاتهم
  @Prop({ trim: true })
  adminNote?: string;

  @Prop({ type: Object, default: {} })
  raw?: Record<string, any>; // آخر استجابة من المزود لأغراض التدقيق
}

export const VirtualNumberRequestSchema = SchemaFactory.createForClass(
  VirtualNumberRequest,
);

// فهارس: سجل العميل الزمني، ومسح الحالات الحيّة المنتهية المهلة
VirtualNumberRequestSchema.index({ userId: 1, createdAt: -1 });
VirtualNumberRequestSchema.index({ status: 1, expiresAt: 1 });
VirtualNumberRequestSchema.index({ status: 1, createdAt: -1 });
