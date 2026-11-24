import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import * as crypto from 'crypto';
import { ShippingCode, ShippingCodeDocument } from '../../database/schemas/shipping-code.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { WalletService } from '../wallet/wallet.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class CodesService {
  constructor(
    @InjectModel(ShippingCode.name) private codeModel: Model<ShippingCodeDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private walletService: WalletService,
    private notificationsService: NotificationsService,
  ) {}

  // Generate unique codes (e.g. CHG-9482-KLAX)
  private generateRandomCode(): string {
    const part1 = crypto.randomBytes(2).toString('hex').toUpperCase();
    const part2 = crypto.randomBytes(2).toString('hex').toUpperCase();
    return `CHG-${part1}-${part2}`;
  }

  // معرّف الدفعة: يطبع في عنوان كل قسيمة ضمن مجموعة واحدة (B-20261028-3F1A)
  private generateBatchId(): string {
    const now = new Date();
    const stamp = [
      now.getFullYear(),
      String(now.getMonth() + 1).padStart(2, '0'),
      String(now.getDate()).padStart(2, '0'),
    ].join('');
    return `B-${stamp}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
  }

  // Admin: create batch of shipping / recharge codes
  async generateCodes(params: {
    amount: number;
    count: number;
    adminId: string;
    note?: string;
  }) {
    if (params.amount <= 0) {
      throw new BadRequestException('قيمة الكود يجب أن تكون أكبر من صفر');
    }
    const count = Math.min(Math.max(params.count || 1, 1), 50);
    const batchId = this.generateBatchId();
    const batchNote = (params.note || '').trim() || undefined;
    const createdCodes: ShippingCodeDocument[] = [];

    for (let i = 0; i < count; i++) {
      let uniqueCode = this.generateRandomCode();
      // Ensure code does not collide
      while (await this.codeModel.findOne({ code: uniqueCode })) {
        uniqueCode = this.generateRandomCode();
      }

      const item = new this.codeModel({
        code: uniqueCode,
        amount: params.amount,
        isUsed: false,
        isActive: true,
        createdBy: new Types.ObjectId(params.adminId),
        batchId,
        batchNote,
      });
      await item.save();
      createdCodes.push(item);
    }

    return {
      message: `تم إنشاء ${createdCodes.length} كود شحن بقيمة $${params.amount} بنجاح`,
      batchId,
      batchNote,
      codes: createdCodes,
    };
  }

  // Admin: get all codes with pagination/filter
  async getAllCodes(filter?: { isUsed?: boolean; isActive?: boolean }) {
    const query: any = {};
    if (filter?.isUsed !== undefined) query.isUsed = filter.isUsed;
    if (filter?.isActive !== undefined) query.isActive = filter.isActive;

    return this.codeModel
      .find(query)
      .populate('usedBy', 'name email phone userId')
      .sort({ createdAt: -1 })
      // سقف مرتفع كي لا تنقص دفعة عند التصدير (حدف الوسط = قسائم مفقودة في الـ PDF)
      .limit(500);
  }

  // Admin: toggle active code
  async toggleActive(id: string) {
    const code = await this.codeModel.findById(id);
    if (!code) throw new NotFoundException('الكود غير موجود');
    code.isActive = !code.isActive;
    return code.save();
  }

  // Admin: delete code
  async remove(id: string) {
    const code = await this.codeModel.findByIdAndDelete(id);
    if (!code) throw new NotFoundException('الكود غير موجود');
    return { message: 'تم حذف الكود بنجاح' };
  }

  // User: redeem code to get balance (ذري: يمنع الاسترداد المزدوج عند التزامن)
  async redeemCode(codeString: string, userId: string) {
    const cleanCode = codeString.trim().toUpperCase();
    const claimed = await this.codeModel.findOneAndUpdate(
      { code: cleanCode, isActive: true, isUsed: false },
      {
        $set: {
          isUsed: true,
          usedBy: new Types.ObjectId(userId),
          usedAt: new Date(),
        },
      },
      { new: true },
    );

    if (!claimed) {
      const existing = await this.codeModel.findOne({ code: cleanCode });
      if (!existing) {
        throw new BadRequestException('كود الشحن غير صحيح');
      }
      if (!existing.isActive) {
        throw new BadRequestException('هذا الكود معطل حالياً');
      }
      throw new BadRequestException('هذا الكود تم استخدامه مسبقاً');
    }

    // Credit user's wallet; roll back code claim if wallet credit fails
    try {
      const rechargeResult = await this.walletService.adminAdjustBalance({
        userId,
        amount: claimed.amount,
        description: `شحن عبر كود رقمي: ${claimed.code}`,
        adminId: userId,
        referenceType: 'ShippingCode',
        referenceId: claimed._id.toString(),
      });

      return {
        message: `تم شحن رصيدك بنجاح بمبلغ $${claimed.amount.toFixed(2)}`,
        amountAdded: claimed.amount,
        newBalance: rechargeResult.user.balance,
      };
    } catch (err) {
      await this.codeModel.findByIdAndUpdate(claimed._id, {
        $set: { isUsed: false },
        $unset: { usedBy: 1, usedAt: 1 },
      });
      throw err;
    }
  }

  // Check code validity without redeeming
  async verifyCode(codeString: string) {
    const cleanCode = (codeString || '').trim().toUpperCase();
    if (!cleanCode) {
      throw new BadRequestException('يرجى إدخال كود الشحن');
    }
    const code = await this.codeModel.findOne({ code: cleanCode });
    if (!code) {
      return {
        valid: false,
        message: 'كود الشحن غير صحيح أو غير موجود',
      };
    }
    if (!code.isActive) {
      return {
        valid: false,
        message: 'هذا الكود معطل حالياً',
      };
    }
    if (code.isUsed) {
      return {
        valid: false,
        message: 'هذا الكود تم استخدامه مسبقاً',
      };
    }
    return {
      valid: true,
      amount: code.amount,
      message: `كود صالح بقيمة $${code.amount.toFixed(2)}`,
    };
  }
}
