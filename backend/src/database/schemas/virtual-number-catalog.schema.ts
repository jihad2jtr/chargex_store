import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type VirtualNumberCatalogDocument = VirtualNumberCatalog & Document;

export interface VirtualNumberCountry {
  code: string;
  name: string;
  cost: number; // تكلفة المزود بالدولار
  operators: Array<{ code: string; name: string }>;
  count?: number; // عدد الأرقام المتاحة لدى المزود
}

export interface VirtualNumberService {
  code: string;
  name: string;
  countries: VirtualNumberCountry[];
}

// كتالوج الأرقام الوهمية: خدمة/دولة/سعر تُقرأ من المزود (5sim) وتُخزَّن هنا،
// فلا يُستدعى المزود مع كل فتح للصفحة وتبقى الأسعار معروضة حتى لو تعذّر الاتصال.
// مستند واحد لكل مزود أرقام وهمية، والسعر المعروض للعميل = تكلفة المزود + هامش ربحه.
@Schema({ timestamps: true })
export class VirtualNumberCatalog {
  @Prop({
    type: Types.ObjectId,
    ref: 'Provider',
    required: true,
    unique: true,
    index: true,
  })
  providerId: Types.ObjectId;

  // كتلة أسعار غير قابلة للاستعلام (تُقرأ كاملة ثم تُفلتر في الذاكرة)
  @Prop({ type: Object, default: [] })
  services: VirtualNumberService[];

  // عدد الخدمات المخزّنة — يُعرض في لوحة الإدارة دون تحميل المصفوفة
  @Prop({ type: Number, default: 0 })
  serviceCount: number;

  @Prop()
  fetchedAt?: Date;

  @Prop({ trim: true, default: '' })
  lastError: string;
}

export const VirtualNumberCatalogSchema =
  SchemaFactory.createForClass(VirtualNumberCatalog);
