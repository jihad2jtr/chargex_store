"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var OrdersService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrdersService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const crypto = __importStar(require("crypto"));
const order_schema_1 = require("../../database/schemas/order.schema");
const product_schema_1 = require("../../database/schemas/product.schema");
const app_schema_1 = require("../../database/schemas/app.schema");
const user_schema_1 = require("../../database/schemas/user.schema");
const wallet_transaction_schema_1 = require("../../database/schemas/wallet-transaction.schema");
const notifications_service_1 = require("../notifications/notifications.service");
const providers_service_1 = require("../providers/providers.service");
const crypto_util_1 = require("../../common/utils/crypto.util");
let OrdersService = OrdersService_1 = class OrdersService {
    constructor(orderModel, productModel, appModel, userModel, transactionModel, notificationsService, providersService) {
        this.orderModel = orderModel;
        this.productModel = productModel;
        this.appModel = appModel;
        this.userModel = userModel;
        this.transactionModel = transactionModel;
        this.notificationsService = notificationsService;
        this.providersService = providersService;
        this.logger = new common_1.Logger(OrdersService_1.name);
    }
    generateOrderNumber() {
        const timestamp = new Date().toISOString().slice(0, 10).replace(/-/g, '');
        const rand = crypto.randomBytes(3).toString('hex').toUpperCase();
        return `ORD-${timestamp}-${rand}`;
    }
    async createOrder(params) {
        const user = await this.userModel.findById(params.userId);
        if (!user)
            throw new common_1.NotFoundException('المستخدم غير موجود');
        const product = await this.productModel.findById(params.productId);
        if (!product || !product.isActive) {
            throw new common_1.BadRequestException('المنتج غير متاح حالياً');
        }
        const app = await this.appModel.findById(product.appId);
        if (!app || !app.isActive) {
            throw new common_1.BadRequestException('هذه الخدمة معطلة حالياً');
        }
        const price = product.salePrice;
        if (user.balance < price) {
            throw new common_1.BadRequestException(`رصيدك غير كافٍ. المبلغ المطلوب: $${price.toFixed(2)}، رصيدك الحالي: $${user.balance.toFixed(2)}`);
        }
        let deliveredCode = undefined;
        let initialStatus = order_schema_1.OrderStatus.PENDING;
        const estimatedMinutes = product.estimatedMinutes || 120;
        const deadlineAt = new Date(Date.now() + estimatedMinutes * 60 * 1000);
        const timeline = [];
        const balanceBefore = user.balance;
        const balanceAfter = Number((balanceBefore - price).toFixed(2));
        user.balance = balanceAfter;
        await user.save();
        const orderNumber = this.generateOrderNumber();
        const profit = Number((price - product.costPrice).toFixed(2));
        const sanitizedInput = { ...(params.accountInput || {}) };
        if (product.isSensitive && product.sensitiveFields && product.sensitiveFields.length > 0) {
            for (const field of product.sensitiveFields) {
                if (sanitizedInput[field]) {
                    sanitizedInput[field] = crypto_util_1.CryptoUtil.encrypt(sanitizedInput[field]);
                }
            }
        }
        timeline.push({
            action: 'created_paid',
            title: 'تم إنشاء الطلب ودفع القيمة',
            description: `تم خصم $${price.toFixed(2)} من محفظة العميل للخدمة: ${product.name}`,
            performerId: user._id,
            performerName: user.name,
            performerRole: 'customer',
            timestamp: new Date(),
        });
        let assignedSupervisorId = undefined;
        let assignedSupervisorUser = null;
        if (product.type === product_schema_1.ProductType.CODES) {
            if (!product.inventoryCodes || product.inventoryCodes.length === 0) {
                user.balance = balanceBefore;
                await user.save();
                throw new common_1.BadRequestException('عذراً، هذا المنتج غير متوفر في المخزون حالياً');
            }
            deliveredCode = product.inventoryCodes.shift();
            await product.save();
            initialStatus = order_schema_1.OrderStatus.COMPLETED;
            timeline.push({
                action: 'delivered',
                title: 'تم تسليم الكود تلقائياً',
                description: 'تم تسليم كود البطاقة للعميل مباشرة من المخزون',
                performerName: 'النظام الآلي',
                performerRole: 'system',
                timestamp: new Date(),
            });
        }
        else if (product.type === product_schema_1.ProductType.DIRECT_API) {
            if (product.providerId) {
                const rawInput = params.accountInput || {};
                const gameUserId = rawInput['Player ID'] ||
                    rawInput['User ID'] ||
                    rawInput['المعرف'] ||
                    rawInput['ID'] ||
                    rawInput['userid'] ||
                    rawInput['playerId'] ||
                    Object.values(rawInput)[0];
                const gameZoneId = rawInput['Zone ID'] ||
                    rawInput['Server ID'] ||
                    rawInput['Server/Zone ID'] ||
                    rawInput['السيرفر'] ||
                    rawInput['serverid'] ||
                    rawInput['zoneId'] ||
                    (Object.values(rawInput).length > 1 ? Object.values(rawInput)[1] : undefined);
                if (!gameUserId) {
                    user.balance = balanceBefore;
                    await user.save();
                    throw new common_1.BadRequestException('يرجى إدخال معرف اللاعب (Player ID) المطلوب للشحن');
                }
                const providerResult = await this.providersService.executeOrder(product.providerId.toString(), {
                    productCode: product.providerProductCode || '',
                    gameUserId: String(gameUserId),
                    gameZoneId: gameZoneId ? String(gameZoneId) : undefined,
                    reference: orderNumber,
                });
                if (!providerResult.success) {
                    user.balance = balanceBefore;
                    await user.save();
                    this.logger.error(`Provider direct execution failed for ${orderNumber}: ${providerResult.message}`);
                    throw new common_1.BadRequestException(`تعذر إتمام الشحن عبر المزود: ${providerResult.message}`);
                }
                initialStatus = order_schema_1.OrderStatus.COMPLETED;
                timeline.push({
                    action: 'delivered',
                    title: 'تم تنفيذ الشحن عبر المزود الآلي بنجاح',
                    description: `تم إرسال الطلب وتنفيذه بنجاح عبر مزود الخدمة (المرجع: ${providerResult.transactionId || orderNumber})`,
                    performerName: 'النظام الآلي (API)',
                    performerRole: 'system',
                    timestamp: new Date(),
                });
            }
            else {
                initialStatus = order_schema_1.OrderStatus.COMPLETED;
                timeline.push({
                    action: 'delivered',
                    title: 'تم تنفيذ الشحن عبر المزود الآلي',
                    description: 'تم إرسال الشحن وتنفيذه بنجاح عبر مزود الخدمة',
                    performerName: 'النظام الآلي',
                    performerRole: 'system',
                    timestamp: new Date(),
                });
            }
        }
        else if (product.type === product_schema_1.ProductType.MANUAL) {
            if (product.assignedSupervisorId) {
                assignedSupervisorId = product.assignedSupervisorId;
                assignedSupervisorUser = await this.userModel.findById(assignedSupervisorId);
                initialStatus = order_schema_1.OrderStatus.ASSIGNED;
                timeline.push({
                    action: 'assigned',
                    title: `تم إسناد الطلب للمشرف (${assignedSupervisorUser?.name || 'المشرف المسؤول'})`,
                    description: `تم إسناد الطلب تلقائياً، والوقت المتوقع للتنفيذ: ${estimatedMinutes} دقيقة`,
                    performerName: 'النظام الآلي',
                    performerRole: 'system',
                    timestamp: new Date(),
                });
            }
            else {
                initialStatus = order_schema_1.OrderStatus.PENDING;
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
            completedAt: initialStatus === order_schema_1.OrderStatus.COMPLETED ? new Date() : undefined,
            assignedSupervisorId,
            estimatedMinutes,
            deadlineAt,
            isSensitive: product.isSensitive || false,
            sensitiveFields: product.sensitiveFields || [],
            timeline,
            chatMessages: [],
        });
        await order.save();
        const transaction = new this.transactionModel({
            userId: user._id,
            type: wallet_transaction_schema_1.TransactionType.PURCHASE,
            amount: -price,
            balanceBefore,
            balanceAfter,
            description: `شراء ${product.name} (${app.name})`,
            referenceType: 'Order',
            referenceId: order._id.toString(),
            status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
        });
        await transaction.save();
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
        await this.notificationsService.createNotification({
            forRole: 'admin',
            title: 'طلب جديد 🛒',
            body: `طلب جديد رقم #${orderNumber} لخدمة ${product.name} بمبلغ $${price.toFixed(2)}`,
            type: 'new_order',
            data: { orderId: order._id.toString(), orderNumber },
        });
        if (initialStatus === order_schema_1.OrderStatus.COMPLETED) {
            await this.notificationsService.createNotification({
                userId: user._id.toString(),
                title: 'تم تنفيذ طلبك بنجاح ✅',
                body: product.type === product_schema_1.ProductType.CODES
                    ? `تم استلام كود باقة ${product.name}: ${deliveredCode}`
                    : `تم تنفيذ شحن باقة ${product.name} لحسابك بنجاح`,
                type: 'order_status',
                data: { orderId: order._id.toString(), deliveredCode },
            });
        }
        return {
            message: initialStatus === order_schema_1.OrderStatus.COMPLETED
                ? 'تم تنفيذ الطلب بنجاح'
                : initialStatus === order_schema_1.OrderStatus.ASSIGNED
                    ? 'تم استلام طلبك وجاري تحويله للمشرف المختص لبدء التنفيذ'
                    : 'تم إرسال طلب الشحن بنجاح وهو قيد المراجعة',
            order: await this.getOrderById(order._id.toString()),
            newBalance: user.balance,
            deliveredCode,
        };
    }
    async getMyOrders(userId) {
        return this.orderModel
            .find({ userId: new mongoose_2.Types.ObjectId(userId) })
            .populate('appId', 'name iconUrl')
            .populate('productId', 'name type costPrice salePrice isSensitive')
            .populate('assignedSupervisorId', 'name email phone role')
            .sort({ createdAt: -1 });
    }
    async getOrderById(id) {
        const order = await this.orderModel
            .findById(id)
            .populate('userId', 'name email phone balance userId')
            .populate('appId', 'name iconUrl')
            .populate('productId', 'name type costPrice salePrice isSensitive instructions')
            .populate('assignedSupervisorId', 'name email phone role userId');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        return order;
    }
    async getSupervisorOrders(supervisorId, filter) {
        const query = { assignedSupervisorId: new mongoose_2.Types.ObjectId(supervisorId) };
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
            const isDelayed = o.deadlineAt &&
                now > o.deadlineAt &&
                o.status !== order_schema_1.OrderStatus.COMPLETED &&
                o.status !== order_schema_1.OrderStatus.REFUNDED;
            return {
                ...obj,
                isDelayed,
            };
        });
    }
    async getAllOrdersAdmin(filter) {
        const query = {};
        if (filter?.status && filter.status !== 'all')
            query.status = filter.status;
        if (filter?.type)
            query.type = filter.type;
        if (filter?.supervisorId)
            query.assignedSupervisorId = new mongoose_2.Types.ObjectId(filter.supervisorId);
        if (filter?.isDelayed) {
            query.deadlineAt = { $lt: new Date() };
            query.status = { $nin: [order_schema_1.OrderStatus.COMPLETED, order_schema_1.OrderStatus.REFUNDED] };
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
            const isDelayed = o.deadlineAt &&
                now > o.deadlineAt &&
                o.status !== order_schema_1.OrderStatus.COMPLETED &&
                o.status !== order_schema_1.OrderStatus.REFUNDED;
            return {
                ...obj,
                isDelayed,
            };
        });
    }
    async supervisorAcceptOrder(orderId, supervisor) {
        const order = await this.orderModel.findById(orderId).populate('productId', 'name');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        if (order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
            supervisor.role !== 'admin') {
            throw new common_1.ForbiddenException('هذا الطلب غير مسند إليك');
        }
        if (order.status !== order_schema_1.OrderStatus.ASSIGNED && order.status !== order_schema_1.OrderStatus.PENDING) {
            throw new common_1.BadRequestException('لا يمكن قبول الطلب في حالته الحالية');
        }
        order.status = order_schema_1.OrderStatus.ACCEPTED;
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
        await this.notificationsService.createNotification({
            userId: order.userId.toString(),
            title: 'تم قبول طلبك من قبل المشرف 👨‍💻',
            body: `قبل المشرف طلبك #${order.orderNumber} لخدمة ${order.productId?.name || 'الخدمة'} وجاري البدء.`,
            type: 'order_status',
            data: { orderId: order._id.toString(), status: 'accepted' },
        });
        return { message: 'تم قبول الطلب بنجاح', order };
    }
    async supervisorRejectOrder(orderId, supervisor, reason) {
        const order = await this.orderModel.findById(orderId).populate('productId', 'name');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        if (order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
            supervisor.role !== 'admin') {
            throw new common_1.ForbiddenException('هذا الطلب غير مسند إليك');
        }
        if (order.status === order_schema_1.OrderStatus.COMPLETED || order.status === order_schema_1.OrderStatus.REFUNDED) {
            throw new common_1.BadRequestException('لا يمكن رفض طلب منتهي أو مسترجع');
        }
        order.status = order_schema_1.OrderStatus.REJECTED;
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
        await this.notificationsService.createNotification({
            forRole: 'admin',
            title: 'تنبيه: رفض طلب يدوي من المشرف ⚠️',
            body: `اعتذر المشرف ${supervisor.name} عن تنفيذ الطلب #${order.orderNumber}. السبب: ${reason}. يرجى إعادة الإسناد لمشرف آخر.`,
            type: 'manual_order_rejected',
            data: { orderId: order._id.toString(), orderNumber: order.orderNumber, reason },
        });
        return { message: 'تم تسجيل اعتذار المشرف وسيتم إشعار الإدارة لإعادة الإسناد', order };
    }
    async supervisorStartOrder(orderId, supervisor) {
        const order = await this.orderModel.findById(orderId).populate('productId', 'name');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        if (order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
            supervisor.role !== 'admin') {
            throw new common_1.ForbiddenException('هذا الطلب غير مسند إليك');
        }
        order.status = order_schema_1.OrderStatus.IN_PROGRESS;
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
        await this.notificationsService.createNotification({
            userId: order.userId.toString(),
            title: 'طلبك قيد التنفيذ الآن ⚙️',
            body: `بدأ المشرف في تنفيذ وتجهيز طلبك #${order.orderNumber}.`,
            type: 'order_status',
            data: { orderId: order._id.toString(), status: 'in_progress' },
        });
        return { message: 'تم بدء تنفيذ الطلب بنجاح', order };
    }
    async supervisorRequestInfo(orderId, supervisor, data) {
        const order = await this.orderModel.findById(orderId).populate('productId', 'name');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        if (order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
            supervisor.role !== 'admin') {
            throw new common_1.ForbiddenException('هذا الطلب غير مسند إليك');
        }
        order.status = order_schema_1.OrderStatus.INFO_REQUESTED;
        order.timeline.push({
            action: 'info_requested',
            title: 'طلب المشرف معلومات إضافية',
            description: data.note,
            performerId: supervisor._id,
            performerName: supervisor.name,
            performerRole: 'supervisor',
            timestamp: new Date(),
        });
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
        await this.notificationsService.createNotification({
            userId: order.userId.toString(),
            title: 'المشرف يطلب معلومات إضافية حول طلبك 💬',
            body: data.note,
            type: 'order_chat',
            data: { orderId: order._id.toString(), note: data.note },
        });
        return { message: 'تم إرسال طلب المعلومات للعميل', order };
    }
    async supervisorDeliverOrder(orderId, supervisor, data) {
        const order = await this.orderModel.findById(orderId).populate('productId', 'name isSensitive');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        if (order.assignedSupervisorId?.toString() !== supervisor._id.toString() &&
            supervisor.role !== 'admin') {
            throw new common_1.ForbiddenException('هذا الطلب غير مسند إليك');
        }
        order.status = order_schema_1.OrderStatus.DELIVERED;
        order.deliveredAt = new Date();
        order.resultNotes = data.resultNotes || 'تم تنفيذ الخدمة بنجاح، يرجى مراجعة التفاصيل وتأكيد الاستلام';
        order.resultAttachments = data.attachments || [];
        if (data.credentials && Object.keys(data.credentials).length > 0) {
            order.encryptedResultData = crypto_util_1.CryptoUtil.encrypt(data.credentials);
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
        await this.notificationsService.createNotification({
            userId: order.userId.toString(),
            title: 'تم تسليم طلبك بنجاح! يرجى المراجعة والتأكيد 🎉',
            body: `انتهى المشرف من تنفيذ طلبك #${order.orderNumber}. يرجى الدخول لمراجعة تفاصيل النتيجة وتأكيد الاستلام.`,
            type: 'order_delivered',
            data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
        });
        return { message: 'تم تسليم النتيجة للعميل بنجاح وبانتظار تأكيده', order };
    }
    async customerConfirmOrder(orderId, user) {
        const order = await this.orderModel
            .findById(orderId)
            .populate('productId', 'name')
            .populate('assignedSupervisorId', 'name');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        if (order.userId.toString() !== user._id.toString()) {
            throw new common_1.ForbiddenException('لا تملك صلاحية تأكيد هذا الطلب');
        }
        if (order.status !== order_schema_1.OrderStatus.DELIVERED) {
            throw new common_1.BadRequestException('لا يمكن تأكيد الطلب قبل تسليمه من المشرف');
        }
        order.status = order_schema_1.OrderStatus.COMPLETED;
        order.completedAt = new Date();
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
        if (order.assignedSupervisorId) {
            await this.notificationsService.createNotification({
                userId: order.assignedSupervisorId._id?.toString() || order.assignedSupervisorId.toString(),
                forRole: 'supervisor',
                title: 'تم تأكيد استلام الطلب من العميل ✅',
                body: `قام العميل بتأكيد استلام الطلب #${order.orderNumber} لخدمة ${order.productId?.name} وتم إغلاق الطلب بنجاح.`,
                type: 'order_confirmed',
                data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
            });
        }
        return { message: 'شكراً لك! تم تأكيد استلام الخدمة وإغلاق الطلب بنجاح', order };
    }
    async customerRequestRevision(orderId, user, revisionNotes) {
        const order = await this.orderModel
            .findById(orderId)
            .populate('productId', 'name')
            .populate('assignedSupervisorId', 'name');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        if (order.userId.toString() !== user._id.toString()) {
            throw new common_1.ForbiddenException('لا تملك صلاحية طلب التعديل');
        }
        if (order.status !== order_schema_1.OrderStatus.DELIVERED) {
            throw new common_1.BadRequestException('يمكن طلب التعديل فقط بعد تسليم النتيجة وقبل التأكيد');
        }
        order.status = order_schema_1.OrderStatus.REVISION_REQUESTED;
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
        order.chatMessages.push({
            senderId: user._id,
            senderName: user.name,
            senderRole: 'user',
            message: `[طلب تعديل]: ${revisionNotes}`,
            isSensitive: false,
            createdAt: new Date(),
        });
        await order.save();
        if (order.assignedSupervisorId) {
            await this.notificationsService.createNotification({
                userId: order.assignedSupervisorId._id?.toString() || order.assignedSupervisorId.toString(),
                forRole: 'supervisor',
                title: 'طلب تعديل من العميل 🔄',
                body: `طلب العميل تعديلاً على الطلب #${order.orderNumber}: ${revisionNotes}`,
                type: 'revision_requested',
                data: { orderId: order._id.toString(), revisionNotes },
            });
        }
        return { message: 'تم إرسال طلب التعديل للمشرف بنجاح', order };
    }
    async customerOpenDispute(orderId, user, disputeReason) {
        const order = await this.orderModel.findById(orderId).populate('productId', 'name');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        if (order.userId.toString() !== user._id.toString()) {
            throw new common_1.ForbiddenException('لا تملك صلاحية فتح اعتراض');
        }
        if (order.status === order_schema_1.OrderStatus.COMPLETED || order.status === order_schema_1.OrderStatus.REFUNDED) {
            throw new common_1.BadRequestException('لا يمكن فتح اعتراض على طلب منتهي أو مسترجع');
        }
        order.status = order_schema_1.OrderStatus.DISPUTED;
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
        order.chatMessages.push({
            senderId: user._id,
            senderName: user.name,
            senderRole: 'user',
            message: `[اعتراض رسمي]: ${disputeReason}`,
            isSensitive: false,
            createdAt: new Date(),
        });
        await order.save();
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
    async adminReassignSupervisor(orderId, newSupervisorId, admin, reason) {
        const order = await this.orderModel.findById(orderId).populate('productId', 'name');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        const newSupervisor = await this.userModel.findById(newSupervisorId);
        if (!newSupervisor || (newSupervisor.role !== 'supervisor' && newSupervisor.role !== 'admin')) {
            throw new common_1.BadRequestException('المشرف المختار غير صالح');
        }
        const previousSupervisorId = order.assignedSupervisorId;
        order.assignedSupervisorId = newSupervisor._id;
        order.status = order_schema_1.OrderStatus.ASSIGNED;
        order.rejectionReason = undefined;
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
        await this.notificationsService.createNotification({
            userId: newSupervisor._id.toString(),
            forRole: 'supervisor',
            title: 'طلب يدوي مسند إليك من الإدارة 🔔',
            body: `تم إسناد الطلب #${order.orderNumber} لخدمة ${order.productId?.name} إليك من قبل الإدارة.`,
            type: 'manual_service_assigned',
            data: { orderId: order._id.toString(), orderNumber: order.orderNumber },
        });
        return { message: `تم إعادة إسناد الطلب للمشرف ${newSupervisor.name} بنجاح`, order };
    }
    async adminRefundOrder(orderId, admin, reason) {
        const order = await this.orderModel.findById(orderId).populate('userId');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        if (order.status === order_schema_1.OrderStatus.REFUNDED) {
            throw new common_1.BadRequestException('هذا الطلب تم استرجاعه مسبقاً');
        }
        order.status = order_schema_1.OrderStatus.REFUNDED;
        order.adminNotes = reason || 'استرجاع مالي للرصيد من قبل الإدارة';
        const customer = await this.userModel.findById(order.userId);
        if (customer) {
            const balanceBefore = customer.balance;
            const balanceAfter = Number((balanceBefore + order.amount).toFixed(2));
            customer.balance = balanceAfter;
            await customer.save();
            const refundTrans = new this.transactionModel({
                userId: customer._id,
                type: wallet_transaction_schema_1.TransactionType.REFUND,
                amount: order.amount,
                balanceBefore,
                balanceAfter,
                description: `استرجاع رصيد لطلب ملغي #${order.orderNumber}`,
                referenceType: 'Order',
                referenceId: order._id.toString(),
                status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
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
        await this.notificationsService.createNotification({
            userId: order.userId.toString(),
            title: 'تم استرجاع رصيد طلبك لمحفظتك 💰',
            body: `تم استرجاع مبلغ $${order.amount.toFixed(2)} للطلب #${order.orderNumber} إلى محفظتك بنجاح. السبب: ${reason}`,
            type: 'order_refunded',
            data: { orderId: order._id.toString(), amount: order.amount, reason },
        });
        return { message: 'تم استرجاع المبلغ لمحفظة العميل وإلغاء الطلب بنجاح', order };
    }
    async getOrderMessages(orderId, user) {
        const order = await this.orderModel.findById(orderId).select('chatMessages userId assignedSupervisorId');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        const isBuyer = order.userId.toString() === user._id.toString();
        const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
        const isAdmin = user.role === 'admin';
        if (!isBuyer && !isSupervisor && !isAdmin) {
            throw new common_1.ForbiddenException('لا تملك صلاحية عرض رسائل هذا الطلب');
        }
        return order.chatMessages || [];
    }
    async sendOrderMessage(orderId, user, data) {
        const order = await this.orderModel.findById(orderId).populate('productId', 'name');
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        const isBuyer = order.userId.toString() === user._id.toString();
        const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
        const isAdmin = user.role === 'admin';
        if (!isBuyer && !isSupervisor && !isAdmin) {
            throw new common_1.ForbiddenException('لا تملك صلاحية إرسال رسائل في هذا الطلب');
        }
        const senderRole = isAdmin ? 'admin' : isSupervisor ? 'supervisor' : 'user';
        const newMessage = {
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
        if (isBuyer && order.assignedSupervisorId) {
            await this.notificationsService.createNotification({
                userId: order.assignedSupervisorId.toString(),
                forRole: 'supervisor',
                title: `رسالة جديدة من العميل حول طلب #${order.orderNumber} 💬`,
                body: data.message ? (data.message.length > 80 ? `${data.message.slice(0, 80)}...` : data.message) : 'أرسل العميل مرفقاً',
                type: 'order_chat',
                data: { orderId: order._id.toString() },
            });
        }
        else if (isSupervisor || isAdmin) {
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
    async getOrderDecryptedResult(orderId, user) {
        const order = await this.orderModel.findById(orderId);
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        const isBuyer = order.userId.toString() === user._id.toString();
        const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
        const isAdmin = user.role === 'admin';
        if (!isBuyer && !isSupervisor && !isAdmin) {
            throw new common_1.ForbiddenException('غير مصرح لك باستعراض بيانات هذا الطلب');
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
        const decrypted = crypto_util_1.CryptoUtil.decrypt(order.encryptedResultData);
        return {
            isPurged: false,
            credentials: decrypted,
        };
    }
    async acceptManualOrder(id, notes) {
        const order = await this.getOrderById(id);
        order.status = order_schema_1.OrderStatus.COMPLETED;
        order.adminNotes = notes || 'تم الشحن بنجاح';
        order.completedAt = new Date();
        await order.save();
        return { message: 'تم قبول الطلب بنجاح', order };
    }
    async rejectManualOrder(id, notes) {
        const order = await this.getOrderById(id);
        order.status = order_schema_1.OrderStatus.REJECTED;
        order.adminNotes = notes || 'تم رفض الطلب';
        await order.save();
        return { message: 'تم رفض الطلب بنجاح', order };
    }
};
exports.OrdersService = OrdersService;
exports.OrdersService = OrdersService = OrdersService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(order_schema_1.Order.name)),
    __param(1, (0, mongoose_1.InjectModel)(product_schema_1.Product.name)),
    __param(2, (0, mongoose_1.InjectModel)(app_schema_1.App.name)),
    __param(3, (0, mongoose_1.InjectModel)(user_schema_1.User.name)),
    __param(4, (0, mongoose_1.InjectModel)(wallet_transaction_schema_1.WalletTransaction.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        notifications_service_1.NotificationsService,
        providers_service_1.ProvidersService])
], OrdersService);
//# sourceMappingURL=orders.service.js.map