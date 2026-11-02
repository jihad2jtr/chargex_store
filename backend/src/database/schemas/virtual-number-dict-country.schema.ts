import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type VirtualNumberDictCountryDocument = VirtualNumberDictCountry &
  Document;

// «معجم الدول»: المرجع المركزي الموحّد لهوية الدولة عبر كل المزودين.
// كل دولة لها رمز ISO قياسي ثابت (`code`)، وتحتها رموز كل مزود الأصلية
// (Hero-SMS رقمي كـ"21"، 5sim نصي كـ"egypt"، وغيرها). الأسماء والعلم هنا،
// والسعر/المخزون في الكتالوج، والبيع في المنتجات. بوابة الظهور على التطبيق
// وحده لا على الدولة، لذا لا `offered` هنا.
@Schema({ timestamps: true })
export class VirtualNumberDictCountry {
  // المعرّف الموحّد الثابت: رمز ISO-2 قياسي (يُصحَّح التصادم عند البذر)
  @Prop({ required: true, unique: true, trim: true, uppercase: true, index: true })
  code: string;

  @Prop({ trim: true })
  nameEn?: string;

  @Prop({ trim: true })
  nameAr?: string;

  @Prop({ trim: true })
  flag?: string;

  // الرمز الأصلي لكل مزود: { herosms: '21', fivesim: 'egypt', dogesms: 'EG' ... }
  @Prop({ type: Object, default: {} })
  codes: Record<string, string>;

  @Prop({ type: [String], default: [] })
  aliases: string[];

  @Prop({ type: String, enum: ['seed', 'import', 'manual'], default: 'seed' })
  origin: 'seed' | 'import' | 'manual';

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

  @Prop({ type: String, enum: ['ok', 'review'], default: 'ok' })
  reviewStatus: 'ok' | 'review';
}

export const VirtualNumberDictCountrySchema = SchemaFactory.createForClass(
  VirtualNumberDictCountry,
);
