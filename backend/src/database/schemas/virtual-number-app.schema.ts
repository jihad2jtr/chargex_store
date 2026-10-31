import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type VirtualNumberAppDocument = VirtualNumberApp & Document;

// «تطبيق» الأرقام الوهمية: الخدمة التي يريد العميل التسجيل فيها (تليجرام/واتساب…).
// يُنشأ هنا فارغاً من شاشة إدارة الأرقام — مثل تطبيقات المتجر تماماً — ثم تُضاف
// دوله (منتجاته) من صفحة مزودي الأرقام. العميل لا يرى خدمة إلا إذا كان تطبيقها
// مفعّلاً ويملك دولة واحدة مفعّلة على الأقل تُسعَّر من كتالوج المزود الحيّ.
@Schema({ timestamps: true })
export class VirtualNumberApp {
  @Prop({ required: true, trim: true })
  name: string; // الاسم المعروض للعميل (Telegram)

  @Prop({ trim: true })
  iconUrl?: string; // رابط أيقونة أو 'builtin:<key>'

  // رمز الخدمة لدى المزود (telegram / whatsapp ...)؛ يُطابَق به الكتالوج الحيّ.
  // المطابقة تتم بالرمز لا بمعرّف المزود، فيبقى التطبيق صالحاً عند تبديل المزود
  // ما دام الرمز موجوداً في كتالوجه.
  @Prop({ required: true, trim: true, index: true })
  serviceCode: string;

  // المعرّف المنطقي من المعجم (resolveAppMeta(...).key): يبقى التطبيق واحداً
  // (واتساب مثلاً) مهما اختلف رمز الخدمة لدى كل مزود. غير فريد لأن الفهرس الفريد
  // الحقيقي هو رمز الخدمة `serviceCode`.
  @Prop({ trim: true, index: true })
  appKey?: string;

  // مزود الأرقام الذي عُرِّف التطبيق من كتالوجه (اختياري: للمرجعية وتحديث الأسعار)
  @Prop({ type: Types.ObjectId, ref: 'Provider', index: true })
  providerId?: Types.ObjectId;

  // تطبيق جديد يبدأ مفعّلاً للوحة لكنه لا يظهر للعميل قبل إضافة دولة مفعّلة،
  // فالفلترة عند العميل تشترط وجود منتج (دولة) مفعّل واحد على الأقل.
  @Prop({ default: true, index: true })
  isActive: boolean;

  @Prop({ default: 0, index: true })
  sortOrder: number;
}

export const VirtualNumberAppSchema = SchemaFactory.createForClass(
  VirtualNumberApp,
);

// لا تكرار لتطبيق نفس الخدمة: خدمة واحدة = تطبيق واحد في اللوحة
VirtualNumberAppSchema.index({ serviceCode: 1 }, { unique: true });
