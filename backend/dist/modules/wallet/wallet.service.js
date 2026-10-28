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
Object.defineProperty(exports, "__esModule", { value: true });
exports.WalletService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const wallet_transaction_schema_1 = require("../../database/schemas/wallet-transaction.schema");
const user_schema_1 = require("../../database/schemas/user.schema");
const user_id_util_1 = require("../../common/utils/user-id.util");
const notifications_service_1 = require("../notifications/notifications.service");
let WalletService = class WalletService {
    constructor(transactionModel, userModel, notificationsService) {
        this.transactionModel = transactionModel;
        this.userModel = userModel;
        this.notificationsService = notificationsService;
    }
    async getUserBalance(userId) {
        const user = await this.userModel.findById(userId);
        if (!user)
            throw new common_1.NotFoundException('المستخدم غير موجود');
        return {
            userId: user._id,
            customUserId: user.userId,
            balance: user.balance,
            currency: 'USD',
        };
    }
    async getUserTransactions(userId) {
        return this.transactionModel
            .find({ userId: new mongoose_2.Types.ObjectId(userId) })
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
    async adminAdjustBalance(params) {
        if (params.amount === 0) {
            throw new common_1.BadRequestException('المبلغ لا يمكن أن يكون صفراً');
        }
        const cleanInput = params.userId ? params.userId.trim() : '';
        let user = await this.userModel.findOne((0, user_id_util_1.userIdFilter)(cleanInput));
        if (!user && mongoose_2.Types.ObjectId.isValid(cleanInput)) {
            user = await this.userModel.findById(cleanInput);
        }
        if (!user)
            throw new common_1.NotFoundException('المستخدم غير موجود (يرجى التحقق من آيدي العميل)');
        const balanceBefore = user.balance;
        const balanceAfter = Number((balanceBefore + params.amount).toFixed(2));
        if (balanceAfter < 0) {
            throw new common_1.BadRequestException('الرصيد المتبقي لا يمكن أن يكون سالباً');
        }
        user.balance = balanceAfter;
        await user.save();
        const transaction = new this.transactionModel({
            userId: user._id,
            type: params.amount > 0
                ? wallet_transaction_schema_1.TransactionType.TOPUP
                : wallet_transaction_schema_1.TransactionType.ADMIN_ADJUSTMENT,
            amount: params.amount,
            balanceBefore,
            balanceAfter,
            description: params.description ||
                (params.amount > 0 ? 'شحن رصيد من الإدارة' : 'خصم رصيد من الإدارة'),
            referenceType: params.referenceType ?? 'Admin',
            referenceId: params.referenceId ?? params.adminId,
            status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
        });
        await transaction.save();
        await this.notificationsService.createNotification({
            userId: user._id.toString(),
            title: params.amount > 0 ? 'شحن رصيد ناجح 🎉' : 'تعديل رصيد من الإدارة',
            body: params.amount > 0
                ? `تم شحن رصيدك بمبلغ $${params.amount.toFixed(2)} بنجاح. رصيدك الحالي: $${balanceAfter.toFixed(2)}`
                : `تم خصم $${Math.abs(params.amount).toFixed(2)} من حسابك. رصيدك الحالي: $${balanceAfter.toFixed(2)}`,
            type: 'wallet_topup',
            data: { amount: params.amount, newBalance: balanceAfter },
        });
        return {
            message: 'تم تحديث رصيد المستخدم بنجاح',
            user: {
                id: user._id,
                userId: user.userId,
                name: user.name,
                email: user.email,
                balance: user.balance,
            },
            transaction,
        };
    }
};
exports.WalletService = WalletService;
exports.WalletService = WalletService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(wallet_transaction_schema_1.WalletTransaction.name)),
    __param(1, (0, mongoose_1.InjectModel)(user_schema_1.User.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model,
        notifications_service_1.NotificationsService])
], WalletService);
//# sourceMappingURL=wallet.service.js.map