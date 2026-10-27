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

// إشارة داخلية تُستعمل فقط للتحكّم بالسيطرة داخل المعاملة؛ تُترجَم إلى BadRequest خارجها
class InsufficientBalanceSignal extends Error {}

// إشارة داخلية: البنية الحالية لا تدعم المعاملات (mongod مستقل محلي) → fallback تتابعي
class TransactionUnsupportedSignal extends Error {}

@Injectable()
export class OrdersService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OrdersService.name);

  // مصالحة دورية للطلبات المعلّقة (لم تكن تعمل إلا بضغط الأدمن يدوياً)
  private static readonly RECONCILE_INTERVAL_MS = 5 * 60 * 1000;
  private reconcileTimer?: ReturnType<typeof setInterval>;
  private reconcileKickoffTimer?: ReturnType<typeof setTimeout>;
  private isReconciling = false;

  // هل البنية تدعم المعاملات؟ أطلس (replica set) نعم؛ mongod المحلي المستقل لا — نُكتشف مرة واحدة
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
    // جولة أولى بعد دقيقة ثم كل 5 دقائق؛ المؤقّتات unref فلا تُبقي العملية حيّة ولا تُعلّق اختبارات vitest
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

  // حملة مصالحة واحدة متزامنة داخلياً؛ تجاوز إن كانت السابقة لم تنتهِ
  private async runReconciliationPass() {
    if (this.isReconciling) return;
    this.isReconciling = true;
    try {
      await this.reconcileProviderOrders(20);
    } finally {
      this.isReconciling = false;
    }
  }

  // تعويض سحب إعادة إرسال مكرّرة (M2): إرجاع الخصم الثاني إلى العميل وحفظ الحركة
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
        description: 'إرجاع تلقائي لسحب مكرّر من إعادة إرسال نفس الطلب',
        referenceType: 'Order',
        status: TransactionStatus.COMPLETED,
      });
    } catch (err: any) {
      this.logger.error(`Duplicate-debit compensation failed for user ${user._id}: ${err?.message}`);
      await this.notifyAdminsSafe(
        'تنبيه مالي: سحب مكرّر غير معوّض',
        `أُعيد إرسال طلب بنفس المعرّف للعميل ${user.name} لكن تعذّر إرجاع الخصم الثاني ($${price.toFixed(2)})؛ يلزم تدخل يدوي.`,
      );
    }
  }

  // إشعارات لا يجب أن تُفشل عملية طلب/تنفيذ ناجحة (H5)
  private async notifyAdminsSafe(title: string, body: string) {
    try {
      await this.notificationsService.createNotification({ forRole: 'admin', title, body, type: 'order_status' });
    } catch (err: any) {
      this.logger.warn(`Admin notification failed (${title}): ${err?.message}`);
    }
  }

  // سحب ذري لأكواد من المخزون — يمنع تسليم نفس الكود لطلبين متزامنين (H4)
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

  // الخصم تم والطلب لم يُحفظ: نُرجع المال، وإن فشل الرجوع يُنوَّه للإدارة فوراً (H1)
  private async refundUnpersistedDebit(user: UserDocument, price: number, cause: any) {
    this.logger.error(`Order persist failed after debit for ${user._id}: ${cause?.message}`);
    try {
      await this.userModel.findByIdAndUpdate(user._id, { $inc: { balance: price } });
    } catch (refundErr: any) {
      this.logger.error(`Emergency refund failed for user ${user._id}: ${refundErr?.message}`);
      await this.notifyAdminsSafe(
        'تنبيه مالي: خصم بلا تعويض',
        `فشل حفظ طلب بعد خصم $${price.toFixed(2)} من العميل ${user.name} وفشل إرجاعه تلقائياً؛ يلزم تدخل يدوي.`,
      );
    }
  }

  // يُرجع كوداً كان سُحب ذرّياً إلى المخزون عند فشل إتمام الطلب (D)
  private async releaseInventoryCode(productId: Types.ObjectId, code: string) {
    try {
      await this.productModel.findByIdAndUpdate(productId, { $addToSet: { inventoryCodes: code } });
    } catch (err: any) {
      this.logger.error(`Could not return inventory code ${code} for product ${productId}: ${err?.message}`);
      await this.notifyAdminsSafe(
        'تنبيه مخزون: كود غير معاد',
        `أُخرج الكود ${code} من المخزون ولم يُسلَّم ولم يعد؛ يلزم مراجعة يدوية للمخزون.`,
      );
    }
  }

  // يميّز خطأ «البنية لا تدعم المعاملات» عن سواه (mongod مستقل/محلي) (A/E)
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

  // الحسم المالي عند إنشاء الطلب: الخصم + حفظ الطلب + حركة الشراء كلٌّ أو لا شيء داخل معاملة أطلس؛
  // وإن كانت البنية بلا معاملات يُنفَّذ تتابعياً مع تعويض (A/E)
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
            `رصيدك غير كافٍ. المبلغ المطلوب: $${price.toFixed(2)}، رصيدك الحالي: $${user.balance.toFixed(2)}`,
          );
        }
        if (err?.code === 11000 && cleanRequestId) {
          // المعاملة أُجهِضت تلقائياً: لم يُسحب شيء — نُعيد الطلب الأصلي بلا تعويض
          const existing = await this.orderModel.findOne({ requestId: cleanRequestId });
          if (existing) return { kind: 'duplicate', existing };
        }
        if (this.isUnsupportedTransactionError(err)) {
          this.txSupported = false;
          this.logger.warn('Topology lacks transaction support; falling back to compensating sequential path');
          return this.commitPurchaseSequential(params);
        }
        this.logger.error(`createOrder transaction failed for ${orderDoc.orderNumber}: ${err?.message}`);
        throw new BadRequestException('تعذر إتمام العملية، لم يتم خصم أي مبلغ. يرجى المحاولة لاحقاً');
      } finally {
        await session.endSession();
      }
    }

    return this.commitPurchaseSequential(params);
  }

  // مسار بديل للبنية بلا معاملات: خصم ذرّي ثم حفظ مع تعويض عند الفشل (سلوك سابق محفوظ)
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
        `رصيدك غير كافٍ. المبلغ المطلوب: $${price.toFixed(2)}، رصيدك الحالي: $${user.balance.toFixed(2)}`,
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
      throw new BadRequestException('تعذر إتمام العملية، تم إرجاع المبلغ إلى محفظتك. يرجى المحاولة لاحقاً');
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
        order.rejectionReason = 'تعذر تسجيل الحركة المالية، تم إرجاع المبلغ';
        await order.save();
        await this.userModel.findByIdAndUpdate(user._id, { $inc: { balance: price } });
      } catch (compensationErr: any) {
        this.logger.error(`Compensation chain failed for ${order.orderNumber}: ${compensationErr.message}`);
        await this.notifyAdminsSafe(
          'تنبيه مالي: طلب معلّق بعد فشل تسجيل الحركة',
          `الطلب #${order.orderNumber} (عميل ${user.name}، مبلغ $${price.toFixed(2)}) تعذّر تسجيل حركته المالية وتعذّر إتمام إرجاعه تلقائياً؛ يلزم مراجعة يدوية.`,
        );
      }
      throw new BadRequestException('تعذر إتمام العملية، لم يتم خصم أي مبلغ. يرجى المحاولة لاحقاً');
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
    // معرّف إرسال العميل: يجعل إعادة المحاولة بعد انقطاع آمنة (idempotency)
    requestId?: string;
  }) {
    const user = await this.userModel.findById(params.userId);
    if (!user) throw new NotFoundException('المستخدم غير موجود');

    const product = await this.productModel
      .findById(params.productId)
      .populate('serviceTemplateId');
    if (!product || !product.isActive) {
      throw new BadRequestException('المنتج غير متاح حالياً');
    }

    const app = await this.appModel.findById(product.appId);
    if (!app || !app.isActive) {
      throw new BadRequestException('هذه الخدمة معطلة حالياً');
    }

    // الحقول المطلوبة والحساسة: تُشتق من قالب الخدمة المرتبط (المصدر الموثوق)،
    // مع الرجوع إلى حقول المنتج كخطة بديلة للخدمات غير المرتبطة بقالب.
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

    // التحقق من اكتمال الحقول المطلوبة قبل خصم أي مبلغ من المحفظة
    // (منتجات الأكواد تُسلَّم آلياً فلا تحتاج حقول إدخال)
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
          `يرجى إكمال الحقول المطلوبة: ${missingFields.join('، ')}`,
        );
      }
    }

    const price = product.salePrice;
    if (user.balance < price) {
      throw new BadRequestException(
        `رصيدك غير كافٍ. المبلغ المطلوب: $${price.toFixed(2)}، رصيدك الحالي: $${user.balance.toFixed(2)}`,
      );
    }

    // Fail fast: verify the provider is reachable and funded BEFORE touching the wallet
    if (product.type === ProductType.DIRECT_API && product.providerId) {
      await this.providersService.ensureReadyForOrder(product.providerId.toString(), product.costPrice || 0);
    }

    if (product.type === ProductType.CODES && (!product.inventoryCodes || product.inventoryCodes.length === 0)) {
      throw new BadRequestException('عذراً، هذا المنتج غير متوفر في المخزون حالياً');
    }

    // الخصم لم يقع بعد: النية (مستند الطلب) والخصم والحركة المالية تُحسم معاً داخل معاملة ذرّية (A/E)

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
      title: 'تم إنشاء الطلب ودفع القيمة',
      description: `تم خصم $${price.toFixed(2)} من محفظة العميل للخدمة: ${product.name}`,
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
      appId: app._id,
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
    // الخصم + حفظ الطلب + حركة الشراء ذرّياً داخل معاملة؛ أو تتابعياً مع تعويض عند غياب الدعم
    const commit = await this.commitPurchaseMoney({
      orderDoc,
      cleanRequestId,
      user,
      price,
      ledgerDescription: `شراء ${product.name} (${app.name})`,
    });
    if (commit.kind === 'duplicate') {
      // إعادة إرسال بنفس requestId: لم يُسحب شيء في المعاملة، أو عُوِّض في المسار التتابعي
      return {
        message: 'تم تنفيذ طلبك سابقاً، وهذه نسخة عنه',
        order: await this.getOrderById(commit.existing._id.toString()),
        newBalance: await this.getUserBalance(user._id),
        deliveredCode: commit.existing.deliveredCode,
      };
    }
    const order = commit.order;
    // Derived from the authoritative post-debit document, never from a stale read
    const balanceAfter = Number(commit.debited.balance.toFixed(2));
    const balanceBefore = Number((balanceAfter + price).toFixed(2));

    let assignedSupervisorId: Types.ObjectId | undefined = undefined;
    let assignedSupervisorUser: UserDocument | null = null;

    if (product.type === ProductType.CODES) {
      // Re-checked here because a concurrent order may have drained the stock —
      // السحب ذري ($pop) فلا يُسلَّم نفس الكود لطلبين متزامنين
      const code = await this.allocateInventoryCode(product._id);
      if (!code) {
        return this.failPaidOrder(order, {
          amount: price,
          reason: 'عذراً، هذا المنتج غير متوفر في المخزون حالياً',
        });
      }
      deliveredCode = code;
      initialStatus = OrderStatus.COMPLETED;

      order.timeline.push({
        action: 'delivered',
        title: 'تم تسليم الكود تلقائياً',
        description: 'تم تسليم كود البطاقة للعميل مباشرة من المخزون',
        performerName: 'النظام الآلي',
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
          rawInput['المعرف'] ||
          rawInput['ID'] ||
          rawInput['userid'] ||
          rawInput['playerId'] ||
          Object.values(rawInput)[0];

        const gameZoneId =
          rawInput['Zone ID'] ||
          rawInput['Server ID'] ||
          rawInput['Server/Zone ID'] ||
          rawInput['السيرفر'] ||
          rawInput['serverid'] ||
          rawInput['zoneId'] ||
          (Object.values(rawInput).length > 1 ? Object.values(rawInput)[1] : undefined);

        if (!gameUserId) {
          // Refund the customer atomically and keep the attempt on record
          return this.failPaidOrder(order, {
            amount: price,
            reason: 'يرجى إدخال معرف اللاعب (Player ID) المطلوب للشحن',
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
          // An unexpected transport/execution throw must never cost the customer money —
          // والمهلة المنتهية المجهولة المصير تبقى معلّقة للمصالحة لا استرجاعاً أعمى (H3)
          providerResult = {
            success: false,
            message: err?.message || 'تعذر الاتصال بمزوّد الخدمة',
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
            );
          } catch (markErr: any) {
            this.logger.warn(`Could not mark provider failure: ${markErr.message}`);
          }

          // انقطاع مهلة/استثناء نقل: المزود قد يكون نفّذ الشحن فعلاً — الطلب يبقى
          // معلّقاً والمرجع محفوظاً حتى تحسمه المصالحة الدورية (تأكيد أو استرجاع)
          if (providerResult.isTimeout) {
            order.providerReference = order.providerReference || orderNumber;
            order.status = OrderStatus.PENDING;
            order.rejectionReason = `جارٍ التحقق من حالة الطلب لدى مزود الخدمة: ${providerResult.message}`;
            order.timeline.push({
              action: 'provider_timeout',
              title: 'انقطاع الاتصال بمزود الخدمة — الطلب قيد التحقق',
              description: 'قد يكون الطلب نُفّذ لدى المزود رغم انقطاع الاستجابة؛ سيعاد فحصه تلقائياً ويُبلّغ العميل بالنتيجة.',
              performerName: 'النظام الآلي',
              performerRole: 'system',
              timestamp: new Date(),
            });
            await order.save();

            await this.notifyAdminsSafe(
              'تنبيه: مهلة انقطاع لدى المزود',
              `الطلب #${orderNumber} (${product.name}) انتهى نداؤه بالمهلة — سيُحسم تلقائياً عبر المصالحة.`,
            );

            return {
              message: `تم استلام طلبك؛ انقطع الاتصال بمزود الخدمة أثناء التنفيذ وسيُحدَّث حالته تلقائياً خلال دقائق (${orderNumber})`,
              order: await this.getOrderById(order._id.toString()),
              newBalance: balanceAfter,
            };
          }

          await this.notificationsService
            .createNotification({
              forRole: 'admin',
              title: 'فشل تنفيذ طلب لدى المزوّد',
              body: `تعذّر تنفيذ الطلب #${orderNumber} (${product.name}) عبر المزوّد: ${providerResult.message}. تم إرجاع المبلغ للعميل تلقائياً.`,
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
            reason: `تعذر إتمام الشحن عبر المزود: ${providerResult.message}`,
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
          title: 'تم تنفيذ الشحن عبر المزود الآلي بنجاح',
          description: `تم إرسال الطلب وتنفيذه بنجاح عبر مزود الخدمة (المرجع: ${providerResult.transactionId || orderNumber})`,
          performerName: 'النظام الآلي (API)',
          performerRole: 'system',
          timestamp: new Date(),
        });
      } else {
        initialStatus = OrderStatus.COMPLETED;
        order.timeline.push({
          action: 'delivered',
          title: 'تم تنفيذ الشحن عبر المزود الآلي',
          description: 'تم إرسال الشحن وتنفيذه بنجاح عبر مزود الخدمة',
          performerName: 'النظام الآلي',
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
          title: `تم إسناد الطلب للمشرف (${assignedSupervisorUser?.name || 'المشرف المسؤول'})`,
          description: `تم إسناد الطلب تلقائياً، والوقت المتوقع للتنفيذ: ${estimatedMinutes} دقيقة`,
          performerName: 'النظام الآلي',
          performerRole: 'system',
          timestamp: new Date(),
        });
      } else {
        initialStatus = OrderStatus.PENDING;
        order.timeline.push({
          action: 'pending_assignment',
          title: 'بانتظار إسناد المشرف',
          description: 'الطلب بانتظار قيام الإدارة بتعيين مشرف للتنفيذ',
          performerName: 'النظام',
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
      // الطلب أُكمل/أُرسل لدى المزود لكن حالة المستند لم تتحدث — تُلتقط بالمصالحة أو يدوياً
      this.logger.error(`Order finalize save failed for ${orderNumber}: ${finalizeErr.message}`);
      // كود الأكواد المسحوب لا تُغطّيه المصالحة: يُعاد للمخزون كي لا يتيتم (D)
      if (product.type === ProductType.CODES && deliveredCode) {
        await this.releaseInventoryCode(product._id, deliveredCode);
      }
      await this.notifyAdminsSafe(
        'تنبيه: تعذّر تحديث حالة طلب بعد التنفيذ',
        `الطلب #${orderNumber} نُفّذ/أُرسل لكن حالته لم تُحدَّث في القاعدة؛ يلزم مراجعة يدوية.`,
      );
    }

    // Notify Supervisor if assigned (إشعار لاحق لا يفشل الطلب الناجح — H5)
    if (assignedSupervisorId && assignedSupervisorUser) {
      await this.notificationsService
        .createNotification({
          userId: assignedSupervisorId.toString(),
          forRole: 'supervisor',
          title: 'طلب يدوي جديد مسند إليك 🔔',
          body: `طلب جديد #${orderNumber} لخدمة ${product.name}. الوقت المتوقع: ${estimatedMinutes} دقيقة.`,
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
        title: 'طلب جديد 🛒',
        body: `طلب جديد رقم #${orderNumber} لخدمة ${product.name} بمبلغ $${price.toFixed(2)}`,
        type: 'new_order',
        data: { orderId: order._id.toString(), orderNumber },
      })
      .catch((err: any) => this.logger.warn(`Admin new-order notification failed: ${err.message}`));

    // Notify User if completed immediately
    if (initialStatus === OrderStatus.COMPLETED) {
      await this.notificationsService
        .createNotification({
          userId: user._id.toString(),
          title: 'تم تنفيذ طلبك بنجاح ✅',
          body:
            product.type === ProductType.CODES
              ? `تم استلام كود باقة ${product.name}: ${deliveredCode}`
              : `تم تنفيذ شحن باقة ${product.name} لحسابك بنجاح`,
          type: 'order_status',
          data: { orderId: order._id.toString(), deliveredCode },
        })
        .catch((err: any) => this.logger.warn(`Customer completion notification failed: ${err.message}`));
    }

    // القراءة الأخيرة رفاهية: فشلها لا يجب أن يُسقط استجابة طلبٍ نجح فعلاً (H5)
    let orderView: any = order;
    try {
      orderView = await this.getOrderById(order._id.toString());
    } catch (viewErr: any) {
      this.logger.warn(`Could not refetch order view for ${orderNumber}: ${viewErr.message}`);
    }

    return {
      message:
        initialStatus === OrderStatus.COMPLETED
          ? 'تم تنفيذ الطلب بنجاح'
          : initialStatus === OrderStatus.ASSIGNED
          ? 'تم استلام طلبك وجاري تحويله للمشرف المختص لبدء التنفيذ'
          : 'تم إرسال طلب الشحن بنجاح وهو قيد المراجعة',
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
      // تعذّر إرجاع المال: الطلب يبقى معلّقاً والمرجع محفوظاً — المصالحة الدورية
      // أو مراجعة الأدمن تحسمه، ولا يُبتلع الخطأ بصمت (H2)
      this.logger.error(`Refund credit failed for ${order.orderNumber}: ${creditErr.message}`);
      try {
        order.providerReference = order.providerReference || order.orderNumber;
        await order.save();
      } catch (saveErr: any) {
        this.logger.error(`Could not persist reference for ${order.orderNumber}: ${saveErr.message}`);
      }
      await this.notifyAdminsSafe(
        'تنبيه مالي: فشل إرجاع مبلغ لطلب متعذر',
        `الطلب #${order.orderNumber} تعذّر تنفيذُه ($${params.amount.toFixed(2)}) وفشل إرجاع المبلغ للعميل؛ يلزم تدخل يدوي.`,
      );
      throw new BadRequestException(`${params.reason} (رقم الطلب: ${order.orderNumber})`);
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
      title: 'تعذّر تنفيذ الطلب وتم إرجاع المبلغ تلقائياً',
      description: params.reason,
      performerName: 'النظام الآلي',
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
        description: `إرجاع تلقائي لطلب متعذر #${order.orderNumber}`,
        referenceType: 'Order',
        referenceId: order._id.toString(),
        status: TransactionStatus.COMPLETED,
      });
    } catch (ledgerErr: any) {
      // المال رُجع فعلياً لكن الدفتر لم يسجّل — تنبيه الإدارة بدل الصمت (H2)
      this.logger.error(`Refund ledger entry failed for ${order.orderNumber}: ${ledgerErr.message}`);
      await this.notifyAdminsSafe(
        'تنبيه دفتر: حركة إرجاع غير مسجلة',
        `أُرجع $${params.amount.toFixed(2)} للعميل في الطلب #${order.orderNumber} لكن تسجيل الحركة فشل؛ يلزم مراجعة الدفتر.`,
      );
    }

    throw new BadRequestException(`${params.reason} (رقم الطلب: ${order.orderNumber})`);
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
      performerName: 'المصالحة الآلية',
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
      description: `إرجاع تلقائي (مصالحة) لطلب #${order.orderNumber}`,
      referenceType: 'Order',
      referenceId: order._id.toString(),
      status: TransactionStatus.COMPLETED,
    });

    await this.notificationsService.createNotification({
      userId: order.userId.toString(),
      title: 'تم إرجاع مبلغ طلبك إلى المحفظة',
      body: `تعذّر تنفيذ الطلب #${order.orderNumber} لدى مزود الخدمة، وتم إرجاع $${order.amount.toFixed(2)} إلى محفظتك.`,
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
          title: 'تم تأكيد تنفيذ الطلب لدى المزوّد',
          description: inspection.message || 'أكد المزوّد تنفيذ الطلب',
          performerName: 'المصالحة الآلية',
          performerRole: 'system',
          timestamp: new Date(),
        });
        await order.save();
        settled++;
        continue;
      }

      if (inspection.state === 'failed') {
        const reason = `أبلغ المزوّد عن فشل تنفيذ الطلب: ${inspection.message || 'سبب غير محدد'}`;
        order.providerResponse = inspection.raw as Record<string, any>;
        order.providerSettledAt = new Date();
        await this.autoRefundOrder(order, reason, 'تم استرجاع المبلغ تلقائياً بعد فشل المزوّد');
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

        // We refunded but the provider delivered — a human must reconcile this one
        order.providerSettledAt = new Date();
        order.timeline.push({
          action: 'provider_mismatch',
          title: 'تنبيه: المزوّد يعتبر الطلب منفذاً بعد استرجاعه',
          description: inspection.message || 'تأكد المزوّد من تنفيذ الطلب رغم إرجاع المبلغ للعميل',
          performerName: 'المصالحة الآلية',
          performerRole: 'system',
          timestamp: new Date(),
        });
        await order.save();
        flagged++;

        await this.notificationsService.createNotification({
          forRole: 'admin',
          title: 'تنبيه مالي: طلب مسترجع لكن المزوّد نفّذه',
          body: `الطلب #${order.orderNumber} تم إرجاع مبلغه للعميل، لكن المزوّد يؤكد تنفيذه. يرجى المراجعة اليدوية.`,
          type: 'provider_mismatch',
          data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
        });
      } catch (err: any) {
        this.logger.warn(`Reverse reconciliation failed for order ${order.orderNumber}: ${err.message}`);
      }
    }

    // Third pass: orders orphaned mid-flight (e.g. the platform killed the function
    // while the provider call was still running) — the customer was charged but the
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
          title: 'تم تأكيد تنفيذ الطلب لدى المزوّد',
          description: inspection.message || 'أكد المزوّد تنفيذ الطلب',
          performerName: 'المصالحة الآلية',
          performerRole: 'system',
          timestamp: new Date(),
        });
        await order.save();
        recovered++;

        await this.notificationsService.createNotification({
          userId: order.userId.toString(),
          title: 'تم تنفيذ طلبك بنجاح',
          body: `تم تأكيد تنفيذ الطلب #${order.orderNumber} لدى مزود الخدمة.`,
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
          `أبلغ المزوّد عن فشل تنفيذ الطلب: ${inspection.message || 'سبب غير محدد'}`,
          'تم استرجاع المبلغ تلقائياً بعد فشل المزوّد',
        );
        refunded++;
        continue;
      }

      // حالة مجهولة (مزود لا يعيد حالة طلب): لا يبقى معلّقاً بصمت — تنبيه للإدارة (M3)
      if (inspection.state === 'unknown') {
        order.providerSettledAt = new Date();
        order.timeline.push({
          action: 'provider_unknown',
          title: 'تعذّر تحديد حالة الطلب لدى المزوّد',
          description: inspection.message || 'لا توجد حالة مؤكدة من المزوّد؛ يلزم مراجعة يدوية',
          performerName: 'المصالحة الآلية',
          performerRole: 'system',
          timestamp: new Date(),
        });
        await order.save();
        flagged++;

        await this.notificationsService
          .createNotification({
            forRole: 'admin',
            title: 'طلب معلّق بحالة مجهولة لدى المزود',
            body: `الطلب #${order.orderNumber} خُصم من العميل ولم يستطع الفحص الآلي تأكيد تنفيذه أو فشله؛ يرجى المراجعة اليدوية.`,
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
      message: `تمت مراجعة ${orders.length + refundedOrders.length + orphanedOrders.length} طلباً: ${settled} مؤكد، ${recovered} مُستعاد، ${refunded} مسترجع، ${pending} قيد الانتظار، ${flagged} بحاجة مراجعة يدوية`,
    };
  }

  // --- 2. Queries: User / Supervisor / Admin ---
  async getMyOrders(userId: string) {
    return this.orderModel
      .find({ userId: new Types.ObjectId(userId) })
      .populate('appId', 'name iconUrl')
      .populate('productId', 'name type costPrice salePrice isSensitive')
      .populate('assignedSupervisorId', 'name email phone role')
      .sort({ createdAt: -1 });
  }

  async getOrderById(id: string) {
    const order = await this.orderModel
      .findById(id)
      .populate('userId', 'name email phone balance userId')
      .populate('appId', 'name iconUrl')
      .populate({
        path: 'productId',
        select: 'name type costPrice salePrice isSensitive instructions serviceTemplateId',
        populate: { path: 'serviceTemplateId', select: 'name fields' },
      })
      .populate('assignedSupervisorId', 'name email phone role userId');
    if (!order) throw new NotFoundException('الطلب غير موجود');
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
      .populate('productId', 'name type costPrice salePrice isSensitive')
      .populate('assignedSupervisorId', 'name email phone role userId')
      .sort({ createdAt: -1 })
      .lean();

    // القوائم لا تُحمّل المحادثات وسجل الأحداث (تُجلب عند فتح الطلب فقط) لتسريع الاستجابة
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
    if (!order) throw new NotFoundException('الطلب غير موجود');

    if (
      order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
      supervisor.role !== 'admin'
    ) {
      throw new ForbiddenException('هذا الطلب غير مسند إليك');
    }

    if (order.status !== OrderStatus.ASSIGNED && order.status !== OrderStatus.PENDING) {
      throw new BadRequestException('لا يمكن قبول الطلب في حالته الحالية');
    }

    order.status = OrderStatus.ACCEPTED;
    order.acceptedAt = new Date();

    order.timeline.push({
      action: 'accepted',
      title: 'قبل المشرف الطلب',
      description: `قام المشرف ${supervisor.name} بقبول الطلب والاستعداد للبدء في تنفيذه`,
      performerId: supervisor._id,
      performerName: supervisor.name,
      performerRole: 'supervisor',
      timestamp: new Date(),
    });

    await order.save();

    // Notify customer
    await this.notificationsService.createNotification({
      userId: order.userId.toString(),
      title: 'تم قبول طلبك من قبل المشرف 👨‍💻',
      body: `قبل المشرف طلبك #${order.orderNumber} لخدمة ${(order.productId as any)?.name || 'الخدمة'} وجاري البدء.`,
      type: 'order_status',
      data: { orderId: order._id.toString(), status: 'accepted' },
    });

    return { message: 'تم قبول الطلب بنجاح', order };
  }

  // Supervisor rejects order (with reason)
  async supervisorRejectOrder(orderId: string, supervisor: UserDocument, reason: string) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name');
    if (!order) throw new NotFoundException('الطلب غير موجود');

    if (
      order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
      supervisor.role !== 'admin'
    ) {
      throw new ForbiddenException('هذا الطلب غير مسند إليك');
    }

    if (order.status === OrderStatus.COMPLETED || order.status === OrderStatus.REFUNDED) {
      throw new BadRequestException('لا يمكن رفض طلب منتهي أو مسترجع');
    }

    order.status = OrderStatus.REJECTED;
    order.rejectionReason = reason;

    order.timeline.push({
      action: 'rejected',
      title: 'اعتذر المشرف عن تنفيذ الطلب',
      description: `اعتذر المشرف ${supervisor.name} عن التنفيذ. السبب: ${reason}`,
      performerId: supervisor._id,
      performerName: supervisor.name,
      performerRole: 'supervisor',
      timestamp: new Date(),
    });

    await order.save();

    // الاعتذار عن التنفيذ يُخرج الطلب من قائمة المشرف؛ فقد يعود عميلاً إن لم يبقَ لديه إسناد
    await this.usersService.reconcileSupervisorRole(supervisor._id);

    // Notify Admins that order was rejected and requires reassignment
    await this.notificationsService.createNotification({
      forRole: 'admin',
      title: 'تنبيه: رفض طلب يدوي من المشرف ⚠️',
      body: `اعتذر المشرف ${supervisor.name} عن تنفيذ الطلب #${order.orderNumber}. السبب: ${reason}. يرجى إعادة الإسناد لمشرف آخر.`,
      type: 'manual_order_rejected',
      data: { orderId: order._id.toString(), orderNumber: order.orderNumber, reason },
    });

    return { message: 'تم تسجيل اعتذار المشرف وسيتم إشعار الإدارة لإعادة الإسناد', order };
  }

  // Supervisor starts execution
  async supervisorStartOrder(orderId: string, supervisor: UserDocument) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name');
    if (!order) throw new NotFoundException('الطلب غير موجود');

    if (
      order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
      supervisor.role !== 'admin'
    ) {
      throw new ForbiddenException('هذا الطلب غير مسند إليك');
    }

    order.status = OrderStatus.IN_PROGRESS;
    order.startedAt = new Date();

    order.timeline.push({
      action: 'started',
      title: 'بدأ المشرف في تنفيذ الخدمة',
      description: `بدأ المشرف ${supervisor.name} العمل على الطلب`,
      performerId: supervisor._id,
      performerName: supervisor.name,
      performerRole: 'supervisor',
      timestamp: new Date(),
    });

    await order.save();

    // Notify customer
    await this.notificationsService.createNotification({
      userId: order.userId.toString(),
      title: 'طلبك قيد التنفيذ الآن ⚙️',
      body: `بدأ المشرف في تنفيذ وتجهيز طلبك #${order.orderNumber}.`,
      type: 'order_status',
      data: { orderId: order._id.toString(), status: 'in_progress' },
    });

    return { message: 'تم بدء تنفيذ الطلب بنجاح', order };
  }

  // Supervisor requests additional info/files from customer
  async supervisorRequestInfo(
    orderId: string,
    supervisor: UserDocument,
    data: { note: string; attachmentUrl?: string },
  ) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name');
    if (!order) throw new NotFoundException('الطلب غير موجود');

    if (
      order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
      supervisor.role !== 'admin'
    ) {
      throw new ForbiddenException('هذا الطلب غير مسند إليك');
    }

    order.status = OrderStatus.INFO_REQUESTED;

    order.timeline.push({
      action: 'info_requested',
      title: 'طلب المشرف معلومات إضافية',
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
      title: 'المشرف يطلب معلومات إضافية حول طلبك 💬',
      body: data.note,
      type: 'order_chat',
      data: { orderId: order._id.toString(), note: data.note },
    });

    return { message: 'تم إرسال طلب المعلومات للعميل', order };
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
    if (!order) throw new NotFoundException('الطلب غير موجود');

    if (
      order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
      supervisor.role !== 'admin'
    ) {
      throw new ForbiddenException('هذا الطلب غير مسند إليك');
    }

    order.status = OrderStatus.DELIVERED;
    order.deliveredAt = new Date();
    order.resultNotes = data.resultNotes || 'تم تنفيذ الخدمة بنجاح، يرجى مراجعة التفاصيل وتأكيد الاستلام';
    order.resultAttachments = data.attachments || [];

    // Encrypt sensitive credentials securely using AES-256
    if (data.credentials && Object.keys(data.credentials).length > 0) {
      order.encryptedResultData = CryptoUtil.encrypt(data.credentials);
    }

    order.timeline.push({
      action: 'delivered',
      title: 'تم تسليم نتيجة الخدمة إلى العميل',
      description: 'أنهى المشرف العمل وسلّم تفاصيل النتيجة وبانتظار تأكيد العميل وإغلاق الطلب',
      performerId: supervisor._id,
      performerName: supervisor.name,
      performerRole: 'supervisor',
      timestamp: new Date(),
    });

    await order.save();

    // Notify customer (ensure no raw credentials leaked in notification text!)
    await this.notificationsService.createNotification({
      userId: order.userId.toString(),
      title: 'تم تسليم طلبك بنجاح! يرجى المراجعة والتأكيد 🎉',
      body: `انتهى المشرف من تنفيذ طلبك #${order.orderNumber}. يرجى الدخول لمراجعة تفاصيل النتيجة وتأكيد الاستلام.`,
      type: 'order_delivered',
      data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
    });

    return { message: 'تم تسليم النتيجة للعميل بنجاح وبانتظار تأكيده', order };
  }

  // --- 4. Customer Workflows ---
  // Customer confirms receipt & closes order (auto purges sensitive credentials)
  async customerConfirmOrder(orderId: string, user: UserDocument) {
    const order = await this.orderModel
      .findById(orderId)
      .populate('productId', 'name')
      .populate('assignedSupervisorId', 'name');
    if (!order) throw new NotFoundException('الطلب غير موجود');

    if (order.userId.toString() !== user._id.toString()) {
      throw new ForbiddenException('لا تملك صلاحية تأكيد هذا الطلب');
    }

    if (order.status !== OrderStatus.DELIVERED) {
      throw new BadRequestException('لا يمكن تأكيد الطلب قبل تسليمه من المشرف');
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
      title: 'أكد العميل استلام الخدمة ورضاه عنها',
      description: 'تم إغلاق الطلب بنجاح بعد موافقة العميل وتأكيد استلامه',
      performerId: user._id,
      performerName: user.name,
      performerRole: 'customer',
      timestamp: new Date(),
    });

    await order.save();

    // Notify Supervisor
    if (order.assignedSupervisorId) {
      await this.notificationsService.createNotification({
        userId: (order.assignedSupervisorId as any)._id?.toString() || order.assignedSupervisorId.toString(),
        forRole: 'supervisor',
        title: 'تم تأكيد استلام الطلب من العميل ✅',
        body: `قام العميل بتأكيد استلام الطلب #${order.orderNumber} لخدمة ${(order.productId as any)?.name} وتم إغلاق الطلب بنجاح.`,
        type: 'order_confirmed',
        data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
      });
    }

    return { message: 'شكراً لك! تم تأكيد استلام الخدمة وإغلاق الطلب بنجاح', order };
  }

  // Customer requests revision
  async customerRequestRevision(orderId: string, user: UserDocument, revisionNotes: string) {
    const order = await this.orderModel
      .findById(orderId)
      .populate('productId', 'name')
      .populate('assignedSupervisorId', 'name');
    if (!order) throw new NotFoundException('الطلب غير موجود');

    if (order.userId.toString() !== user._id.toString()) {
      throw new ForbiddenException('لا تملك صلاحية طلب التعديل');
    }

    if (order.status !== OrderStatus.DELIVERED) {
      throw new BadRequestException('يمكن طلب التعديل فقط بعد تسليم النتيجة وقبل التأكيد');
    }

    order.status = OrderStatus.REVISION_REQUESTED;
    order.revisionNotes = revisionNotes;

    order.timeline.push({
      action: 'revision_requested',
      title: 'طلب العميل تعديل على الخدمة',
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
      message: `[طلب تعديل]: ${revisionNotes}`,
      isSensitive: false,
      createdAt: new Date(),
    });

    await order.save();

    // Notify supervisor
    if (order.assignedSupervisorId) {
      await this.notificationsService.createNotification({
        userId: (order.assignedSupervisorId as any)._id?.toString() || order.assignedSupervisorId.toString(),
        forRole: 'supervisor',
        title: 'طلب تعديل من العميل 🔄',
        body: `طلب العميل تعديلاً على الطلب #${order.orderNumber}: ${revisionNotes}`,
        type: 'revision_requested',
        data: { orderId: order._id.toString(), revisionNotes },
      });
    }

    return { message: 'تم إرسال طلب التعديل للمشرف بنجاح', order };
  }

  // Customer opens dispute / objection
  async customerOpenDispute(orderId: string, user: UserDocument, disputeReason: string) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name');
    if (!order) throw new NotFoundException('الطلب غير موجود');

    if (order.userId.toString() !== user._id.toString()) {
      throw new ForbiddenException('لا تملك صلاحية فتح اعتراض');
    }

    if (order.status === OrderStatus.COMPLETED || order.status === OrderStatus.REFUNDED) {
      throw new BadRequestException('لا يمكن فتح اعتراض على طلب منتهي أو مسترجع');
    }

    order.status = OrderStatus.DISPUTED;
    order.disputeReason = disputeReason;

    order.timeline.push({
      action: 'disputed',
      title: 'فتح العميل اعتراضاً رسمياً على الطلب',
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
      message: `[اعتراض رسمي]: ${disputeReason}`,
      isSensitive: false,
      createdAt: new Date(),
    });

    await order.save();

    // Notify Admin & Supervisor urgently
    await this.notificationsService.createNotification({
      forRole: 'admin',
      title: 'اعتراض مفتوح على طلب 🚨',
      body: `فتح العميل ${user.name} اعتراضاً على الطلب #${order.orderNumber}. السبب: ${disputeReason}`,
      type: 'order_disputed',
      data: { orderId: order._id.toString(), disputeReason },
    });

    if (order.assignedSupervisorId) {
      await this.notificationsService.createNotification({
        userId: order.assignedSupervisorId.toString(),
        forRole: 'supervisor',
        title: 'تنبيه: العميل فتح اعتراضاً على الطلب 🚨',
        body: `طلب #${order.orderNumber}: ${disputeReason}`,
        type: 'order_disputed',
        data: { orderId: order._id.toString(), disputeReason },
      });
    }

    return { message: 'تم فتح الاعتراض وسيتدخل فريق الإدارة للمراجعة وحل المشكلة', order };
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
    if (!order) throw new NotFoundException('الطلب غير موجود');

    const newSupervisor = await this.userModel.findById(newSupervisorId);
    if (!newSupervisor || newSupervisor.isActive === false) {
      throw new BadRequestException('المستخدم المختار غير صالح');
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
      title: `قام الأدمن بإعادة إسناد الطلب إلى المشرف ${newSupervisor.name}`,
      description: reason ? `السبب: ${reason}` : 'إعادة إسناد من قبل الإدارة',
      performerId: admin._id,
      performerName: admin.name,
      performerRole: 'admin',
      timestamp: new Date(),
    });

    await order.save();

    // مزامنة الرتب: المشرف الجديد يُرقّى، والسابق يعود عميلاً إن لم يبقَ لديه أي إسناد
    if (previousSupervisorId && previousSupervisorId.toString() !== newSupervisor._id.toString()) {
      await this.usersService.reconcileSupervisorRole(previousSupervisorId);
    }
    await this.usersService.reconcileSupervisorRole(newSupervisor._id);

    // Notify new supervisor
    await this.notificationsService.createNotification({
      userId: newSupervisor._id.toString(),
      forRole: 'supervisor',
      title: 'طلب يدوي مسند إليك من الإدارة 🔔',
      body: `تم إسناد الطلب #${order.orderNumber} لخدمة ${(order.productId as any)?.name} إليك من قبل الإدارة.`,
      type: 'manual_service_assigned',
      data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
    });

    return { message: `تم إعادة إسناد الطلب للمشرف ${newSupervisor.name} بنجاح`, order };
  }

  // Admin executes instant refund to customer's wallet
  async adminRefundOrder(orderId: string, admin: UserDocument, reason: string) {
    // انتقال ذري للحالة: يرفض أي تكرار بنقرتين متزامنتين بدل read-modify-write (H6)
    const order = await this.orderModel
      .findOneAndUpdate(
        { _id: orderId, status: { $ne: OrderStatus.REFUNDED } },
        {
          $set: {
            status: OrderStatus.REFUNDED,
            adminNotes: reason || 'استرجاع مالي للرصيد من قبل الإدارة',
          },
        },
        { new: true },
      )
      .populate('userId');
    if (!order) {
      const existing = await this.orderModel.findById(orderId);
      if (!existing) throw new NotFoundException('الطلب غير موجود');
      throw new BadRequestException('هذا الطلب تم استرجاعه مسبقاً');
    }

    // إرجاع ذري للمال؛ مستخدم محذوف ⇒ تنبيه الإدارة بدل تعليم الطلب مسترجعاً بلا مال (H6)
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
          description: `استرجاع رصيد لطلب ملغي #${order.orderNumber}`,
          referenceType: 'Order',
          referenceId: order._id.toString(),
          status: TransactionStatus.COMPLETED,
        });
      } catch (ledgerErr: any) {
        this.logger.error(`Admin refund ledger entry failed for ${order.orderNumber}: ${ledgerErr.message}`);
        await this.notifyAdminsSafe(
          'تنبيه دفتر: استرجاع إداري غير مسجل',
          `أُرجع $${order.amount.toFixed(2)} للعميل في الطلب #${order.orderNumber} من الإدارة لكن تسجيل الحركة فشل؛ يلزم مراجعة الدفتر.`,
        );
      }
    } else {
      this.logger.error(`Admin refund for ${order.orderNumber}: customer account not found, funds not credited`);
      await this.notifyAdminsSafe(
        'تنبيه مالي: استرجاع إداري لعميل غير موجود',
        `الطلب #${order.orderNumber} ($${order.amount.toFixed(2)}) استُرجع لكن حساب العميل لم يُوجد؛ يلزم تعويض يدوي.`,
      );
    }

    order.timeline.push({
      action: 'refunded',
      title: 'تم إلغاء الطلب واسترجاع المبلغ للعميل',
      description: `قام الأدمن ${admin.name} باسترجاع $${order.amount.toFixed(2)} لمحفظة العميل. السبب: ${reason}`,
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
        title: 'تم استرجاع رصيد طلبك لمحفظتك 💰',
        body: `تم استرجاع مبلغ $${order.amount.toFixed(2)} للطلب #${order.orderNumber} إلى محفظتك بنجاح. السبب: ${reason}`,
        type: 'order_refunded',
        data: { orderId: order._id.toString(), amount: order.amount, reason },
      })
      .catch((err: any) => this.logger.warn(`Refund notification failed: ${err.message}`));

    return { message: 'تم استرجاع المبلغ لمحفظة العميل وإلغاء الطلب بنجاح', order };
  }

  // --- 6. Order Messages & Secure Credentials ---
  // Get chat messages for an order
  async getOrderMessages(orderId: string, user: UserDocument) {
    const order = await this.orderModel.findById(orderId).select('chatMessages userId assignedSupervisorId');
    if (!order) throw new NotFoundException('الطلب غير موجود');

    // Access check: buyer, assigned supervisor, or admin
    const isBuyer = order.userId.toString() === user._id.toString();
    const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
    const isAdmin = user.role === 'admin';

    if (!isBuyer && !isSupervisor && !isAdmin) {
      throw new ForbiddenException('لا تملك صلاحية عرض رسائل هذا الطلب');
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
    },
  ) {
    const order = await this.orderModel.findById(orderId).populate('productId', 'name');
    if (!order) throw new NotFoundException('الطلب غير موجود');

    const isBuyer = order.userId.toString() === user._id.toString();
    const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
    const isAdmin = user.role === 'admin';

    if (!isBuyer && !isSupervisor && !isAdmin) {
      throw new ForbiddenException('لا تملك صلاحية إرسال رسائل في هذا الطلب');
    }

    const senderRole = isAdmin ? 'admin' : isSupervisor ? 'supervisor' : 'user';

    const newMessage: OrderChatMessage = {
      senderId: user._id,
      senderName: user.name,
      senderRole,
      message: data.message || '',
      attachmentUrl: data.attachmentUrl,
      attachmentName: data.attachmentName,
      attachmentType: data.attachmentType,
      isSensitive: data.isSensitive || false,
      createdAt: new Date(),
    };

    order.chatMessages.push(newMessage);
    await order.save();

    // Determine recipient for notification
    if (isBuyer && order.assignedSupervisorId) {
      await this.notificationsService.createNotification({
        userId: order.assignedSupervisorId.toString(),
        forRole: 'supervisor',
        title: `رسالة جديدة من العميل حول طلب #${order.orderNumber} 💬`,
        body: data.message ? (data.message.length > 80 ? `${data.message.slice(0, 80)}...` : data.message) : 'أرسل العميل مرفقاً',
        type: 'order_chat',
        data: { orderId: order._id.toString() },
      });
    } else if (isSupervisor || isAdmin) {
      await this.notificationsService.createNotification({
        userId: order.userId.toString(),
        title: `رسالة جديدة من ${user.name} حول طلبك #${order.orderNumber} 💬`,
        body: data.message ? (data.message.length > 80 ? `${data.message.slice(0, 80)}...` : data.message) : 'تم إرسال مرفق جديد',
        type: 'order_chat',
        data: { orderId: order._id.toString() },
      });
    }

    return newMessage;
  }

  // Securely decrypt and return sensitive result credentials for authorized viewer
  async getOrderDecryptedResult(orderId: string, user: UserDocument) {
    const order = await this.orderModel.findById(orderId);
    if (!order) throw new NotFoundException('الطلب غير موجود');

    const isBuyer = order.userId.toString() === user._id.toString();
    const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
    const isAdmin = user.role === 'admin';

    if (!isBuyer && !isSupervisor && !isAdmin) {
      throw new ForbiddenException('غير مصرح لك باستعراض بيانات هذا الطلب');
    }

    if (order.isResultPurged) {
      return {
        isPurged: true,
        purgedAt: order.purgedAt,
        message: 'تم حذف البيانات السرية تلقائياً بعد تأكيد الاستلام لحماية أمان حسابك',
        credentials: null,
      };
    }

    if (!order.encryptedResultData) {
      return {
        isPurged: false,
        credentials: null,
        message: 'لا توجد بيانات سرية مشفرة مسجلة في هذا الطلب',
      };
    }

    const decrypted = CryptoUtil.decrypt(order.encryptedResultData);
    return {
      isPurged: false,
      credentials: decrypted,
    };
  }

  // يفك تشفير مدخلات العميل (accountInput) للمشرف المسند أو الأدمن فقط
  async getOrderDecryptedInput(orderId: string, user: UserDocument) {
    const order = await this.orderModel.findById(orderId);
    if (!order) throw new NotFoundException('الطلب غير موجود');

    const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
    const isAdmin = user.role === 'admin';

    if (!isSupervisor && !isAdmin) {
      throw new ForbiddenException('غير مصرح لك باستعراض بيانات هذا الطلب');
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
    order.adminNotes = notes || 'تم الشحن بنجاح';
    order.completedAt = new Date();
    await order.save();
    return { message: 'تم قبول الطلب بنجاح', order };
  }

  async rejectManualOrder(id: string, notes: string) {
    const order = await this.getOrderById(id);
    order.status = OrderStatus.REJECTED;
    order.adminNotes = notes || 'تم رفض الطلب';
    await order.save();
    return { message: 'تم رفض الطلب بنجاح', order };
  }
}
