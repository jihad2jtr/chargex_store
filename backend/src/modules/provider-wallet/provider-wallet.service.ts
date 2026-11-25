import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Role } from '../../common/interfaces/role.enum';
import { Order, OrderDocument, OrderStatus } from '../../database/schemas/order.schema';
import { ProductType } from '../../database/schemas/product.schema';
import {
  ProviderWalletTransaction,
  ProviderWalletTransactionDocument,
  ProviderWalletTxType,
} from '../../database/schemas/provider-wallet-transaction.schema';
import {
  ProviderWithdrawal,
  ProviderWithdrawalDocument,
  ProviderWithdrawalStatus,
} from '../../database/schemas/provider-withdrawal.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import {
  TransactionStatus,
  TransactionType,
  WalletTransaction,
  WalletTransactionDocument,
} from '../../database/schemas/wallet-transaction.schema';
import { NotificationsService } from '../notifications/notifications.service';

const round2 = (n: number) => Math.round((Number(n) || 0) * 100) / 100;

@Injectable()
export class ProviderWalletService {
  private readonly logger = new Logger(ProviderWalletService.name);

  constructor(
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    @InjectModel(Order.name) private readonly orderModel: Model<OrderDocument>,
    @InjectModel(WalletTransaction.name)
    private readonly walletTxModel: Model<WalletTransactionDocument>,
    @InjectModel(ProviderWalletTransaction.name)
    private readonly providerTxModel: Model<ProviderWalletTransactionDocument>,
    @InjectModel(ProviderWithdrawal.name)
    private readonly withdrawalModel: Model<ProviderWithdrawalDocument>,
    private readonly notificationsService: NotificationsService,
  ) {}

  private async notifyAdminsSafe(title: string, body: string, data?: Record<string, any>) {
    try {
      const admins = await this.userModel.find({ role: Role.ADMIN }).select('_id');
      await Promise.all(
        admins.map((a) =>
          this.notificationsService.createNotification({
            userId: a._id.toString(),
            title,
            body,
            type: 'provider_withdrawal',
            data,
          }),
        ),
      );
    } catch (err: any) {
      this.logger.warn(`Failed to notify admins: ${err?.message}`);
    }
  }

  async getMySummary(userId: string) {
    const user = await this.userModel
      .findById(userId)
      .select(
        'name role balance providerBalance supervisorProfitPercent shamCashAccountName shamCashAccountId',
      );
    if (!user) throw new NotFoundException('المستخدم غير موجود');

    const supOid = user._id;
    const [transactions, withdrawals, txAgg] = await Promise.all([
      this.providerTxModel
        .find({ supervisorId: supOid })
        .sort({ createdAt: -1 })
        .limit(50)
        .lean(),
      this.withdrawalModel
        .find({ supervisorId: supOid })
        .sort({ createdAt: -1 })
        .limit(30)
        .lean(),
      this.providerTxModel.aggregate<{
        _id: string;
        totalAmount: number;
        totalAdminProfit: number;
        count: number;
      }>([
        { $match: { supervisorId: supOid } },
        {
          $group: {
            _id: '$type',
            totalAmount: { $sum: '$amount' },
            totalAdminProfit: { $sum: { $ifNull: ['$adminProfit', 0] } },
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    const byType = new Map(txAgg.map((r) => [r._id, r]));
    const earningRow = byType.get(ProviderWalletTxType.EARNING);
    const transferRow = byType.get(ProviderWalletTxType.TRANSFER_TO_MAIN);
    const approvedWithdrawals = withdrawals
      .filter((w) => w.status === ProviderWithdrawalStatus.APPROVED)
      .reduce((sum, w) => sum + (Number(w.amount) || 0), 0);
    const pendingWithdrawals = withdrawals
      .filter((w) => w.status === ProviderWithdrawalStatus.PENDING)
      .reduce((sum, w) => sum + (Number(w.amount) || 0), 0);

    return {
      providerBalance: round2(user.providerBalance ?? 0),
      mainBalance: round2(user.balance ?? 0),
      supervisorProfitPercent: Number(user.supervisorProfitPercent ?? 0),
      shamCashAccountName: user.shamCashAccountName ?? '',
      shamCashAccountId: user.shamCashAccountId ?? '',
      stats: {
        totalEarned: round2(earningRow?.totalAmount ?? 0),
        completedOrders: Number(earningRow?.count ?? 0),
        adminProfitGenerated: round2(earningRow?.totalAdminProfit ?? 0),
        totalTransferred: round2(Math.abs(transferRow?.totalAmount ?? 0)),
        totalWithdrawn: round2(approvedWithdrawals),
        pendingWithdrawals: round2(pendingWithdrawals),
      },
      transactions,
      withdrawals,
    };
  }

  async updateShamCashAccount(
    userId: string,
    dto: { accountName: string; accountId: string },
  ) {
    const accountName = (dto.accountName || '').trim();
    const accountId = (dto.accountId || '').trim();
    if (!accountName || !accountId) {
      throw new BadRequestException(
        'يرجى إدخال اسم صاحب حساب الشام كاش ورقم/معرّف الحساب',
      );
    }

    const user = await this.userModel.findByIdAndUpdate(
      userId,
      {
        $set: {
          shamCashAccountName: accountName,
          shamCashAccountId: accountId,
        },
      },
      { new: true },
    );
    if (!user) throw new NotFoundException('المستخدم غير موجود');

    return {
      message: 'تم حفظ بيانات حساب الشام كاش بنجاح',
      shamCashAccountName: user.shamCashAccountName,
      shamCashAccountId: user.shamCashAccountId,
    };
  }

  async transferToMainBalance(userId: string, rawAmount: number) {
    const amount = round2(rawAmount);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('أدخل مبلغاً صالحاً للتحويل');
    }

    const updated = await this.userModel.findOneAndUpdate(
      { _id: userId, providerBalance: { $gte: amount } },
      { $inc: { providerBalance: -amount, balance: amount } },
      { new: true },
    );
    if (!updated) {
      throw new BadRequestException('رصيد محفظة مقدم الخدمة غير كافٍ');
    }

    const providerAfter = round2(updated.providerBalance ?? 0);
    const providerBefore = round2(providerAfter + amount);
    const mainAfter = round2(updated.balance ?? 0);
    const mainBefore = round2(mainAfter - amount);

    await Promise.all([
      this.providerTxModel.create({
        supervisorId: updated._id,
        type: ProviderWalletTxType.TRANSFER_TO_MAIN,
        amount: -amount,
        balanceBefore: providerBefore,
        balanceAfter: providerAfter,
        description: `تحويل $${amount.toFixed(2)} إلى الرصيد الأساسي في التطبيق`,
      }),
      this.walletTxModel.create({
        userId: updated._id,
        type: TransactionType.TOPUP,
        amount,
        balanceBefore: mainBefore,
        balanceAfter: mainAfter,
        description: `تحويل أرباح من محفظة مقدم الخدمة ($${amount.toFixed(2)})`,
        referenceType: 'ProviderTransfer',
        referenceId: updated._id.toString(),
        status: TransactionStatus.COMPLETED,
      }),
    ]);

    return {
      message: `تم تحويل $${amount.toFixed(2)} إلى رصيدك الأساسي بنجاح`,
      providerBalance: providerAfter,
      mainBalance: mainAfter,
    };
  }

  async requestWithdrawal(
    userId: string,
    dto: { amount: number; notes?: string },
  ) {
    const amount = round2(dto.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('أدخل مبلغاً صالحاً للسحب');
    }

    const user = await this.userModel.findById(userId);
    if (!user) throw new NotFoundException('المستخدم غير موجود');

    const accountName = (user.shamCashAccountName || '').trim();
    const accountId = (user.shamCashAccountId || '').trim();
    if (!accountName || !accountId) {
      throw new BadRequestException(
        'يجب إضافة بيانات حساب الشام كاش الخاص بك أولاً قبل إرسال طلب السحب',
      );
    }

    const updated = await this.userModel.findOneAndUpdate(
      { _id: user._id, providerBalance: { $gte: amount } },
      { $inc: { providerBalance: -amount } },
      { new: true },
    );
    if (!updated) {
      throw new BadRequestException('رصيد محفظة مقدم الخدمة غير كافٍ');
    }

    const balanceAfter = round2(updated.providerBalance ?? 0);
    const balanceBefore = round2(balanceAfter + amount);

    const withdrawal = await this.withdrawalModel.create({
      supervisorId: user._id,
      amount,
      method: 'sham_cash',
      shamCashAccountName: accountName,
      shamCashAccountId: accountId,
      notes: (dto.notes || '').trim(),
      status: ProviderWithdrawalStatus.PENDING,
    });

    await this.providerTxModel.create({
      supervisorId: user._id,
      type: ProviderWalletTxType.WITHDRAWAL_HOLD,
      amount: -amount,
      balanceBefore,
      balanceAfter,
      description: `حجز مبلغ طلب سحب شام كاش (${accountName} - ${accountId})`,
      referenceId: withdrawal._id.toString(),
    });

    await this.notifyAdminsSafe(
      'طلب سحب جديد من مقدم خدمة 💸',
      `طلب ${user.name} سحب $${amount.toFixed(2)} عبر الشام كاش (${accountId})`,
      { withdrawalId: withdrawal._id.toString(), supervisorId: user._id.toString() },
    );

    return {
      message: 'تم إرسال طلب السحب للمراجعة والموافقة من الإدارة',
      providerBalance: balanceAfter,
      withdrawal,
    };
  }

  /**
   * إيداع حصة مقدم الخدمة في محفظته الخاصة عند اكتمال الطلب يدوياً.
   * محمي بقيد ذرّي على providerCredited لمنع الترحيل المكرر.
   */
  async creditForCompletedOrder(order: OrderDocument): Promise<boolean> {
    const rawSup = order?.assignedSupervisorId as any;
    const supervisorId =
      rawSup?._id?.toString?.() ?? rawSup?.toString?.() ?? '';
    if (!supervisorId || !Types.ObjectId.isValid(supervisorId)) return false;

    const creditAmount = round2(
      Number(order.cost) > 0 ? Number(order.cost) : Number(order.amount) || 0,
    );
    if (creditAmount <= 0) return false;

    const claimed = await this.orderModel.findOneAndUpdate(
      { _id: order._id, providerCredited: { $ne: true } },
      { $set: { providerCredited: true, providerCreditedAt: new Date() } },
      { new: true },
    );
    if (!claimed) return false;

    const updatedUser = await this.userModel.findByIdAndUpdate(
      supervisorId,
      { $inc: { providerBalance: creditAmount } },
      { new: true },
    );
    if (!updatedUser) return false;

    const balanceAfter = round2(updatedUser.providerBalance ?? 0);
    const balanceBefore = round2(balanceAfter - creditAmount);
    const adminProfit = round2(Number(order.profit) || 0);

    await this.providerTxModel.create({
      supervisorId: updatedUser._id,
      type: ProviderWalletTxType.EARNING,
      amount: creditAmount,
      balanceBefore,
      balanceAfter,
      adminProfit,
      description: `أرباح تنفيذ الطلب #${order.orderNumber}`,
      referenceId: order._id.toString(),
    });

    try {
      await this.notificationsService.createNotification({
        userId: supervisorId,
        title: 'تم إضافة أرباح لمحفظتك الخاصة 💰',
        body: `أُضيف $${creditAmount.toFixed(2)} إلى محفظة مقدم الخدمة بعد إتمام الطلب #${order.orderNumber}.`,
        type: 'provider_earning',
        data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
      });
    } catch (err: any) {
      this.logger.warn(`Failed to notify supervisor earning: ${err?.message}`);
    }

    return true;
  }

  /** لوحة الإدارة: طلبات السحب + ملخص أرباح الأدمن من عمليات مقدمي الخدمة */
  async getAdminOverview(status?: string) {
    const filter: any = {};
    if (
      status &&
      Object.values(ProviderWithdrawalStatus).includes(
        status as ProviderWithdrawalStatus,
      )
    ) {
      filter.status = status;
    }

    const now = new Date();
    const startToday = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
    );
    const start30 = new Date(now.getTime() - 30 * 86_400_000);

    const [withdrawals, pendingCount, manualAgg, perSupervisor] =
      await Promise.all([
        this.withdrawalModel
          .find(filter)
          .populate(
            'supervisorId',
            'name email phone userId providerBalance supervisorProfitPercent shamCashAccountName shamCashAccountId',
          )
          .sort({ createdAt: -1 })
          .limit(100)
          .lean(),
        this.withdrawalModel.countDocuments({
          status: ProviderWithdrawalStatus.PENDING,
        }),
        this.orderModel.aggregate<{
          _id: null;
          totalOrders: number;
          totalRevenue: number;
          totalProviderShare: number;
          totalAdminProfit: number;
          todayAdminProfit: number;
          last30AdminProfit: number;
        }>([
          {
            $match: {
              type: ProductType.MANUAL,
              assignedSupervisorId: { $ne: null },
              status: {
                $nin: [OrderStatus.REJECTED, OrderStatus.REFUNDED],
              },
            },
          },
          {
            $group: {
              _id: null,
              totalOrders: { $sum: 1 },
              totalRevenue: { $sum: '$amount' },
              totalProviderShare: { $sum: '$cost' },
              totalAdminProfit: { $sum: '$profit' },
              todayAdminProfit: {
                $sum: {
                  $cond: [{ $gte: ['$createdAt', startToday] }, '$profit', 0],
                },
              },
              last30AdminProfit: {
                $sum: {
                  $cond: [{ $gte: ['$createdAt', start30] }, '$profit', 0],
                },
              },
            },
          },
        ]),
        this.orderModel.aggregate<{
          _id: Types.ObjectId;
          orders: number;
          revenue: number;
          providerShare: number;
          adminProfit: number;
        }>([
          {
            $match: {
              type: ProductType.MANUAL,
              assignedSupervisorId: { $ne: null },
              status: {
                $nin: [OrderStatus.REJECTED, OrderStatus.REFUNDED],
              },
            },
          },
          {
            $group: {
              _id: '$assignedSupervisorId',
              orders: { $sum: 1 },
              revenue: { $sum: '$amount' },
              providerShare: { $sum: '$cost' },
              adminProfit: { $sum: '$profit' },
            },
          },
        ]),
      ]);

    const agg = manualAgg[0];
    return {
      pendingWithdrawalsCount: Number(pendingCount || 0),
      profitSummary: {
        totalOrders: Number(agg?.totalOrders ?? 0),
        totalRevenue: round2(agg?.totalRevenue ?? 0),
        totalProviderShare: round2(agg?.totalProviderShare ?? 0),
        totalAdminProfit: round2(agg?.totalAdminProfit ?? 0),
        todayAdminProfit: round2(agg?.todayAdminProfit ?? 0),
        last30AdminProfit: round2(agg?.last30AdminProfit ?? 0),
      },
      perSupervisor: perSupervisor.map((s) => ({
        supervisorId: String(s._id),
        orders: Number(s.orders),
        revenue: round2(s.revenue),
        providerShare: round2(s.providerShare),
        adminProfit: round2(s.adminProfit),
      })),
      withdrawals,
    };
  }

  async approveWithdrawal(id: string, adminUser: UserDocument, adminNote?: string) {
    const cleanNote = (adminNote || '').trim();
    const updated = await this.withdrawalModel.findOneAndUpdate(
      { _id: id, status: ProviderWithdrawalStatus.PENDING },
      {
        $set: {
          status: ProviderWithdrawalStatus.APPROVED,
          adminNote: cleanNote,
          reviewedBy: adminUser._id,
          reviewedAt: new Date(),
        },
      },
      { new: true },
    );
    if (!updated) {
      throw new BadRequestException('طلب السحب غير موجود أو تمت معالجته مسبقاً');
    }

    try {
      await this.notificationsService.createNotification({
        userId: updated.supervisorId.toString(),
        title: 'تمت الموافقة على طلب السحب ✅',
        body: `تمت الموافقة على سحب $${updated.amount.toFixed(2)} إلى حساب الشام كاش (${updated.shamCashAccountId})${cleanNote ? ` — ${cleanNote}` : ''}`,
        type: 'provider_withdrawal',
        data: { withdrawalId: updated._id.toString() },
      });
    } catch (err: any) {
      this.logger.warn(`Failed to notify approval: ${err?.message}`);
    }

    return { message: 'تم اعتماد طلب السحب بنجاح', withdrawal: updated };
  }

  async rejectWithdrawal(id: string, adminUser: UserDocument, adminNote?: string) {
    const cleanNote = (adminNote || '').trim();
    const updated = await this.withdrawalModel.findOneAndUpdate(
      { _id: id, status: ProviderWithdrawalStatus.PENDING },
      {
        $set: {
          status: ProviderWithdrawalStatus.REJECTED,
          adminNote: cleanNote,
          reviewedBy: adminUser._id,
          reviewedAt: new Date(),
        },
      },
      { new: true },
    );
    if (!updated) {
      throw new BadRequestException('طلب السحب غير موجود أو تمت معالجته مسبقاً');
    }

    const refundedUser = await this.userModel.findByIdAndUpdate(
      updated.supervisorId,
      { $inc: { providerBalance: updated.amount } },
      { new: true },
    );
    const balanceAfter = round2(refundedUser?.providerBalance ?? updated.amount);
    const balanceBefore = round2(balanceAfter - updated.amount);

    await this.providerTxModel.create({
      supervisorId: updated.supervisorId,
      type: ProviderWalletTxType.WITHDRAWAL_REFUND,
      amount: updated.amount,
      balanceBefore,
      balanceAfter,
      description: `إرجاع مبلغ طلب سحب مرفوض${cleanNote ? `: ${cleanNote}` : ''}`,
      referenceId: updated._id.toString(),
    });

    try {
      await this.notificationsService.createNotification({
        userId: updated.supervisorId.toString(),
        title: 'تم رفض طلب السحب وإرجاع المبلغ',
        body: `أُعيد $${updated.amount.toFixed(2)} إلى محفظة مقدم الخدمة${cleanNote ? `. السبب: ${cleanNote}` : ''}`,
        type: 'provider_withdrawal',
        data: { withdrawalId: updated._id.toString() },
      });
    } catch (err: any) {
      this.logger.warn(`Failed to notify rejection: ${err?.message}`);
    }

    return { message: 'تم رفض طلب السحب وإعادة المبلغ للمحفظة', withdrawal: updated };
  }
}
