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

  // Admin: create batch of shipping / recharge codes
  async generateCodes(params: {
    amount: number;
    count: number;
    adminId: string;
  }) {
    if (params.amount <= 0) {
      throw new BadRequestException('قيمة الكود يجب أن تكون أكبر من صفر');
    }
    const count = Math.min(params.count || 1, 50);
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
      });
      await item.save();
      createdCodes.push(item);
    }

    return {
      message: `تم إنشاء ${createdCodes.length} كود شحن بقيمة $${params.amount} بنجاح`,
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
      .limit(200);
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

  // User: redeem code to get balance
  async redeemCode(codeString: string, userId: string) {
    const cleanCode = codeString.trim().toUpperCase();
    const code = await this.codeModel.findOne({ code: cleanCode });

    if (!code) {
      throw new BadRequestException('كود الشحن غير صحيح');
    }

    if (!code.isActive) {
      throw new BadRequestException('هذا الكود معطل حالياً');
    }

    if (code.isUsed) {
      throw new BadRequestException('هذا الكود تم استخدامه مسبقاً');
    }

    // Mark code as used
    code.isUsed = true;
    code.usedBy = new Types.ObjectId(userId);
    code.usedAt = new Date();
    await code.save();

    // Credit user's wallet
    const rechargeResult = await this.walletService.adminAdjustBalance({
      userId,
      amount: code.amount,
      description: `شحن عبر كود رقمي: ${code.code}`,
      adminId: userId,
    });

    return {
      message: `تم شحن رصيدك بنجاح بمبلغ $${code.amount.toFixed(2)}`,
      amountAdded: code.amount,
      newBalance: rechargeResult.user.balance,
    };
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
