import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type VirtualNumberDictionaryDocument = VirtualNumberDictionary &
  Document;

// «معجم التطبيقات المتاح»: مفتاح توفر لكل تطبيق من المعجم الموحّد.
// القائمة كانت ثابتة في الكود (popular-apps.ts بـ200 تطبيقاً) وصارت بيانات
// تُدار من صفحة «معجم التطبيقات»: التطبيق المتاح وحده يظهر في انتقاء الدول
// لدى المزودين، ويُقبل في الاستيراد الجماعي، ويصل إلى شاشة العميل.
// الإيقاف إخفاءٌ عرضي لا امّحاء: وثاقات التطبيق ومنتجاتها تبقى في القاعدة.
@Schema({ timestamps: true })
export class VirtualNumberDictionary {
  // مفتاح المعجم الموحّد (resolveAppMeta(...).key) — صغير بلا مسافات
  @Prop({ required: true, unique: true, trim: true, lowercase: true })
  appKey: string;

  @Prop({ default: true })
  offered: boolean;

  // مرجع للعرض فقط؛ الأسماء والأيقونات تُقرأ من المعجم الثابت
  @Prop({ trim: true })
  nameEn?: string;
}

export const VirtualNumberDictionarySchema = SchemaFactory.createForClass(
  VirtualNumberDictionary,
);
