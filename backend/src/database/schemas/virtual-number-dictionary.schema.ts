import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type VirtualNumberDictionaryDocument = VirtualNumberDictionary &
  Document;

// «معجم التطبيقات»: المرجع المركزي الموحّد لهوية التطبيق عبر كل المزودين.
// كان بوابة «متاح/مخفي» فقط (appKey + offered) والأسماء تُقرأ من مصفوفة ثابتة؛
// صار كياناً كاملاً يحمل الهوية الموحّدة ورموز كل مزود الأصلية ومصادرها.
//   - الهوية هنا (key + أسماء + codes لكل مزود)، والسعر/المخزون في الكتالوج،
//     والاختيار للبيع في المنتجات — بلا خلط.
//   - `offered` وحده بوابة الظهور للمزودين والعميل؛ الإيقاف إخفاءٌ عرضي لا امّحاء.
//   - الاستيراد من المزودين لا يقلب `offered` إلى true إطلاقاً: المتاح قرار إداري.
@Schema({ timestamps: true })
export class VirtualNumberDictionary {
  // المعرّف الموحّد الثابت للتطبيق (كان resolveAppMeta(...).key) — صغير بلا مسافات
  @Prop({ required: true, unique: true, trim: true, lowercase: true, index: true })
  appKey: string;

  // بوابة الظهور للمزودين والعميل (المعجم القديم: الحقل الوحيد المدار)
  @Prop({ default: false })
  offered: boolean;

  @Prop({ trim: true })
  nameEn?: string;

  @Prop({ trim: true })
  nameAr?: string;

  // اسم الأيقونة/الشعار المتوفر في التطبيق (أو رابط)
  @Prop({ trim: true })
  icon?: string;

  // الرمز الأصلي لكل مزود: { herosms: 'wa', fivesim: 'whatsapp', dogesms: 'wa' ... }
  // المفاتيح = قيم ProviderType النصية، فيدعم أي مزود مستقبلي بلا تعديل البنية.
  @Prop({ type: Object, default: {} })
  codes: Record<string, string>;

  // مرادفات وأكواد إضافية للبحث والمطابقة
  @Prop({ type: [String], default: [] })
  aliases: string[];

  // مصدر الكيان: بذر من الثابت / استيراد من مزود / إنشاء يدوي
  @Prop({ type: String, enum: ['seed', 'import', 'manual'], default: 'seed' })
  origin: 'seed' | 'import' | 'manual';

  // سجل تدقيق: أي اسم/رمز من أي مزود ومتى حُدِّث (القاعدة: لا يُفقد مصدر الاسم)
  @Prop({
    type: [
      {
        providerType: String,
        rawCode: String,
        rawName: String,
        syncedAt: Date,
        _id: false,
      },
    ],
    default: [],
  })
  sources: Array<{
    providerType: string;
    rawCode: string;
    rawName: string;
    syncedAt: Date;
  }>;

  // حالة المطابقة: مؤكّدة، أو بحاجة مراجعة يدوية (اسم يحتمل أكثر من هوية)
  @Prop({ type: String, enum: ['ok', 'review'], default: 'ok' })
  reviewStatus: 'ok' | 'review';
}

export const VirtualNumberDictionarySchema = SchemaFactory.createForClass(
  VirtualNumberDictionary,
);
