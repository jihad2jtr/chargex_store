import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import {
  WalletTransaction,
  WalletTransactionDocument,
  TransactionType,
  TransactionStatus,
} from '../../database/schemas/wallet-transaction.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { userIdFilter } from '../../common/utils/user-id.util';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class WalletService {
  constructor(
    @InjectModel(WalletTransaction.name)
    private transactionModel: Model<WalletTransactionDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private notificationsService: NotificationsService,
  ) {}

  async getUserBalance(userId: string) {
    const user = await this.userModel.findById(userId);
    if (!user) throw new NotFoundException('المستخدم غير موجود');
    return {
      userId: user._id,
      customUserId: user.userId,
      balance: user.balance,
      currency: 'USD',
    };
  }

  async getUserTransactions(userId: string) {
    return this.transactionModel
      .find({ userId: new Types.ObjectId(userId) })
      .sort({ createdAt: -1 })
      .limit(100);
  }

  async getAllTransactionsAdmin() {
    return this.transactionModel
      .find()
      .populate('userId', 'name email phone userId')
      .sort({ createdAt: -1 })
      .limit(200);
  }

  // Admin manually adds or deducts balance by User ID (طريقة الشحن عبر الآيدي)
  async adminAdjustBalance(params: {
    userId: string;
    amount: number;
    description: string;
    adminId: string;
    // مصدر العملية: 'Admin' (شحن بالآيدي) أو 'ManualOrder' أو 'ShippingCode'
    // يُستخدم لتمييز عمليات سجل الشحن ومنع تكرارها
    referenceType?: string;
    referenceId?: string;
  }) {
    if (params.amount === 0) {
      throw new BadRequestException('المبلغ لا يمكن أن يكون صفراً');
    }

    const cleanInput = params.userId ? params.userId.trim() : '';
    let user = await this.userModel.findOne(userIdFilter(cleanInput));
    if (!user && Types.ObjectId.isValid(cleanInput)) {
      user = await this.userModel.findById(cleanInput);
    }
    if (!user)
      throw new NotFoundException(
        'المستخدم غير موجود (يرجى التحقق من آيدي العميل)',
      );

    const filter: any = { _id: user._id };
    if (params.amount < 0) {
      filter.balance = { $gte: Math.abs(params.amount) };
    }
    const updatedUser = await this.userModel.findOneAndUpdate(
      filter,
      { $inc: { balance: params.amount } },
      { new: true },
    );
    if (!updatedUser) {
      throw new BadRequestException('الرصيد المتبقي لا يمكن أن يكون سالباً');
    }

    const balanceAfter = Number(updatedUser.balance.toFixed(2));
    const balanceBefore = Number((balanceAfter - params.amount).toFixed(2));

    const transaction = new this.transactionModel({
      userId: user._id,
      type:
        params.amount > 0
          ? TransactionType.TOPUP
          : TransactionType.ADMIN_ADJUSTMENT,
      amount: params.amount,
      balanceBefore,
      balanceAfter,
      description:
        params.description ||
        (params.amount > 0 ? 'شحن رصيد من الإدارة' : 'خصم رصيد من الإدارة'),
      referenceType: params.referenceType ?? 'Admin',
      referenceId: params.referenceId ?? params.adminId,
      status: TransactionStatus.COMPLETED,
    });
    await transaction.save();

    // Send notification to user
    await this.notificationsService.createNotification({
      userId: user._id.toString(),
      title: params.amount > 0 ? 'شحن رصيد ناجح 🎉' : 'تعديل رصيد من الإدارة',
      body:
        params.amount > 0
          ? `تم شحن رصيدك بمبلغ $${params.amount.toFixed(2)} بنجاح. رصيدك الحالي: $${balanceAfter.toFixed(2)}`
          : `تم خصم $${Math.abs(params.amount).toFixed(2)} من حسابك. رصيدك الحالي: $${balanceAfter.toFixed(2)}`,
      type: 'wallet_topup',
      data: { amount: params.amount, newBalance: balanceAfter },
    });

    return {
      message: 'تم تحديث رصيد المستخدم بنجاح',
      user: {
        id: updatedUser._id,
        userId: updatedUser.userId,
        name: updatedUser.name,
        email: updatedUser.email,
        balance: balanceAfter,
      },
      transaction,
    };
  }
}
