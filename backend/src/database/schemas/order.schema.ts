import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { ProductType } from './product.schema';

export type OrderDocument = Order & Document;

export enum OrderStatus {
  PENDING = 'pending',
  ASSIGNED = 'assigned',
  ACCEPTED = 'accepted',
  IN_PROGRESS = 'in_progress',
  INFO_REQUESTED = 'info_requested',
  DELIVERED = 'delivered',
  REVISION_REQUESTED = 'revision_requested',
  DISPUTED = 'disputed',
  COMPLETED = 'completed',
  REJECTED = 'rejected',
  REFUNDED = 'refunded',
}

@Schema({ _id: false })
export class OrderTimelineEvent {
  @Prop({ required: true })
  action: string; // 'created_paid' | 'assigned' | 'accepted' | 'started' | 'info_requested' | 'delivered' | 'revision_requested' | 'confirmed' | 'disputed' | 'reassigned' | 'refunded'

  @Prop({ required: true })
  title: string;

  @Prop()
  description?: string;

  @Prop({ type: Types.ObjectId, ref: 'User' })
  performerId?: Types.ObjectId;

  @Prop({ default: 'النظام' })
  performerName: string;

  @Prop({ default: 'system' })
  performerRole: string; // 'system' | 'customer' | 'supervisor' | 'admin'

  @Prop({ default: Date.now })
  timestamp: Date;
}

export const OrderTimelineEventSchema = SchemaFactory.createForClass(OrderTimelineEvent);

@Schema({ _id: true, timestamps: true })
export class OrderChatMessage {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  senderId: Types.ObjectId;

  @Prop({ required: true })
  senderName: string;

  @Prop({ required: true })
  senderRole: string; // 'user' | 'supervisor' | 'admin'

  @Prop({ default: '' })
  message: string;

  @Prop()
  attachmentUrl?: string;

  @Prop()
  attachmentName?: string;

  @Prop()
  attachmentType?: string; // 'image' | 'file'

  @Prop({ default: false })
  isSensitive?: boolean;

  @Prop({ default: Date.now })
  createdAt: Date;
}

export const OrderChatMessageSchema = SchemaFactory.createForClass(OrderChatMessage);

@Schema({ timestamps: true })
export class Order {
  @Prop({ required: true, unique: true, index: true })
  orderNumber: string;

  // معرّف إرسال العميل لمعادلة إعادة المحاولة بعد انقطاع الاستجابة (idempotency)
  @Prop({ trim: true, unique: true, sparse: true })
  requestId?: string;

  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'App', required: true, index: true })
  appId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'Product', required: true, index: true })
  productId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'Provider' })
  providerId?: Types.ObjectId;

  @Prop({ type: String, enum: ProductType, required: true, index: true })
  type: ProductType;

  @Prop({ type: Number, required: true })
  amount: number; // Sale price in USD charged to user

  @Prop({ type: Number, required: true, default: 0.0 })
  cost: number; // Provider cost at time of purchase

  @Prop({ type: Number, required: true, default: 0.0 })
  profit: number; // Net profit

  @Prop({ type: String, enum: OrderStatus, default: OrderStatus.PENDING, index: true })
  status: OrderStatus;

  @Prop({ type: Object, default: {} })
  accountInput: Record<string, any>; // Player ID, account details entered by customer

  @Prop({ trim: true })
  adminNotes?: string; // Acceptance note or rejection reason

  @Prop({ trim: true })
  deliveredCode?: string; // Digital card code delivered to client

  @Prop({ trim: true })
  providerReference?: string;

  @Prop({ type: Object, default: {} })
  providerResponse?: Record<string, any>;

  @Prop()
  providerSettledAt?: Date; // Set once the provider execution is confirmed/reconciled

  // --- Manual Human Execution System Fields ---
  @Prop({ type: Types.ObjectId, ref: 'User', index: true })
  assignedSupervisorId?: Types.ObjectId; // Supervisor executing this manual service

  @Prop({ type: Number, default: 120 })
  estimatedMinutes?: number; // SLA in minutes

  @Prop({ index: true })
  deadlineAt?: Date; // Expected completion time

  @Prop()
  acceptedAt?: Date;

  @Prop()
  startedAt?: Date;

  @Prop()
  deliveredAt?: Date;

  @Prop()
  completedAt?: Date;

  @Prop({ type: Boolean, default: false })
  isSensitive?: boolean; // Sensitive credentials flag

  @Prop({ type: [String], default: [] })
  sensitiveFields?: string[];

  @Prop({ trim: true })
  encryptedResultData?: string; // AES-256 encrypted result credentials (e.g. Gmail pass, 2FA backup codes)

  @Prop({ trim: true })
  resultNotes?: string; // Delivery note/explanation shown to customer

  @Prop({ type: [String], default: [] })
  resultAttachments?: string[]; // Result screenshot URLs / proof of work

  @Prop({ type: Boolean, default: false })
  isResultPurged?: boolean; // Set true when sensitive data is deleted after confirmation

  @Prop()
  purgedAt?: Date;

  @Prop({ trim: true })
  rejectionReason?: string; // Reason given by supervisor if rejected

  @Prop({ trim: true })
  disputeReason?: string; // Reason given by customer when opening dispute

  @Prop({ trim: true })
  revisionNotes?: string; // Notes given by customer when asking for revision

  @Prop({ type: [OrderTimelineEventSchema], default: [] })
  timeline: OrderTimelineEvent[];

  @Prop({ type: [OrderChatMessageSchema], default: [] })
  chatMessages: OrderChatMessage[];
}

export const OrderSchema = SchemaFactory.createForClass(Order);

// فهارس تُسرّع استعلامات اللوحة (تصفية بالنطاق الزمني، الترتيب، والتصفية بالحالة/النوع)
OrderSchema.index({ createdAt: -1 });
OrderSchema.index({ status: 1, createdAt: -1 });
OrderSchema.index({ type: 1, createdAt: -1 });
