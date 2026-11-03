import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type VirtualNumberProductDocument = VirtualNumberProduct & Document;

// «منتج» الأرقام الوهمية: دولة واحدة ضمن تطبيق (خدمة) لدى مزود بعينه، ومشغّل
// بعينه («سيرفر»: Hero-SMS / 5sim يعرضان الخدمة نفسها عبر مشغّلين لكل منهم سعره
// ومخزونه). هوية المنتج إذن = appId + providerId + countryCode + operator، وهو ما
// يسمح بأن يظهر واتساب-الفلبين مرتين لمزود واحد: مرة عبر مشغّل ومرة عبر آخر.
// يُضاف من صفحة مزودي الأرقام باختيار الدولة والمشغّل من كتالوج المزود، وهو الذي
// يُفعَّل أو يُلغى ليظهر أو يختفي لدى العميل — مقابل منتج اللعبة في المتجر.
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

  // المشغّل («سيرفر») الذي يُشترى منه هذا المنتج: يُرسل للمزود عند الطلب، وبه
  // تفترق المنتجات عن بعضها لنفس الدولة. الفراغ = أي مشغّل متاح (نمط المزودين
  // الذين لا يعرضون مشغّلين، أو بيانات قديمة قبل هذا الحقل).
  @Prop({ trim: true, default: '', index: true })
  operator: string;

  @Prop({ trim: true, default: '' })
  operatorName: string; // لقطة اسم المشغّل للعرض (Orange، axis…)

  @Prop({ trim: true, default: '' })
  operatorType: string; // physical | virtual كما يسميه المزود (للعرض)

  @Prop({ type: Number, default: 0 })
  cost: number; // لقطة تكلفة المزود لحظة الإضافة (للعرض عند غياب الكتالوج)

  @Prop({ type: Number, default: 0 })
  count: number; // لقطة عدد الأرقام المتاحة

  // لقطة مشغّلي الدولة كما وصلت من المزود (بأسعارهم) للعرض في اللوحة
  @Prop({ type: [Object], default: [] })
  operators: Array<{
    code: string;
    name: string;
    price?: number;
    type?: string;
    count?: number;
  }>;

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

// نفس التطبيق ونفس الدولة يجوز من مزودين مختلفين، ومن مشغّلين مختلفين لنفس
// المزود — لكن لا تُضاف (الدولة + المشغّل) مرتين لنفس المزود. هذا الفهرس هو جوهر
// السماح بتعدد السيرفرات (المشغّلين) لكل مزود.
// ملاحظة: الفهرس القديم {appId, providerId, countryCode} يُسقَط عند الإقلاع
// (VirtualNumbersService.onModuleInit) لأنه كان يمنع وجود مشغّلين لنفس الدولة.
export const VIRTUAL_NUMBER_PRODUCT_LEGACY_INDEX =
  'appId_1_providerId_1_countryCode_1';
VirtualNumberProductSchema.index(
  { appId: 1, providerId: 1, countryCode: 1, operator: 1 },
  { unique: true },
);
VirtualNumberProductSchema.index({ serviceCode: 1, countryCode: 1 });
