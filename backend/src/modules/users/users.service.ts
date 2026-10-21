import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Role } from '../../common/interfaces/role.enum';

@Injectable()
export class UsersService {
  constructor(@InjectModel(User.name) private userModel: Model<UserDocument>) {}

  async findAll() {
    return this.userModel.find().select('-password -refreshToken').sort({ createdAt: -1 });
  }

  async findOne(id: string) {
    const cleanId = id ? id.trim() : '';
    let user = await this.userModel.findOne({ userId: cleanId }).select('-password -refreshToken');
    if (!user && Types.ObjectId.isValid(cleanId)) {
      user = await this.userModel.findById(cleanId).select('-password -refreshToken');
    }
    if (!user) throw new NotFoundException('المستخدم غير موجود');
    return user;
  }

  async search(query: string) {
    return this.userModel
      .find({
        $or: [
          { userId: { $regex: query, $options: 'i' } },
          { name: { $regex: query, $options: 'i' } },
          { email: { $regex: query, $options: 'i' } },
          { phone: { $regex: query, $options: 'i' } },
        ],
      })
      .select('-password -refreshToken')
      .limit(20);
  }

  async toggleActive(id: string) {
    const cleanId = id ? id.trim() : '';
    let user = await this.userModel.findOne({ userId: cleanId });
    if (!user && Types.ObjectId.isValid(cleanId)) {
      user = await this.userModel.findById(cleanId);
    }
    if (!user) throw new NotFoundException('المستخدم غير موجود');
    user.isActive = !user.isActive;
    return user.save();
  }

  // Get all supervisors & admins that can be assigned to manual services
  async findSupervisors() {
    return this.userModel
      .find({
        role: { $in: [Role.SUPERVISOR, Role.ADMIN] },
        isActive: true,
      })
      .select('name email phone role userId createdAt')
      .sort({ name: 1 });
  }

  // Admin creates a new supervisor
  async createSupervisor(data: { name: string; email: string; password: string; phone?: string }) {
    const existing = await this.userModel.findOne({ email: data.email.toLowerCase().trim() });
    if (existing) {
      throw new Error('البريد الإلكتروني مسجل مسبقاً');
    }
    const bcrypt = await import('bcryptjs');
    const hashedPassword = await bcrypt.hash(data.password, 10);
    const userId = `chx${Date.now().toString().slice(-9)}`;

    const supervisor = new this.userModel({
      userId,
      name: data.name.trim(),
      email: data.email.toLowerCase().trim(),
      password: hashedPassword,
      phone: data.phone?.trim(),
      role: 'supervisor',
      balance: 0.0,
      isActive: true,
    });
    await supervisor.save();

    return {
      message: 'تم إنشاء حساب المشرف بنجاح',
      supervisor: {
        _id: supervisor._id,
        userId: supervisor.userId,
        name: supervisor.name,
        email: supervisor.email,
        phone: supervisor.phone,
        role: supervisor.role,
      },
    };
  }

  // Update user role (e.g. promote user to supervisor)
  async updateRole(id: string, role: string) {
    const cleanId = id ? id.trim() : '';
    let user = await this.userModel.findOne({ userId: cleanId });
    if (!user && Types.ObjectId.isValid(cleanId)) {
      user = await this.userModel.findById(cleanId);
    }
    if (!user) throw new NotFoundException('المستخدم غير موجود');
    user.role = role as any;
    await user.save();
    return {
      message: 'تم تحديث الرتبة بنجاح',
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    };
  }
}
