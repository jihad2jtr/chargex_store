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
var AgentService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AgentService = void 0;
const common_1 = require("@nestjs/common");
const mongoose_1 = require("@nestjs/mongoose");
const mongoose_2 = require("mongoose");
const bcrypt = __importStar(require("bcryptjs"));
const user_schema_1 = require("../../database/schemas/user.schema");
const wallet_transaction_schema_1 = require("../../database/schemas/wallet-transaction.schema");
const role_enum_1 = require("../../common/interfaces/role.enum");
const user_id_util_1 = require("../../common/utils/user-id.util");
const notifications_service_1 = require("../notifications/notifications.service");
const AGENT_INCOMING_REFERENCE_TYPES = ['Admin', 'IdTopup', 'ManualOrder'];
let AgentService = AgentService_1 = class AgentService {
    constructor(userModel, transactionModel, notificationsService) {
        this.userModel = userModel;
        this.transactionModel = transactionModel;
        this.notificationsService = notificationsService;
        this.logger = new common_1.Logger(AgentService_1.name);
    }
    async generateUniqueUserId() {
        return (0, user_id_util_1.generateUserId)(async (candidateId) => Boolean(await this.userModel.findOne((0, user_id_util_1.userIdFilter)(candidateId))));
    }
    async getDashboardStats(agentId) {
        const agent = await this.userModel.findById(agentId);
        if (!agent)
            throw new common_1.NotFoundException('حساب الوكيل غير موجود');
        const totalSubUsers = await this.userModel.countDocuments({
            parentAgentId: new mongoose_2.Types.ObjectId(agentId),
        });
        const activeSubUsers = await this.userModel.countDocuments({
            parentAgentId: new mongoose_2.Types.ObjectId(agentId),
            isActive: true,
        });
        const suspendedSubUsers = await this.userModel.countDocuments({
            parentAgentId: new mongoose_2.Types.ObjectId(agentId),
            isActive: false,
        });
        const transferAgg = await this.transactionModel.aggregate([
            {
                $match: {
                    userId: new mongoose_2.Types.ObjectId(agentId),
                    type: wallet_transaction_schema_1.TransactionType.AGENT_TRANSFER,
                    amount: { $lt: 0 },
                },
            },
            {
                $group: {
                    _id: null,
                    totalAmount: { $sum: { $abs: '$amount' } },
                    totalCount: { $sum: 1 },
                },
            },
        ]);
        const totalTransferred = transferAgg.length > 0
            ? Number(transferAgg[0].totalAmount.toFixed(2))
            : 0.0;
        const transferCount = transferAgg.length > 0 ? transferAgg[0].totalCount : 0;
        const incomingAgg = await this.transactionModel.aggregate([
            {
                $match: {
                    userId: new mongoose_2.Types.ObjectId(agentId),
                    amount: { $gt: 0 },
                    referenceType: { $in: AGENT_INCOMING_REFERENCE_TYPES },
                },
            },
            {
                $group: {
                    _id: null,
                    totalAmount: { $sum: '$amount' },
                    totalCount: { $sum: 1 },
                },
            },
        ]);
        const totalReceived = incomingAgg.length > 0
            ? Number(incomingAgg[0].totalAmount.toFixed(2))
            : 0.0;
        const receivedCount = incomingAgg.length > 0 ? incomingAgg[0].totalCount : 0;
        const recentTransfers = await this.transactionModel
            .find({
            userId: new mongoose_2.Types.ObjectId(agentId),
            type: wallet_transaction_schema_1.TransactionType.AGENT_TRANSFER,
        })
            .sort({ createdAt: -1 })
            .limit(5);
        return {
            agent: {
                id: agent._id,
                userId: agent.userId,
                name: agent.name,
                email: agent.email,
                phone: agent.phone,
                balance: agent.balance,
                role: agent.role,
            },
            stats: {
                totalSubUsers,
                activeSubUsers,
                suspendedSubUsers,
                totalTransferred,
                transferCount,
                totalReceived,
                receivedCount,
            },
            recentTransfers,
        };
    }
    async getMyUsers(agentId, search, statusFilter) {
        const query = {
            parentAgentId: new mongoose_2.Types.ObjectId(agentId),
        };
        if (statusFilter === 'active') {
            query.isActive = true;
        }
        else if (statusFilter === 'suspended') {
            query.isActive = false;
        }
        if (search && search.trim().length > 0) {
            const q = search.trim();
            query.$or = [
                { name: { $regex: q, $options: 'i' } },
                { email: { $regex: q, $options: 'i' } },
                { phone: { $regex: q, $options: 'i' } },
                { userId: { $regex: q, $options: 'i' } },
            ];
        }
        const users = await this.userModel
            .find(query)
            .select('-password -refreshToken')
            .sort({ createdAt: -1 });
        return users.map((u) => ({
            _id: u._id,
            userId: u.userId,
            name: u.name,
            email: u.email,
            phone: u.phone,
            balance: u.balance,
            isActive: u.isActive,
            deactivatedByAgent: u.deactivatedByAgent || false,
            agentDeactivationReason: u.agentDeactivationReason,
            agentNotes: u.agentNotes,
            createdAt: u.createdAt,
        }));
    }
    async createUserUnderAgent(agentId, data) {
        const agent = await this.userModel.findById(agentId);
        if (!agent)
            throw new common_1.NotFoundException('حساب الوكيل غير موجود');
        const cleanEmail = data.email.toLowerCase().trim();
        const existing = await this.userModel.findOne({ email: cleanEmail });
        if (existing) {
            throw new common_1.BadRequestException('البريد الإلكتروني مسجل مسبقاً في النظام');
        }
        const initialAmount = Number(data.initialBalance || 0);
        if (initialAmount < 0) {
            throw new common_1.BadRequestException('الرصيد الأولي لا يمكن أن يكون سالباً');
        }
        if (initialAmount > 0 && agent.balance < initialAmount) {
            throw new common_1.BadRequestException(`رصيدك كوكيل غير كافٍ لمنح رصيد أولي بقيمة $${initialAmount.toFixed(2)}. رصيدك الحالي: $${agent.balance.toFixed(2)}`);
        }
        const hashedPassword = await bcrypt.hash(data.password, 10);
        const customUserId = await this.generateUniqueUserId();
        const newUser = new this.userModel({
            userId: customUserId,
            name: data.name.trim(),
            email: cleanEmail,
            password: hashedPassword,
            phone: data.phone?.trim(),
            role: role_enum_1.Role.USER,
            balance: initialAmount,
            parentAgentId: agent._id,
            agentNotes: data.notes?.trim(),
            isActive: true,
        });
        await newUser.save();
        if (initialAmount > 0) {
            const agentBalBefore = agent.balance;
            const agentBalAfter = Number((agentBalBefore - initialAmount).toFixed(2));
            agent.balance = agentBalAfter;
            await agent.save();
            await this.transactionModel.create({
                userId: agent._id,
                type: wallet_transaction_schema_1.TransactionType.AGENT_TRANSFER,
                amount: -initialAmount,
                balanceBefore: agentBalBefore,
                balanceAfter: agentBalAfter,
                description: `تحويل رصيد أولي للمستخدم الجديد ${newUser.name} (${newUser.userId})`,
                referenceType: 'AgentTransfer',
                referenceId: newUser._id.toString(),
                status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
            });
            await this.transactionModel.create({
                userId: newUser._id,
                type: wallet_transaction_schema_1.TransactionType.AGENT_TRANSFER,
                amount: initialAmount,
                balanceBefore: 0.0,
                balanceAfter: initialAmount,
                description: `رصيد افتتاح حساب من الوكيل المعتمد ${agent.name}`,
                referenceType: 'AgentTransfer',
                referenceId: agent._id.toString(),
                status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
            });
        }
        return {
            message: 'تم إنشاء المستخدم التابع للوكيل بنجاح',
            user: {
                _id: newUser._id,
                userId: newUser.userId,
                name: newUser.name,
                email: newUser.email,
                phone: newUser.phone,
                balance: newUser.balance,
                isActive: newUser.isActive,
                createdAt: newUser.createdAt,
            },
            agentRemainingBalance: agent.balance,
        };
    }
    async linkUserToAgent(agentId, userIdentifier) {
        const cleanId = userIdentifier ? userIdentifier.trim() : '';
        let target = await this.userModel.findOne((0, user_id_util_1.userIdFilter)(cleanId));
        if (!target && cleanId.includes('@')) {
            target = await this.userModel.findOne({ email: cleanId.toLowerCase() });
        }
        if (!target && mongoose_2.Types.ObjectId.isValid(cleanId)) {
            target = await this.userModel.findById(cleanId);
        }
        if (!target) {
            throw new common_1.NotFoundException('لم يتم العثور على المستخدم (تأكد من إدخال الآيدي أو البريد بدقة)');
        }
        if (target._id.toString() === agentId) {
            throw new common_1.BadRequestException('لا يمكنك ربط حسابك الخاص بنفسك');
        }
        if (target.role === role_enum_1.Role.ADMIN || target.role === role_enum_1.Role.SUPERVISOR) {
            throw new common_1.BadRequestException('لا يمكن ربط حسابات الإدارة والمشرفين كعملاء');
        }
        if (target.parentAgentId) {
            if (target.parentAgentId.toString() === agentId) {
                return {
                    message: 'هذا المستخدم مسجل بالفعل تحت إشرافك كوكيل',
                    user: target,
                };
            }
            throw new common_1.BadRequestException('هذا المستخدم مرتبط بوكيل معتمد آخر مسبقاً');
        }
        target.parentAgentId = new mongoose_2.Types.ObjectId(agentId);
        await target.save();
        return {
            message: `تم ربط المستخدم "${target.name}" بحسابك كوكيل بنجاح ✅`,
            user: {
                _id: target._id,
                userId: target.userId,
                name: target.name,
                email: target.email,
                phone: target.phone,
                balance: target.balance,
                isActive: target.isActive,
            },
        };
    }
    async transferBalance(agentId, targetUserId, amount, note) {
        const transferAmount = Number(amount);
        if (!transferAmount || transferAmount <= 0) {
            throw new common_1.BadRequestException('يرجى إدخال مبلغ تحويل صالح أكبر من صفر');
        }
        const agent = await this.userModel.findById(agentId);
        if (!agent)
            throw new common_1.NotFoundException('حساب الوكيل غير موجود');
        if (agent.balance < transferAmount) {
            throw new common_1.BadRequestException(`رصيدك الحالي غير كافٍ. المطلوب: $${transferAmount.toFixed(2)}، الرصيد المتاح: $${agent.balance.toFixed(2)}`);
        }
        const cleanTarget = targetUserId ? targetUserId.trim() : '';
        let target = await this.userModel.findOne((0, user_id_util_1.userIdFilter)(cleanTarget));
        if (!target && mongoose_2.Types.ObjectId.isValid(cleanTarget)) {
            target = await this.userModel.findById(cleanTarget);
        }
        if (!target && cleanTarget.includes('@')) {
            target = await this.userModel.findOne({
                email: cleanTarget.toLowerCase(),
            });
        }
        if (!target) {
            throw new common_1.NotFoundException('المستخدم المستلم غير موجود');
        }
        if (!target.parentAgentId) {
            target.parentAgentId = agent._id;
        }
        else if (target.parentAgentId.toString() !== agentId &&
            agent.role !== role_enum_1.Role.ADMIN) {
            throw new common_1.ForbiddenException('المستخدم المستلم يتبع لوكيل آخر، لا يمكنك التحويل إلا لعملائك التابعين لك');
        }
        if (!target.isActive) {
            throw new common_1.BadRequestException('حساب المستخدم معطل حالياً، يرجى تفعيل الحساب أولاً قبل التحويل');
        }
        const agentBalBefore = agent.balance;
        const agentBalAfter = Number((agentBalBefore - transferAmount).toFixed(2));
        agent.balance = agentBalAfter;
        await agent.save();
        const targetBalBefore = target.balance;
        const targetBalAfter = Number((targetBalBefore + transferAmount).toFixed(2));
        target.balance = targetBalAfter;
        await target.save();
        const agentTx = await this.transactionModel.create({
            userId: agent._id,
            type: wallet_transaction_schema_1.TransactionType.AGENT_TRANSFER,
            amount: -transferAmount,
            balanceBefore: agentBalBefore,
            balanceAfter: agentBalAfter,
            description: `تحويل رصيد للعميل ${target.name} (${target.userId || target.email})${note ? ` - ${note}` : ''}`,
            referenceType: 'AgentTransfer',
            referenceId: target._id.toString(),
            status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
        });
        const userTx = await this.transactionModel.create({
            userId: target._id,
            type: wallet_transaction_schema_1.TransactionType.AGENT_TRANSFER,
            amount: transferAmount,
            balanceBefore: targetBalBefore,
            balanceAfter: targetBalAfter,
            description: `شحن رصيد من الوكيل المعتمد ${agent.name}${note ? ` (${note})` : ''}`,
            referenceType: 'AgentTransfer',
            referenceId: agent._id.toString(),
            status: wallet_transaction_schema_1.TransactionStatus.COMPLETED,
        });
        await this.notificationsService.createNotification({
            userId: target._id.toString(),
            title: 'شحن رصيد من الوكيل ⚡',
            body: `تم استلام تحويل رصيد بقيمة $${transferAmount.toFixed(2)} من وكيلك (${agent.name}). رصيدك الحالي: $${targetBalAfter.toFixed(2)}`,
            type: 'wallet_topup',
            data: {
                amount: transferAmount,
                newBalance: targetBalAfter,
                agentName: agent.name,
            },
        });
        return {
            message: `تم تحويل مبلغ $${transferAmount.toFixed(2)} بنجاح للعميل ${target.name} ✅`,
            newAgentBalance: agent.balance,
            user: {
                _id: target._id,
                userId: target.userId,
                name: target.name,
                newBalance: target.balance,
            },
            transactionId: agentTx._id,
        };
    }
    async toggleUserStatus(agentId, targetUserId, isActive, reason) {
        const cleanId = targetUserId ? targetUserId.trim() : '';
        let target = await this.userModel.findOne((0, user_id_util_1.userIdFilter)(cleanId));
        if (!target && mongoose_2.Types.ObjectId.isValid(cleanId)) {
            target = await this.userModel.findById(cleanId);
        }
        if (!target) {
            throw new common_1.NotFoundException('المستخدم غير موجود');
        }
        if (!target.parentAgentId || target.parentAgentId.toString() !== agentId) {
            const agent = await this.userModel.findById(agentId);
            if (agent?.role !== role_enum_1.Role.ADMIN) {
                throw new common_1.ForbiddenException('لا يمكنك إدارة حالة مستخدم لا يتبع لوكالتك');
            }
        }
        if (!isActive) {
            target.isActive = false;
            target.deactivatedByAgent = true;
            target.agentDeactivationReason =
                reason?.trim() ||
                    'تم تجميد الحساب من قبل الوكيل المعتمد لعدم تسوية المستحقات المالية';
            target.refreshToken = undefined;
            await target.save();
            this.logger.warn(`Agent ${agentId} suspended user ${target._id} (${target.email}). Reason: ${target.agentDeactivationReason}`);
            return {
                message: `تم تجميد وإيقاف حساب العميل "${target.name}" فوراً ⛔ ومنعه من الشراء والدخول`,
                user: {
                    _id: target._id,
                    userId: target.userId,
                    name: target.name,
                    isActive: false,
                    deactivatedByAgent: true,
                    agentDeactivationReason: target.agentDeactivationReason,
                },
            };
        }
        else {
            target.isActive = true;
            target.deactivatedByAgent = false;
            target.agentDeactivationReason = undefined;
            await target.save();
            this.logger.log(`Agent ${agentId} reactivated user ${target._id} (${target.email})`);
            return {
                message: `تمت إعادة تفعيل حساب العميل "${target.name}" بنجاح ✅`,
                user: {
                    _id: target._id,
                    userId: target.userId,
                    name: target.name,
                    isActive: true,
                    deactivatedByAgent: false,
                    agentDeactivationReason: null,
                },
            };
        }
    }
    async getTransferHistory(agentId) {
        const agentObjectId = new mongoose_2.Types.ObjectId(agentId);
        const docs = await this.transactionModel
            .find({
            userId: agentObjectId,
            $or: [
                { type: wallet_transaction_schema_1.TransactionType.AGENT_TRANSFER, amount: { $lt: 0 } },
                {
                    amount: { $gt: 0 },
                    referenceType: { $in: AGENT_INCOMING_REFERENCE_TYPES },
                },
            ],
        })
            .sort({ createdAt: -1 })
            .limit(100)
            .lean();
        const targetIds = docs
            .filter((doc) => doc.amount < 0 && doc.referenceId)
            .map((doc) => String(doc.referenceId))
            .filter((id) => mongoose_2.Types.ObjectId.isValid(id))
            .map((id) => new mongoose_2.Types.ObjectId(id));
        const targets = targetIds.length
            ? await this.userModel
                .find({ _id: { $in: targetIds } })
                .select('name userId email')
                .lean()
            : [];
        const targetById = new Map(targets.map((user) => [String(user._id), user]));
        return docs.map((doc) => {
            const isOutgoing = doc.amount < 0;
            const target = isOutgoing ? targetById.get(String(doc.referenceId)) : null;
            const counterparty = isOutgoing
                ? {
                    name: target?.name ?? '',
                    userId: target?.userId ?? '',
                    email: target?.email ?? '',
                }
                : { name: 'الإدارة', userId: '', email: '' };
            return {
                _id: doc._id,
                createdAt: doc.createdAt,
                direction: isOutgoing ? 'out' : 'in',
                amount: Math.abs(doc.amount),
                description: doc.description,
                referenceType: doc.referenceType ?? '',
                counterparty,
                recipient: counterparty,
            };
        });
    }
};
exports.AgentService = AgentService;
exports.AgentService = AgentService = AgentService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, mongoose_1.InjectModel)(user_schema_1.User.name)),
    __param(1, (0, mongoose_1.InjectModel)(wallet_transaction_schema_1.WalletTransaction.name)),
    __metadata("design:paramtypes", [mongoose_2.Model,
        mongoose_2.Model,
        notifications_service_1.NotificationsService])
], AgentService);
//# sourceMappingURL=agent.service.js.map