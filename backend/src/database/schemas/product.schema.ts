import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type ProductDocument = Product & Document;

export enum ProductType {
  DIRECT_API = 'direct_api',
  CODES = 'codes',
  MANUAL = 'manual',
}

export enum ProfitMarginType {
  PERCENTAGE = 'percentage',
  FIXED = 'fixed',
}

@Schema({ timestamps: true })
export class Product {
  // منتجات المتجر ترتبط بتطبيق متجر. أما «خدمات الأرقام اليدوية» فلا تطبيق
  // متجر لها وترتبط بتطبيق أرقام عبر virtualNumberAppId، لذا appId اختياري.
  @Prop({ type: Types.ObjectId, ref: 'App', index: true })
  appId?: Types.ObjectId;

  // خدمة يدوية للأرقام: تُربط بتطبيق أرقام (تليجرام/واتساب…) بدل تطبيق المتجر
  @Prop({ type: Types.ObjectId, ref: 'VirtualNumberApp', index: true })
  virtualNumberAppId?: Types.ObjectId;

  @Prop({ required: true, trim: true })
  name: string;

  @Prop({ type: Types.ObjectId, ref: 'ServiceTemplate', index: true })
  serviceTemplateId?: Types.ObjectId; // نوع العملية: قالب الخدمة المرتبط بالمنتج

  @Prop({ trim: true, default: '' })
  quantityLabel: string; // حجم الكمية الوصفي للمنتج (مثال: 60 UC)

  // الفئة التفصيلية داخل التطبيق/اللعبة (كمية / باقة / أي فئة مخصصة تضيفها الإدارة)
  // تُخزَّن كنص حر لتفادي ربط الميزة بقائمة ثابتة: القيم المدمجة quantity و package
  // وأي قيمة أخرى تُعرض كما هي في واجهة المتجر
  @Prop({ trim: true, default: 'quantity', index: true })
  kind: string;

  @Prop({ trim: true })
  description?: string;

  @Prop({ type: String, enum: ProductType, default: ProductType.DIRECT_API, index: true })
  type: ProductType;

  @Prop({ type: Types.ObjectId, ref: 'Provider', index: true })
  providerId?: Types.ObjectId;

  @Prop({ trim: true })
  providerProductCode?: string;

  @Prop({ type: Number, required: true, default: 0.0 })
  costPrice: number; // Cost price in USD

  @Prop({ type: String, enum: ProfitMarginType, default: ProfitMarginType.PERCENTAGE })
  profitMarginType: ProfitMarginType;

  @Prop({ type: Number, default: 10.0 })
  profitMarginValue: number;

  @Prop({ type: Number, required: true, default: 0.0 })
  salePrice: number; // Final calculated price in USD

  @Prop({ type: Number })
  previousPrice?: number; // Shown dimmed under the new price if updated

  @Prop({ type: Boolean, default: false })
  hasPriceChanged: boolean;

  @Prop({ default: true, index: true })
  isActive: boolean;

  @Prop({ type: [String], default: [] })
  inventoryCodes: string[]; // Stock of digital gift card codes (Google Play, etc.)

  @Prop({ type: [String], default: ['Player ID'] })
  requiredFields: string[]; // Input fields required from user upon purchase

  // Manual Services Configuration
  @Prop({ type: Types.ObjectId, ref: 'User', index: true })
  assignedSupervisorId?: Types.ObjectId; // Default supervisor responsible for this manual service

  @Prop({ type: Number, default: 120 })
  estimatedMinutes?: number; // Estimated execution SLA in minutes (e.g. 60 or 120)

  @Prop({ type: Boolean, default: false })
  isSensitive?: boolean; // If true, credentials & data are AES-256 encrypted & auto-purged

  @Prop({ type: [String], default: [] })
  sensitiveFields?: string[]; // Specific keys in customer input/output that require encryption (e.g. ['password'])

  @Prop({ trim: true })
  instructions?: string; // Execution guidelines for customer or supervisor
}

export const ProductSchema = SchemaFactory.createForClass(Product);
