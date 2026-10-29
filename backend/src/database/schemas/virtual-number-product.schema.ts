import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type VirtualNumberProductDocument = VirtualNumberProduct & Document;

// «منتج» الأرقام الوهمية: دولة واحدة ضمن تطبيق (خدمة). يُضاف من صفحة مزودي
// الأرقام باختيار الدولة من كتالوج المزود، وهو الذي يُفعَّل أو يُلغى ليظهر أو
// يختفي لدى العميل في صفحة الأرقام — مقابل منتج اللعبة في المتجر.
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

  // رمز الخدمة (يُطابق تطبيقه) — يُستخدم للتحقق السريع قبل الطلب دون جلب التطبيق
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

  // المزود الذي أُخذت منه الدولة (مرجعي لتحديث الأسعار)
  @Prop({ type: Types.ObjectId, ref: 'Provider', index: true })
  providerId?: Types.ObjectId;

  @Prop({ default: true, index: true })
  isActive: boolean;
}

export const VirtualNumberProductSchema = SchemaFactory.createForClass(
  VirtualNumberProduct,
);

// دولة واحدة لكل تطبيق: لا تكرار للإضافة، وسرعة في التحقق عند الطلب
VirtualNumberProductSchema.index({ appId: 1, countryCode: 1 }, { unique: true });
VirtualNumberProductSchema.index({ serviceCode: 1, countryCode: 1 });
