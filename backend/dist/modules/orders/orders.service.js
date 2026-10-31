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
const users_service_1 = require("../users/users.service");
const crypto_util_1 = require("../../common/utils/crypto.util");
class InsufficientBalanceSignal extends Error {
}
let OrdersService = OrdersService_1 = class OrdersService {
    constructor(orderModel, productModel, appModel, userModel, transactionModel, notificationsService, providersService, usersService, connection) {
        this.orderModel = orderModel;
        this.productModel = productModel;
        this.appModel = appModel;
        this.userModel = userModel;
        this.transactionModel = transactionModel;
        this.notificationsService = notificationsService;
        this.providersService = providersService;
        this.usersService = usersService;
        this.connection = connection;
        this.logger = new common_1.Logger(OrdersService_1.name);
        this.isReconciling = false;
    }
    onModuleInit() {
        this.reconcileKickoffTimer = setTimeout(() => {
            void this.runReconciliationPass().catch(() => undefined);
        }, 60_000);
        this.reconcileKickoffTimer.unref?.();
        this.reconcileTimer = setInterval(() => {
            void this.runReconciliationPass().catch(() => undefined);
        }, OrdersService_1.RECONCILE_INTERVAL_MS);
        this.reconcileTimer.unref?.();
    }
    onModuleDestroy() {
        if (this.reconcileTimer)
            clearInterval(this.reconcileTimer);
        if (this.reconcileKickoffTimer)
            clearTimeout(this.reconcileKickoffTimer);
    }
    async runReconciliationPass() {
        if (this.isReconciling)
            return;
        this.isReconciling = true;
        try {
            await this.reconcileProviderOrders(20);
        }
        finally {
            this.isReconciling = false;
        }
    }
    async compensateDuplicateDebit(user, price) {
        try {
            const credited = await this.userModel.findByIdAndUpdate(user._id, { $inc: { balance: price } }, { new: true });
            const balanceAfter = Number((credited?.balance ?? price).toFixed(2));
            await this.transactionModel.create({
                userId: user._id,
                type: wallet_transaction_schema_1.TransactionType.REFUND,
                amount: price,
                balanceBefore: Number((balanceAfter - price).toFixed(2)),
                balanceAfter,
                description: 'إرجاع تلقائي لسحب مكرّر من إعادة إرسال نفس الطلب',
                referenceType: 'Order',
                status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
            });
        }
        catch (err) {
            this.logger.error(`Duplicate-debit compensation failed for user ${user._id}: ${err?.message}`);
            await this.notifyAdminsSafe('تنبيه مالي: سحب مكرّر غير معوّض', `أُعيد إرسال طلب بنفس المعرّف للعميل ${user.name} لكن تعذّر إرجاع الخصم الثاني ($${price.toFixed(2)})؛ يلزم تدخل يدوي.`);
        }
    }
    async notifyAdminsSafe(title, body) {
        try {
            await this.notificationsService.createNotification({ forRole: 'admin', title, body, type: 'order_status' });
        }
        catch (err) {
            this.logger.warn(`Admin notification failed (${title}): ${err?.message}`);
        }
    }
    async allocateInventoryCode(productId) {
        const updated = await this.productModel.findOneAndUpdate({ _id: productId, 'inventoryCodes': { $exists: true, $ne: [] } }, { $pop: { inventoryCodes: 1 } }, { new: false });
        const codes = updated?.inventoryCodes;
        if (!Array.isArray(codes) || codes.length === 0)
            return null;
        return String(codes[codes.length - 1]);
    }
    async getUserBalance(userId) {
        const doc = await this.userModel.findById(userId).select('balance').lean();
        return Number(doc?.balance ?? 0);
    }
    async refundUnpersistedDebit(user, price, cause) {
        this.logger.error(`Order persist failed after debit for ${user._id}: ${cause?.message}`);
        try {
            await this.userModel.findByIdAndUpdate(user._id, { $inc: { balance: price } });
        }
        catch (refundErr) {
            this.logger.error(`Emergency refund failed for user ${user._id}: ${refundErr?.message}`);
            await this.notifyAdminsSafe('تنبيه مالي: خصم بلا تعويض', `فشل حفظ طلب بعد خصم $${price.toFixed(2)} من العميل ${user.name} وفشل إرجاعه تلقائياً؛ يلزم تدخل يدوي.`);
        }
    }
    async releaseInventoryCode(productId, code) {
        try {
            await this.productModel.findByIdAndUpdate(productId, { $addToSet: { inventoryCodes: code } });
        }
        catch (err) {
            this.logger.error(`Could not return inventory code ${code} for product ${productId}: ${err?.message}`);
            await this.notifyAdminsSafe('تنبيه مخزون: كود غير معاد', `أُخرج الكود ${code} من المخزون ولم يُسلَّم ولم يعد؛ يلزم مراجعة يدوية للمخزون.`);
        }
    }
    isUnsupportedTransactionError(err) {
        if (!err)
            return false;
        const code = err.code;
        const codeName = err.codeName || '';
        const msg = String(err.message || '');
        return (code === 20 ||
            code === 263 ||
            codeName === 'IllegalOperation' ||
            codeName === 'OperationNotSupportedInTransaction' ||
            /replica set|transaction numbers|transactions? are not supported|not supported|without a replica set|standalone/i.test(msg));
    }
    async commitPurchaseMoney(params) {
        const { orderDoc, cleanRequestId, user, price, ledgerDescription } = params;
        if (this.txSupported !== false) {
            const session = await this.connection.startSession();
            try {
                let created;
                let debitedUser = null;
                await session.withTransaction(async () => {
                    debitedUser = await this.userModel.findOneAndUpdate({ _id: user._id, balance: { $gte: price } }, { $inc: { balance: -price } }, { new: true, session });
                    if (!debitedUser)
                        throw new InsufficientBalanceSignal();
                    const docs = await this.orderModel.create([orderDoc], { session });
                    created = docs[0];
                    const bAfter = Number(debitedUser.balance.toFixed(2));
                    const bBefore = Number((bAfter + price).toFixed(2));
                    await this.transactionModel.create([
                        {
                            userId: user._id,
                            type: wallet_transaction_schema_1.TransactionType.PURCHASE,
                            amount: -price,
                            balanceBefore: bBefore,
                            balanceAfter: bAfter,
                            description: ledgerDescription,
                            referenceType: 'Order',
                            referenceId: created._id.toString(),
                            status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
                        },
                    ], { session });
                });
                this.txSupported = true;
                return { kind: 'created', order: created, debited: debitedUser };
            }
            catch (err) {
                if (err instanceof InsufficientBalanceSignal) {
                    throw new common_1.BadRequestException(`رصيدك غير كافٍ. المبلغ المطلوب: $${price.toFixed(2)}، رصيدك الحالي: $${user.balance.toFixed(2)}`);
                }
                if (err?.code === 11000 && cleanRequestId) {
                    const existing = await this.orderModel.findOne({ requestId: cleanRequestId });
                    if (existing)
                        return { kind: 'duplicate', existing };
                }
                if (this.isUnsupportedTransactionError(err)) {
                    this.txSupported = false;
                    this.logger.warn('Topology lacks transaction support; falling back to compensating sequential path');
                    return this.commitPurchaseSequential(params);
                }
                this.logger.error(`createOrder transaction failed for ${orderDoc.orderNumber}: ${err?.message}`);
                throw new common_1.BadRequestException('تعذر إتمام العملية، لم يتم خصم أي مبلغ. يرجى المحاولة لاحقاً');
            }
            finally {
                await session.endSession();
            }
        }
        return this.commitPurchaseSequential(params);
    }
    async commitPurchaseSequential(params) {
        const { orderDoc, cleanRequestId, user, price, ledgerDescription } = params;
        const debited = await this.userModel.findOneAndUpdate({ _id: user._id, balance: { $gte: price } }, { $inc: { balance: -price } }, { new: true });
        if (!debited) {
            throw new common_1.BadRequestException(`رصيدك غير كافٍ. المبلغ المطلوب: $${price.toFixed(2)}، رصيدك الحالي: $${user.balance.toFixed(2)}`);
        }
        const balanceAfter = Number(debited.balance.toFixed(2));
        const balanceBefore = Number((balanceAfter + price).toFixed(2));
        let order;
        try {
            order = await this.orderModel.create(orderDoc);
        }
        catch (saveErr) {
            if (saveErr?.code === 11000 && cleanRequestId) {
                const existing = await this.orderModel.findOne({ requestId: cleanRequestId });
                if (existing) {
                    await this.compensateDuplicateDebit(user, price);
                    return { kind: 'duplicate', existing };
                }
            }
            await this.refundUnpersistedDebit(user, price, saveErr);
            throw new common_1.BadRequestException('تعذر إتمام العملية، تم إرجاع المبلغ إلى محفظتك. يرجى المحاولة لاحقاً');
        }
        try {
            await this.transactionModel.create({
                userId: user._id,
                type: wallet_transaction_schema_1.TransactionType.PURCHASE,
                amount: -price,
                balanceBefore,
                balanceAfter,
                description: ledgerDescription,
                referenceType: 'Order',
                referenceId: order._id.toString(),
                status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
            });
        }
        catch (ledgerErr) {
            this.logger.error(`Could not record purchase transaction for ${order.orderNumber}: ${ledgerErr.message}`);
            try {
                order.status = order_schema_1.OrderStatus.REFUNDED;
                order.rejectionReason = 'تعذر تسجيل الحركة المالية، تم إرجاع المبلغ';
                await order.save();
                await this.userModel.findByIdAndUpdate(user._id, { $inc: { balance: price } });
            }
            catch (compensationErr) {
                this.logger.error(`Compensation chain failed for ${order.orderNumber}: ${compensationErr.message}`);
                await this.notifyAdminsSafe('تنبيه مالي: طلب معلّق بعد فشل تسجيل الحركة', `الطلب #${order.orderNumber} (عميل ${user.name}، مبلغ $${price.toFixed(2)}) تعذّر تسجيل حركته المالية وتعذّر إتمام إرجاعه تلقائياً؛ يلزم مراجعة يدوية.`);
            }
            throw new common_1.BadRequestException('تعذر إتمام العملية، لم يتم خصم أي مبلغ. يرجى المحاولة لاحقاً');
        }
        return { kind: 'created', order, debited };
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
        const product = await this.productModel
            .findById(params.productId)
            .populate('serviceTemplateId');
        if (!product || !product.isActive) {
            throw new common_1.BadRequestException('المنتج غير متاح حالياً');
        }
        const app = product.appId
            ? await this.appModel.findById(product.appId)
            : null;
        if (product.appId && (!app || !app.isActive)) {
            throw new common_1.BadRequestException('هذه الخدمة معطلة حالياً');
        }
        const template = product.serviceTemplateId;
        const templateFields = template?.fields || [];
        const effectiveRequiredFields = templateFields.length > 0
            ? templateFields.filter((f) => f.required).map((f) => f.label)
            : product.requiredFields || [];
        const effectiveSensitiveFields = Array.from(new Set([
            ...(product.sensitiveFields || []),
            ...templateFields
                .filter((f) => f.isSensitive || f.type === 'password')
                .map((f) => f.label),
        ]));
        const rawInput = params.accountInput || {};
        if (product.type !== product_schema_1.ProductType.CODES) {
            const missingFields = effectiveRequiredFields.filter((label) => rawInput[label] === undefined ||
                rawInput[label] === null ||
                String(rawInput[label]).trim() === '');
            if (missingFields.length > 0) {
                throw new common_1.BadRequestException(`يرجى إكمال الحقول المطلوبة: ${missingFields.join('، ')}`);
            }
        }
        const price = product.salePrice;
        if (user.balance < price) {
            throw new common_1.BadRequestException(`رصيدك غير كافٍ. المبلغ المطلوب: $${price.toFixed(2)}، رصيدك الحالي: $${user.balance.toFixed(2)}`);
        }
        if (product.type === product_schema_1.ProductType.DIRECT_API && product.providerId) {
            await this.providersService.ensureReadyForOrder(product.providerId.toString(), product.costPrice || 0);
        }
        if (product.type === product_schema_1.ProductType.CODES && (!product.inventoryCodes || product.inventoryCodes.length === 0)) {
            throw new common_1.BadRequestException('عذراً، هذا المنتج غير متوفر في المخزون حالياً');
        }
        let deliveredCode = undefined;
        let initialStatus = order_schema_1.OrderStatus.PENDING;
        const estimatedMinutes = product.estimatedMinutes || 120;
        const deadlineAt = new Date(Date.now() + estimatedMinutes * 60 * 1000);
        const timeline = [];
        const orderNumber = this.generateOrderNumber();
        const profit = Number((price - product.costPrice).toFixed(2));
        const sanitizedInput = { ...(params.accountInput || {}) };
        for (const field of effectiveSensitiveFields) {
            if (sanitizedInput[field]) {
                sanitizedInput[field] = crypto_util_1.CryptoUtil.encrypt(String(sanitizedInput[field]));
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
        const cleanRequestId = typeof params.requestId === 'string' && params.requestId.trim() ? params.requestId.trim() : undefined;
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
            status: order_schema_1.OrderStatus.PENDING,
            accountInput: sanitizedInput,
            estimatedMinutes,
            deadlineAt,
            isSensitive: effectiveSensitiveFields.length > 0 || product.isSensitive || false,
            sensitiveFields: effectiveSensitiveFields,
            timeline,
            chatMessages: [],
            ...(cleanRequestId ? { requestId: cleanRequestId } : {}),
        };
        const commit = await this.commitPurchaseMoney({
            orderDoc,
            cleanRequestId,
            user,
            price,
            ledgerDescription: `شراء ${product.name}${app?.name ? ` (${app.name})` : ''}`,
        });
        if (commit.kind === 'duplicate') {
            return {
                message: 'تم تنفيذ طلبك سابقاً، وهذه نسخة عنه',
                order: await this.getOrderById(commit.existing._id.toString()),
                newBalance: await this.getUserBalance(user._id),
                deliveredCode: commit.existing.deliveredCode,
            };
        }
        const order = commit.order;
        const balanceAfter = Number(commit.debited.balance.toFixed(2));
        let assignedSupervisorId = undefined;
        let assignedSupervisorUser = null;
        if (product.type === product_schema_1.ProductType.CODES) {
            const code = await this.allocateInventoryCode(product._id);
            if (!code) {
                return this.failPaidOrder(order, {
                    amount: price,
                    reason: 'عذراً، هذا المنتج غير متوفر في المخزون حالياً',
                });
            }
            deliveredCode = code;
            initialStatus = order_schema_1.OrderStatus.COMPLETED;
            order.timeline.push({
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
                    return this.failPaidOrder(order, {
                        amount: price,
                        reason: 'يرجى إدخال معرف اللاعب (Player ID) المطلوب للشحن',
                    });
                }
                let providerResult;
                try {
                    providerResult = await this.providersService.executeOrder(product.providerId.toString(), {
                        productCode: product.providerProductCode || '',
                        gameUserId: String(gameUserId),
                        gameZoneId: gameZoneId ? String(gameZoneId) : undefined,
                        reference: orderNumber,
                    });
                }
                catch (err) {
                    providerResult = {
                        success: false,
                        message: err?.message || 'تعذر الاتصال بمزوّد الخدمة',
                        isTimeout: true,
                    };
                }
                if (!providerResult.success) {
                    this.logger.error(`Provider direct execution failed for ${orderNumber}: ${providerResult.message}`);
                    try {
                        await this.providersService.markProviderFailure(product.providerId.toString(), providerResult.message, product.costPrice || 0);
                    }
                    catch (markErr) {
                        this.logger.warn(`Could not mark provider failure: ${markErr.message}`);
                    }
                    if (providerResult.isTimeout) {
                        order.providerReference = order.providerReference || orderNumber;
                        order.status = order_schema_1.OrderStatus.PENDING;
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
                        await this.notifyAdminsSafe('تنبيه: مهلة انقطاع لدى المزود', `الطلب #${orderNumber} (${product.name}) انتهى نداؤه بالمهلة — سيُحسم تلقائياً عبر المصالحة.`);
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
                        .catch((notifyErr) => {
                        this.logger.warn(`Could not notify admins about provider failure: ${notifyErr.message}`);
                    });
                    return this.failPaidOrder(order, {
                        amount: price,
                        reason: `تعذر إتمام الشحن عبر المزود: ${providerResult.message}`,
                        providerRaw: providerResult.raw,
                    });
                }
                if (providerResult.raw?.items?.[0]?.externalData?.length) {
                    deliveredCode = providerResult.raw.items[0].externalData.join(', ');
                }
                order.providerReference = providerResult.transactionId || orderNumber;
                order.providerResponse = providerResult.raw;
                initialStatus = order_schema_1.OrderStatus.COMPLETED;
                order.timeline.push({
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
                order.timeline.push({
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
                order.timeline.push({
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
        order.status = initialStatus;
        order.deliveredCode = deliveredCode;
        order.assignedSupervisorId = assignedSupervisorId;
        order.rejectionReason = undefined;
        order.completedAt = initialStatus === order_schema_1.OrderStatus.COMPLETED ? new Date() : undefined;
        try {
            await order.save();
        }
        catch (finalizeErr) {
            this.logger.error(`Order finalize save failed for ${orderNumber}: ${finalizeErr.message}`);
            if (product.type === product_schema_1.ProductType.CODES && deliveredCode) {
                await this.releaseInventoryCode(product._id, deliveredCode);
            }
            await this.notifyAdminsSafe('تنبيه: تعذّر تحديث حالة طلب بعد التنفيذ', `الطلب #${orderNumber} نُفّذ/أُرسل لكن حالته لم تُحدَّث في القاعدة؛ يلزم مراجعة يدوية.`);
        }
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
                .catch((err) => this.logger.warn(`Supervisor notification failed: ${err.message}`));
        }
        await this.notificationsService
            .createNotification({
            forRole: 'admin',
            title: 'طلب جديد 🛒',
            body: `طلب جديد رقم #${orderNumber} لخدمة ${product.name} بمبلغ $${price.toFixed(2)}`,
            type: 'new_order',
            data: { orderId: order._id.toString(), orderNumber },
        })
            .catch((err) => this.logger.warn(`Admin new-order notification failed: ${err.message}`));
        if (initialStatus === order_schema_1.OrderStatus.COMPLETED) {
            await this.notificationsService
                .createNotification({
                userId: user._id.toString(),
                title: 'تم تنفيذ طلبك بنجاح ✅',
                body: product.type === product_schema_1.ProductType.CODES
                    ? `تم استلام كود باقة ${product.name}: ${deliveredCode}`
                    : `تم تنفيذ شحن باقة ${product.name} لحسابك بنجاح`,
                type: 'order_status',
                data: { orderId: order._id.toString(), deliveredCode },
            })
                .catch((err) => this.logger.warn(`Customer completion notification failed: ${err.message}`));
        }
        let orderView = order;
        try {
            orderView = await this.getOrderById(order._id.toString());
        }
        catch (viewErr) {
            this.logger.warn(`Could not refetch order view for ${orderNumber}: ${viewErr.message}`);
        }
        return {
            message: initialStatus === order_schema_1.OrderStatus.COMPLETED
                ? 'تم تنفيذ الطلب بنجاح'
                : initialStatus === order_schema_1.OrderStatus.ASSIGNED
                    ? 'تم استلام طلبك وجاري تحويله للمشرف المختص لبدء التنفيذ'
                    : 'تم إرسال طلب الشحن بنجاح وهو قيد المراجعة',
            order: orderView,
            newBalance: balanceAfter,
            deliveredCode,
        };
    }
    async failPaidOrder(order, params) {
        let refunded = null;
        try {
            refunded = await this.userModel.findByIdAndUpdate(order.userId, { $inc: { balance: params.amount } }, { new: true });
        }
        catch (creditErr) {
            this.logger.error(`Refund credit failed for ${order.orderNumber}: ${creditErr.message}`);
            try {
                order.providerReference = order.providerReference || order.orderNumber;
                await order.save();
            }
            catch (saveErr) {
                this.logger.error(`Could not persist reference for ${order.orderNumber}: ${saveErr.message}`);
            }
            await this.notifyAdminsSafe('تنبيه مالي: فشل إرجاع مبلغ لطلب متعذر', `الطلب #${order.orderNumber} تعذّر تنفيذُه ($${params.amount.toFixed(2)}) وفشل إرجاع المبلغ للعميل؛ يلزم تدخل يدوي.`);
            throw new common_1.BadRequestException(`${params.reason} (رقم الطلب: ${order.orderNumber})`);
        }
        const balanceAfter = Number((refunded?.balance ?? params.amount).toFixed(2));
        const balanceBefore = Number((balanceAfter - params.amount).toFixed(2));
        order.status = order_schema_1.OrderStatus.REFUNDED;
        order.rejectionReason = params.reason;
        order.providerReference = order.providerReference || order.orderNumber;
        if (params.providerRaw !== undefined) {
            order.providerResponse = params.providerRaw;
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
        try {
            await this.transactionModel.create({
                userId: order.userId,
                type: wallet_transaction_schema_1.TransactionType.REFUND,
                amount: params.amount,
                balanceBefore,
                balanceAfter,
                description: `إرجاع تلقائي لطلب متعذر #${order.orderNumber}`,
                referenceType: 'Order',
                referenceId: order._id.toString(),
                status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
            });
        }
        catch (ledgerErr) {
            this.logger.error(`Refund ledger entry failed for ${order.orderNumber}: ${ledgerErr.message}`);
            await this.notifyAdminsSafe('تنبيه دفتر: حركة إرجاع غير مسجلة', `أُرجع $${params.amount.toFixed(2)} للعميل في الطلب #${order.orderNumber} لكن تسجيل الحركة فشل؛ يلزم مراجعة الدفتر.`);
        }
        throw new common_1.BadRequestException(`${params.reason} (رقم الطلب: ${order.orderNumber})`);
    }
    async autoRefundOrder(order, reason, title) {
        const refundedUser = await this.userModel.findByIdAndUpdate(order.userId, { $inc: { balance: order.amount } }, { new: true });
        const balanceAfter = Number((refundedUser?.balance ?? order.amount).toFixed(2));
        order.status = order_schema_1.OrderStatus.REFUNDED;
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
            type: wallet_transaction_schema_1.TransactionType.REFUND,
            amount: order.amount,
            balanceBefore: Number((balanceAfter - order.amount).toFixed(2)),
            balanceAfter,
            description: `إرجاع تلقائي (مصالحة) لطلب #${order.orderNumber}`,
            referenceType: 'Order',
            referenceId: order._id.toString(),
            status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
        });
        await this.notificationsService.createNotification({
            userId: order.userId.toString(),
            title: 'تم إرجاع مبلغ طلبك إلى المحفظة',
            body: `تعذّر تنفيذ الطلب #${order.orderNumber} لدى مزود الخدمة، وتم إرجاع $${order.amount.toFixed(2)} إلى محفظتك.`,
            type: 'order_refunded',
            data: { orderId: order._id.toString(), amount: order.amount, reason },
        });
    }
    async reconcileProviderOrders(limit = 20) {
        const orders = await this.orderModel
            .find({
            type: product_schema_1.ProductType.DIRECT_API,
            providerId: { $ne: null },
            providerReference: { $exists: true, $ne: null },
            providerSettledAt: { $exists: false },
            status: order_schema_1.OrderStatus.COMPLETED,
            $or: [{ deliveredCode: { $exists: false } }, { deliveredCode: null }, { deliveredCode: '' }],
        })
            .sort({ createdAt: -1 })
            .limit(limit);
        let settled = 0;
        let refunded = 0;
        let pending = 0;
        for (const order of orders) {
            const providerId = order.providerId?.toString();
            if (!providerId || !order.providerReference)
                continue;
            let inspection;
            try {
                inspection = await this.providersService.inspectOrderStatus(providerId, order.providerReference);
            }
            catch (err) {
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
                order.providerResponse = inspection.raw;
                order.providerSettledAt = new Date();
                await this.autoRefundOrder(order, reason, 'تم استرجاع المبلغ تلقائياً بعد فشل المزوّد');
                refunded++;
                continue;
            }
            pending++;
        }
        let flagged = 0;
        const refundedOrders = await this.orderModel
            .find({
            type: product_schema_1.ProductType.DIRECT_API,
            providerId: { $ne: null },
            providerReference: { $exists: true, $ne: null },
            providerSettledAt: { $exists: false },
            status: order_schema_1.OrderStatus.REFUNDED,
            createdAt: { $lte: new Date(Date.now() - 5 * 60 * 1000) },
        })
            .sort({ createdAt: -1 })
            .limit(limit);
        for (const order of refundedOrders) {
            const providerId = order.providerId?.toString();
            if (!providerId || !order.providerReference)
                continue;
            try {
                const inspection = await this.providersService.inspectOrderStatus(providerId, order.providerReference);
                if (inspection.state !== 'delivered')
                    continue;
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
            }
            catch (err) {
                this.logger.warn(`Reverse reconciliation failed for order ${order.orderNumber}: ${err.message}`);
            }
        }
        let recovered = 0;
        const orphanedOrders = await this.orderModel
            .find({
            type: product_schema_1.ProductType.DIRECT_API,
            providerId: { $ne: null },
            providerSettledAt: { $exists: false },
            status: order_schema_1.OrderStatus.PENDING,
            createdAt: { $lte: new Date(Date.now() - 3 * 60 * 1000) },
        })
            .sort({ createdAt: -1 })
            .limit(limit);
        for (const order of orphanedOrders) {
            const providerId = order.providerId?.toString();
            const reference = order.providerReference || order.orderNumber;
            if (!providerId || !reference)
                continue;
            let inspection;
            try {
                inspection = await this.providersService.inspectOrderStatus(providerId, reference);
            }
            catch (err) {
                this.logger.warn(`Orphan reconciliation failed for order ${order.orderNumber}: ${err.message}`);
                continue;
            }
            if (inspection.state === 'delivered') {
                order.status = order_schema_1.OrderStatus.COMPLETED;
                order.deliveredCode = inspection.codes?.length ? inspection.codes.join(', ') : order.deliveredCode;
                order.providerReference = reference;
                order.providerResponse = inspection.raw;
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
                order.providerResponse = inspection.raw;
                order.providerSettledAt = new Date();
                await this.autoRefundOrder(order, `أبلغ المزوّد عن فشل تنفيذ الطلب: ${inspection.message || 'سبب غير محدد'}`, 'تم استرجاع المبلغ تلقائياً بعد فشل المزوّد');
                refunded++;
                continue;
            }
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
    async getMyOrders(userId) {
        return this.orderModel
            .find({ userId: new mongoose_2.Types.ObjectId(userId) })
            .populate('appId', 'name iconUrl appType')
            .populate('virtualNumberAppId', 'name iconUrl')
            .populate('productId', 'name type costPrice salePrice isSensitive')
            .populate('assignedSupervisorId', 'name email phone role')
            .sort({ createdAt: -1 });
    }
    async getOrderById(id) {
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
            .select('-chatMessages -timeline')
            .populate('userId', 'name email phone balance userId')
            .populate('appId', 'name iconUrl')
            .populate('virtualNumberAppId', 'name iconUrl')
            .populate('productId', 'name type costPrice salePrice isSensitive')
            .populate('assignedSupervisorId', 'name email phone role userId')
            .sort({ createdAt: -1 })
            .lean();
        const now = new Date();
        return orders.map((o) => {
            const isDelayed = !!o.deadlineAt &&
                now > new Date(o.deadlineAt) &&
                o.status !== order_schema_1.OrderStatus.COMPLETED &&
                o.status !== order_schema_1.OrderStatus.REFUNDED;
            return {
                ...o,
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
        await this.usersService.reconcileSupervisorRole(supervisor._id);
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
        if (!newSupervisor || newSupervisor.isActive === false) {
            throw new common_1.BadRequestException('المستخدم المختار غير صالح');
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
        if (previousSupervisorId && previousSupervisorId.toString() !== newSupervisor._id.toString()) {
            await this.usersService.reconcileSupervisorRole(previousSupervisorId);
        }
        await this.usersService.reconcileSupervisorRole(newSupervisor._id);
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
        const order = await this.orderModel
            .findOneAndUpdate({ _id: orderId, status: { $ne: order_schema_1.OrderStatus.REFUNDED } }, {
            $set: {
                status: order_schema_1.OrderStatus.REFUNDED,
                adminNotes: reason || 'استرجاع مالي للرصيد من قبل الإدارة',
            },
        }, { new: true })
            .populate('userId');
        if (!order) {
            const existing = await this.orderModel.findById(orderId);
            if (!existing)
                throw new common_1.NotFoundException('الطلب غير موجود');
            throw new common_1.BadRequestException('هذا الطلب تم استرجاعه مسبقاً');
        }
        const customer = await this.userModel.findByIdAndUpdate(order.userId, { $inc: { balance: order.amount } }, { new: true });
        if (customer) {
            const balanceAfter = Number(customer.balance.toFixed(2));
            const balanceBefore = Number((balanceAfter - order.amount).toFixed(2));
            try {
                await this.transactionModel.create({
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
            }
            catch (ledgerErr) {
                this.logger.error(`Admin refund ledger entry failed for ${order.orderNumber}: ${ledgerErr.message}`);
                await this.notifyAdminsSafe('تنبيه دفتر: استرجاع إداري غير مسجل', `أُرجع $${order.amount.toFixed(2)} للعميل في الطلب #${order.orderNumber} من الإدارة لكن تسجيل الحركة فشل؛ يلزم مراجعة الدفتر.`);
            }
        }
        else {
            this.logger.error(`Admin refund for ${order.orderNumber}: customer account not found, funds not credited`);
            await this.notifyAdminsSafe('تنبيه مالي: استرجاع إداري لعميل غير موجود', `الطلب #${order.orderNumber} ($${order.amount.toFixed(2)}) استُرجع لكن حساب العميل لم يُوجد؛ يلزم تعويض يدوي.`);
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
        await this.notificationsService
            .createNotification({
            userId: order.userId.toString(),
            title: 'تم استرجاع رصيد طلبك لمحفظتك 💰',
            body: `تم استرجاع مبلغ $${order.amount.toFixed(2)} للطلب #${order.orderNumber} إلى محفظتك بنجاح. السبب: ${reason}`,
            type: 'order_refunded',
            data: { orderId: order._id.toString(), amount: order.amount, reason },
        })
            .catch((err) => this.logger.warn(`Refund notification failed: ${err.message}`));
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
    async getOrderDecryptedInput(orderId, user) {
        const order = await this.orderModel.findById(orderId);
        if (!order)
            throw new common_1.NotFoundException('الطلب غير موجود');
        const isSupervisor = order.assignedSupervisorId?.toString() === user._id.toString();
        const isAdmin = user.role === 'admin';
        if (!isSupervisor && !isAdmin) {
            throw new common_1.ForbiddenException('غير مصرح لك باستعراض بيانات هذا الطلب');
        }
        const sensitiveFields = order.sensitiveFields || [];
        const input = order.accountInput || {};
        const decryptedInput = {};
        for (const [key, value] of Object.entries(input)) {
            if (sensitiveFields.includes(key) && typeof value === 'string' && value.includes(':')) {
                decryptedInput[key] = crypto_util_1.CryptoUtil.decrypt(value) ?? value;
            }
            else {
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
OrdersService.RECONCILE_INTERVAL_MS = 5 * 60 * 1000;
exports.OrdersService = OrdersService = OrdersService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(order_schema_1.Order.name)),
    __param(1, (0, mongoose_1.InjectModel)(product_schema_1.Product.name)),
    __param(2, (0, mongoose_1.InjectModel)(app_schema_1.App.name)),
    __param(3, (0, mongoose_1.InjectModel)(user_schema_1.User.name)),
    __param(4, (0, mongoose_1.InjectModel)(wallet_transaction_schema_1.WalletTransaction.name)),
    __param(8, (0, mongoose_1.InjectConnection)()),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        notifications_service_1.NotificationsService,
        providers_service_1.ProvidersService,
        users_service_1.UsersService,
        mongoose_2.Connection])
], OrdersService);
//# sourceMappingURL=orders.service.js.map