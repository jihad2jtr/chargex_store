import { Injectable, BadRequestException, NotFoundException, ForbiddenException, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { InjectModel, InjectConnection } from '@nestjs/mongoose';
import { Model, Types, Connection } from 'mongoose';
import * as crypto from 'crypto';
import { Order, OrderDocument, OrderStatus, OrderTimelineEvent, OrderChatMessage } from '../../database/schemas/order.schema';
import { Product, ProductDocument, ProductType } from '../../database/schemas/product.schema';
import { App, AppDocument } from '../../database/schemas/app.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { WalletTransaction, WalletTransactionDocument, TransactionType, TransactionStatus } from '../../database/schemas/wallet-transaction.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { ProvidersService } from '../providers/providers.service';
import { UsersService } from '../users/users.service';
import { CryptoUtil } from '../../common/utils/crypto.util';

// ╪ح╪┤╪د╪▒╪ر ╪»╪د╪«┘┘è╪ر ╪ز┘╪│╪ز╪╣┘à┘ ┘┘é╪╖ ┘┘╪ز╪ص┘â┘ّ┘à ╪ذ╪د┘╪│┘è╪╖╪▒╪ر ╪»╪د╪«┘ ╪د┘┘à╪╣╪د┘à┘╪ر╪ؤ ╪ز┘╪ز╪▒╪ش┘┘à ╪ح┘┘ë BadRequest ╪«╪د╪▒╪ش┘ç╪د
class InsufficientBalanceSignal extends Error {}

@Injectable()
export class OrdersService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OrdersService.name);

  // ┘à╪╡╪د┘╪ص╪ر ╪»┘ê╪▒┘è╪ر ┘┘╪╖┘╪ذ╪د╪ز ╪د┘┘à╪╣┘┘ّ┘é╪ر (┘┘à ╪ز┘â┘ ╪ز╪╣┘à┘ ╪ح┘╪د ╪ذ╪╢╪║╪╖ ╪د┘╪ث╪»┘à┘ ┘è╪»┘ê┘è╪د┘ï)
  private static readonly RECONCILE_INTERVAL_MS = 5 * 60 * 1000;
  private reconcileTimer?: ReturnType<typeof setInterval>;
  private reconcileKickoffTimer?: ReturnType<typeof setTimeout>;
  private isReconciling = false;

  // ┘ç┘ ╪د┘╪ذ┘┘è╪ر ╪ز╪»╪╣┘à ╪د┘┘à╪╣╪د┘à┘╪د╪ز╪ا ╪ث╪╖┘╪│ (replica set) ┘╪╣┘à╪ؤ mongod ╪د┘┘à╪ص┘┘è ╪د┘┘à╪│╪ز┘é┘ ┘╪د ظ¤ ┘┘┘â╪ز╪┤┘ ┘à╪▒╪ر ┘ê╪د╪ص╪»╪ر
  private txSupported?: boolean;

  constructor(
    @InjectModel(Order.name) private orderModel: Model<OrderDocument>,
    @InjectModel(Product.name) private productModel: Model<ProductDocument>,
    @InjectModel(App.name) private appModel: Model<AppDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(WalletTransaction.name) private transactionModel: Model<WalletTransactionDocument>,
    private notificationsService: NotificationsService,
    private providersService: ProvidersService,
    private usersService: UsersService,
    @InjectConnection() private readonly connection: Connection,
  ) {}

  onModuleInit() {
    // ╪ش┘ê┘╪ر ╪ث┘ê┘┘ë ╪ذ╪╣╪» ╪»┘é┘è┘é╪ر ╪س┘à ┘â┘ 5 ╪»┘é╪د╪خ┘é╪ؤ ╪د┘┘à╪ج┘é┘ّ╪ز╪د╪ز unref ┘┘╪د ╪ز┘╪ذ┘é┘è ╪د┘╪╣┘à┘┘è╪ر ╪ص┘è┘ّ╪ر ┘ê┘╪د ╪ز┘╪╣┘┘ّ┘é ╪د╪«╪ز╪ذ╪د╪▒╪د╪ز vitest
    this.reconcileKickoffTimer = setTimeout(() => {
      void this.runReconciliationPass().catch(() => undefined);
    }, 60_000);
    this.reconcileKickoffTimer.unref?.();
    this.reconcileTimer = setInterval(() => {
      void this.runReconciliationPass().catch(() => undefined);
    }, OrdersService.RECONCILE_INTERVAL_MS);
    this.reconcileTimer.unref?.();
  }

  onModuleDestroy() {
    if (this.reconcileTimer) clearInterval(this.reconcileTimer);
    if (this.reconcileKickoffTimer) clearTimeout(this.reconcileKickoffTimer);
  }

  // ╪ص┘à┘╪ر ┘à╪╡╪د┘╪ص╪ر ┘ê╪د╪ص╪»╪ر ┘à╪ز╪▓╪د┘à┘╪ر ╪»╪د╪«┘┘è╪د┘ï╪ؤ ╪ز╪ش╪د┘ê╪▓ ╪ح┘ ┘â╪د┘╪ز ╪د┘╪│╪د╪ذ┘é╪ر ┘┘à ╪ز┘╪ز┘ç┘
  private async runReconciliationPass() {
    if (this.isReconciling) return;
    this.isReconciling = true;
    try {
      await this.reconcileProviderOrders(20);
    } finally {
      this.isReconciling = false;
    }
  }

  // ╪ز╪╣┘ê┘è╪╢ ╪│╪ص╪ذ ╪ح╪╣╪د╪»╪ر ╪ح╪▒╪│╪د┘ ┘à┘â╪▒┘ّ╪▒╪ر (M2): ╪ح╪▒╪ش╪د╪╣ ╪د┘╪«╪╡┘à ╪د┘╪س╪د┘┘è ╪ح┘┘ë ╪د┘╪╣┘à┘è┘ ┘ê╪ص┘╪╕ ╪د┘╪ص╪▒┘â╪ر
  private async compensateDuplicateDebit(user: UserDocument, price: number) {
    try {
      const credited = await this.userModel.findByIdAndUpdate(
        user._id,
        { $inc: { balance: price } },
        { new: true },
      );
      const balanceAfter = Number((credited?.balance ?? price).toFixed(2));
      await this.transactionModel.create({
        userId: user._id,
        type: TransactionType.REFUND,
        amount: price,
        balanceBefore: Number((balanceAfter - price).toFixed(2)),
        balanceAfter,
        description: '╪ح╪▒╪ش╪د╪╣ ╪ز┘┘é╪د╪خ┘è ┘╪│╪ص╪ذ ┘à┘â╪▒┘ّ╪▒ ┘à┘ ╪ح╪╣╪د╪»╪ر ╪ح╪▒╪│╪د┘ ┘┘╪│ ╪د┘╪╖┘╪ذ',
        referenceType: 'Order',
        status: TransactionStatus.COMPLETED,
      });
    } catch (err: any) {
      this.logger.error(`Duplicate-debit compensation failed for user ${user._id}: ${err?.message}`);
      await this.notifyAdminsSafe(
        '╪ز┘╪ذ┘è┘ç ┘à╪د┘┘è: ╪│╪ص╪ذ ┘à┘â╪▒┘ّ╪▒ ╪║┘è╪▒ ┘à╪╣┘ê┘ّ╪╢',
        `╪ث┘╪╣┘è╪» ╪ح╪▒╪│╪د┘ ╪╖┘╪ذ ╪ذ┘┘╪│ ╪د┘┘à╪╣╪▒┘ّ┘ ┘┘╪╣┘à┘è┘ ${user.name} ┘┘â┘ ╪ز╪╣╪░┘ّ╪▒ ╪ح╪▒╪ش╪د╪╣ ╪د┘╪«╪╡┘à ╪د┘╪س╪د┘┘è ($${price.toFixed(2)})╪ؤ ┘è┘╪▓┘à ╪ز╪»╪«┘ ┘è╪»┘ê┘è.`,
      );
    }
  }

  // ╪ح╪┤╪╣╪د╪▒╪د╪ز ┘╪د ┘è╪ش╪ذ ╪ث┘ ╪ز┘┘╪┤┘ ╪╣┘à┘┘è╪ر ╪╖┘╪ذ/╪ز┘┘┘è╪░ ┘╪د╪ش╪ص╪ر (H5)
  private async notifyAdminsSafe(title: string, body: string) {
    try {
      await this.notificationsService.createNotification({ forRole: 'admin', title, body, type: 'order_status' });
    } catch (err: any) {
      this.logger.warn(`Admin notification failed (${title}): ${err?.message}`);
    }
  }

  // ╪│╪ص╪ذ ╪░╪▒┘è ┘╪ث┘â┘ê╪د╪» ┘à┘ ╪د┘┘à╪«╪▓┘ê┘ ظ¤ ┘è┘à┘╪╣ ╪ز╪│┘┘è┘à ┘┘╪│ ╪د┘┘â┘ê╪» ┘╪╖┘╪ذ┘è┘ ┘à╪ز╪▓╪د┘à┘┘è┘ (H4)
  private async allocateInventoryCode(productId: Types.ObjectId): Promise<string | null> {
    const updated = await this.productModel.findOneAndUpdate(
      { _id: productId, 'inventoryCodes': { $exists: true, $ne: [] } },
      { $pop: { inventoryCodes: 1 } },
      { new: false },
    );
    const codes = (updated as any)?.inventoryCodes;
    if (!Array.isArray(codes) || codes.length === 0) return null;
    return String(codes[codes.length - 1]);
  }

  private async getUserBalance(userId: Types.ObjectId): Promise<number> {
    const doc = await this.userModel.findById(userId).select('balance').lean();
    return Number((doc as any)?.balance ?? 0);
  }

  // ╪د┘╪«╪╡┘à ╪ز┘à ┘ê╪د┘╪╖┘╪ذ ┘┘à ┘è┘╪ص┘╪╕: ┘┘╪▒╪ش╪╣ ╪د┘┘à╪د┘╪î ┘ê╪ح┘ ┘╪┤┘ ╪د┘╪▒╪ش┘ê╪╣ ┘è┘┘┘ê┘┘ّ┘ç ┘┘╪ح╪»╪د╪▒╪ر ┘┘ê╪▒╪د┘ï (H1)
  private async refundUnpersistedDebit(user: UserDocument, price: number, cause: any) {
    this.logger.error(`Order persist failed after debit for ${user._id}: ${cause?.message}`);
    try {
      await this.userModel.findByIdAndUpdate(user._id, { $inc: { balance: price } });
    } catch (refundErr: any) {
      this.logger.error(`Emergency refund failed for user ${user._id}: ${refundErr?.message}`);
      await this.notifyAdminsSafe(
        '╪ز┘╪ذ┘è┘ç ┘à╪د┘┘è: ╪«╪╡┘à ╪ذ┘╪د ╪ز╪╣┘ê┘è╪╢',
        `┘╪┤┘ ╪ص┘╪╕ ╪╖┘╪ذ ╪ذ╪╣╪» ╪«╪╡┘à $${price.toFixed(2)} ┘à┘ ╪د┘╪╣┘à┘è┘ ${user.name} ┘ê┘╪┤┘ ╪ح╪▒╪ش╪د╪╣┘ç ╪ز┘┘é╪د╪خ┘è╪د┘ï╪ؤ ┘è┘╪▓┘à ╪ز╪»╪«┘ ┘è╪»┘ê┘è.`,
      );
    }
  }

  // ┘è┘╪▒╪ش╪╣ ┘â┘ê╪»╪د┘ï ┘â╪د┘ ╪│┘╪ص╪ذ ╪░╪▒┘ّ┘è╪د┘ï ╪ح┘┘ë ╪د┘┘à╪«╪▓┘ê┘ ╪╣┘╪» ┘╪┤┘ ╪ح╪ز┘à╪د┘à ╪د┘╪╖┘╪ذ (D)
  private async releaseInventoryCode(productId: Types.ObjectId, code: string) {
    try {
      await this.productModel.findByIdAndUpdate(productId, { $addToSet: { inventoryCodes: code } });
    } catch (err: any) {
      this.logger.error(`Could not return inventory code ${code} for product ${productId}: ${err?.message}`);
      await this.notifyAdminsSafe(
        '╪ز┘╪ذ┘è┘ç ┘à╪«╪▓┘ê┘: ┘â┘ê╪» ╪║┘è╪▒ ┘à╪╣╪د╪»',
        `╪ث┘╪«╪▒╪ش ╪د┘┘â┘ê╪» ${code} ┘à┘ ╪د┘┘à╪«╪▓┘ê┘ ┘ê┘┘à ┘è┘╪│┘┘┘ّ┘à ┘ê┘┘à ┘è╪╣╪»╪ؤ ┘è┘╪▓┘à ┘à╪▒╪د╪ش╪╣╪ر ┘è╪»┘ê┘è╪ر ┘┘┘à╪«╪▓┘ê┘.`,
      );
    }
  }

  // ┘è┘à┘è┘ّ╪▓ ╪«╪╖╪ث ┬س╪د┘╪ذ┘┘è╪ر ┘╪د ╪ز╪»╪╣┘à ╪د┘┘à╪╣╪د┘à┘╪د╪ز┬╗ ╪╣┘ ╪│┘ê╪د┘ç (mongod ┘à╪│╪ز┘é┘/┘à╪ص┘┘è) (A/E)
  private isUnsupportedTransactionError(err: any): boolean {
    if (!err) return false;
    const code = err.code;
    const codeName = err.codeName || '';
    const msg = String(err.message || '');
    return (
      code === 20 ||
      code === 263 ||
      codeName === 'IllegalOperation' ||
      codeName === 'OperationNotSupportedInTransaction' ||
      /replica set|transaction numbers|transactions? are not supported|not supported|without a replica set|standalone/i.test(
        msg,
      )
    );
  }

  // ╪د┘╪ص╪│┘à ╪د┘┘à╪د┘┘è ╪╣┘╪» ╪ح┘╪┤╪د╪ة ╪د┘╪╖┘╪ذ: ╪د┘╪«╪╡┘à + ╪ص┘╪╕ ╪د┘╪╖┘╪ذ + ╪ص╪▒┘â╪ر ╪د┘╪┤╪▒╪د╪ة ┘â┘┘î┘ّ ╪ث┘ê ┘╪د ╪┤┘è╪ة ╪»╪د╪«┘ ┘à╪╣╪د┘à┘╪ر ╪ث╪╖┘╪│╪ؤ
  // ┘ê╪ح┘ ┘â╪د┘╪ز ╪د┘╪ذ┘┘è╪ر ╪ذ┘╪د ┘à╪╣╪د┘à┘╪د╪ز ┘è┘┘┘┘┘ّ╪░ ╪ز╪ز╪د╪ذ╪╣┘è╪د┘ï ┘à╪╣ ╪ز╪╣┘ê┘è╪╢ (A/E)
  private async commitPurchaseMoney(params: {
    orderDoc: Record<string, any>;
    cleanRequestId?: string;
    user: UserDocument;
    price: number;
    ledgerDescription: string;
  }): Promise<
    { kind: 'created'; order: OrderDocument; debited: UserDocument } | { kind: 'duplicate'; existing: OrderDocument }
  > {
    const { orderDoc, cleanRequestId, user, price, ledgerDescription } = params;

    if (this.txSupported !== false) {
      const session = await this.connection.startSession();
      try {
        let created!: OrderDocument;
        let debitedUser: UserDocument | null = null;
        await session.withTransaction(async () => {
          debitedUser = await this.userModel.findOneAndUpdate(
            { _id: user._id, balance: { $gte: price } },
            { $inc: { balance: -price } },
            { new: true, session },
          );
          if (!debitedUser) throw new InsufficientBalanceSignal();
          const docs = await this.orderModel.create([orderDoc], { session });
          created = docs[0];
          const bAfter = Number(debitedUser.balance.toFixed(2));
          const bBefore = Number((bAfter + price).toFixed(2));
          await this.transactionModel.create(
            [
              {
                userId: user._id,
                type: TransactionType.PURCHASE,
                amount: -price,
                balanceBefore: bBefore,
                balanceAfter: bAfter,
                description: ledgerDescription,
                referenceType: 'Order',
                referenceId: created._id.toString(),
                status: TransactionStatus.COMPLETED,
              },
            ],
            { session },
          );
        });
        this.txSupported = true;
        return { kind: 'created', order: created, debited: debitedUser! };
      } catch (err: any) {
        if (err instanceof InsufficientBalanceSignal) {
          throw new BadRequestException(
            `╪▒╪╡┘è╪»┘â ╪║┘è╪▒ ┘â╪د┘┘. ╪د┘┘à╪ذ┘╪║ ╪د┘┘à╪╖┘┘ê╪ذ: $${price.toFixed(2)}╪î ╪▒╪╡┘è╪»┘â ╪د┘╪ص╪د┘┘è: $${user.balance.toFixed(2)}`,
          );
        }
        if (err?.code === 11000 && cleanRequestId) {
          // ╪د┘┘à╪╣╪د┘à┘╪ر ╪ث┘╪ش┘ç┘╪╢╪ز ╪ز┘┘é╪د╪خ┘è╪د┘ï: ┘┘à ┘è┘╪│╪ص╪ذ ╪┤┘è╪ة ظ¤ ┘┘╪╣┘è╪» ╪د┘╪╖┘╪ذ ╪د┘╪ث╪╡┘┘è ╪ذ┘╪د ╪ز╪╣┘ê┘è╪╢
          const existing = await this.orderModel.findOne({ requestId: cleanRequestId });
          if (existing) return { kind: 'duplicate', existing };
        }
        if (this.isUnsupportedTransactionError(err)) {
          this.txSupported = false;
          this.logger.warn('Topology lacks transaction support; falling back to compensating sequential path');
          return this.commitPurchaseSequential(params);
        }
        this.logger.error(`createOrder transaction failed for ${orderDoc.orderNumber}: ${err?.message}`);
        throw new BadRequestException('╪ز╪╣╪░╪▒ ╪ح╪ز┘à╪د┘à ╪د┘╪╣┘à┘┘è╪ر╪î ┘┘à ┘è╪ز┘à ╪«╪╡┘à ╪ث┘è ┘à╪ذ┘╪║. ┘è╪▒╪ش┘ë ╪د┘┘à╪ص╪د┘ê┘╪ر ┘╪د╪ص┘é╪د┘ï');
      } finally {
        await session.endSession();
      }
    }

    return this.commitPurchaseSequential(params);
  }

  // ┘à╪│╪د╪▒ ╪ذ╪»┘è┘ ┘┘╪ذ┘┘è╪ر ╪ذ┘╪د ┘à╪╣╪د┘à┘╪د╪ز: ╪«╪╡┘à ╪░╪▒┘ّ┘è ╪س┘à ╪ص┘╪╕ ┘à╪╣ ╪ز╪╣┘ê┘è╪╢ ╪╣┘╪» ╪د┘┘╪┤┘ (╪│┘┘ê┘â ╪│╪د╪ذ┘é ┘à╪ص┘┘ê╪╕)
  private async commitPurchaseSequential(params: {
    orderDoc: Record<string, any>;
    cleanRequestId?: string;
    user: UserDocument;
    price: number;
    ledgerDescription: string;
  }): Promise<
    { kind: 'created'; order: OrderDocument; debited: UserDocument } | { kind: 'duplicate'; existing: OrderDocument }
  > {
    const { orderDoc, cleanRequestId, user, price, ledgerDescription } = params;

    const debited = await this.userModel.findOneAndUpdate(
      { _id: user._id, balance: { $gte: price } },
      { $inc: { balance: -price } },
      { new: true },
    );
    if (!debited) {
      throw new BadRequestException(
        `╪▒╪╡┘è╪»┘â ╪║┘è╪▒ ┘â╪د┘┘. ╪د┘┘à╪ذ┘╪║ ╪د┘┘à╪╖┘┘ê╪ذ: $${price.toFixed(2)}╪î ╪▒╪╡┘è╪»┘â ╪د┘╪ص╪د┘┘è: $${user.balance.toFixed(2)}`,
      );
    }
    const balanceAfter = Number(debited.balance.toFixed(2));
    const balanceBefore = Number((balanceAfter + price).toFixed(2));

    let order: OrderDocument;
    try {
      order = await this.orderModel.create(orderDoc);
    } catch (saveErr: any) {
      if (saveErr?.code === 11000 && cleanRequestId) {
        const existing = await this.orderModel.findOne({ requestId: cleanRequestId });
        if (existing) {
          await this.compensateDuplicateDebit(user, price);
          return { kind: 'duplicate', existing };
        }
      }
      await this.refundUnpersistedDebit(user, price, saveErr);
      throw new BadRequestException('╪ز╪╣╪░╪▒ ╪ح╪ز┘à╪د┘à ╪د┘╪╣┘à┘┘è╪ر╪î ╪ز┘à ╪ح╪▒╪ش╪د╪╣ ╪د┘┘à╪ذ┘╪║ ╪ح┘┘ë ┘à╪ص┘╪╕╪ز┘â. ┘è╪▒╪ش┘ë ╪د┘┘à╪ص╪د┘ê┘╪ر ┘╪د╪ص┘é╪د┘ï');
    }

    try {
      await this.transactionModel.create({
        userId: user._id,
        type: TransactionType.PURCHASE,
        amount: -price,
        balanceBefore,
        balanceAfter,
        description: ledgerDescription,
        referenceType: 'Order',
        referenceId: order._id.toString(),
        status: TransactionStatus.COMPLETED,
      });
    } catch (ledgerErr: any) {
      this.logger.error(`Could not record purchase transaction for ${order.orderNumber}: ${ledgerErr.message}`);
      try {
        order.status = OrderStatus.REFUNDED;
        order.rejectionReason = '╪ز╪╣╪░╪▒ ╪ز╪│╪ش┘è┘ ╪د┘╪ص╪▒┘â╪ر ╪د┘┘à╪د┘┘è╪ر╪î ╪ز┘à ╪ح╪▒╪ش╪د╪╣ ╪د┘┘à╪ذ┘╪║';
        await order.save();
        await this.userModel.findByIdAndUpdate(user._id, { $inc: { balance: price } });
      } catch (compensationErr: any) {
        this.logger.error(`Compensation chain failed for ${order.orderNumber}: ${compensationErr.message}`);
        await this.notifyAdminsSafe(
          '╪ز┘╪ذ┘è┘ç ┘à╪د┘┘è: ╪╖┘╪ذ ┘à╪╣┘┘ّ┘é ╪ذ╪╣╪» ┘╪┤┘ ╪ز╪│╪ش┘è┘ ╪د┘╪ص╪▒┘â╪ر',
          `╪د┘╪╖┘╪ذ #${order.orderNumber} (╪╣┘à┘è┘ ${user.name}╪î ┘à╪ذ┘╪║ $${price.toFixed(2)}) ╪ز╪╣╪░┘ّ╪▒ ╪ز╪│╪ش┘è┘ ╪ص╪▒┘â╪ز┘ç ╪د┘┘à╪د┘┘è╪ر ┘ê╪ز╪╣╪░┘ّ╪▒ ╪ح╪ز┘à╪د┘à ╪ح╪▒╪ش╪د╪╣┘ç ╪ز┘┘é╪د╪خ┘è╪د┘ï╪ؤ ┘è┘╪▓┘à ┘à╪▒╪د╪ش╪╣╪ر ┘è╪»┘ê┘è╪ر.`,
        );
      }
      throw new BadRequestException('╪ز╪╣╪░╪▒ ╪ح╪ز┘à╪د┘à ╪د┘╪╣┘à┘┘è╪ر╪î ┘┘à ┘è╪ز┘à ╪«╪╡┘à ╪ث┘è ┘à╪ذ┘╪║. ┘è╪▒╪ش┘ë ╪د┘┘à╪ص╪د┘ê┘╪ر ┘╪د╪ص┘é╪د┘ï');
    }

    return { kind: 'created', order, debited };
  }

  private generateOrderNumber(): string {
    const timestamp = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const rand = crypto.randomBytes(3).toString('hex').toUpperCase();
    return `ORD-${timestamp}-${rand}`;
  }

  // --- 1. Customer: Place Order ---
  async createOrder(params: {
    userId: string;
    productId: string;
    accountInput?: Record<string, any>;
    // ┘à╪╣╪▒┘ّ┘ ╪ح╪▒╪│╪د┘ ╪د┘╪╣┘à┘è┘: ┘è╪ش╪╣┘ ╪ح╪╣╪د╪»╪ر ╪د┘┘à╪ص╪د┘ê┘╪ر ╪ذ╪╣╪» ╪د┘┘é╪╖╪د╪╣ ╪ت┘à┘╪ر (idempotency)
    requestId?: string;
  }) {
    const user = await this.userModel.findById(params.userId);
    if (!user) throw new NotFoundException('╪د┘┘à╪│╪ز╪«╪»┘à ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    const product = await this.productModel
      .findById(params.productId)
      .populate('serviceTemplateId');
    if (!product || !product.isActive) {
      throw new BadRequestException('╪د┘┘à┘╪ز╪ش ╪║┘è╪▒ ┘à╪ز╪د╪ص ╪ص╪د┘┘è╪د┘ï');
    }

    // ╪د┘╪ز╪╖╪ذ┘è┘é ╪د╪«╪ز┘è╪د╪▒┘è: ╪«╪»┘à╪ر ╪د┘╪ث╪▒┘é╪د┘à ╪د┘┘è╪»┘ê┘è╪ر ╪ذ┘╪د ╪ز╪╖╪ذ┘è┘é ┘à╪ز╪ش╪▒ (┘┘ç╪د virtualNumberAppId)
    const app = product.appId
      ? await this.appModel.findById(product.appId)
      : null;
    if (product.appId && (!app || !app.isActive)) {
      throw new BadRequestException('┘ç╪░┘ç ╪د┘╪«╪»┘à╪ر ┘à╪╣╪╖┘╪ر ╪ص╪د┘┘è╪د┘ï');
    }

    // ╪د┘╪ص┘é┘ê┘ ╪د┘┘à╪╖┘┘ê╪ذ╪ر ┘ê╪د┘╪ص╪│╪د╪│╪ر: ╪ز┘╪┤╪ز┘é ┘à┘ ┘é╪د┘╪ذ ╪د┘╪«╪»┘à╪ر ╪د┘┘à╪▒╪ز╪ذ╪╖ (╪د┘┘à╪╡╪»╪▒ ╪د┘┘à┘ê╪س┘ê┘é)╪î
    // ┘à╪╣ ╪د┘╪▒╪ش┘ê╪╣ ╪ح┘┘ë ╪ص┘é┘ê┘ ╪د┘┘à┘╪ز╪ش ┘â╪«╪╖╪ر ╪ذ╪»┘è┘╪ر ┘┘╪«╪»┘à╪د╪ز ╪║┘è╪▒ ╪د┘┘à╪▒╪ز╪ذ╪╖╪ر ╪ذ┘é╪د┘╪ذ.
    const template = (product as any).serviceTemplateId as
      | { fields?: Array<{ label: string; required?: boolean; isSensitive?: boolean; type?: string }> }
      | null
      | undefined;
    const templateFields = template?.fields || [];

    const effectiveRequiredFields =
      templateFields.length > 0
        ? templateFields.filter((f) => f.required).map((f) => f.label)
        : product.requiredFields || [];

    const effectiveSensitiveFields = Array.from(
      new Set([
        ...(product.sensitiveFields || []),
        ...templateFields
          .filter((f) => f.isSensitive || f.type === 'password')
          .map((f) => f.label),
      ]),
    );

    // ╪د┘╪ز╪ص┘é┘é ┘à┘ ╪د┘â╪ز┘à╪د┘ ╪د┘╪ص┘é┘ê┘ ╪د┘┘à╪╖┘┘ê╪ذ╪ر ┘é╪ذ┘ ╪«╪╡┘à ╪ث┘è ┘à╪ذ┘╪║ ┘à┘ ╪د┘┘à╪ص┘╪╕╪ر
    // (┘à┘╪ز╪ش╪د╪ز ╪د┘╪ث┘â┘ê╪د╪» ╪ز┘╪│┘┘┘ّ┘à ╪ت┘┘è╪د┘ï ┘┘╪د ╪ز╪ص╪ز╪د╪ش ╪ص┘é┘ê┘ ╪ح╪»╪«╪د┘)
    const rawInput = params.accountInput || {};
    if (product.type !== ProductType.CODES) {
      const missingFields = effectiveRequiredFields.filter(
        (label) =>
          rawInput[label] === undefined ||
          rawInput[label] === null ||
          String(rawInput[label]).trim() === '',
      );
      if (missingFields.length > 0) {
        throw new BadRequestException(
          `┘è╪▒╪ش┘ë ╪ح┘â┘à╪د┘ ╪د┘╪ص┘é┘ê┘ ╪د┘┘à╪╖┘┘ê╪ذ╪ر: ${missingFields.join('╪î ')}`,
        );
      }
    }

    const price = product.salePrice;
    if (user.balance < price) {
      throw new BadRequestException(
        `╪▒╪╡┘è╪»┘â ╪║┘è╪▒ ┘â╪د┘┘. ╪د┘┘à╪ذ┘╪║ ╪د┘┘à╪╖┘┘ê╪ذ: $${price.toFixed(2)}╪î ╪▒╪╡┘è╪»┘â ╪د┘╪ص╪د┘┘è: $${user.balance.toFixed(2)}`,
      );
    }

    // Fail fast: verify the provider is reachable and funded BEFORE touching the wallet
    if (product.type === ProductType.DIRECT_API && product.providerId) {
      await this.providersService.ensureReadyForOrder(product.providerId.toString(), product.costPrice || 0);
    }

    if (product.type === ProductType.CODES && (!product.inventoryCodes || product.inventoryCodes.length === 0)) {
      throw new BadRequestException('╪╣╪░╪▒╪د┘ï╪î ┘ç╪░╪د ╪د┘┘à┘╪ز╪ش ╪║┘è╪▒ ┘à╪ز┘ê┘╪▒ ┘┘è ╪د┘┘à╪«╪▓┘ê┘ ╪ص╪د┘┘è╪د┘ï');
    }

    // ╪د┘╪«╪╡┘à ┘┘à ┘è┘é╪╣ ╪ذ╪╣╪»: ╪د┘┘┘è╪ر (┘à╪│╪ز┘╪» ╪د┘╪╖┘╪ذ) ┘ê╪د┘╪«╪╡┘à ┘ê╪د┘╪ص╪▒┘â╪ر ╪د┘┘à╪د┘┘è╪ر ╪ز┘╪ص╪│┘à ┘à╪╣╪د┘ï ╪»╪د╪«┘ ┘à╪╣╪د┘à┘╪ر ╪░╪▒┘ّ┘è╪ر (A/E)

    // Process specific product type logic
    let deliveredCode: string | undefined = undefined;
    let initialStatus = OrderStatus.PENDING;
    const estimatedMinutes = product.estimatedMinutes || 120;
    const deadlineAt = new Date(Date.now() + estimatedMinutes * 60 * 1000);
    const timeline: OrderTimelineEvent[] = [];

    const orderNumber = this.generateOrderNumber();
    const profit = Number((price - product.costPrice).toFixed(2));

    // Handle Sensitive Fields in Customer Input
    const sanitizedInput: Record<string, any> = { ...(params.accountInput || {}) };
    for (const field of effectiveSensitiveFields) {
      if (sanitizedInput[field]) {
        sanitizedInput[field] = CryptoUtil.encrypt(String(sanitizedInput[field]));
      }
    }

    // Timeline event 1: Created & Paid
    timeline.push({
      action: 'created_paid',
      title: '╪ز┘à ╪ح┘╪┤╪د╪ة ╪د┘╪╖┘╪ذ ┘ê╪»┘╪╣ ╪د┘┘é┘è┘à╪ر',
      description: `╪ز┘à ╪«╪╡┘à $${price.toFixed(2)} ┘à┘ ┘à╪ص┘╪╕╪ر ╪د┘╪╣┘à┘è┘ ┘┘╪«╪»┘à╪ر: ${product.name}`,
      performerId: user._id,
      performerName: user.name,
      performerRole: 'customer',
      timestamp: new Date(),
    });

    // Persist the order BEFORE calling the provider so every attempt stays auditable
    // (retry-safe: same requestId hits the unique index and must not create a second order)
    const cleanRequestId =
      typeof params.requestId === 'string' && params.requestId.trim() ? params.requestId.trim() : undefined;
    const orderDoc = {
      orderNumber,
      userId: user._id,
      appId: app?._id,
      virtualNumberAppId: product.virtualNumberAppId,
      productId: product._id,
      providerId: product.providerId,
      type: product.type,
      amount: price,
      cost: product.costPrice,
      profit,
      status: OrderStatus.PENDING,
      accountInput: sanitizedInput,
      estimatedMinutes,
      deadlineAt,
      isSensitive: effectiveSensitiveFields.length > 0 || product.isSensitive || false,
      sensitiveFields: effectiveSensitiveFields,
      timeline,
      chatMessages: [],
      ...(cleanRequestId ? { requestId: cleanRequestId } : {}),
    };
    // ╪د┘╪«╪╡┘à + ╪ص┘╪╕ ╪د┘╪╖┘╪ذ + ╪ص╪▒┘â╪ر ╪د┘╪┤╪▒╪د╪ة ╪░╪▒┘ّ┘è╪د┘ï ╪»╪د╪«┘ ┘à╪╣╪د┘à┘╪ر╪ؤ ╪ث┘ê ╪ز╪ز╪د╪ذ╪╣┘è╪د┘ï ┘à╪╣ ╪ز╪╣┘ê┘è╪╢ ╪╣┘╪» ╪║┘è╪د╪ذ ╪د┘╪»╪╣┘à
    const commit = await this.commitPurchaseMoney({
      orderDoc,
      cleanRequestId,
      user,
      price,
      // ╪د╪│┘à ╪د┘╪ز╪╖╪ذ┘è┘é ┘┘╪│┘è╪د┘é╪ؤ ╪«╪»┘à╪د╪ز ╪د┘╪ث╪▒┘é╪د┘à ╪د┘┘è╪»┘ê┘è╪ر ╪ذ┘╪د ╪ز╪╖╪ذ┘è┘é ┘à╪ز╪ش╪▒ ┘┘è┘┘â╪ز┘┘ë ╪ذ╪د╪│┘à ╪د┘┘à┘╪ز╪ش
      ledgerDescription: `╪┤╪▒╪د╪ة ${product.name}${app?.name ? ` (${app.name})` : ''}`,
    });
    if (commit.kind === 'duplicate') {
      // ╪ح╪╣╪د╪»╪ر ╪ح╪▒╪│╪د┘ ╪ذ┘┘╪│ requestId: ┘┘à ┘è┘╪│╪ص╪ذ ╪┤┘è╪ة ┘┘è ╪د┘┘à╪╣╪د┘à┘╪ر╪î ╪ث┘ê ╪╣┘┘ê┘┘ّ╪╢ ┘┘è ╪د┘┘à╪│╪د╪▒ ╪د┘╪ز╪ز╪د╪ذ╪╣┘è
      return {
        message: '╪ز┘à ╪ز┘┘┘è╪░ ╪╖┘╪ذ┘â ╪│╪د╪ذ┘é╪د┘ï╪î ┘ê┘ç╪░┘ç ┘╪│╪«╪ر ╪╣┘┘ç',
        order: await this.getOrderById(commit.existing._id.toString()),
        newBalance: await this.getUserBalance(user._id),
        deliveredCode: commit.existing.deliveredCode,
      };
    }
    const order = commit.order;
    // Derived from the authoritative post-debit document, never from a stale read
    const balanceAfter = Number(commit.debited.balance.toFixed(2));

    let assignedSupervisorId: Types.ObjectId | undefined = undefined;
    let assignedSupervisorUser: UserDocument | null = null;

    if (product.type === ProductType.CODES) {
      // Re-checked here because a concurrent order may have drained the stock ظ¤
      // ╪د┘╪│╪ص╪ذ ╪░╪▒┘è ($pop) ┘┘╪د ┘è┘╪│┘┘┘ّ┘à ┘┘╪│ ╪د┘┘â┘ê╪» ┘╪╖┘╪ذ┘è┘ ┘à╪ز╪▓╪د┘à┘┘è┘
      const code = await this.allocateInventoryCode(product._id);
      if (!code) {
        return this.failPaidOrder(order, {
          amount: price,
          reason: '╪╣╪░╪▒╪د┘ï╪î ┘ç╪░╪د ╪د┘┘à┘╪ز╪ش ╪║┘è╪▒ ┘à╪ز┘ê┘╪▒ ┘┘è ╪د┘┘à╪«╪▓┘ê┘ ╪ص╪د┘┘è╪د┘ï',
        });
      }
      deliveredCode = code;
      initialStatus = OrderStatus.COMPLETED;

      order.timeline.push({
        action: 'delivered',
        title: '╪ز┘à ╪ز╪│┘┘è┘à ╪د┘┘â┘ê╪» ╪ز┘┘é╪د╪خ┘è╪د┘ï',
        description: '╪ز┘à ╪ز╪│┘┘è┘à ┘â┘ê╪» ╪د┘╪ذ╪╖╪د┘é╪ر ┘┘╪╣┘à┘è┘ ┘à╪ذ╪د╪┤╪▒╪ر ┘à┘ ╪د┘┘à╪«╪▓┘ê┘',
        performerName: '╪د┘┘╪╕╪د┘à ╪د┘╪ت┘┘è',
        performerRole: 'system',
        timestamp: new Date(),
      });
    } else if (product.type === ProductType.DIRECT_API) {
      if (product.providerId) {
        // Extract player ID / zone ID from accountInput
        const rawInput = params.accountInput || {};
        const gameUserId =
          rawInput['Player ID'] ||
          rawInput['User ID'] ||
          rawInput['╪د┘┘à╪╣╪▒┘'] ||
          rawInput['ID'] ||
          rawInput['userid'] ||
          rawInput['playerId'] ||
          Object.values(rawInput)[0];

        const gameZoneId =
          rawInput['Zone ID'] ||
          rawInput['Server ID'] ||
          rawInput['Server/Zone ID'] ||
          rawInput['╪د┘╪│┘è╪▒┘╪▒'] ||
          rawInput['serverid'] ||
          rawInput['zoneId'] ||
          (Object.values(rawInput).length > 1 ? Object.values(rawInput)[1] : undefined);

        if (!gameUserId) {
          // Refund the customer atomically and keep the attempt on record
          return this.failPaidOrder(order, {
            amount: price,
            reason: '┘è╪▒╪ش┘ë ╪ح╪»╪«╪د┘ ┘à╪╣╪▒┘ ╪د┘┘╪د╪╣╪ذ (Player ID) ╪د┘┘à╪╖┘┘ê╪ذ ┘┘╪┤╪ص┘',
          });
        }

        let providerResult: Awaited<ReturnType<ProvidersService['executeOrder']>>;
        try {
          providerResult = await this.providersService.executeOrder(product.providerId.toString(), {
            productCode: product.providerProductCode || '',
            gameUserId: String(gameUserId),
            gameZoneId: gameZoneId ? String(gameZoneId) : undefined,
            reference: orderNumber,
          });
        } catch (err: any) {
          // An unexpected transport/execution throw must never cost the customer money ظ¤
          // ┘ê╪د┘┘à┘ç┘╪ر ╪د┘┘à┘╪ز┘ç┘è╪ر ╪د┘┘à╪ش┘ç┘ê┘╪ر ╪د┘┘à╪╡┘è╪▒ ╪ز╪ذ┘é┘ë ┘à╪╣┘┘ّ┘é╪ر ┘┘┘à╪╡╪د┘╪ص╪ر ┘╪د ╪د╪│╪ز╪▒╪ش╪د╪╣╪د┘ï ╪ث╪╣┘à┘ë (H3)
          providerResult = {
            success: false,
            message: err?.message || '╪ز╪╣╪░╪▒ ╪د┘╪د╪ز╪╡╪د┘ ╪ذ┘à╪▓┘ê┘ّ╪» ╪د┘╪«╪»┘à╪ر',
            isTimeout: true,
          };
        }

        if (!providerResult.success) {
          this.logger.error(`Provider direct execution failed for ${orderNumber}: ${providerResult.message}`);

          // Surface the incident to the provider record and to the admins
          try {
            await this.providersService.markProviderFailure(
              product.providerId.toString(),
              providerResult.message,
              product.costPrice || 0,
            );
          } catch (markErr: any) {
            this.logger.warn(`Could not mark provider failure: ${markErr.message}`);
          }

          // ╪د┘┘é╪╖╪د╪╣ ┘à┘ç┘╪ر/╪د╪│╪ز╪س┘╪د╪ة ┘┘é┘: ╪د┘┘à╪▓┘ê╪» ┘é╪» ┘è┘â┘ê┘ ┘┘┘ّ╪░ ╪د┘╪┤╪ص┘ ┘╪╣┘╪د┘ï ظ¤ ╪د┘╪╖┘╪ذ ┘è╪ذ┘é┘ë
          // ┘à╪╣┘┘ّ┘é╪د┘ï ┘ê╪د┘┘à╪▒╪ش╪╣ ┘à╪ص┘┘ê╪╕╪د┘ï ╪ص╪ز┘ë ╪ز╪ص╪│┘à┘ç ╪د┘┘à╪╡╪د┘╪ص╪ر ╪د┘╪»┘ê╪▒┘è╪ر (╪ز╪ث┘â┘è╪» ╪ث┘ê ╪د╪│╪ز╪▒╪ش╪د╪╣)
          if (providerResult.isTimeout) {
            order.providerReference = order.providerReference || orderNumber;
            order.status = OrderStatus.PENDING;
            order.rejectionReason = `╪ش╪د╪▒┘ ╪د┘╪ز╪ص┘é┘é ┘à┘ ╪ص╪د┘╪ر ╪د┘╪╖┘╪ذ ┘╪»┘ë ┘à╪▓┘ê╪» ╪د┘╪«╪»┘à╪ر: ${providerResult.message}`;
            order.timeline.push({
              action: 'provider_timeout',
              title: '╪د┘┘é╪╖╪د╪╣ ╪د┘╪د╪ز╪╡╪د┘ ╪ذ┘à╪▓┘ê╪» ╪د┘╪«╪»┘à╪ر ظ¤ ╪د┘╪╖┘╪ذ ┘é┘è╪» ╪د┘╪ز╪ص┘é┘é',
              description: '┘é╪» ┘è┘â┘ê┘ ╪د┘╪╖┘╪ذ ┘┘┘┘ّ╪░ ┘╪»┘ë ╪د┘┘à╪▓┘ê╪» ╪▒╪║┘à ╪د┘┘é╪╖╪د╪╣ ╪د┘╪د╪│╪ز╪ش╪د╪ذ╪ر╪ؤ ╪│┘è╪╣╪د╪» ┘╪ص╪╡┘ç ╪ز┘┘é╪د╪خ┘è╪د┘ï ┘ê┘è┘╪ذ┘┘ّ╪║ ╪د┘╪╣┘à┘è┘ ╪ذ╪د┘┘╪ز┘è╪ش╪ر.',
              performerName: '╪د┘┘╪╕╪د┘à ╪د┘╪ت┘┘è',
              performerRole: 'system',
              timestamp: new Date(),
            });
            await order.save();

            await this.notifyAdminsSafe(
              '╪ز┘╪ذ┘è┘ç: ┘à┘ç┘╪ر ╪د┘┘é╪╖╪د╪╣ ┘╪»┘ë ╪د┘┘à╪▓┘ê╪»',
              `╪د┘╪╖┘╪ذ #${orderNumber} (${product.name}) ╪د┘╪ز┘ç┘ë ┘╪»╪د╪ج┘ç ╪ذ╪د┘┘à┘ç┘╪ر ظ¤ ╪│┘è┘╪ص╪│┘à ╪ز┘┘é╪د╪خ┘è╪د┘ï ╪╣╪ذ╪▒ ╪د┘┘à╪╡╪د┘╪ص╪ر.`,
            );

            return {
              message: `╪ز┘à ╪د╪│╪ز┘╪د┘à ╪╖┘╪ذ┘â╪ؤ ╪د┘┘é╪╖╪╣ ╪د┘╪د╪ز╪╡╪د┘ ╪ذ┘à╪▓┘ê╪» ╪د┘╪«╪»┘à╪ر ╪ث╪س┘╪د╪ة ╪د┘╪ز┘┘┘è╪░ ┘ê╪│┘è┘╪ص╪»┘┘ّ╪س ╪ص╪د┘╪ز┘ç ╪ز┘┘é╪د╪خ┘è╪د┘ï ╪«┘╪د┘ ╪»┘é╪د╪خ┘é (${orderNumber})`,
              order: await this.getOrderById(order._id.toString()),
              newBalance: balanceAfter,
            };
          }

          await this.notificationsService
            .createNotification({
              forRole: 'admin',
              title: '┘╪┤┘ ╪ز┘┘┘è╪░ ╪╖┘╪ذ ┘╪»┘ë ╪د┘┘à╪▓┘ê┘ّ╪»',
              body: `╪ز╪╣╪░┘ّ╪▒ ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ #${orderNumber} (${product.name}) ╪╣╪ذ╪▒ ╪د┘┘à╪▓┘ê┘ّ╪»: ${providerResult.message}. ╪ز┘à ╪ح╪▒╪ش╪د╪╣ ╪د┘┘à╪ذ┘╪║ ┘┘╪╣┘à┘è┘ ╪ز┘┘é╪د╪خ┘è╪د┘ï.`,
              type: 'provider_failure',
              data: {
                orderId: order._id.toString(),
                orderNumber,
                productId: product._id.toString(),
                providerId: product.providerId.toString(),
              },
            })
            .catch((notifyErr: any) => {
              this.logger.warn(`Could not notify admins about provider failure: ${notifyErr.message}`);
            });

          // No funds are kept: the customer is refunded atomically
          return this.failPaidOrder(order, {
            amount: price,
            reason: `╪ز╪╣╪░╪▒ ╪ح╪ز┘à╪د┘à ╪د┘╪┤╪ص┘ ╪╣╪ذ╪▒ ╪د┘┘à╪▓┘ê╪»: ${providerResult.message}`,
            providerRaw: providerResult.raw,
          });
        }

        if (providerResult.raw?.items?.[0]?.externalData?.length) {
          deliveredCode = providerResult.raw.items[0].externalData.join(', ');
        }

        // Kept for later reconciliation against the provider
        order.providerReference = providerResult.transactionId || orderNumber;
        order.providerResponse = providerResult.raw as Record<string, any>;

        initialStatus = OrderStatus.COMPLETED;
        order.timeline.push({
          action: 'delivered',
          title: '╪ز┘à ╪ز┘┘┘è╪░ ╪د┘╪┤╪ص┘ ╪╣╪ذ╪▒ ╪د┘┘à╪▓┘ê╪» ╪د┘╪ت┘┘è ╪ذ┘╪ش╪د╪ص',
          description: `╪ز┘à ╪ح╪▒╪│╪د┘ ╪د┘╪╖┘╪ذ ┘ê╪ز┘┘┘è╪░┘ç ╪ذ┘╪ش╪د╪ص ╪╣╪ذ╪▒ ┘à╪▓┘ê╪» ╪د┘╪«╪»┘à╪ر (╪د┘┘à╪▒╪ش╪╣: ${providerResult.transactionId || orderNumber})`,
          performerName: '╪د┘┘╪╕╪د┘à ╪د┘╪ت┘┘è (API)',
          performerRole: 'system',
          timestamp: new Date(),
        });
      } else {
        initialStatus = OrderStatus.COMPLETED;
        order.timeline.push({
          action: 'delivered',
          title: '╪ز┘à ╪ز┘┘┘è╪░ ╪د┘╪┤╪ص┘ ╪╣╪ذ╪▒ ╪د┘┘à╪▓┘ê╪» ╪د┘╪ت┘┘è',
          description: '╪ز┘à ╪ح╪▒╪│╪د┘ ╪د┘╪┤╪ص┘ ┘ê╪ز┘┘┘è╪░┘ç ╪ذ┘╪ش╪د╪ص ╪╣╪ذ╪▒ ┘à╪▓┘ê╪» ╪د┘╪«╪»┘à╪ر',
          performerName: '╪د┘┘╪╕╪د┘à ╪د┘╪ت┘┘è',
          performerRole: 'system',
          timestamp: new Date(),
        });
      }
    } else if (product.type === ProductType.MANUAL) {
      // Manual Service requiring human execution
      if (product.assignedSupervisorId) {
        assignedSupervisorId = product.assignedSupervisorId;
        assignedSupervisorUser = await this.userModel.findById(assignedSupervisorId);
        initialStatus = OrderStatus.ASSIGNED;

        order.timeline.push({
          action: 'assigned',
          title: `╪ز┘à ╪ح╪│┘╪د╪» ╪د┘╪╖┘╪ذ ┘┘┘à╪┤╪▒┘ (${assignedSupervisorUser?.name || '╪د┘┘à╪┤╪▒┘ ╪د┘┘à╪│╪ج┘ê┘'})`,
          description: `╪ز┘à ╪ح╪│┘╪د╪» ╪د┘╪╖┘╪ذ ╪ز┘┘é╪د╪خ┘è╪د┘ï╪î ┘ê╪د┘┘ê┘é╪ز ╪د┘┘à╪ز┘ê┘é╪╣ ┘┘╪ز┘┘┘è╪░: ${estimatedMinutes} ╪»┘é┘è┘é╪ر`,
          performerName: '╪د┘┘╪╕╪د┘à ╪د┘╪ت┘┘è',
          performerRole: 'system',
          timestamp: new Date(),
        });
      } else {
        initialStatus = OrderStatus.PENDING;
        order.timeline.push({
          action: 'pending_assignment',
          title: '╪ذ╪د┘╪ز╪╕╪د╪▒ ╪ح╪│┘╪د╪» ╪د┘┘à╪┤╪▒┘',
          description: '╪د┘╪╖┘╪ذ ╪ذ╪د┘╪ز╪╕╪د╪▒ ┘é┘è╪د┘à ╪د┘╪ح╪»╪د╪▒╪ر ╪ذ╪ز╪╣┘è┘è┘ ┘à╪┤╪▒┘ ┘┘╪ز┘┘┘è╪░',
          performerName: '╪د┘┘╪╕╪د┘à',
          performerRole: 'system',
          timestamp: new Date(),
        });
      }
    }

    // Finalize the order shell created before the provider call
    order.status = initialStatus;
    order.deliveredCode = deliveredCode;
    order.assignedSupervisorId = assignedSupervisorId;
    order.rejectionReason = undefined;
    order.completedAt = initialStatus === OrderStatus.COMPLETED ? new Date() : undefined;
    try {
      await order.save();
    } catch (finalizeErr: any) {
      // ╪د┘╪╖┘╪ذ ╪ث┘┘â┘à┘/╪ث┘╪▒╪│┘ ┘╪»┘ë ╪د┘┘à╪▓┘ê╪» ┘┘â┘ ╪ص╪د┘╪ر ╪د┘┘à╪│╪ز┘╪» ┘┘à ╪ز╪ز╪ص╪»╪س ظ¤ ╪ز┘┘╪ز┘é╪╖ ╪ذ╪د┘┘à╪╡╪د┘╪ص╪ر ╪ث┘ê ┘è╪»┘ê┘è╪د┘ï
      this.logger.error(`Order finalize save failed for ${orderNumber}: ${finalizeErr.message}`);
      // ┘â┘ê╪» ╪د┘╪ث┘â┘ê╪د╪» ╪د┘┘à╪│╪ص┘ê╪ذ ┘╪د ╪ز┘╪║╪╖┘ّ┘è┘ç ╪د┘┘à╪╡╪د┘╪ص╪ر: ┘è┘╪╣╪د╪» ┘┘┘à╪«╪▓┘ê┘ ┘â┘è ┘╪د ┘è╪ز┘è╪ز┘à (D)
      if (product.type === ProductType.CODES && deliveredCode) {
        await this.releaseInventoryCode(product._id, deliveredCode);
      }
      await this.notifyAdminsSafe(
        '╪ز┘╪ذ┘è┘ç: ╪ز╪╣╪░┘ّ╪▒ ╪ز╪ص╪»┘è╪س ╪ص╪د┘╪ر ╪╖┘╪ذ ╪ذ╪╣╪» ╪د┘╪ز┘┘┘è╪░',
        `╪د┘╪╖┘╪ذ #${orderNumber} ┘┘┘┘ّ╪░/╪ث┘╪▒╪│┘ ┘┘â┘ ╪ص╪د┘╪ز┘ç ┘┘à ╪ز┘╪ص╪»┘┘ّ╪س ┘┘è ╪د┘┘é╪د╪╣╪»╪ر╪ؤ ┘è┘╪▓┘à ┘à╪▒╪د╪ش╪╣╪ر ┘è╪»┘ê┘è╪ر.`,
      );
    }

    // Notify Supervisor if assigned (╪ح╪┤╪╣╪د╪▒ ┘╪د╪ص┘é ┘╪د ┘è┘╪┤┘ ╪د┘╪╖┘╪ذ ╪د┘┘╪د╪ش╪ص ظ¤ H5)
    if (assignedSupervisorId && assignedSupervisorUser) {
      await this.notificationsService
        .createNotification({
          userId: assignedSupervisorId.toString(),
          forRole: 'supervisor',
          title: '╪╖┘╪ذ ┘è╪»┘ê┘è ╪ش╪»┘è╪» ┘à╪│┘╪» ╪ح┘┘è┘â ≡ا¤¤',
          body: `╪╖┘╪ذ ╪ش╪»┘è╪» #${orderNumber} ┘╪«╪»┘à╪ر ${product.name}. ╪د┘┘ê┘é╪ز ╪د┘┘à╪ز┘ê┘é╪╣: ${estimatedMinutes} ╪»┘é┘è┘é╪ر.`,
          type: 'manual_service_assigned',
          data: {
            orderId: order._id.toString(),
            orderNumber,
            serviceName: product.name,
            estimatedMinutes,
          },
        })
        .catch((err: any) => this.logger.warn(`Supervisor notification failed: ${err.message}`));
    }

    // Notify Admins of new order
    await this.notificationsService
      .createNotification({
        forRole: 'admin',
        title: '╪╖┘╪ذ ╪ش╪»┘è╪» ≡اؤْ',
        body: `╪╖┘╪ذ ╪ش╪»┘è╪» ╪▒┘é┘à #${orderNumber} ┘╪«╪»┘à╪ر ${product.name} ╪ذ┘à╪ذ┘╪║ $${price.toFixed(2)}`,
        type: 'new_order',
        data: { orderId: order._id.toString(), orderNumber },
      })
      .catch((err: any) => this.logger.warn(`Admin new-order notification failed: ${err.message}`));

    // Notify User if completed immediately
    if (initialStatus === OrderStatus.COMPLETED) {
      await this.notificationsService
        .createNotification({
          userId: user._id.toString(),
          title: '╪ز┘à ╪ز┘┘┘è╪░ ╪╖┘╪ذ┘â ╪ذ┘╪ش╪د╪ص ظ£à',
          body:
            product.type === ProductType.CODES
              ? `╪ز┘à ╪د╪│╪ز┘╪د┘à ┘â┘ê╪» ╪ذ╪د┘é╪ر ${product.name}: ${deliveredCode}`
              : `╪ز┘à ╪ز┘┘┘è╪░ ╪┤╪ص┘ ╪ذ╪د┘é╪ر ${product.name} ┘╪ص╪│╪د╪ذ┘â ╪ذ┘╪ش╪د╪ص`,
          type: 'order_status',
          data: { orderId: order._id.toString(), deliveredCode },
        })
        .catch((err: any) => this.logger.warn(`Customer completion notification failed: ${err.message}`));
    }

    // ╪د┘┘é╪▒╪د╪ة╪ر ╪د┘╪ث╪«┘è╪▒╪ر ╪▒┘╪د┘ç┘è╪ر: ┘╪┤┘┘ç╪د ┘╪د ┘è╪ش╪ذ ╪ث┘ ┘è┘╪│┘é╪╖ ╪د╪│╪ز╪ش╪د╪ذ╪ر ╪╖┘╪ذ┘ ┘╪ش╪ص ┘╪╣┘╪د┘ï (H5)
    let orderView: any = order;
    try {
      orderView = await this.getOrderById(order._id.toString());
    } catch (viewErr: any) {
      this.logger.warn(`Could not refetch order view for ${orderNumber}: ${viewErr.message}`);
    }

    return {
      message:
        initialStatus === OrderStatus.COMPLETED
          ? '╪ز┘à ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ ╪ذ┘╪ش╪د╪ص'
          : initialStatus === OrderStatus.ASSIGNED
          ? '╪ز┘à ╪د╪│╪ز┘╪د┘à ╪╖┘╪ذ┘â ┘ê╪ش╪د╪▒┘è ╪ز╪ص┘ê┘è┘┘ç ┘┘┘à╪┤╪▒┘ ╪د┘┘à╪«╪ز╪╡ ┘╪ذ╪»╪ة ╪د┘╪ز┘┘┘è╪░'
          : '╪ز┘à ╪ح╪▒╪│╪د┘ ╪╖┘╪ذ ╪د┘╪┤╪ص┘ ╪ذ┘╪ش╪د╪ص ┘ê┘ç┘ê ┘é┘è╪» ╪د┘┘à╪▒╪د╪ش╪╣╪ر',
      order: orderView,
      newBalance: balanceAfter,
      deliveredCode,
    };
  }

  // Atomically refund a paid-but-unfulfilled order while keeping the paper trail intact
  private async failPaidOrder(
    order: OrderDocument,
    params: { amount: number; reason: string; providerRaw?: any },
  ): Promise<never> {
    let refunded: UserDocument | null = null;
    try {
      refunded = await this.userModel.findByIdAndUpdate(
        order.userId,
        { $inc: { balance: params.amount } },
        { new: true },
      );
    } catch (creditErr: any) {
      // ╪ز╪╣╪░┘ّ╪▒ ╪ح╪▒╪ش╪د╪╣ ╪د┘┘à╪د┘: ╪د┘╪╖┘╪ذ ┘è╪ذ┘é┘ë ┘à╪╣┘┘ّ┘é╪د┘ï ┘ê╪د┘┘à╪▒╪ش╪╣ ┘à╪ص┘┘ê╪╕╪د┘ï ظ¤ ╪د┘┘à╪╡╪د┘╪ص╪ر ╪د┘╪»┘ê╪▒┘è╪ر
      // ╪ث┘ê ┘à╪▒╪د╪ش╪╣╪ر ╪د┘╪ث╪»┘à┘ ╪ز╪ص╪│┘à┘ç╪î ┘ê┘╪د ┘è┘╪ذ╪ز┘╪╣ ╪د┘╪«╪╖╪ث ╪ذ╪╡┘à╪ز (H2)
      this.logger.error(`Refund credit failed for ${order.orderNumber}: ${creditErr.message}`);
      try {
        order.providerReference = order.providerReference || order.orderNumber;
        await order.save();
      } catch (saveErr: any) {
        this.logger.error(`Could not persist reference for ${order.orderNumber}: ${saveErr.message}`);
      }
      await this.notifyAdminsSafe(
        '╪ز┘╪ذ┘è┘ç ┘à╪د┘┘è: ┘╪┤┘ ╪ح╪▒╪ش╪د╪╣ ┘à╪ذ┘╪║ ┘╪╖┘╪ذ ┘à╪ز╪╣╪░╪▒',
        `╪د┘╪╖┘╪ذ #${order.orderNumber} ╪ز╪╣╪░┘ّ╪▒ ╪ز┘┘┘è╪░┘┘ç ($${params.amount.toFixed(2)}) ┘ê┘╪┤┘ ╪ح╪▒╪ش╪د╪╣ ╪د┘┘à╪ذ┘╪║ ┘┘╪╣┘à┘è┘╪ؤ ┘è┘╪▓┘à ╪ز╪»╪«┘ ┘è╪»┘ê┘è.`,
      );
      throw new BadRequestException(`${params.reason} (╪▒┘é┘à ╪د┘╪╖┘╪ذ: ${order.orderNumber})`);
    }

    const balanceAfter = Number((refunded?.balance ?? params.amount).toFixed(2));
    const balanceBefore = Number((balanceAfter - params.amount).toFixed(2));

    order.status = OrderStatus.REFUNDED;
    order.rejectionReason = params.reason;
    // The provider references orders by this same number, so keep it for later checks
    order.providerReference = order.providerReference || order.orderNumber;
    if (params.providerRaw !== undefined) {
      order.providerResponse = params.providerRaw as Record<string, any>;
    }
    order.timeline.push({
      action: 'auto_refunded',
      title: '╪ز╪╣╪░┘ّ╪▒ ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ ┘ê╪ز┘à ╪ح╪▒╪ش╪د╪╣ ╪د┘┘à╪ذ┘╪║ ╪ز┘┘é╪د╪خ┘è╪د┘ï',
      description: params.reason,
      performerName: '╪د┘┘╪╕╪د┘à ╪د┘╪ت┘┘è',
      performerRole: 'system',
      timestamp: new Date(),
    });
    await order.save();

    // Matches the PURCHASE entry so the wallet ledger always balances
    try {
      await this.transactionModel.create({
        userId: order.userId,
        type: TransactionType.REFUND,
        amount: params.amount,
        balanceBefore,
        balanceAfter,
        description: `╪ح╪▒╪ش╪د╪╣ ╪ز┘┘é╪د╪خ┘è ┘╪╖┘╪ذ ┘à╪ز╪╣╪░╪▒ #${order.orderNumber}`,
        referenceType: 'Order',
        referenceId: order._id.toString(),
        status: TransactionStatus.COMPLETED,
      });
    } catch (ledgerErr: any) {
      // ╪د┘┘à╪د┘ ╪▒┘╪ش╪╣ ┘╪╣┘┘è╪د┘ï ┘┘â┘ ╪د┘╪»┘╪ز╪▒ ┘┘à ┘è╪│╪ش┘ّ┘ ظ¤ ╪ز┘╪ذ┘è┘ç ╪د┘╪ح╪»╪د╪▒╪ر ╪ذ╪»┘ ╪د┘╪╡┘à╪ز (H2)
      this.logger.error(`Refund ledger entry failed for ${order.orderNumber}: ${ledgerErr.message}`);
      await this.notifyAdminsSafe(
        '╪ز┘╪ذ┘è┘ç ╪»┘╪ز╪▒: ╪ص╪▒┘â╪ر ╪ح╪▒╪ش╪د╪╣ ╪║┘è╪▒ ┘à╪│╪ش┘╪ر',
        `╪ث┘╪▒╪ش╪╣ $${params.amount.toFixed(2)} ┘┘╪╣┘à┘è┘ ┘┘è ╪د┘╪╖┘╪ذ #${order.orderNumber} ┘┘â┘ ╪ز╪│╪ش┘è┘ ╪د┘╪ص╪▒┘â╪ر ┘╪┤┘╪ؤ ┘è┘╪▓┘à ┘à╪▒╪د╪ش╪╣╪ر ╪د┘╪»┘╪ز╪▒.`,
      );
    }

    throw new BadRequestException(`${params.reason} (╪▒┘é┘à ╪د┘╪╖┘╪ذ: ${order.orderNumber})`);
  }

  // Refunds a paid order atomically and records the matching ledger entry
  private async autoRefundOrder(order: OrderDocument, reason: string, title: string) {
    const refundedUser = await this.userModel.findByIdAndUpdate(
      order.userId,
      { $inc: { balance: order.amount } },
      { new: true },
    );
    const balanceAfter = Number((refundedUser?.balance ?? order.amount).toFixed(2));

    order.status = OrderStatus.REFUNDED;
    order.rejectionReason = reason;
    order.timeline.push({
      action: 'auto_refunded',
      title,
      description: reason,
      performerName: '╪د┘┘à╪╡╪د┘╪ص╪ر ╪د┘╪ت┘┘è╪ر',
      performerRole: 'system',
      timestamp: new Date(),
    });
    await order.save();

    await this.transactionModel.create({
      userId: order.userId,
      type: TransactionType.REFUND,
      amount: order.amount,
      balanceBefore: Number((balanceAfter - order.amount).toFixed(2)),
      balanceAfter,
      description: `╪ح╪▒╪ش╪د╪╣ ╪ز┘┘é╪د╪خ┘è (┘à╪╡╪د┘╪ص╪ر) ┘╪╖┘╪ذ #${order.orderNumber}`,
      referenceType: 'Order',
      referenceId: order._id.toString(),
      status: TransactionStatus.COMPLETED,
    });

    await this.notificationsService.createNotification({
      userId: order.userId.toString(),
      title: '╪ز┘à ╪ح╪▒╪ش╪د╪╣ ┘à╪ذ┘╪║ ╪╖┘╪ذ┘â ╪ح┘┘ë ╪د┘┘à╪ص┘╪╕╪ر',
      body: `╪ز╪╣╪░┘ّ╪▒ ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ #${order.orderNumber} ┘╪»┘ë ┘à╪▓┘ê╪» ╪د┘╪«╪»┘à╪ر╪î ┘ê╪ز┘à ╪ح╪▒╪ش╪د╪╣ $${order.amount.toFixed(2)} ╪ح┘┘ë ┘à╪ص┘╪╕╪ز┘â.`,
      type: 'order_refunded',
      data: { orderId: order._id.toString(), amount: order.amount, reason },
    });
  }

  // Re-checks provider-executed orders that were marked completed without an actual delivery
  async reconcileProviderOrders(limit = 20) {
    const orders = await this.orderModel
      .find({
        type: ProductType.DIRECT_API,
        providerId: { $ne: null },
        providerReference: { $exists: true, $ne: null },
        providerSettledAt: { $exists: false },
        status: OrderStatus.COMPLETED,
        $or: [{ deliveredCode: { $exists: false } }, { deliveredCode: null }, { deliveredCode: '' }],
      })
      .sort({ createdAt: -1 })
      .limit(limit);

    let settled = 0;
    let refunded = 0;
    let pending = 0;

    for (const order of orders) {
      const providerId = order.providerId?.toString();
      if (!providerId || !order.providerReference) continue;

      let inspection: Awaited<ReturnType<ProvidersService['inspectOrderStatus']>>;
      try {
        inspection = await this.providersService.inspectOrderStatus(providerId, order.providerReference);
      } catch (err: any) {
        this.logger.warn(`Reconciliation failed for order ${order.orderNumber}: ${err.message}`);
        continue;
      }

      if (inspection.state === 'delivered') {
        order.deliveredCode = inspection.codes?.length ? inspection.codes.join(', ') : order.deliveredCode;
        order.providerSettledAt = new Date();
        order.timeline.push({
          action: 'provider_settled',
          title: '╪ز┘à ╪ز╪ث┘â┘è╪» ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ ┘╪»┘ë ╪د┘┘à╪▓┘ê┘ّ╪»',
          description: inspection.message || '╪ث┘â╪» ╪د┘┘à╪▓┘ê┘ّ╪» ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ',
          performerName: '╪د┘┘à╪╡╪د┘╪ص╪ر ╪د┘╪ت┘┘è╪ر',
          performerRole: 'system',
          timestamp: new Date(),
        });
        await order.save();
        settled++;
        continue;
      }

      if (inspection.state === 'failed') {
        const reason = `╪ث╪ذ┘╪║ ╪د┘┘à╪▓┘ê┘ّ╪» ╪╣┘ ┘╪┤┘ ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ: ${inspection.message || '╪│╪ذ╪ذ ╪║┘è╪▒ ┘à╪ص╪»╪»'}`;
        order.providerResponse = inspection.raw as Record<string, any>;
        order.providerSettledAt = new Date();
        await this.autoRefundOrder(order, reason, '╪ز┘à ╪د╪│╪ز╪▒╪ش╪د╪╣ ╪د┘┘à╪ذ┘╪║ ╪ز┘┘é╪د╪خ┘è╪د┘ï ╪ذ╪╣╪» ┘╪┤┘ ╪د┘┘à╪▓┘ê┘ّ╪»');
        refunded++;
        continue;
      }

      pending++;
    }

    // Second pass: refunded attempts the provider may actually have executed (timeout cases)
    let flagged = 0;
    const refundedOrders = await this.orderModel
      .find({
        type: ProductType.DIRECT_API,
        providerId: { $ne: null },
        providerReference: { $exists: true, $ne: null },
        providerSettledAt: { $exists: false },
        status: OrderStatus.REFUNDED,
        createdAt: { $lte: new Date(Date.now() - 5 * 60 * 1000) },
      })
      .sort({ createdAt: -1 })
      .limit(limit);

    for (const order of refundedOrders) {
      const providerId = order.providerId?.toString();
      if (!providerId || !order.providerReference) continue;

      try {
        const inspection = await this.providersService.inspectOrderStatus(providerId, order.providerReference);
        if (inspection.state !== 'delivered') continue;

        // We refunded but the provider delivered ظ¤ a human must reconcile this one
        order.providerSettledAt = new Date();
        order.timeline.push({
          action: 'provider_mismatch',
          title: '╪ز┘╪ذ┘è┘ç: ╪د┘┘à╪▓┘ê┘ّ╪» ┘è╪╣╪ز╪ذ╪▒ ╪د┘╪╖┘╪ذ ┘à┘┘╪░╪د┘ï ╪ذ╪╣╪» ╪د╪│╪ز╪▒╪ش╪د╪╣┘ç',
          description: inspection.message || '╪ز╪ث┘â╪» ╪د┘┘à╪▓┘ê┘ّ╪» ┘à┘ ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ ╪▒╪║┘à ╪ح╪▒╪ش╪د╪╣ ╪د┘┘à╪ذ┘╪║ ┘┘╪╣┘à┘è┘',
          performerName: '╪د┘┘à╪╡╪د┘╪ص╪ر ╪د┘╪ت┘┘è╪ر',
          performerRole: 'system',
          timestamp: new Date(),
        });
        await order.save();
        flagged++;

        await this.notificationsService.createNotification({
          forRole: 'admin',
          title: '╪ز┘╪ذ┘è┘ç ┘à╪د┘┘è: ╪╖┘╪ذ ┘à╪│╪ز╪▒╪ش╪╣ ┘┘â┘ ╪د┘┘à╪▓┘ê┘ّ╪» ┘┘┘ّ╪░┘ç',
          body: `╪د┘╪╖┘╪ذ #${order.orderNumber} ╪ز┘à ╪ح╪▒╪ش╪د╪╣ ┘à╪ذ┘╪║┘ç ┘┘╪╣┘à┘è┘╪î ┘┘â┘ ╪د┘┘à╪▓┘ê┘ّ╪» ┘è╪ج┘â╪» ╪ز┘┘┘è╪░┘ç. ┘è╪▒╪ش┘ë ╪د┘┘à╪▒╪د╪ش╪╣╪ر ╪د┘┘è╪»┘ê┘è╪ر.`,
          type: 'provider_mismatch',
          data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
        });
      } catch (err: any) {
        this.logger.warn(`Reverse reconciliation failed for order ${order.orderNumber}: ${err.message}`);
      }
    }

    // Third pass: orders orphaned mid-flight (e.g. the platform killed the function
    // while the provider call was still running) ظ¤ the customer was charged but the
    // order never reached a final state
    let recovered = 0;
    const orphanedOrders = await this.orderModel
      .find({
        type: ProductType.DIRECT_API,
        providerId: { $ne: null },
        providerSettledAt: { $exists: false },
        status: OrderStatus.PENDING,
        createdAt: { $lte: new Date(Date.now() - 3 * 60 * 1000) },
      })
      .sort({ createdAt: -1 })
      .limit(limit);

    for (const order of orphanedOrders) {
      const providerId = order.providerId?.toString();
      const reference = order.providerReference || order.orderNumber;
      if (!providerId || !reference) continue;

      let inspection: Awaited<ReturnType<ProvidersService['inspectOrderStatus']>>;
      try {
        inspection = await this.providersService.inspectOrderStatus(providerId, reference);
      } catch (err: any) {
        this.logger.warn(`Orphan reconciliation failed for order ${order.orderNumber}: ${err.message}`);
        continue;
      }

      if (inspection.state === 'delivered') {
        order.status = OrderStatus.COMPLETED;
        order.deliveredCode = inspection.codes?.length ? inspection.codes.join(', ') : order.deliveredCode;
        order.providerReference = reference;
        order.providerResponse = inspection.raw as Record<string, any>;
        order.providerSettledAt = new Date();
        order.completedAt = new Date();
        order.timeline.push({
          action: 'provider_settled',
          title: '╪ز┘à ╪ز╪ث┘â┘è╪» ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ ┘╪»┘ë ╪د┘┘à╪▓┘ê┘ّ╪»',
          description: inspection.message || '╪ث┘â╪» ╪د┘┘à╪▓┘ê┘ّ╪» ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ',
          performerName: '╪د┘┘à╪╡╪د┘╪ص╪ر ╪د┘╪ت┘┘è╪ر',
          performerRole: 'system',
          timestamp: new Date(),
        });
        await order.save();
        recovered++;

        await this.notificationsService.createNotification({
          userId: order.userId.toString(),
          title: '╪ز┘à ╪ز┘┘┘è╪░ ╪╖┘╪ذ┘â ╪ذ┘╪ش╪د╪ص',
          body: `╪ز┘à ╪ز╪ث┘â┘è╪» ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ #${order.orderNumber} ┘╪»┘ë ┘à╪▓┘ê╪» ╪د┘╪«╪»┘à╪ر.`,
          type: 'order_status',
          data: { orderId: order._id.toString(), deliveredCode: order.deliveredCode },
        });
        continue;
      }

      if (inspection.state === 'failed') {
        order.providerResponse = inspection.raw as Record<string, any>;
        order.providerSettledAt = new Date();
        await this.autoRefundOrder(
          order,
          `╪ث╪ذ┘╪║ ╪د┘┘à╪▓┘ê┘ّ╪» ╪╣┘ ┘╪┤┘ ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ: ${inspection.message || '╪│╪ذ╪ذ ╪║┘è╪▒ ┘à╪ص╪»╪»'}`,
          '╪ز┘à ╪د╪│╪ز╪▒╪ش╪د╪╣ ╪د┘┘à╪ذ┘╪║ ╪ز┘┘é╪د╪خ┘è╪د┘ï ╪ذ╪╣╪» ┘╪┤┘ ╪د┘┘à╪▓┘ê┘ّ╪»',
        );
        refunded++;
        continue;
      }

      // ╪ص╪د┘╪ر ┘à╪ش┘ç┘ê┘╪ر (┘à╪▓┘ê╪» ┘╪د ┘è╪╣┘è╪» ╪ص╪د┘╪ر ╪╖┘╪ذ): ┘╪د ┘è╪ذ┘é┘ë ┘à╪╣┘┘ّ┘é╪د┘ï ╪ذ╪╡┘à╪ز ظ¤ ╪ز┘╪ذ┘è┘ç ┘┘╪ح╪»╪د╪▒╪ر (M3)
      if (inspection.state === 'unknown') {
        order.providerSettledAt = new Date();
        order.timeline.push({
          action: 'provider_unknown',
          title: '╪ز╪╣╪░┘ّ╪▒ ╪ز╪ص╪»┘è╪» ╪ص╪د┘╪ر ╪د┘╪╖┘╪ذ ┘╪»┘ë ╪د┘┘à╪▓┘ê┘ّ╪»',
          description: inspection.message || '┘╪د ╪ز┘ê╪ش╪» ╪ص╪د┘╪ر ┘à╪ج┘â╪»╪ر ┘à┘ ╪د┘┘à╪▓┘ê┘ّ╪»╪ؤ ┘è┘╪▓┘à ┘à╪▒╪د╪ش╪╣╪ر ┘è╪»┘ê┘è╪ر',
          performerName: '╪د┘┘à╪╡╪د┘╪ص╪ر ╪د┘╪ت┘┘è╪ر',
          performerRole: 'system',
          timestamp: new Date(),
        });
        await order.save();
        flagged++;

        await this.notificationsService
          .createNotification({
            forRole: 'admin',
            title: '╪╖┘╪ذ ┘à╪╣┘┘ّ┘é ╪ذ╪ص╪د┘╪ر ┘à╪ش┘ç┘ê┘╪ر ┘╪»┘ë ╪د┘┘à╪▓┘ê╪»',
            body: `╪د┘╪╖┘╪ذ #${order.orderNumber} ╪«┘╪╡┘à ┘à┘ ╪د┘╪╣┘à┘è┘ ┘ê┘┘à ┘è╪│╪ز╪╖╪╣ ╪د┘┘╪ص╪╡ ╪د┘╪ت┘┘è ╪ز╪ث┘â┘è╪» ╪ز┘┘┘è╪░┘ç ╪ث┘ê ┘╪┤┘┘ç╪ؤ ┘è╪▒╪ش┘ë ╪د┘┘à╪▒╪د╪ش╪╣╪ر ╪د┘┘è╪»┘ê┘è╪ر.`,
            type: 'provider_mismatch',
            data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
          })
          .catch(() => undefined);
        continue;
      }

      pending++;
    }

    return {
      checked: orders.length + refundedOrders.length + orphanedOrders.length,
      settled,
      refunded,
      pending,
      flagged,
      recovered,
      message: `╪ز┘à╪ز ┘à╪▒╪د╪ش╪╣╪ر ${orders.length + refundedOrders.length + orphanedOrders.length} ╪╖┘╪ذ╪د┘ï: ${settled} ┘à╪ج┘â╪»╪î ${recovered} ┘à┘╪│╪ز╪╣╪د╪»╪î ${refunded} ┘à╪│╪ز╪▒╪ش╪╣╪î ${pending} ┘é┘è╪» ╪د┘╪د┘╪ز╪╕╪د╪▒╪î ${flagged} ╪ذ╪ص╪د╪ش╪ر ┘à╪▒╪د╪ش╪╣╪ر ┘è╪»┘ê┘è╪ر`,
    };
  }

  // --- 2. Queries: User / Supervisor / Admin ---
  async getMyOrders(userId: string) {
    return this.orderModel
      .find({ userId: new Types.ObjectId(userId) })
      // appType ┘è┘╪▒╪│┘ ┘à╪╣ ╪د┘╪ز╪╖╪ذ┘è┘é ┘â┘è ╪ز╪╡┘┘ّ┘ ╪┤╪د╪┤╪ر ┬س╪╖┘╪ذ╪د╪ز┘è┬╗ ┘â┘ ╪╖┘╪ذ ╪ح┘┘ë ┘┘ê╪╣
      // (╪ز╪╖╪ذ┘è┘é╪د╪ز/╪ث┘╪╣╪د╪ذ/╪«╪»┘à╪د╪ز)╪ؤ ╪د┘╪ث╪▒┘é╪د┘à ╪د┘┘ê┘ç┘à┘è╪ر ╪ز┘╪»┘à╪ش ┘à┘ ┘à╪│╪د╪▒┘ç╪د ╪د┘╪«╪د╪╡
      .populate('appId', 'name iconUrl appType')
      // ╪«╪»┘à╪د╪ز ╪د┘╪ث╪▒┘é╪د┘à ╪د┘┘è╪»┘ê┘è╪ر ╪ذ┘╪د ╪ز╪╖╪ذ┘è┘é ┘à╪ز╪ش╪▒: ╪د╪│┘à ╪د┘╪ز╪╖╪ذ┘è┘é ┘è┘┘é╪▒╪ث ┘à┘ ╪ز╪╖╪ذ┘è┘é ╪د┘╪ث╪▒┘é╪د┘à
      .populate('virtualNumberAppId', 'name iconUrl')
      .populate('productId', 'name type costPrice salePrice isSensitive')
      .populate('assignedSupervisorId', 'name email phone role')
      .sort({ createdAt: -1 });
  }

  async getOrderById(id: string) {
    const order = await this.orderModel
      .findById(id)
      .populate('userId', 'name email phone balance userId')
      .populate('appId', 'name iconUrl')
      .populate('virtualNumberAppId', 'name iconUrl')
      .populate({
        path: 'productId',
        select: 'name type costPrice salePrice isSensitive instructions serviceTemplateId',
        populate: { path: 'serviceTemplateId', select: 'name fields' },
      })
      .populate('assignedSupervisorId', 'name email phone role userId');
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');
    return order;
  }

  // Supervisor: View assigned orders
  async getSupervisorOrders(supervisorId: string, filter?: { status?: string }) {
    const query: any = { assignedSupervisorId: new Types.ObjectId(supervisorId) };
    if (filter?.status && filter.status !== 'all') {
      query.status = filter.status;
    }

    const orders = await this.orderModel
      .find(query)
      .populate('userId', 'name email phone userId')
      .populate('appId', 'name iconUrl')
      .populate('virtualNumberAppId', 'name iconUrl')
      .populate({
        path: 'productId',
        select: 'name type costPrice salePrice isSensitive instructions serviceTemplateId',
        populate: { path: 'serviceTemplateId', select: 'name fields' },
      })
      .sort({ createdAt: -1 });

    const now = new Date();
    return orders.map((o) => {
      const obj = o.toObject();
      const isDelayed =
        o.deadlineAt &&
        now > o.deadlineAt &&
        o.status !== OrderStatus.COMPLETED &&
        o.status !== OrderStatus.REFUNDED;
      return {
        ...obj,
        isDelayed,
      };
    });
  }

  // Admin: View all orders with rich filters
  async getAllOrdersAdmin(filter?: {
    status?: OrderStatus;
    type?: ProductType;
    supervisorId?: string;
    isDelayed?: boolean;
    search?: string;
  }) {
    const query: any = {};
    if (filter?.status && filter.status !== ('all' as any)) query.status = filter.status;
    if (filter?.type) query.type = filter.type;
    if (filter?.supervisorId) query.assignedSupervisorId = new Types.ObjectId(filter.supervisorId);

    if (filter?.isDelayed) {
      query.deadlineAt = { $lt: new Date() };
      query.status = { $nin: [OrderStatus.COMPLETED, OrderStatus.REFUNDED] };
    }

    if (filter?.search) {
      query.orderNumber = { $regex: filter.search, $options: 'i' };
    }

    const orders = await this.orderModel
      .find(query)
      .select('-chatMessages -timeline')
      .populate('userId', 'name email phone balance userId')
      .populate('appId', 'name iconUrl')
      .populate('virtualNumberAppId', 'name iconUrl')
      .populate('productId', 'name type costPrice salePrice isSensitive')
      .populate('assignedSupervisorId', 'name email phone role userId')
      .sort({ createdAt: -1 })
      .lean();

    // ╪د┘┘é┘ê╪د╪خ┘à ┘╪د ╪ز┘╪ص┘à┘ّ┘ ╪د┘┘à╪ص╪د╪»╪س╪د╪ز ┘ê╪│╪ش┘ ╪د┘╪ث╪ص╪»╪د╪س (╪ز┘╪ش┘╪ذ ╪╣┘╪» ┘╪ز╪ص ╪د┘╪╖┘╪ذ ┘┘é╪╖) ┘╪ز╪│╪▒┘è╪╣ ╪د┘╪د╪│╪ز╪ش╪د╪ذ╪ر
    const now = new Date();
    return orders.map((o: any) => {
      const isDelayed =
        !!o.deadlineAt &&
        now > new Date(o.deadlineAt) &&
        o.status !== OrderStatus.COMPLETED &&
        o.status !== OrderStatus.REFUNDED;
      return {
        ...o,
        isDelayed,
      };
    });
  }

  // --- 3. Supervisor Workflows ---
  // Supervisor accepts order
  async supervisorAcceptOrder(orderId: string, supervisor: UserDocument) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name');
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    if (
      order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
      supervisor.role !== 'admin'
    ) {
      throw new ForbiddenException('┘ç╪░╪د ╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à╪│┘╪» ╪ح┘┘è┘â');
    }

    if (order.status !== OrderStatus.ASSIGNED && order.status !== OrderStatus.PENDING) {
      throw new BadRequestException('┘╪د ┘è┘à┘â┘ ┘é╪ذ┘ê┘ ╪د┘╪╖┘╪ذ ┘┘è ╪ص╪د┘╪ز┘ç ╪د┘╪ص╪د┘┘è╪ر');
    }

    // ╪د┘┘é╪ذ┘ê┘ ┘è╪ذ╪»╪ث ╪د┘╪ز┘┘┘è╪░ ┘à╪ذ╪د╪┤╪▒╪ر: ┘╪د ╪«╪╖┘ê╪ر ┬س╪ذ╪»╪ة ╪ز┘┘┘è╪░┬╗ ┘à┘┘╪╡┘╪ر ╪╣┘╪» ╪د┘┘à╪┤╪▒┘ ظ¤
    // ╪▓╪▒ ┬س┘é╪ذ┘ê┘ ╪د┘╪«╪»┘à╪ر┬╗ ┘ê╪ص╪»┘ç ┘è┘â┘┘ ╪د┘╪د┘╪ز┘é╪د┘ ╪ح┘┘ë ┘é┘è╪» ╪د┘╪ز┘┘┘è╪░
    order.status = OrderStatus.IN_PROGRESS;
    order.acceptedAt = new Date();
    order.startedAt = new Date();

    order.timeline.push({
      action: 'accepted',
      title: '┘é╪ذ┘ ┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر ╪د┘╪╖┘╪ذ ┘ê╪┤╪▒╪╣ ┘┘è ╪د┘╪ز┘┘┘è╪░',
      description: `┘é╪د┘à ${supervisor.name} ╪ذ┘é╪ذ┘ê┘ ╪د┘╪╖┘╪ذ ┘ê╪د┘╪ذ╪»╪ة ┘┘è ╪ز┘┘┘è╪░┘ç ┘à╪ذ╪د╪┤╪▒╪ر`,
      performerId: supervisor._id,
      performerName: supervisor.name,
      performerRole: 'supervisor',
      timestamp: new Date(),
    });

    await order.save();

    // Notify customer
    await this.notificationsService.createNotification({
      userId: order.userId.toString(),
      title: '╪ز┘à ┘é╪ذ┘ê┘ ╪╖┘╪ذ┘â ┘ê╪┤╪▒╪╣ ╪د┘┘à╪┤╪▒┘ ┘┘è ╪د┘╪ز┘┘┘è╪░ ≡اّذظ≡اْ╗',
      body: `┘é╪ذ┘ ┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر ╪╖┘╪ذ┘â #${order.orderNumber} ┘╪«╪»┘à╪ر ${(order.productId as any)?.name || '╪د┘╪«╪»┘à╪ر'} ┘ê╪ش╪د╪▒┘è ╪د┘╪ز┘┘┘è╪░.`,
      type: 'order_status',
      data: { orderId: order._id.toString(), status: 'in_progress' },
    });

    return { message: '╪ز┘à ┘é╪ذ┘ê┘ ╪د┘╪╖┘╪ذ ┘ê╪د┘╪ذ╪»╪ة ┘┘è ╪ز┘┘┘è╪░┘ç', order };
  }

  // Supervisor rejects order (with reason)
  async supervisorRejectOrder(orderId: string, supervisor: UserDocument, reason: string) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name');
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    if (
      order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
      supervisor.role !== 'admin'
    ) {
      throw new ForbiddenException('┘ç╪░╪د ╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à╪│┘╪» ╪ح┘┘è┘â');
    }

    if (order.status === OrderStatus.COMPLETED || order.status === OrderStatus.REFUNDED) {
      throw new BadRequestException('┘╪د ┘è┘à┘â┘ ╪▒┘╪╢ ╪╖┘╪ذ ┘à┘╪ز┘ç┘è ╪ث┘ê ┘à╪│╪ز╪▒╪ش╪╣');
    }

    order.status = OrderStatus.REJECTED;
    order.rejectionReason = reason;

    order.timeline.push({
      action: 'rejected',
      title: '╪د╪╣╪ز╪░╪▒ ╪د┘┘à╪┤╪▒┘ ╪╣┘ ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ',
      description: `╪د╪╣╪ز╪░╪▒ ╪د┘┘à╪┤╪▒┘ ${supervisor.name} ╪╣┘ ╪د┘╪ز┘┘┘è╪░. ╪د┘╪│╪ذ╪ذ: ${reason}`,
      performerId: supervisor._id,
      performerName: supervisor.name,
      performerRole: 'supervisor',
      timestamp: new Date(),
    });

    await order.save();

    // ╪د┘╪د╪╣╪ز╪░╪د╪▒ ╪╣┘ ╪د┘╪ز┘┘┘è╪░ ┘è┘╪«╪▒╪ش ╪د┘╪╖┘╪ذ ┘à┘ ┘é╪د╪خ┘à╪ر ╪د┘┘à╪┤╪▒┘╪ؤ ┘┘é╪» ┘è╪╣┘ê╪» ╪╣┘à┘è┘╪د┘ï ╪ح┘ ┘┘à ┘è╪ذ┘é┘ ┘╪»┘è┘ç ╪ح╪│┘╪د╪»
    await this.usersService.reconcileSupervisorRole(supervisor._id);

    // Notify Admins that order was rejected and requires reassignment
    await this.notificationsService.createNotification({
      forRole: 'admin',
      title: '╪ز┘╪ذ┘è┘ç: ╪▒┘╪╢ ╪╖┘╪ذ ┘è╪»┘ê┘è ┘à┘ ╪د┘┘à╪┤╪▒┘ ظأبي╕',
      body: `╪د╪╣╪ز╪░╪▒ ╪د┘┘à╪┤╪▒┘ ${supervisor.name} ╪╣┘ ╪ز┘┘┘è╪░ ╪د┘╪╖┘╪ذ #${order.orderNumber}. ╪د┘╪│╪ذ╪ذ: ${reason}. ┘è╪▒╪ش┘ë ╪ح╪╣╪د╪»╪ر ╪د┘╪ح╪│┘╪د╪» ┘┘à╪┤╪▒┘ ╪ت╪«╪▒.`,
      type: 'manual_order_rejected',
      data: { orderId: order._id.toString(), orderNumber: order.orderNumber, reason },
    });

    return { message: '╪ز┘à ╪ز╪│╪ش┘è┘ ╪د╪╣╪ز╪░╪د╪▒ ╪د┘┘à╪┤╪▒┘ ┘ê╪│┘è╪ز┘à ╪ح╪┤╪╣╪د╪▒ ╪د┘╪ح╪»╪د╪▒╪ر ┘╪ح╪╣╪د╪»╪ر ╪د┘╪ح╪│┘╪د╪»', order };
  }

  // Supervisor requests additional info/files from customer
  async supervisorRequestInfo(
    orderId: string,
    supervisor: UserDocument,
    data: { note: string; attachmentUrl?: string },
  ) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name');
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    if (
      order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
      supervisor.role !== 'admin'
    ) {
      throw new ForbiddenException('┘ç╪░╪د ╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à╪│┘╪» ╪ح┘┘è┘â');
    }

    order.status = OrderStatus.INFO_REQUESTED;

    order.timeline.push({
      action: 'info_requested',
      title: '╪╖┘╪ذ ╪د┘┘à╪┤╪▒┘ ┘à╪╣┘┘ê┘à╪د╪ز ╪ح╪╢╪د┘┘è╪ر',
      description: data.note,
      performerId: supervisor._id,
      performerName: supervisor.name,
      performerRole: 'supervisor',
      timestamp: new Date(),
    });

    // Also add to chat messages
    order.chatMessages.push({
      senderId: supervisor._id,
      senderName: supervisor.name,
      senderRole: 'supervisor',
      message: data.note,
      attachmentUrl: data.attachmentUrl,
      isSensitive: false,
      createdAt: new Date(),
    });

    await order.save();

    // Notify customer
    await this.notificationsService.createNotification({
      userId: order.userId.toString(),
      title: '╪د┘┘à╪┤╪▒┘ ┘è╪╖┘╪ذ ┘à╪╣┘┘ê┘à╪د╪ز ╪ح╪╢╪د┘┘è╪ر ╪ص┘ê┘ ╪╖┘╪ذ┘â ≡اْش',
      body: data.note,
      type: 'order_chat',
      data: { orderId: order._id.toString(), note: data.note },
    });

    return { message: '╪ز┘à ╪ح╪▒╪│╪د┘ ╪╖┘╪ذ ╪د┘┘à╪╣┘┘ê┘à╪د╪ز ┘┘╪╣┘à┘è┘', order };
  }

  // Supervisor delivers result (with credentials, notes, attachments)
  async supervisorDeliverOrder(
    orderId: string,
    supervisor: UserDocument,
    data: {
      resultNotes?: string;
      credentials?: Record<string, any>;
      attachments?: string[];
    },
  ) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name isSensitive');
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    if (
      order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
      supervisor.role !== 'admin'
    ) {
      throw new ForbiddenException('┘ç╪░╪د ╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à╪│┘╪» ╪ح┘┘è┘â');
    }

    order.status = OrderStatus.DELIVERED;
    order.deliveredAt = new Date();
    order.resultNotes = data.resultNotes || '╪ز┘à ╪ز┘┘┘è╪░ ╪د┘╪«╪»┘à╪ر ╪ذ┘╪ش╪د╪ص╪î ┘è╪▒╪ش┘ë ┘à╪▒╪د╪ش╪╣╪ر ╪د┘┘╪ز┘è╪ش╪ر╪ؤ ╪ز╪ث┘â┘è╪» ╪د┘╪ح┘┘ç╪د╪ة ┘ê╪ح╪║┘╪د┘é ╪د┘╪╖┘╪ذ ┘è╪ز┘à╪د┘ ┘à┘ ┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر';
    order.resultAttachments = data.attachments || [];

    // Encrypt sensitive credentials securely using AES-256
    if (data.credentials && Object.keys(data.credentials).length > 0) {
      order.encryptedResultData = CryptoUtil.encrypt(data.credentials);
    }

    order.timeline.push({
      action: 'delivered',
      title: '╪ز┘à ╪ز╪│┘┘è┘à ┘╪ز┘è╪ش╪ر ╪د┘╪«╪»┘à╪ر ╪ح┘┘ë ╪د┘╪╣┘à┘è┘',
      description: '╪ث┘┘ç┘ë ╪د┘┘à╪┤╪▒┘ ╪د┘╪╣┘à┘ ┘ê╪│┘┘ّ┘à ╪ز┘╪د╪╡┘è┘ ╪د┘┘╪ز┘è╪ش╪ر╪î ┘ê╪ذ╪د┘╪ز╪╕╪د╪▒ ╪ز╪ث┘â┘è╪» ╪د┘╪ح┘┘ç╪د╪ة ┘à┘ ┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر ┘╪ح╪║┘╪د┘é ╪د┘╪╖┘╪ذ',
      performerId: supervisor._id,
      performerName: supervisor.name,
      performerRole: 'supervisor',
      timestamp: new Date(),
    });

    await order.save();

    // Notify customer (ensure no raw credentials leaked in notification text!)
    await this.notificationsService.createNotification({
      userId: order.userId.toString(),
      title: '╪ز┘à ╪ز╪│┘┘è┘à ┘╪ز┘è╪ش╪ر ╪╖┘╪ذ┘â! ┘è╪▒╪ش┘ë ╪د┘┘à╪▒╪د╪ش╪╣╪ر ≡اë',
      body: `╪د┘╪ز┘ç┘ë ╪د┘┘à╪┤╪▒┘ ┘à┘ ╪ز┘┘┘è╪░ ╪╖┘╪ذ┘â #${order.orderNumber}. ╪▒╪د╪ش╪╣ ╪د┘┘╪ز┘è╪ش╪ر╪î ┘ê╪ح┘ ┘è┘╪▓┘à┘â ╪╖┘╪ذ ╪ز╪╣╪»┘è┘ ╪ث┘ê ╪د╪╣╪ز╪▒╪د╪╢╪ؤ ╪ث┘à╪د ╪ح╪║┘╪د┘é ╪د┘╪╖┘╪ذ ┘┘è╪ز┘à ╪ذ╪╣╪» ╪ز╪ث┘â┘è╪» ┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر.`,
      type: 'order_delivered',
      data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
    });

    return { message: '╪ز┘à ╪ز╪│┘┘è┘à ╪د┘┘╪ز┘è╪ش╪ر ┘┘╪╣┘à┘è┘', order };
  }

  // --- 4. Customer Workflows ---
  // ┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر ┘ê╪ص╪»┘ç ┘à┘ ┘è╪ج┘â╪» ╪ح╪ز┘à╪د┘à ╪د┘╪╣┘à┘┘è╪ر ┘ê┘è╪║┘┘é ╪د┘╪╖┘╪ذ (╪ذ╪╣╪» ╪د┘╪ز╪│┘┘è┘à) ظ¤
  // ╪د┘╪╣┘à┘è┘ ┘┘à ┘è╪╣╪» ┘è┘à┘┘â ╪▓╪▒ ╪ز╪ث┘â┘è╪»╪ؤ ╪د┘╪ح╪║┘╪د┘é ┘┘┘à┘ê╪╕┘ ╪د┘┘à┘┘┘ّ╪░ ╪ث┘ê ╪د┘╪ح╪»╪د╪▒╪ر
  async supervisorCompleteOrder(orderId: string, supervisor: UserDocument) {
    const order = await this.orderModel
      .findById(orderId)
      .populate('productId', 'name')
      .populate('assignedSupervisorId', 'name');
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    if (
      order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
      supervisor.role !== 'admin'
    ) {
      throw new ForbiddenException('┘ç╪░╪د ╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à╪│┘╪» ╪ح┘┘è┘â');
    }

    if (order.status !== OrderStatus.DELIVERED) {
      throw new BadRequestException('┘╪د ┘è┘à┘â┘ ╪ز╪ث┘â┘è╪» ╪ح╪ز┘à╪د┘à ╪د┘╪╖┘╪ذ ┘é╪ذ┘ ╪ز╪│┘┘è┘à ╪د┘┘╪ز┘è╪ش╪ر');
    }

    order.status = OrderStatus.COMPLETED;
    order.completedAt = new Date();

    // Auto-Purge sensitive credentials if configured
    if (order.isSensitive) {
      order.encryptedResultData = undefined;
      order.isResultPurged = true;
      order.purgedAt = new Date();
    }

    order.timeline.push({
      action: 'confirmed',
      title: '╪ث┘â╪» ┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر ╪ح╪ز┘à╪د┘à ╪د┘╪╖┘╪ذ ┘ê╪ث╪║┘┘é┘ç',
      description: '╪ز┘à ╪ح╪║┘╪د┘é ╪د┘╪╖┘╪ذ ╪ذ┘╪ش╪د╪ص ╪ذ╪╣╪» ╪ز╪ث┘â┘è╪» ┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر ╪╣┘┘ë ╪ح┘╪ش╪د╪▓ ╪د┘╪╣┘à┘┘è╪ر',
      performerId: supervisor._id,
      performerName: supervisor.name,
      performerRole: 'supervisor',
      timestamp: new Date(),
    });

    await order.save();

    // Notify customer that their order was finalized and closed
    await this.notificationsService.createNotification({
      userId: order.userId.toString(),
      title: '╪ز┘à ╪ح╪║┘╪د┘é ╪╖┘╪ذ┘â ╪ذ╪╣╪» ╪ز╪ث┘â┘è╪» ╪د┘╪ح┘┘ç╪د╪ة ظ£à',
      body: `╪ث┘â╪» ┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر ╪ح╪ز┘à╪د┘à ╪د┘╪╖┘╪ذ #${order.orderNumber} ┘╪«╪»┘à╪ر ${(order.productId as any)?.name} ┘ê╪ز┘à ╪ح╪║┘╪د┘é┘ç ╪ذ┘╪ش╪د╪ص.`,
      type: 'order_confirmed',
      data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
    });

    // ╪د┘╪╖┘╪ذ ╪د┘╪ز┘ç┘ë: ╪ث╪«╪▒╪ش ╪د┘┘à╪┤╪▒┘ ┘à┘ ┘é╪د╪خ┘à╪ر ╪د┘╪ح╪│┘╪د╪» ╪ح┘ ┘┘à ┘è╪ذ┘é┘ ┘╪»┘è┘ç ┘à╪د ┘è┘┘┘┘┘ّ╪░
    await this.usersService.reconcileSupervisorRole(supervisor._id);

    return { message: '╪ز┘à ╪ز╪ث┘â┘è╪» ╪ح╪ز┘à╪د┘à ╪د┘╪╖┘╪ذ ┘ê╪ح╪║┘╪د┘é┘ç ╪ذ┘╪ش╪د╪ص', order };
  }

  // Customer requests revision
  async customerRequestRevision(orderId: string, user: UserDocument, revisionNotes: string) {
    const order = await this.orderModel
      .findById(orderId)
      .populate('productId', 'name')
      .populate('assignedSupervisorId', 'name');
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    if (order.userId.toString() !== user._id.toString()) {
      throw new ForbiddenException('┘╪د ╪ز┘à┘┘â ╪╡┘╪د╪ص┘è╪ر ╪╖┘╪ذ ╪د┘╪ز╪╣╪»┘è┘');
    }

    if (order.status !== OrderStatus.DELIVERED) {
      throw new BadRequestException('┘è┘à┘â┘ ╪╖┘╪ذ ╪د┘╪ز╪╣╪»┘è┘ ┘┘é╪╖ ╪ذ╪╣╪» ╪ز╪│┘┘è┘à ╪د┘┘╪ز┘è╪ش╪ر ┘ê┘é╪ذ┘ ╪د┘╪ز╪ث┘â┘è╪»');
    }

    order.status = OrderStatus.REVISION_REQUESTED;
    order.revisionNotes = revisionNotes;

    order.timeline.push({
      action: 'revision_requested',
      title: '╪╖┘╪ذ ╪د┘╪╣┘à┘è┘ ╪ز╪╣╪»┘è┘ ╪╣┘┘ë ╪د┘╪«╪»┘à╪ر',
      description: revisionNotes,
      performerId: user._id,
      performerName: user.name,
      performerRole: 'customer',
      timestamp: new Date(),
    });

    // Also add to chat messages
    order.chatMessages.push({
      senderId: user._id,
      senderName: user.name,
      senderRole: 'user',
      message: `[╪╖┘╪ذ ╪ز╪╣╪»┘è┘]: ${revisionNotes}`,
      isSensitive: false,
      createdAt: new Date(),
    });

    await order.save();

    // Notify supervisor
    if (order.assignedSupervisorId) {
      await this.notificationsService.createNotification({
        userId: (order.assignedSupervisorId as any)._id?.toString() || order.assignedSupervisorId.toString(),
        forRole: 'supervisor',
        title: '╪╖┘╪ذ ╪ز╪╣╪»┘è┘ ┘à┘ ╪د┘╪╣┘à┘è┘ ≡ا¤',
        body: `╪╖┘╪ذ ╪د┘╪╣┘à┘è┘ ╪ز╪╣╪»┘è┘╪د┘ï ╪╣┘┘ë ╪د┘╪╖┘╪ذ #${order.orderNumber}: ${revisionNotes}`,
        type: 'revision_requested',
        data: { orderId: order._id.toString(), revisionNotes },
      });
    }

    return { message: '╪ز┘à ╪ح╪▒╪│╪د┘ ╪╖┘╪ذ ╪د┘╪ز╪╣╪»┘è┘ ┘┘┘à╪┤╪▒┘ ╪ذ┘╪ش╪د╪ص', order };
  }

  // Customer opens dispute / objection
  async customerOpenDispute(orderId: string, user: UserDocument, disputeReason: string) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name');
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    if (order.userId.toString() !== user._id.toString()) {
      throw new ForbiddenException('┘╪د ╪ز┘à┘┘â ╪╡┘╪د╪ص┘è╪ر ┘╪ز╪ص ╪د╪╣╪ز╪▒╪د╪╢');
    }

    if (order.status === OrderStatus.COMPLETED || order.status === OrderStatus.REFUNDED) {
      throw new BadRequestException('┘╪د ┘è┘à┘â┘ ┘╪ز╪ص ╪د╪╣╪ز╪▒╪د╪╢ ╪╣┘┘ë ╪╖┘╪ذ ┘à┘╪ز┘ç┘è ╪ث┘ê ┘à╪│╪ز╪▒╪ش╪╣');
    }

    order.status = OrderStatus.DISPUTED;
    order.disputeReason = disputeReason;

    order.timeline.push({
      action: 'disputed',
      title: '┘╪ز╪ص ╪د┘╪╣┘à┘è┘ ╪د╪╣╪ز╪▒╪د╪╢╪د┘ï ╪▒╪│┘à┘è╪د┘ï ╪╣┘┘ë ╪د┘╪╖┘╪ذ',
      description: disputeReason,
      performerId: user._id,
      performerName: user.name,
      performerRole: 'customer',
      timestamp: new Date(),
    });

    // Also add to chat messages
    order.chatMessages.push({
      senderId: user._id,
      senderName: user.name,
      senderRole: 'user',
      message: `[╪د╪╣╪ز╪▒╪د╪╢ ╪▒╪│┘à┘è]: ${disputeReason}`,
      isSensitive: false,
      createdAt: new Date(),
    });

    await order.save();

    // Notify Admin & Supervisor urgently
    await this.notificationsService.createNotification({
      forRole: 'admin',
      title: '╪د╪╣╪ز╪▒╪د╪╢ ┘à┘╪ز┘ê╪ص ╪╣┘┘ë ╪╖┘╪ذ ≡اأذ',
      body: `┘╪ز╪ص ╪د┘╪╣┘à┘è┘ ${user.name} ╪د╪╣╪ز╪▒╪د╪╢╪د┘ï ╪╣┘┘ë ╪د┘╪╖┘╪ذ #${order.orderNumber}. ╪د┘╪│╪ذ╪ذ: ${disputeReason}`,
      type: 'order_disputed',
      data: { orderId: order._id.toString(), disputeReason },
    });

    if (order.assignedSupervisorId) {
      await this.notificationsService.createNotification({
        userId: order.assignedSupervisorId.toString(),
        forRole: 'supervisor',
        title: '╪ز┘╪ذ┘è┘ç: ╪د┘╪╣┘à┘è┘ ┘╪ز╪ص ╪د╪╣╪ز╪▒╪د╪╢╪د┘ï ╪╣┘┘ë ╪د┘╪╖┘╪ذ ≡اأذ',
        body: `╪╖┘╪ذ #${order.orderNumber}: ${disputeReason}`,
        type: 'order_disputed',
        data: { orderId: order._id.toString(), disputeReason },
      });
    }

    return { message: '╪ز┘à ┘╪ز╪ص ╪د┘╪د╪╣╪ز╪▒╪د╪╢ ┘ê╪│┘è╪ز╪»╪«┘ ┘╪▒┘è┘é ╪د┘╪ح╪»╪د╪▒╪ر ┘┘┘à╪▒╪د╪ش╪╣╪ر ┘ê╪ص┘ ╪د┘┘à╪┤┘â┘╪ر', order };
  }

  // --- 5. Admin Workflows ---
  // Reassign order to another supervisor
  async adminReassignSupervisor(
    orderId: string,
    newSupervisorId: string,
    admin: UserDocument,
    reason?: string,
  ) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name');
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    const newSupervisor = await this.userModel.findById(newSupervisorId);
    if (!newSupervisor || newSupervisor.isActive === false) {
      throw new BadRequestException('╪د┘┘à╪│╪ز╪«╪»┘à ╪د┘┘à╪«╪ز╪د╪▒ ╪║┘è╪▒ ╪╡╪د┘╪ص');
    }

    const previousSupervisorId = order.assignedSupervisorId;
    order.assignedSupervisorId = newSupervisor._id;
    order.status = OrderStatus.ASSIGNED;
    order.rejectionReason = undefined;

    // Recalculate deadline
    const estimated = order.estimatedMinutes || 120;
    order.deadlineAt = new Date(Date.now() + estimated * 60 * 1000);

    order.timeline.push({
      action: 'reassigned',
      title: `┘é╪د┘à ╪د┘╪ث╪»┘à┘ ╪ذ╪ح╪╣╪د╪»╪ر ╪ح╪│┘╪د╪» ╪د┘╪╖┘╪ذ ╪ح┘┘ë ╪د┘┘à╪┤╪▒┘ ${newSupervisor.name}`,
      description: reason ? `╪د┘╪│╪ذ╪ذ: ${reason}` : '╪ح╪╣╪د╪»╪ر ╪ح╪│┘╪د╪» ┘à┘ ┘é╪ذ┘ ╪د┘╪ح╪»╪د╪▒╪ر',
      performerId: admin._id,
      performerName: admin.name,
      performerRole: 'admin',
      timestamp: new Date(),
    });

    await order.save();

    // ┘à╪▓╪د┘à┘╪ر ╪د┘╪▒╪ز╪ذ: ╪د┘┘à╪┤╪▒┘ ╪د┘╪ش╪»┘è╪» ┘è┘╪▒┘é┘ّ┘ë╪î ┘ê╪د┘╪│╪د╪ذ┘é ┘è╪╣┘ê╪» ╪╣┘à┘è┘╪د┘ï ╪ح┘ ┘┘à ┘è╪ذ┘é┘ ┘╪»┘è┘ç ╪ث┘è ╪ح╪│┘╪د╪»
    if (previousSupervisorId && previousSupervisorId.toString() !== newSupervisor._id.toString()) {
      await this.usersService.reconcileSupervisorRole(previousSupervisorId);
    }
    await this.usersService.reconcileSupervisorRole(newSupervisor._id);

    // Notify new supervisor
    await this.notificationsService.createNotification({
      userId: newSupervisor._id.toString(),
      forRole: 'supervisor',
      title: '╪╖┘╪ذ ┘è╪»┘ê┘è ┘à╪│┘╪» ╪ح┘┘è┘â ┘à┘ ╪د┘╪ح╪»╪د╪▒╪ر ≡ا¤¤',
      body: `╪ز┘à ╪ح╪│┘╪د╪» ╪د┘╪╖┘╪ذ #${order.orderNumber} ┘╪«╪»┘à╪ر ${(order.productId as any)?.name} ╪ح┘┘è┘â ┘à┘ ┘é╪ذ┘ ╪د┘╪ح╪»╪د╪▒╪ر.`,
      type: 'manual_service_assigned',
      data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
    });

    return { message: `╪ز┘à ╪ح╪╣╪د╪»╪ر ╪ح╪│┘╪د╪» ╪د┘╪╖┘╪ذ ┘┘┘à╪┤╪▒┘ ${newSupervisor.name} ╪ذ┘╪ش╪د╪ص`, order };
  }

  // Admin executes instant refund to customer's wallet
  async adminRefundOrder(orderId: string, admin: UserDocument, reason: string) {
    // ╪د┘╪ز┘é╪د┘ ╪░╪▒┘è ┘┘╪ص╪د┘╪ر: ┘è╪▒┘╪╢ ╪ث┘è ╪ز┘â╪▒╪د╪▒ ╪ذ┘┘é╪▒╪ز┘è┘ ┘à╪ز╪▓╪د┘à┘╪ز┘è┘ ╪ذ╪»┘ read-modify-write (H6)
    const order = await this.orderModel
      .findOneAndUpdate(
        { _id: orderId, status: { $ne: OrderStatus.REFUNDED } },
        {
          $set: {
            status: OrderStatus.REFUNDED,
            adminNotes: reason || '╪د╪│╪ز╪▒╪ش╪د╪╣ ┘à╪د┘┘è ┘┘╪▒╪╡┘è╪» ┘à┘ ┘é╪ذ┘ ╪د┘╪ح╪»╪د╪▒╪ر',
          },
        },
        { new: true },
      )
      .populate('userId');
    if (!order) {
      const existing = await this.orderModel.findById(orderId);
      if (!existing) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');
      throw new BadRequestException('┘ç╪░╪د ╪د┘╪╖┘╪ذ ╪ز┘à ╪د╪│╪ز╪▒╪ش╪د╪╣┘ç ┘à╪│╪ذ┘é╪د┘ï');
    }

    // ╪ح╪▒╪ش╪د╪╣ ╪░╪▒┘è ┘┘┘à╪د┘╪ؤ ┘à╪│╪ز╪«╪»┘à ┘à╪ص╪░┘ê┘ ظçْ ╪ز┘╪ذ┘è┘ç ╪د┘╪ح╪»╪د╪▒╪ر ╪ذ╪»┘ ╪ز╪╣┘┘è┘à ╪د┘╪╖┘╪ذ ┘à╪│╪ز╪▒╪ش╪╣╪د┘ï ╪ذ┘╪د ┘à╪د┘ (H6)
    const customer = await this.userModel.findByIdAndUpdate(
      order.userId,
      { $inc: { balance: order.amount } },
      { new: true },
    );

    if (customer) {
      const balanceAfter = Number(customer.balance.toFixed(2));
      const balanceBefore = Number((balanceAfter - order.amount).toFixed(2));

      // Record refund transaction
      try {
        await this.transactionModel.create({
          userId: customer._id,
          type: TransactionType.REFUND,
          amount: order.amount,
          balanceBefore,
          balanceAfter,
          description: `╪د╪│╪ز╪▒╪ش╪د╪╣ ╪▒╪╡┘è╪» ┘╪╖┘╪ذ ┘à┘╪║┘è #${order.orderNumber}`,
          referenceType: 'Order',
          referenceId: order._id.toString(),
          status: TransactionStatus.COMPLETED,
        });
      } catch (ledgerErr: any) {
        this.logger.error(`Admin refund ledger entry failed for ${order.orderNumber}: ${ledgerErr.message}`);
        await this.notifyAdminsSafe(
          '╪ز┘╪ذ┘è┘ç ╪»┘╪ز╪▒: ╪د╪│╪ز╪▒╪ش╪د╪╣ ╪ح╪»╪د╪▒┘è ╪║┘è╪▒ ┘à╪│╪ش┘',
          `╪ث┘╪▒╪ش╪╣ $${order.amount.toFixed(2)} ┘┘╪╣┘à┘è┘ ┘┘è ╪د┘╪╖┘╪ذ #${order.orderNumber} ┘à┘ ╪د┘╪ح╪»╪د╪▒╪ر ┘┘â┘ ╪ز╪│╪ش┘è┘ ╪د┘╪ص╪▒┘â╪ر ┘╪┤┘╪ؤ ┘è┘╪▓┘à ┘à╪▒╪د╪ش╪╣╪ر ╪د┘╪»┘╪ز╪▒.`,
        );
      }
    } else {
      this.logger.error(`Admin refund for ${order.orderNumber}: customer account not found, funds not credited`);
      await this.notifyAdminsSafe(
        '╪ز┘╪ذ┘è┘ç ┘à╪د┘┘è: ╪د╪│╪ز╪▒╪ش╪د╪╣ ╪ح╪»╪د╪▒┘è ┘╪╣┘à┘è┘ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»',
        `╪د┘╪╖┘╪ذ #${order.orderNumber} ($${order.amount.toFixed(2)}) ╪د╪│╪ز┘╪▒╪ش╪╣ ┘┘â┘ ╪ص╪│╪د╪ذ ╪د┘╪╣┘à┘è┘ ┘┘à ┘è┘┘ê╪ش╪»╪ؤ ┘è┘╪▓┘à ╪ز╪╣┘ê┘è╪╢ ┘è╪»┘ê┘è.`,
      );
    }

    order.timeline.push({
      action: 'refunded',
      title: '╪ز┘à ╪ح┘╪║╪د╪ة ╪د┘╪╖┘╪ذ ┘ê╪د╪│╪ز╪▒╪ش╪د╪╣ ╪د┘┘à╪ذ┘╪║ ┘┘╪╣┘à┘è┘',
      description: `┘é╪د┘à ╪د┘╪ث╪»┘à┘ ${admin.name} ╪ذ╪د╪│╪ز╪▒╪ش╪د╪╣ $${order.amount.toFixed(2)} ┘┘à╪ص┘╪╕╪ر ╪د┘╪╣┘à┘è┘. ╪د┘╪│╪ذ╪ذ: ${reason}`,
      performerId: admin._id,
      performerName: admin.name,
      performerRole: 'admin',
      timestamp: new Date(),
    });

    await order.save();

    // Notify customer
    await this.notificationsService
      .createNotification({
        userId: order.userId.toString(),
        title: '╪ز┘à ╪د╪│╪ز╪▒╪ش╪د╪╣ ╪▒╪╡┘è╪» ╪╖┘╪ذ┘â ┘┘à╪ص┘╪╕╪ز┘â ≡اْ░',
        body: `╪ز┘à ╪د╪│╪ز╪▒╪ش╪د╪╣ ┘à╪ذ┘╪║ $${order.amount.toFixed(2)} ┘┘╪╖┘╪ذ #${order.orderNumber} ╪ح┘┘ë ┘à╪ص┘╪╕╪ز┘â ╪ذ┘╪ش╪د╪ص. ╪د┘╪│╪ذ╪ذ: ${reason}`,
        type: 'order_refunded',
        data: { orderId: order._id.toString(), amount: order.amount, reason },
      })
      .catch((err: any) => this.logger.warn(`Refund notification failed: ${err.message}`));

    return { message: '╪ز┘à ╪د╪│╪ز╪▒╪ش╪د╪╣ ╪د┘┘à╪ذ┘╪║ ┘┘à╪ص┘╪╕╪ر ╪د┘╪╣┘à┘è┘ ┘ê╪ح┘╪║╪د╪ة ╪د┘╪╖┘╪ذ ╪ذ┘╪ش╪د╪ص', order };
  }

  // --- 6. Order Messages & Secure Credentials ---
  // Get chat messages for an order
  async getOrderMessages(orderId: string, user: UserDocument) {
    const order = await this.orderModel.findById(orderId).select('chatMessages userId assignedSupervisorId');
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    // Access check: buyer, assigned supervisor, or admin
    const isBuyer = order.userId.toString() === user._id.toString();
    const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
    const isAdmin = user.role === 'admin';

    if (!isBuyer && !isSupervisor && !isAdmin) {
      throw new ForbiddenException('┘╪د ╪ز┘à┘┘â ╪╡┘╪د╪ص┘è╪ر ╪╣╪▒╪╢ ╪▒╪│╪د╪خ┘ ┘ç╪░╪د ╪د┘╪╖┘╪ذ');
    }

    return order.chatMessages || [];
  }

  // Send message on order thread
  async sendOrderMessage(
    orderId: string,
    user: UserDocument,
    data: {
      message: string;
      attachmentUrl?: string;
      attachmentName?: string;
      attachmentType?: string;
      isSensitive?: boolean;
      isPinned?: boolean;
      pinLabel?: string;
    },
  ) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name');
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    const isBuyer = order.userId.toString() === user._id.toString();
    const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
    const isAdmin = user.role === 'admin';

    if (!isBuyer && !isSupervisor && !isAdmin) {
      throw new ForbiddenException('┘╪د ╪ز┘à┘┘â ╪╡┘╪د╪ص┘è╪ر ╪ح╪▒╪│╪د┘ ╪▒╪│╪د╪خ┘ ┘┘è ┘ç╪░╪د ╪د┘╪╖┘╪ذ');
    }

    // ╪د┘╪»╪▒╪»╪┤╪ر ╪ز┘╪ز┘ç┘è ╪ذ╪د┘╪ز┘ç╪د╪ة ╪د┘╪╖┘╪ذ: ╪د┘╪╣┘à┘è┘ ┘╪د ┘è╪▒╪د╪│┘ ╪ذ╪╣╪» ╪د┘╪ح╪║┘╪د┘é╪î
    // ╪ذ┘è┘┘à╪د ┘è╪ذ┘é┘ë ┘┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر ┘ê╪د┘╪ح╪»╪د╪▒╪ر ╪ص┘é ╪د┘╪ز┘ê╪س┘è┘é ┘┘è ╪د┘╪ث╪▒╪┤┘è┘
    const orderEnded =
      order.status === OrderStatus.COMPLETED || order.status === OrderStatus.REFUNDED;
    if (isBuyer && orderEnded) {
      throw new ForbiddenException('╪د┘╪ز┘ç┘ë ╪د┘╪╖┘╪ذ ظ¤ ╪د┘╪»╪▒╪»╪┤╪ر ┘à╪║┘┘é╪ر ╪ذ╪╣╪» ╪ح╪║┘╪د┘é┘ç');
    }

    const senderRole = isAdmin ? 'admin' : isSupervisor ? 'supervisor' : 'user';

    // ╪د┘╪ز╪س╪ذ┘è╪ز ╪ص┘é ┘┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر (┘à╪┤╪▒┘ ┘à╪│┘╪» ╪ث┘ê ╪ث╪»┘à┘) ┘╪د ┘┘╪╣┘à┘è┘: ╪د┘╪▒╪│╪د┘╪ر ╪د┘┘à╪س╪ذ╪ز╪ر
    // ┘ç┘è ┬س╪ذ┘è╪د┘╪د╪ز ╪د┘╪╖┘╪ذ┬╗ (┘â┘ê╪» ╪ز╪ص┘é┘é/╪▒┘é┘à ┘ç╪د╪ز┘/┘â┘ê╪» ╪ذ╪«╪╖┘ê╪ز┘è┘) ┘┘╪د ╪ز┘╪س╪ذ┘┘ّ╪ز ╪ذ┘╪د ┘╪╡
    const pinRequested = data.isPinned === true;
    if (pinRequested) {
      if (isBuyer) throw new BadRequestException('╪ز╪س╪ذ┘è╪ز ╪د┘╪▒╪│╪د╪خ┘ ┘à╪ز╪د╪ص ┘┘à┘é╪»┘ّ┘à ╪د┘╪«╪»┘à╪ر ┘┘é╪╖');
      if (!(data.message || '').trim()) {
        throw new BadRequestException('╪د┘╪▒╪│╪د┘╪ر ╪د┘┘à╪س╪ذ╪ز╪ر ┘è╪ش╪ذ ╪ث┘ ╪ز╪ص┘à┘ ┘╪╡╪د┘ï (┘â┘ê╪» ╪ث┘ê ╪▒┘é┘à)');
      }
    }

    const newMessage: OrderChatMessage = {
      senderId: user._id,
      senderName: user.name,
      senderRole,
      message: data.message || '',
      attachmentUrl: data.attachmentUrl,
      attachmentName: data.attachmentName,
      attachmentType: data.attachmentType,
      isSensitive: data.isSensitive || false,
      isPinned: pinRequested,
      pinLabel: pinRequested ? (data.pinLabel || '').trim() || '╪ذ┘è╪د┘╪د╪ز ┘à╪س╪ذ╪ز╪ر' : undefined,
      createdAt: new Date(),
    };

    order.chatMessages.push(newMessage);
    // ┘╪│╪«╪ر ┘à┘┘╪«┘ّ╪╡╪ر ┘┘è ╪ذ┘è╪د┘╪د╪ز ╪د┘╪╖┘╪ذ: ╪ز┘╪╣╪▒╪╢ ┘┘è ┬س╪╖┘╪ذ╪د╪ز┘è┬╗ ╪»┘ê┘ ┘╪ز╪ص ╪د┘┘à╪ص╪د╪»╪س╪ر╪î
    // ┘ê╪د┘╪╢╪║╪╖ ╪╣┘┘è┘ç╪د ┘è┘╪ز╪ص ╪د┘╪┤╪د╪ز ┘┘╪│┘ç
    if (pinRequested) {
      order.pinnedData.push({
        label: newMessage.pinLabel!,
        value: newMessage.message.trim(),
        createdAt: newMessage.createdAt,
      });
    }
    await order.save();

    // Determine recipient for notification
    if (isBuyer && order.assignedSupervisorId) {
      await this.notificationsService.createNotification({
        userId: order.assignedSupervisorId.toString(),
        forRole: 'supervisor',
        title: `╪▒╪│╪د┘╪ر ╪ش╪»┘è╪»╪ر ┘à┘ ╪د┘╪╣┘à┘è┘ ╪ص┘ê┘ ╪╖┘╪ذ #${order.orderNumber} ≡اْش`,
        body: data.message ? (data.message.length > 80 ? `${data.message.slice(0, 80)}...` : data.message) : '╪ث╪▒╪│┘ ╪د┘╪╣┘à┘è┘ ┘à╪▒┘┘é╪د┘ï',
        type: 'order_chat',
        data: { orderId: order._id.toString() },
      });
    } else if (isSupervisor || isAdmin) {
      await this.notificationsService.createNotification({
        userId: order.userId.toString(),
        title: pinRequested
          ? `╪ذ┘è╪د┘╪د╪ز ╪ش╪»┘è╪»╪ر ┘╪╖┘╪ذ┘â #${order.orderNumber} ≡اôî`
          : `╪▒╪│╪د┘╪ر ╪ش╪»┘è╪»╪ر ┘à┘ ${user.name} ╪ص┘ê┘ ╪╖┘╪ذ┘â #${order.orderNumber} ≡اْش`,
        body: data.message ? (data.message.length > 80 ? `${data.message.slice(0, 80)}...` : data.message) : '╪ز┘à ╪ح╪▒╪│╪د┘ ┘à╪▒┘┘é ╪ش╪»┘è╪»',
        type: 'order_chat',
        data: { orderId: order._id.toString() },
      });
    }

    return newMessage;
  }

  // Securely decrypt and return sensitive result credentials for authorized viewer
  async getOrderDecryptedResult(orderId: string, user: UserDocument) {
    const order = await this.orderModel.findById(orderId);
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    const isBuyer = order.userId.toString() === user._id.toString();
    const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
    const isAdmin = user.role === 'admin';

    if (!isBuyer && !isSupervisor && !isAdmin) {
      throw new ForbiddenException('╪║┘è╪▒ ┘à╪╡╪▒╪ص ┘┘â ╪ذ╪د╪│╪ز╪╣╪▒╪د╪╢ ╪ذ┘è╪د┘╪د╪ز ┘ç╪░╪د ╪د┘╪╖┘╪ذ');
    }

    if (order.isResultPurged) {
      return {
        isPurged: true,
        purgedAt: order.purgedAt,
        message: '╪ز┘à ╪ص╪░┘ ╪د┘╪ذ┘è╪د┘╪د╪ز ╪د┘╪│╪▒┘è╪ر ╪ز┘┘é╪د╪خ┘è╪د┘ï ╪ذ╪╣╪» ╪ح╪║┘╪د┘é ╪د┘╪╖┘╪ذ ┘╪ص┘à╪د┘è╪ر ╪ث┘à╪د┘ ╪ص╪│╪د╪ذ┘â',
        credentials: null,
      };
    }

    if (!order.encryptedResultData) {
      return {
        isPurged: false,
        credentials: null,
        message: '┘╪د ╪ز┘ê╪ش╪» ╪ذ┘è╪د┘╪د╪ز ╪│╪▒┘è╪ر ┘à╪┤┘╪▒╪ر ┘à╪│╪ش┘╪ر ┘┘è ┘ç╪░╪د ╪د┘╪╖┘╪ذ',
      };
    }

    const decrypted = CryptoUtil.decrypt(order.encryptedResultData);
    return {
      isPurged: false,
      credentials: decrypted,
    };
  }

  // ┘è┘┘â ╪ز╪┤┘┘è╪▒ ┘à╪»╪«┘╪د╪ز ╪د┘╪╣┘à┘è┘ (accountInput) ┘┘┘à╪┤╪▒┘ ╪د┘┘à╪│┘╪» ╪ث┘ê ╪د┘╪ث╪»┘à┘ ┘┘é╪╖
  async getOrderDecryptedInput(orderId: string, user: UserDocument) {
    const order = await this.orderModel.findById(orderId);
    if (!order) throw new NotFoundException('╪د┘╪╖┘╪ذ ╪║┘è╪▒ ┘à┘ê╪ش┘ê╪»');

    const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
    const isAdmin = user.role === 'admin';

    if (!isSupervisor && !isAdmin) {
      throw new ForbiddenException('╪║┘è╪▒ ┘à╪╡╪▒╪ص ┘┘â ╪ذ╪د╪│╪ز╪╣╪▒╪د╪╢ ╪ذ┘è╪د┘╪د╪ز ┘ç╪░╪د ╪د┘╪╖┘╪ذ');
    }

    const sensitiveFields = order.sensitiveFields || [];
    const input = order.accountInput || {};
    const decryptedInput: Record<string, any> = {};

    for (const [key, value] of Object.entries(input)) {
      if (sensitiveFields.includes(key) && typeof value === 'string' && value.includes(':')) {
        decryptedInput[key] = CryptoUtil.decrypt(value) ?? value;
      } else {
        decryptedInput[key] = value;
      }
    }

    return {
      orderId: order._id.toString(),
      orderNumber: order.orderNumber,
      isSensitive: order.isSensitive || false,
      sensitiveFields,
      accountInput: decryptedInput,
    };
  }

  // Legacy fallback support for accept/reject
  async acceptManualOrder(id: string, notes?: string) {
    const order = await this.getOrderById(id);
    order.status = OrderStatus.COMPLETED;
    order.adminNotes = notes || '╪ز┘à ╪د┘╪┤╪ص┘ ╪ذ┘╪ش╪د╪ص';
    order.completedAt = new Date();
    await order.save();
    return { message: '╪ز┘à ┘é╪ذ┘ê┘ ╪د┘╪╖┘╪ذ ╪ذ┘╪ش╪د╪ص', order };
  }

  async rejectManualOrder(id: string, notes: string) {
    const order = await this.getOrderById(id);
    order.status = OrderStatus.REJECTED;
    order.adminNotes = notes || '╪ز┘à ╪▒┘╪╢ ╪د┘╪╖┘╪ذ';
    await order.save();
    return { message: '╪ز┘à ╪▒┘╪╢ ╪د┘╪╖┘╪ذ ╪ذ┘╪ش╪د╪ص', order };
  }
}
