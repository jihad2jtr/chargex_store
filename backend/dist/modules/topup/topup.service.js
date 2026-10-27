"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var TopupService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.TopupService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const sham_cash_account_schema_1 = require("../../database/schemas/sham-cash-account.schema");
const manual_order_schema_1 = require("../../database/schemas/manual-order.schema");
const shipping_code_schema_1 = require("../../database/schemas/shipping-code.schema");
const topup_method_schema_1 = require("../../database/schemas/topup-method.schema");
const user_schema_1 = require("../../database/schemas/user.schema");
const wallet_transaction_schema_1 = require("../../database/schemas/wallet-transaction.schema");
const wallet_service_1 = require("../wallet/wallet.service");
const notifications_service_1 = require("../notifications/notifications.service");
let TopupService = TopupService_1 = class TopupService {
    constructor(accountModel, manualOrderModel, codeModel, topupMethodModel, userModel, transactionModel, walletService, notificationsService) {
        this.accountModel = accountModel;
        this.manualOrderModel = manualOrderModel;
        this.codeModel = codeModel;
        this.topupMethodModel = topupMethodModel;
        this.userModel = userModel;
        this.transactionModel = transactionModel;
        this.walletService = walletService;
        this.notificationsService = notificationsService;
        this.logger = new common_1.Logger(TopupService_1.name);
    }
    async getActiveAccounts(type) {
        const filter = { isActive: true };
        if (type)
            filter.type = type;
        return this.accountModel.find(filter).sort({ createdAt: -1 });
    }
    async getAllAccountsAdmin(type) {
        const filter = {};
        if (type)
            filter.type = type;
        return this.accountModel.find(filter).sort({ createdAt: -1 });
    }
    async createAccount(data) {
        const account = new this.accountModel({
            ...data,
            isActive: true,
        });
        return account.save();
    }
    async updateAccount(id, updateData) {
        const account = await this.accountModel.findByIdAndUpdate(id, updateData, { new: true });
        if (!account)
            throw new common_1.NotFoundException('الحساب غير موجود');
        return account;
    }
    async toggleAccountActive(id) {
        const account = await this.accountModel.findById(id);
        if (!account)
            throw new common_1.NotFoundException('الحساب غير موجود');
        account.isActive = !account.isActive;
        return account.save();
    }
    async deleteAccount(id) {
        const account = await this.accountModel.findByIdAndDelete(id);
        if (!account)
            throw new common_1.NotFoundException('الحساب غير موجود');
        return { message: 'تم حذف الحساب بنجاح' };
    }
    async submitTopupRequest(params) {
        if (params.amount <= 0) {
            throw new common_1.BadRequestException('المبلغ يجب أن يكون أكبر من صفر');
        }
        const manualOrder = new this.manualOrderModel({
            userId: new mongoose_2.Types.ObjectId(params.userId),
            type: params.type,
            amount: params.amount,
            details: params.details,
            receiptImageUrl: params.receiptImageUrl,
            status: manual_order_schema_1.ManualOrderStatus.PENDING,
        });
        await manualOrder.save();
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
    async getManualOrders(status) {
        const filter = {};
        if (status)
            filter.status = status;
        return this.manualOrderModel
            .find(filter)
            .populate('userId', 'name email phone balance userId')
            .sort({ createdAt: -1 });
    }
    async getMyTopupRequests(userId) {
        const userObjectId = new mongoose_2.Types.ObjectId(userId);
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
        return this.mergeTopupLog(manualOrders, redeemedCodes, legacyIdTopups);
    }
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
        return this.mergeTopupLog(manualOrders, redeemedCodes, legacyIdTopups);
    }
    legacyIdTopupFilter() {
        return {
            referenceType: 'Admin',
            description: { $not: /^(شحن رصيد عبر |شحن عبر كود رقمي:)/ },
        };
    }
    mergeTopupLog(manualOrders, redeemedCodes, legacyIdTopups = []) {
        const codeEntries = redeemedCodes.map((code) => ({
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
        const legacyEntries = legacyIdTopups.map((tx) => ({
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
        const manualEntries = manualOrders.map((order) => ({
            ...order,
            source: order.source ?? 'manual',
        }));
        return [...manualEntries, ...codeEntries, ...legacyEntries].sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    }
    async createIdTopup(params) {
        const cleanId = (params.userId || '').trim();
        if (!cleanId)
            throw new common_1.BadRequestException('يرجى إدخال آيدي العميل');
        if (!params.amount)
            throw new common_1.BadRequestException('المبلغ يجب أن يكون أكبر من صفر');
        let user = await this.userModel.findOne({ userId: cleanId });
        if (!user && mongoose_2.Types.ObjectId.isValid(cleanId)) {
            user = await this.userModel.findById(cleanId);
        }
        if (!user)
            throw new common_1.NotFoundException('المستخدم غير موجود (يرجى التحقق من آيدي العميل)');
        const notes = (params.description || '').trim() || (params.amount > 0 ? 'شحن مباشر عبر الآيدي' : 'خصم مباشر عبر الآيدي');
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
            status: manual_order_schema_1.ManualOrderStatus.APPROVED,
            adminNotes: notes,
            processedBy: new mongoose_2.Types.ObjectId(params.adminId),
            processedAt: new Date(),
        });
        await entry.save();
        return {
            message: 'تم شحن رصيد العميل بنجاح وسُجّلت العملية في سجل الشحن',
            user: result.user,
            entry,
        };
    }
    async approveTopup(id, adminId, approvedAmount, notes) {
        const manualOrder = await this.manualOrderModel.findById(id);
        if (!manualOrder)
            throw new common_1.NotFoundException('طلب الشحن غير موجود');
        if (manualOrder.status !== manual_order_schema_1.ManualOrderStatus.PENDING) {
            throw new common_1.BadRequestException('تمت معالجة هذا الطلب مسبقاً');
        }
        const finalAmount = approvedAmount !== undefined && approvedAmount > 0 ? approvedAmount : manualOrder.amount;
        manualOrder.status = manual_order_schema_1.ManualOrderStatus.APPROVED;
        manualOrder.amount = finalAmount;
        manualOrder.adminNotes = notes || 'تم التحقق من الإيصال والموافقة بنجاح';
        manualOrder.processedBy = new mongoose_2.Types.ObjectId(adminId);
        manualOrder.processedAt = new Date();
        await manualOrder.save();
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
    async rejectTopup(id, adminId, notes) {
        const manualOrder = await this.manualOrderModel.findById(id);
        if (!manualOrder)
            throw new common_1.NotFoundException('طلب الشحن غير موجود');
        if (manualOrder.status !== manual_order_schema_1.ManualOrderStatus.PENDING) {
            throw new common_1.BadRequestException('تمت معالجة هذا الطلب مسبقاً');
        }
        manualOrder.status = manual_order_schema_1.ManualOrderStatus.REJECTED;
        manualOrder.adminNotes = notes || 'تم رفض الطلب لعدم تطابق بيانات الإيصال';
        manualOrder.processedBy = new mongoose_2.Types.ObjectId(adminId);
        manualOrder.processedAt = new Date();
        await manualOrder.save();
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
};
exports.TopupService = TopupService;
exports.TopupService = TopupService = TopupService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(sham_cash_account_schema_1.ShamCashAccount.name)),
    __param(1, (0, mongoose_1.InjectModel)(manual_order_schema_1.ManualOrder.name)),
    __param(2, (0, mongoose_1.InjectModel)(shipping_code_schema_1.ShippingCode.name)),
    __param(3, (0, mongoose_1.InjectModel)(topup_method_schema_1.TopupMethod.name)),
    __param(4, (0, mongoose_1.InjectModel)(user_schema_1.User.name)),
    __param(5, (0, mongoose_1.InjectModel)(wallet_transaction_schema_1.WalletTransaction.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        mongoose_2.Model,
        wallet_service_1.WalletService,
        notifications_service_1.NotificationsService])
], TopupService);
//# sourceMappingURL=topup.service.js.map