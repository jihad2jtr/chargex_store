import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type VirtualNumberProductDocument = VirtualNumberProduct & Document;

// «منتج» الأرقام الوهمية: دولة واحدة ضمن تطبيق (خدمة) لدى مزود بعينه. هوية
// المنتج إذن = appId + providerId + countryCode، وهو ما يسمح بأن يظهر
// واتساب-الفلبين مرتين: عرض من «Server 1» وعرض مستقل من «Server 2».
// يُضاف من صفحة مزودي الأرقام باختيار الدولة من كتالوج المزود، وهو الذي يُفعَّل
// أو يُلغى ليظهر أو يختفي لدى العميل — مقابل منتج اللعبة في المتجر.
// السعر لا يُخزَّن هنا: يُحسب لحظياً من تكلفة المزود في الكتالوج الحيّ + هامش
// ربحه. لقطات الحقول (cost/count/operators) تُعرض في اللوحة فقط عند تعذّر الكتالوج.
@Schema({ timestamps: true })
export class VirtualNumberProduct {
  @Prop({
    type: Types.ObjectId,
    ref: 'VirtualNumberApp',
    required: true,
    index: true,
  })
  appId: Types.ObjectId;

  // رمز الخدمة الأصلي لدى هذا المزود بالذات (قد يختلف بين مزودين لنفس التطبيق)
  @Prop({ required: true, trim: true, index: true })
  serviceCode: string;

  // رمز الدولة لدى المزود ('1' / 'uk' ...)؛ بها يُخاطَب المزود عند الشراء
  @Prop({ required: true, trim: true })
  countryCode: string;

  @Prop({ trim: true, default: '' })
  countryName: string; // لقطة من اسم الدولة للعرض

  @Prop({ type: Number, default: 0 })
  cost: number; // لقطة تكلفة المزود لحظة الإضافة (للعرض عند غياب الكتالوج)

  @Prop({ type: Number, default: 0 })
  count: number; // لقطة عدد الأرقام المتاحة

  @Prop({ type: [Object], default: [] })
  operators: Array<{ code: string; name: string }>;

  // المزود الذي أُخذت منه الدولة: إلزامي لأن التقييم والجودة والسعر كلّه يخصّ مزوداً
  @Prop({
    type: Types.ObjectId,
    ref: 'Provider',
    required: true,
    index: true,
  })
  providerId: Types.ObjectId;

  @Prop({ default: true, index: true })
  isActive: boolean;

  // --- عدادات الجودة: تُبنى من نتائج الشراء الفعلية، لا من السعر ---
  // لا يُخلط تقييم مزود مع آخر: العدادات على وثيقة المنتج وحده.
  @Prop({
    type: Object,
    default: {
      totalOrders: 0,
      success: 0,
      failure: 0,
      cancelled: 0,
      outOfStock: 0,
      pending: 0,
      consecutiveFailures: 0,
    },
  })
  quality: {
    totalOrders: number;
    success: number;
    failure: number;
    cancelled: number;
    outOfStock: number;
    pending: number;
    consecutiveFailures: number;
  };

  // أوقفه النظام تلقائياً بعد بلوغ عتبة الفشل المتتالي المؤكد
  @Prop({ default: false, index: true })
  autoDisabled: boolean;

  @Prop()
  disabledAt?: Date;

  @Prop({ trim: true })
  disabledReason?: string;

  // من أوقفه يدوياً من اللوحة (الاسم الحقيقي للإدارة فقط)
  @Prop({ trim: true })
  disabledBy?: string;
}

export const VirtualNumberProductSchema = SchemaFactory.createForClass(
  VirtualNumberProduct,
);

// نفس التطبيق ونفس الدولة يجوز من مزودين مختلفين — لكن لا تُضاف الدولة مرتين
// لنفس المزود. هذا الفهرس هو جوهر السماح بتعدد المزودين.
VirtualNumberProductSchema.index(
  { appId: 1, providerId: 1, countryCode: 1 },
  { unique: true },
);
VirtualNumberProductSchema.index({ serviceCode: 1, countryCode: 1 });
