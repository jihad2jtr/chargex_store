import { Injectable, BadRequestException, NotFoundException, ForbiddenException, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import * as crypto from 'crypto';
import { Order, OrderDocument, OrderStatus, OrderTimelineEvent, OrderChatMessage } from '../../database/schemas/order.schema';
import { Product, ProductDocument, ProductType } from '../../database/schemas/product.schema';
import { App, AppDocument } from '../../database/schemas/app.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { WalletTransaction, WalletTransactionDocument, TransactionType, TransactionStatus } from '../../database/schemas/wallet-transaction.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { ProvidersService } from '../providers/providers.service';
import { CryptoUtil } from '../../common/utils/crypto.util';

@Injectable()
export class OrdersService {
  private readonly logger = new Logger(OrdersService.name);

  constructor(
    @InjectModel(Order.name) private orderModel: Model<OrderDocument>,
    @InjectModel(Product.name) private productModel: Model<ProductDocument>,
    @InjectModel(App.name) private appModel: Model<AppDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(WalletTransaction.name) private transactionModel: Model<WalletTransactionDocument>,
    private notificationsService: NotificationsService,
    private providersService: ProvidersService,
  ) {}

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
  }) {
    const user = await this.userModel.findById(params.userId);
    if (!user) throw new NotFoundException('المستخدم غير موجود');

    const product = await this.productModel.findById(params.productId);
    if (!product || !product.isActive) {
      throw new BadRequestException('المنتج غير متاح حالياً');
    }

    const app = await this.appModel.findById(product.appId);
    if (!app || !app.isActive) {
      throw new BadRequestException('هذه الخدمة معطلة حالياً');
    }

    const price = product.salePrice;
    if (user.balance < price) {
      throw new BadRequestException(
        `رصيدك غير كافٍ. المبلغ المطلوب: $${price.toFixed(2)}، رصيدك الحالي: $${user.balance.toFixed(2)}`,
      );
    }

    // Process specific product type logic
    let deliveredCode: string | undefined = undefined;
    let initialStatus = OrderStatus.PENDING;
    const estimatedMinutes = product.estimatedMinutes || 120;
    const deadlineAt = new Date(Date.now() + estimatedMinutes * 60 * 1000);
    const timeline: OrderTimelineEvent[] = [];

    // Deduct user balance
    const balanceBefore = user.balance;
    const balanceAfter = Number((balanceBefore - price).toFixed(2));
    user.balance = balanceAfter;
    await user.save();

    const orderNumber = this.generateOrderNumber();
    const profit = Number((price - product.costPrice).toFixed(2));

    // Handle Sensitive Fields in Customer Input
    const sanitizedInput: Record<string, any> = { ...(params.accountInput || {}) };
    if (product.isSensitive && product.sensitiveFields && product.sensitiveFields.length > 0) {
      for (const field of product.sensitiveFields) {
        if (sanitizedInput[field]) {
          sanitizedInput[field] = CryptoUtil.encrypt(sanitizedInput[field]);
        }
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

    let assignedSupervisorId: Types.ObjectId | undefined = undefined;
    let assignedSupervisorUser: UserDocument | null = null;

    if (product.type === ProductType.CODES) {
      if (!product.inventoryCodes || product.inventoryCodes.length === 0) {
        // Rollback balance if inventory empty
        user.balance = balanceBefore;
        await user.save();
        throw new BadRequestException('عذراً، هذا المنتج غير متوفر في المخزون حالياً');
      }
      deliveredCode = product.inventoryCodes.shift();
      await product.save();
      initialStatus = OrderStatus.COMPLETED;

      timeline.push({
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
          // Rollback customer balance
          user.balance = balanceBefore;
          await user.save();
          throw new BadRequestException('يرجى إدخال معرف اللاعب (Player ID) المطلوب للشحن');
        }

        const providerResult = await this.providersService.executeOrder(product.providerId.toString(), {
          productCode: product.providerProductCode || '',
          gameUserId: String(gameUserId),
          gameZoneId: gameZoneId ? String(gameZoneId) : undefined,
          reference: orderNumber,
        });

        if (!providerResult.success) {
          // Rollback customer balance so no funds are deducted
          user.balance = balanceBefore;
          await user.save();
          this.logger.error(`Provider direct execution failed for ${orderNumber}: ${providerResult.message}`);
          throw new BadRequestException(`تعذر إتمام الشحن عبر المزود: ${providerResult.message}`);
        }

        initialStatus = OrderStatus.COMPLETED;
        timeline.push({
          action: 'delivered',
          title: 'تم تنفيذ الشحن عبر المزود الآلي بنجاح',
          description: `تم إرسال الطلب وتنفيذه بنجاح عبر مزود الخدمة (المرجع: ${providerResult.transactionId || orderNumber})`,
          performerName: 'النظام الآلي (API)',
          performerRole: 'system',
          timestamp: new Date(),
        });
      } else {
        initialStatus = OrderStatus.COMPLETED;
        timeline.push({
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

        timeline.push({
          action: 'assigned',
          title: `تم إسناد الطلب للمشرف (${assignedSupervisorUser?.name || 'المشرف المسؤول'})`,
          description: `تم إسناد الطلب تلقائياً، والوقت المتوقع للتنفيذ: ${estimatedMinutes} دقيقة`,
          performerName: 'النظام الآلي',
          performerRole: 'system',
          timestamp: new Date(),
        });
      } else {
        initialStatus = OrderStatus.PENDING;
        timeline.push({
          action: 'pending_assignment',
          title: 'بانتظار إسناد المشرف',
          description: 'الطلب بانتظار قيام الإدارة بتعيين مشرف للتنفيذ',
          performerName: 'النظام',
          performerRole: 'system',
          timestamp: new Date(),
        });
      }
    }

    const order = new this.orderModel({
      orderNumber,
      userId: user._id,
      appId: app._id,
      productId: product._id,
      providerId: product.providerId,
      type: product.type,
      amount: price,
      cost: product.costPrice,
      profit,
      status: initialStatus,
      accountInput: sanitizedInput,
      deliveredCode,
      completedAt: initialStatus === OrderStatus.COMPLETED ? new Date() : undefined,
      assignedSupervisorId,
      estimatedMinutes,
      deadlineAt,
      isSensitive: product.isSensitive || false,
      sensitiveFields: product.sensitiveFields || [],
      timeline,
      chatMessages: [],
    });
    await order.save();

    // Record wallet transaction
    const transaction = new this.transactionModel({
      userId: user._id,
      type: TransactionType.PURCHASE,
      amount: -price,
      balanceBefore,
      balanceAfter,
      description: `شراء ${product.name} (${app.name})`,
      referenceType: 'Order',
      referenceId: order._id.toString(),
      status: TransactionStatus.COMPLETED,
    });
    await transaction.save();

    // Notify Supervisor if assigned
    if (assignedSupervisorId && assignedSupervisorUser) {
      await this.notificationsService.createNotification({
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
      });
    }

    // Notify Admins of new order
    await this.notificationsService.createNotification({
      forRole: 'admin',
      title: 'طلب جديد 🛒',
      body: `طلب جديد رقم #${orderNumber} لخدمة ${product.name} بمبلغ $${price.toFixed(2)}`,
      type: 'new_order',
      data: { orderId: order._id.toString(), orderNumber },
    });

    // Notify User if completed immediately
    if (initialStatus === OrderStatus.COMPLETED) {
      await this.notificationsService.createNotification({
        userId: user._id.toString(),
        title: 'تم تنفيذ طلبك بنجاح ✅',
        body:
          product.type === ProductType.CODES
            ? `تم استلام كود باقة ${product.name}: ${deliveredCode}`
            : `تم تنفيذ شحن باقة ${product.name} لحسابك بنجاح`,
        type: 'order_status',
        data: { orderId: order._id.toString(), deliveredCode },
      });
    }

    return {
      message:
        initialStatus === OrderStatus.COMPLETED
          ? 'تم تنفيذ الطلب بنجاح'
          : initialStatus === OrderStatus.ASSIGNED
          ? 'تم استلام طلبك وجاري تحويله للمشرف المختص لبدء التنفيذ'
          : 'تم إرسال طلب الشحن بنجاح وهو قيد المراجعة',
      order: await this.getOrderById(order._id.toString()),
      newBalance: user.balance,
      deliveredCode,
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
      .populate('productId', 'name type costPrice salePrice isSensitive instructions')
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
      .populate('productId', 'name type costPrice salePrice isSensitive instructions')
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
      .populate('userId', 'name email phone balance userId')
      .populate('appId', 'name iconUrl')
      .populate('productId', 'name type costPrice salePrice isSensitive')
      .populate('assignedSupervisorId', 'name email phone role userId')
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
    if (!newSupervisor || (newSupervisor.role !== 'supervisor' && newSupervisor.role !== 'admin')) {
      throw new BadRequestException('المشرف المختار غير صالح');
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
    const order = await this.orderModel.findById(orderId).populate('userId');
    if (!order) throw new NotFoundException('الطلب غير موجود');

    if (order.status === OrderStatus.REFUNDED) {
      throw new BadRequestException('هذا الطلب تم استرجاعه مسبقاً');
    }

    order.status = OrderStatus.REFUNDED;
    order.adminNotes = reason || 'استرجاع مالي للرصيد من قبل الإدارة';

    // Credit user wallet
    const customer = await this.userModel.findById(order.userId);
    if (customer) {
      const balanceBefore = customer.balance;
      const balanceAfter = Number((balanceBefore + order.amount).toFixed(2));
      customer.balance = balanceAfter;
      await customer.save();

      // Record refund transaction
      const refundTrans = new this.transactionModel({
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
      await refundTrans.save();
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
    await this.notificationsService.createNotification({
      userId: order.userId.toString(),
      title: 'تم استرجاع رصيد طلبك لمحفظتك 💰',
      body: `تم استرجاع مبلغ $${order.amount.toFixed(2)} للطلب #${order.orderNumber} إلى محفظتك بنجاح. السبب: ${reason}`,
      type: 'order_refunded',
      data: { orderId: order._id.toString(), amount: order.amount, reason },
    });

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
