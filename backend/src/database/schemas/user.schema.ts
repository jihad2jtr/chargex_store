import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { Role } from '../../common/interfaces/role.enum';
import { generateUserId, userIdFilter } from '../../common/utils/user-id.util';

export type UserDocument = User & Document;

@Schema({ timestamps: true })
export class User {
  @Prop({ unique: true, sparse: true, index: true, trim: true })
  userId?: string;

  @Prop({ required: true, trim: true })
  name: string;

  @Prop({
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
    index: true,
  })
  email: string;

  @Prop({ required: true })
  password: string;

  @Prop({ type: String, enum: Role, default: Role.USER, index: true })
  role: Role;

  @Prop({ type: Number, default: 0.0, min: 0 })
  balance: number; // Balance in USD

  @Prop({ trim: true })
  phone?: string;

  // رابط الصورة الشخصية (من /upload/image) — فارغة يعني بلا صورة
  @Prop({ trim: true })
  avatar?: string;

  @Prop()
  refreshToken?: string;

  @Prop({ type: [String], default: [] })
  fcmTokens: string[];

  @Prop({ default: true })
  isActive: boolean;

  @Prop({ type: Types.ObjectId, ref: 'User', index: true })
  parentAgentId?: Types.ObjectId;

  @Prop({ default: false })
  deactivatedByAgent?: boolean;

  @Prop({ trim: true })
  agentDeactivationReason?: string;

  @Prop({ trim: true })
  agentNotes?: string;
}

export const UserSchema = SchemaFactory.createForClass(User);

UserSchema.pre('save', async function () {
  if (!this.userId) {
    const model = this.constructor as any;
    // الآيدي المتولدة دائماً بأحرف كبيرة: JGO + yyMMdd + 5 أرقام
    this.userId = await generateUserId(async (candidateId) =>
      Boolean(await model.findOne(userIdFilter(candidateId))),
    );
  }
});
