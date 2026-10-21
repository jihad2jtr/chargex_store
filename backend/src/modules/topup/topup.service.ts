import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { ShamCashAccount, ShamCashAccountDocument, PaymentAccountType } from '../../database/schemas/sham-cash-account.schema';
import { ManualOrder, ManualOrderDocument, ManualOrderStatus } from '../../database/schemas/manual-order.schema';
import { TopupMethod, TopupMethodDocument, TopupType } from '../../database/schemas/topup-method.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { WalletService } from '../wallet/wallet.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class TopupService {
  private readonly logger = new Logger(TopupService.name);

  constructor(
    @InjectModel(ShamCashAccount.name) private accountModel: Model<ShamCashAccountDocument>,
    @InjectModel(ManualOrder.name) private manualOrderModel: Model<ManualOrderDocument>,
    @InjectModel(TopupMethod.name) private topupMethodModel: Model<TopupMethodDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private walletService: WalletService,
    private notificationsService: NotificationsService,
  ) {}

  // Get active accounts for clients (Sham Cash or Binance)
  async getActiveAccounts(type?: PaymentAccountType) {
    const filter: any = { isActive: true };
    if (type) filter.type = type;
    return this.accountModel.find(filter).sort({ createdAt: -1 });
  }

  // Admin: get all accounts
  async getAllAccountsAdmin(type?: PaymentAccountType) {
    const filter: any = {};
    if (type) filter.type = type;
    return this.accountModel.find(filter).sort({ createdAt: -1 });
  }

  // Admin: create account
  async createAccount(data: {
    type: PaymentAccountType;
    accountName: string;
    accountId: string;
    barcodeUrl: string;
  }) {
    const account = new this.accountModel({
      ...data,
      isActive: true,
    });
    return account.save();
  }

  // Admin: update account
  async updateAccount(id: string, updateData: any) {
    const account = await this.accountModel.findByIdAndUpdate(id, updateData, { new: true });
    if (!account) throw new NotFoundException('الحساب غير موجود');
    return account;
  }

  // Admin: toggle active account
  async toggleAccountActive(id: string) {
    const account = await this.accountModel.findById(id);
    if (!account) throw new NotFoundException('الحساب غير موجود');
    account.isActive = !account.isActive;
    return account.save();
  }

  // Admin: delete account
  async deleteAccount(id: string) {
    const account = await this.accountModel.findByIdAndDelete(id);
    if (!account) throw new NotFoundException('الحساب غير موجود');
    return { message: 'تم حذف الحساب بنجاح' };
  }

  // Client: submit manual topup request
  async submitTopupRequest(params: {
    userId: string;
    type: 'sham_cash' | 'binance' | 'id_recharge';
    amount: number;
    details: Record<string, any>;
    receiptImageUrl?: string;
  }) {
    if (params.amount <= 0) {
      throw new BadRequestException('المبلغ يجب أن يكون أكبر من صفر');
    }

    const manualOrder = new this.manualOrderModel({
      userId: new Types.ObjectId(params.userId),
      type: params.type,
      amount: params.amount,
      details: params.details,
      receiptImageUrl: params.receiptImageUrl,
      status: ManualOrderStatus.PENDING,
    });
    await manualOrder.save();

    // Notify admins about new topup request
    const user = await this.userModel.findById(params.userId);
    await this.notificationsService.createNotification({
      forRole: 'admin',
      title: 'طلب شحن رصيد جديد 📥',
      body: `طلب شحن بقيمة $${params.amount.toFixed(2)} من العميل ${user?.name || ''} عبر ${params.type}`,
      type: 'new_order',
      data: { manualOrderId: manualOrder._id, amount: params.amount },
    });

    return {
      message: 'تم إرسال طلب شحن الرصيد بنجاح، جاري المراجعة من الإدارة',
      manualOrder,
    };
  }

  // Admin: view all manual topup requests with filtering
  async getManualOrders(status?: ManualOrderStatus) {
    const filter: any = {};
    if (status) filter.status = status;
    return this.manualOrderModel
      .find(filter)
      .populate('userId', 'name email phone balance userId')
      .sort({ createdAt: -1 });
  }

  // Client: view their own manual topup requests
  async getMyTopupRequests(userId: string) {
    return this.manualOrderModel
      .find({ userId: new Types.ObjectId(userId) })
      .sort({ createdAt: -1 });
  }

  // Admin: approve manual topup request
  async approveTopup(id: string, adminId: string, approvedAmount?: number, notes?: string) {
    const manualOrder = await this.manualOrderModel.findById(id);
    if (!manualOrder) throw new NotFoundException('طلب الشحن غير موجود');
    if (manualOrder.status !== ManualOrderStatus.PENDING) {
      throw new BadRequestException('تمت معالجة هذا الطلب مسبقاً');
    }

    const finalAmount = approvedAmount !== undefined && approvedAmount > 0 ? approvedAmount : manualOrder.amount;

    manualOrder.status = ManualOrderStatus.APPROVED;
    manualOrder.amount = finalAmount;
    manualOrder.adminNotes = notes || 'تم التحقق من الإيصال والموافقة بنجاح';
    manualOrder.processedBy = new Types.ObjectId(adminId);
    manualOrder.processedAt = new Date();
    await manualOrder.save();

    // Add balance to user
    await this.walletService.adminAdjustBalance({
      userId: manualOrder.userId.toString(),
      amount: finalAmount,
      description: `شحن رصيد عبر ${manualOrder.type} (طلب رقم: #${manualOrder._id.toString().substring(18)})`,
      adminId,
    });

    return {
      message: 'تمت الموافقة على طلب الشحن وإضافة الرصيد إلى المحفظة',
      manualOrder,
    };
  }

  // Admin: reject manual topup request
  async rejectTopup(id: string, adminId: string, notes: string) {
    const manualOrder = await this.manualOrderModel.findById(id);
    if (!manualOrder) throw new NotFoundException('طلب الشحن غير موجود');
    if (manualOrder.status !== ManualOrderStatus.PENDING) {
      throw new BadRequestException('تمت معالجة هذا الطلب مسبقاً');
    }

    manualOrder.status = ManualOrderStatus.REJECTED;
    manualOrder.adminNotes = notes || 'تم رفض الطلب لعدم تطابق بيانات الإيصال';
    manualOrder.processedBy = new Types.ObjectId(adminId);
    manualOrder.processedAt = new Date();
    await manualOrder.save();

    // Send notification to user with notes
    await this.notificationsService.createNotification({
      userId: manualOrder.userId.toString(),
      title: 'تم رفض طلب الشحن ❌',
      body: `تم رفض طلب الشحن بقيمة $${manualOrder.amount.toFixed(2)}. ملاحظات الإدارة: ${notes || 'بيانات التحويل غير متطابقة'}`,
      type: 'manual_order_rejected',
      data: { manualOrderId: manualOrder._id, notes },
    });

    return {
      message: 'تم رفض طلب الشحن وإشعار العميل بالملاحظات',
      manualOrder,
    };
  }
}
