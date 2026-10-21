import { Injectable, BadRequestException, NotFoundException, ForbiddenException, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import * as bcrypt from 'bcryptjs';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { WalletTransaction, WalletTransactionDocument, TransactionType, TransactionStatus } from '../../database/schemas/wallet-transaction.schema';
import { Role } from '../../common/interfaces/role.enum';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class AgentService {
  private readonly logger = new Logger(AgentService.name);

  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(WalletTransaction.name) private transactionModel: Model<WalletTransactionDocument>,
    private notificationsService: NotificationsService,
  ) {}

  private async generateUniqueUserId(): Promise<string> {
    let unique = false;
    let userId = '';
    while (!unique) {
      const now = new Date();
      const yy = String(now.getFullYear()).slice(-2);
      const mm = String(now.getMonth() + 1).padStart(2, '0');
      const dd = String(now.getDate()).padStart(2, '0');
      const rand = Math.floor(10000 + Math.random() * 90000);
      userId = `chx${yy}${mm}${dd}${rand}`;
      const existing = await this.userModel.findOne({ userId });
      if (!existing) unique = true;
    }
    return userId;
  }

  // --- 1. Agent Dashboard Overview ---
  async getDashboardStats(agentId: string) {
    const agent = await this.userModel.findById(agentId);
    if (!agent) throw new NotFoundException('حساب الوكيل غير موجود');

    const totalSubUsers = await this.userModel.countDocuments({
      parentAgentId: new Types.ObjectId(agentId),
    });

    const activeSubUsers = await this.userModel.countDocuments({
      parentAgentId: new Types.ObjectId(agentId),
      isActive: true,
    });

    const suspendedSubUsers = await this.userModel.countDocuments({
      parentAgentId: new Types.ObjectId(agentId),
      isActive: false,
    });

    // Sum of outgoing transfers by this agent
    const transferAgg = await this.transactionModel.aggregate([
      {
        $match: {
          userId: new Types.ObjectId(agentId),
          type: TransactionType.AGENT_TRANSFER,
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

    const totalTransferred = transferAgg.length > 0 ? Number(transferAgg[0].totalAmount.toFixed(2)) : 0.0;
    const transferCount = transferAgg.length > 0 ? transferAgg[0].totalCount : 0;

    // Recent 5 transactions
    const recentTransfers = await this.transactionModel
      .find({
        userId: new Types.ObjectId(agentId),
        type: TransactionType.AGENT_TRANSFER,
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
      },
      recentTransfers,
    };
  }

  // --- 2. List Agent's Sub-Users ---
  async getMyUsers(agentId: string, search?: string, statusFilter?: 'all' | 'active' | 'suspended') {
    const query: any = {
      parentAgentId: new Types.ObjectId(agentId),
    };

    if (statusFilter === 'active') {
      query.isActive = true;
    } else if (statusFilter === 'suspended') {
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
      createdAt: (u as any).createdAt,
    }));
  }

  // --- 3. Create New User Directly Under Agent ---
  async createUserUnderAgent(
    agentId: string,
    data: {
      name: string;
      email: string;
      password: string;
      phone?: string;
      initialBalance?: number;
      notes?: string;
    },
  ) {
    const agent = await this.userModel.findById(agentId);
    if (!agent) throw new NotFoundException('حساب الوكيل غير موجود');

    const cleanEmail = data.email.toLowerCase().trim();
    const existing = await this.userModel.findOne({ email: cleanEmail });
    if (existing) {
      throw new BadRequestException('البريد الإلكتروني مسجل مسبقاً في النظام');
    }

    const initialAmount = Number(data.initialBalance || 0);
    if (initialAmount < 0) {
      throw new BadRequestException('الرصيد الأولي لا يمكن أن يكون سالباً');
    }
    if (initialAmount > 0 && agent.balance < initialAmount) {
      throw new BadRequestException(
        `رصيدك كوكيل غير كافٍ لمنح رصيد أولي بقيمة $${initialAmount.toFixed(2)}. رصيدك الحالي: $${agent.balance.toFixed(2)}`,
      );
    }

    const hashedPassword = await bcrypt.hash(data.password, 10);
    const customUserId = await this.generateUniqueUserId();

    const newUser = new this.userModel({
      userId: customUserId,
      name: data.name.trim(),
      email: cleanEmail,
      password: hashedPassword,
      phone: data.phone?.trim(),
      role: Role.USER,
      balance: initialAmount,
      parentAgentId: agent._id,
      agentNotes: data.notes?.trim(),
      isActive: true,
    });

    await newUser.save();

    // If initial balance was assigned, deduct from agent atomically and record transactions
    if (initialAmount > 0) {
      const agentBalBefore = agent.balance;
      const agentBalAfter = Number((agentBalBefore - initialAmount).toFixed(2));
      agent.balance = agentBalAfter;
      await agent.save();

      // Agent outgoing transaction
      await this.transactionModel.create({
        userId: agent._id,
        type: TransactionType.AGENT_TRANSFER,
        amount: -initialAmount,
        balanceBefore: agentBalBefore,
        balanceAfter: agentBalAfter,
        description: `تحويل رصيد أولي للمستخدم الجديد ${newUser.name} (${newUser.userId})`,
        referenceType: 'AgentTransfer',
        referenceId: newUser._id.toString(),
        status: TransactionStatus.COMPLETED,
      });

      // User incoming transaction
      await this.transactionModel.create({
        userId: newUser._id,
        type: TransactionType.AGENT_TRANSFER,
        amount: initialAmount,
        balanceBefore: 0.0,
        balanceAfter: initialAmount,
        description: `رصيد افتتاح حساب من الوكيل المعتمد ${agent.name}`,
        referenceType: 'AgentTransfer',
        referenceId: agent._id.toString(),
        status: TransactionStatus.COMPLETED,
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
        createdAt: (newUser as any).createdAt,
      },
      agentRemainingBalance: agent.balance,
    };
  }

  // --- 4. Link an Existing User to this Agent ---
  async linkUserToAgent(agentId: string, userIdentifier: string) {
    const cleanId = userIdentifier ? userIdentifier.trim() : '';
    let target = await this.userModel.findOne({ userId: cleanId });
    if (!target && cleanId.includes('@')) {
      target = await this.userModel.findOne({ email: cleanId.toLowerCase() });
    }
    if (!target && Types.ObjectId.isValid(cleanId)) {
      target = await this.userModel.findById(cleanId);
    }

    if (!target) {
      throw new NotFoundException('لم يتم العثور على المستخدم (تأكد من إدخال الآيدي أو البريد بدقة)');
    }

    if (target._id.toString() === agentId) {
      throw new BadRequestException('لا يمكنك ربط حسابك الخاص بنفسك');
    }

    if (target.role === Role.ADMIN || target.role === Role.SUPERVISOR) {
      throw new BadRequestException('لا يمكن ربط حسابات الإدارة والمشرفين كعملاء');
    }

    if (target.parentAgentId) {
      if (target.parentAgentId.toString() === agentId) {
        return {
          message: 'هذا المستخدم مسجل بالفعل تحت إشرافك كوكيل',
          user: target,
        };
      }
      throw new BadRequestException('هذا المستخدم مرتبط بوكيل معتمد آخر مسبقاً');
    }

    target.parentAgentId = new Types.ObjectId(agentId) as any;
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

  // --- 5. Transfer Balance to Sub-User (تحويل رصيد) ---
  async transferBalance(agentId: string, targetUserId: string, amount: number, note?: string) {
    const transferAmount = Number(amount);
    if (!transferAmount || transferAmount <= 0) {
      throw new BadRequestException('يرجى إدخال مبلغ تحويل صالح أكبر من صفر');
    }

    const agent = await this.userModel.findById(agentId);
    if (!agent) throw new NotFoundException('حساب الوكيل غير موجود');

    if (agent.balance < transferAmount) {
      throw new BadRequestException(
        `رصيدك الحالي غير كافٍ. المطلوب: $${transferAmount.toFixed(2)}، الرصيد المتاح: $${agent.balance.toFixed(2)}`,
      );
    }

    const cleanTarget = targetUserId ? targetUserId.trim() : '';
    let target = await this.userModel.findOne({ userId: cleanTarget });
    if (!target && Types.ObjectId.isValid(cleanTarget)) {
      target = await this.userModel.findById(cleanTarget);
    }
    if (!target && cleanTarget.includes('@')) {
      target = await this.userModel.findOne({ email: cleanTarget.toLowerCase() });
    }

    if (!target) {
      throw new NotFoundException('المستخدم المستلم غير موجود');
    }

    // Auto-link to agent if not yet linked to any other agent
    if (!target.parentAgentId) {
      target.parentAgentId = agent._id as any;
    } else if (target.parentAgentId.toString() !== agentId && agent.role !== Role.ADMIN) {
      throw new ForbiddenException('المستخدم المستلم يتبع لوكيل آخر، لا يمكنك التحويل إلا لعملائك التابعين لك');
    }

    if (!target.isActive) {
      throw new BadRequestException('حساب المستخدم معطل حالياً، يرجى تفعيل الحساب أولاً قبل التحويل');
    }

    // Atomic execution
    const agentBalBefore = agent.balance;
    const agentBalAfter = Number((agentBalBefore - transferAmount).toFixed(2));
    agent.balance = agentBalAfter;
    await agent.save();

    const targetBalBefore = target.balance;
    const targetBalAfter = Number((targetBalBefore + transferAmount).toFixed(2));
    target.balance = targetBalAfter;
    await target.save();

    // Record transaction for Agent (Debit)
    const agentTx = await this.transactionModel.create({
      userId: agent._id,
      type: TransactionType.AGENT_TRANSFER,
      amount: -transferAmount,
      balanceBefore: agentBalBefore,
      balanceAfter: agentBalAfter,
      description: `تحويل رصيد للعميل ${target.name} (${target.userId || target.email})${note ? ` - ${note}` : ''}`,
      referenceType: 'AgentTransfer',
      referenceId: target._id.toString(),
      status: TransactionStatus.COMPLETED,
    });

    // Record transaction for User (Credit)
    const userTx = await this.transactionModel.create({
      userId: target._id,
      type: TransactionType.AGENT_TRANSFER,
      amount: transferAmount,
      balanceBefore: targetBalBefore,
      balanceAfter: targetBalAfter,
      description: `شحن رصيد من الوكيل المعتمد ${agent.name}${note ? ` (${note})` : ''}`,
      referenceType: 'AgentTransfer',
      referenceId: agent._id.toString(),
      status: TransactionStatus.COMPLETED,
    });

    // Send push notification to user
    await this.notificationsService.createNotification({
      userId: target._id.toString(),
      title: 'شحن رصيد من الوكيل ⚡',
      body: `تم استلام تحويل رصيد بقيمة $${transferAmount.toFixed(2)} من وكيلك (${agent.name}). رصيدك الحالي: $${targetBalAfter.toFixed(2)}`,
      type: 'wallet_topup',
      data: { amount: transferAmount, newBalance: targetBalAfter, agentName: agent.name },
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

  // --- 6. Toggle Sub-User Active / Suspended (إيقاف - تفعيل في حال النصب) ---
  async toggleUserStatus(agentId: string, targetUserId: string, isActive: boolean, reason?: string) {
    const cleanId = targetUserId ? targetUserId.trim() : '';
    let target = await this.userModel.findOne({ userId: cleanId });
    if (!target && Types.ObjectId.isValid(cleanId)) {
      target = await this.userModel.findById(cleanId);
    }

    if (!target) {
      throw new NotFoundException('المستخدم غير موجود');
    }

    if (!target.parentAgentId || target.parentAgentId.toString() !== agentId) {
      const agent = await this.userModel.findById(agentId);
      if (agent?.role !== Role.ADMIN) {
        throw new ForbiddenException('لا يمكنك إدارة حالة مستخدم لا يتبع لوكالتك');
      }
    }

    if (!isActive) {
      // SUSPEND USER (إيقاف فوري للعميل)
      target.isActive = false;
      target.deactivatedByAgent = true;
      target.agentDeactivationReason =
        reason?.trim() || 'تم تجميد الحساب من قبل الوكيل المعتمد لعدم تسوية المستحقات المالية';
      // Invalidate current refresh token to kick out active sessions
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
    } else {
      // REACTIVATE USER (إعادة التفعيل)
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

  // --- 7. Transfer History for Agent ---
  async getTransferHistory(agentId: string) {
    return this.transactionModel
      .find({
        userId: new Types.ObjectId(agentId),
        type: TransactionType.AGENT_TRANSFER,
      })
      .sort({ createdAt: -1 })
      .limit(100);
  }
}
