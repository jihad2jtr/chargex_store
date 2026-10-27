import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import {
  ShamCashAccount,
  ShamCashAccountDocument,
  PaymentAccountType,
} from '../../database/schemas/sham-cash-account.schema';
import {
  ManualOrder,
  ManualOrderDocument,
  ManualOrderStatus,
} from '../../database/schemas/manual-order.schema';
import {
  ShippingCode,
  ShippingCodeDocument,
} from '../../database/schemas/shipping-code.schema';
import {
  TopupMethod,
  TopupMethodDocument,
} from '../../database/schemas/topup-method.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import {
  WalletTransaction,
  WalletTransactionDocument,
} from '../../database/schemas/wallet-transaction.schema';
import { WalletService } from '../wallet/wallet.service';
import { userIdFilter } from '../../common/utils/user-id.util';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class TopupService {
  private readonly logger = new Logger(TopupService.name);

  constructor(
    @InjectModel(ShamCashAccount.name)
    private accountModel: Model<ShamCashAccountDocument>,
    @InjectModel(ManualOrder.name)
    private manualOrderModel: Model<ManualOrderDocument>,
    @InjectModel(ShippingCode.name)
    private codeModel: Model<ShippingCodeDocument>,
    @InjectModel(TopupMethod.name)
    private topupMethodModel: Model<TopupMethodDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(WalletTransaction.name)
    private transactionModel: Model<WalletTransactionDocument>,
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
    const account = await this.accountModel.findByIdAndUpdate(id, updateData, {
      new: true,
    });
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

  // Client: view their own topup history
  // الطلبات اليدوية (شام كاش / بينانس / آيدي) تُخزّن في ManualOrder، أما الشحن بالكود
  // فيُسجّل على كود الشحن نفسه (usedBy / usedAt) — لذلك يُدمج الاثنان هنا
  // كي يظهر الشحن عبر الكود في سجل «طلباتي الأخيرة» أيضاً
  async getMyTopupRequests(userId: string) {
    const userObjectId = new Types.ObjectId(userId);

    const [manualOrders, redeemedCodes, legacyIdTopups] = await Promise.all([
      this.manualOrderModel.find({ userId: userObjectId }).lean().exec(),
      this.codeModel
        .find({ usedBy: userObjectId, isUsed: true })
        .sort({ usedAt: -1 })
        .limit(50)
        .lean()
        .exec(),
      this.transactionModel
        .find({ ...this.legacyIdTopupFilter(), userId: userObjectId })
        .sort({ createdAt: -1 })
        .limit(50)
        .lean()
        .exec(),
    ]);

    return this.mergeTopupLog(
      manualOrders as any[],
      redeemedCodes as any[],
      legacyIdTopups as any[],
    );
  }

  // Admin: سجل موحّد لكل عمليات شحن الرصيد بغض النظر عن وسيلتها
  // (شام كاش / Binance / كود شحن / شحن بالآيدي) مع حقل source لكل عملية
  async getAdminTopupLog(limit = 300) {
    const [manualOrders, redeemedCodes, legacyIdTopups] = await Promise.all([
      this.manualOrderModel
        .find()
        .populate('userId', 'name email phone userId')
        .sort({ createdAt: -1 })
        .limit(limit)
        .lean()
        .exec(),
      this.codeModel
        .find({ isUsed: true })
        .populate('usedBy', 'name email phone userId')
        .sort({ usedAt: -1 })
        .limit(limit)
        .lean()
        .exec(),
      this.transactionModel
        .find(this.legacyIdTopupFilter())
        .populate('userId', 'name email phone userId')
        .sort({ createdAt: -1 })
        .limit(limit)
        .lean()
        .exec(),
    ]);

    return this.mergeTopupLog(
      manualOrders as any[],
      redeemedCodes as any[],
      legacyIdTopups as any[],
    );
  }

  /**
   * عمليات الشحن بالآيدي القديمة (قبل تسجيلها في جدول الطلبات) موجودة فقط
   * في حركات المحفظة: مرجعها 'Admin' ووصفها ليس ناتجاً عن موافقة طلب أو استبدال كود،
   * فيُضمّن هنا حتى تظهر بأثر رجعي في السجل.
   */
  private legacyIdTopupFilter() {
    return {
      referenceType: 'Admin',
      description: { $not: /^(شحن رصيد عبر |شحن عبر كود رقمي:)/ },
    };
  }

  /**
   * دمج الطلبات اليدوية مع أكواد الشحن المستبدلة في قائمة واحدة مرتّبة زمنياً.
   * كل كود يُحوّل إلى مدخل بنفس شكل الطلب كي تعرضه الواجهة بنفس البطاقة.
   */
  private mergeTopupLog(
    manualOrders: any[],
    redeemedCodes: any[],
    legacyIdTopups: any[] = [],
  ) {
    const codeEntries = redeemedCodes.map((code: any) => ({
      _id: code._id,
      userId: code.usedBy,
      type: 'code',
      amount: code.amount,
      details: { code: code.code },
      status: 'approved',
      adminNotes: null,
      createdAt: code.usedAt ?? code.createdAt,
      processedAt: code.usedAt,
      source: 'code',
    }));

    // حركات المحفظة القديمة للشحن بالآيدي
    const legacyEntries = legacyIdTopups.map((tx: any) => ({
      _id: tx._id,
      userId: tx.userId,
      type: 'id_topup',
      amount: tx.amount,
      details: { 'آيدي العميل': tx.userId?.userId ?? '' },
      status: 'approved',
      adminNotes: tx.description,
      createdAt: tx.createdAt,
      processedAt: tx.createdAt,
      source: 'wallet',
    }));

    const manualEntries = manualOrders.map((order: any) => ({
      ...order,
      source: order.source ?? 'manual',
    }));

    return [...manualEntries, ...codeEntries, ...legacyEntries].sort(
      (a: any, b: any) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
    );
  }

  // Admin: شحن رصيد مباشر بالآيدي — يُسجّل عملية في السجل بنفس جدول الطلبات
  // كي تظهر مع بقية وسائل الشحن في سجل الأدمن وفي «طلباتي الأخيرة» للعميل
  async createIdTopup(params: {
    userId: string;
    amount: number;
    description?: string;
    adminId: string;
  }) {
    const cleanId = (params.userId || '').trim();
    if (!cleanId) throw new BadRequestException('يرجى إدخال آيدي العميل');
    if (!params.amount)
      throw new BadRequestException('المبلغ يجب أن يكون أكبر من صفر');

    let user = await this.userModel.findOne(userIdFilter(cleanId));
    if (!user && Types.ObjectId.isValid(cleanId)) {
      user = await this.userModel.findById(cleanId);
    }
    if (!user)
      throw new NotFoundException(
        'المستخدم غير موجود (يرجى التحقق من آيدي العميل)',
      );

    const notes =
      (params.description || '').trim() ||
      (params.amount > 0 ? 'شحن مباشر عبر الآيدي' : 'خصم مباشر عبر الآيدي');

    const result = await this.walletService.adminAdjustBalance({
      userId: user._id.toString(),
      amount: params.amount,
      description: notes,
      adminId: params.adminId,
      referenceType: 'IdTopup',
      referenceId: user._id.toString(),
    });

    const entry = new this.manualOrderModel({
      userId: user._id,
      type: 'id_topup',
      amount: params.amount,
      details: { 'آيدي العميل': user.userId },
      status: ManualOrderStatus.APPROVED,
      adminNotes: notes,
      processedBy: new Types.ObjectId(params.adminId),
      processedAt: new Date(),
    });
    await entry.save();

    return {
      message: 'تم شحن رصيد العميل بنجاح وسُجّلت العملية في سجل الشحن',
      user: result.user,
      entry,
    };
  }

  // Admin: approve manual topup request
  async approveTopup(
    id: string,
    adminId: string,
    approvedAmount?: number,
    notes?: string,
  ) {
    const manualOrder = await this.manualOrderModel.findById(id);
    if (!manualOrder) throw new NotFoundException('طلب الشحن غير موجود');
    if (manualOrder.status !== ManualOrderStatus.PENDING) {
      throw new BadRequestException('تمت معالجة هذا الطلب مسبقاً');
    }

    const finalAmount =
      approvedAmount !== undefined && approvedAmount > 0
        ? approvedAmount
        : manualOrder.amount;

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
      referenceType: 'ManualOrder',
      referenceId: manualOrder._id.toString(),
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
