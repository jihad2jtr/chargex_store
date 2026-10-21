import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { Role } from '../../common/interfaces/role.enum';

export type UserDocument = User & Document;

@Schema({ timestamps: true })
export class User {
  @Prop({ unique: true, sparse: true, index: true, trim: true })
  userId?: string;

  @Prop({ required: true, trim: true })
  name: string;

  @Prop({ required: true, unique: true, lowercase: true, trim: true, index: true })
  email: string;

  @Prop({ required: true })
  password: string;

  @Prop({ type: String, enum: Role, default: Role.USER, index: true })
  role: Role;

  @Prop({ type: Number, default: 0.0, min: 0 })
  balance: number; // Balance in USD

  @Prop({ trim: true })
  phone?: string;

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
    let unique = false;
    while (!unique) {
      const now = new Date();
      const yy = String(now.getFullYear()).slice(-2);
      const mm = String(now.getMonth() + 1).padStart(2, '0');
      const dd = String(now.getDate()).padStart(2, '0');
      const rand = Math.floor(10000 + Math.random() * 90000);
      const candidateId = `chx${yy}${mm}${dd}${rand}`;
      const existing = await model.findOne({ userId: candidateId });
      if (!existing) {
        this.userId = candidateId;
        unique = true;
      }
    }
  }
});
