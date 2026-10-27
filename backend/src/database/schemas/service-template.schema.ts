import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
import { ProductType } from './product.schema';

export type ServiceTemplateDocument = ServiceTemplate & Document;

/** أنواع حقول الإدخال الثابتة المتاحة للأدمن عند بناء قالب خدمة */
export enum ServiceFieldType {
  PLAYER_ID = 'player_id', // ايدي
  PHONE = 'phone', // رقم هاتف
  NAME = 'name', // الاسم
  EMAIL = 'email', // ايميل
  PASSWORD = 'password', // كلمة مرور
  QUANTITY = 'quantity', // كمية مع أسهمي زيادة/نقصان
  CUSTOM = 'custom', // حقل مخصص برأس حر
}

/** أنواع الحقول الحساسة التي تتطلب تخزيناً مشفّراً وإتلافاً تلقائياً */
export const SENSITIVE_FIELD_TYPES: ServiceFieldType[] = [
  ServiceFieldType.PASSWORD,
];

@Schema({ _id: false })
export class ServiceFieldDef {
  @Prop({ type: String, enum: ServiceFieldType, required: true })
  type: ServiceFieldType;

  @Prop({ required: true, trim: true })
  label: string; // التسمية العربية التي يراها المستخدم

  @Prop({ default: true })
  required: boolean;

  @Prop({ default: false })
  isSensitive: boolean;

  @Prop({ trim: true, default: '' })
  placeholder?: string;
}

export const ServiceFieldDefSchema =
  SchemaFactory.createForClass(ServiceFieldDef);

@Schema({ timestamps: true })
export class ServiceTemplate {
  @Prop({ required: true, trim: true })
  name: string; // مثال: خدمة شحن عبر الحساب

  @Prop({ trim: true, default: '' })
  description: string;

  @Prop({
    type: String,
    enum: ProductType,
    default: ProductType.MANUAL,
    index: true,
  })
  operationType: ProductType; // نوع العملية المرتبط بالقالب

  @Prop({ type: [ServiceFieldDefSchema], default: [] })
  fields: ServiceFieldDef[];

  @Prop({ default: 0, index: true })
  sortOrder: number;

  @Prop({ default: true, index: true })
  isActive: boolean;
}

export const ServiceTemplateSchema =
  SchemaFactory.createForClass(ServiceTemplate);
