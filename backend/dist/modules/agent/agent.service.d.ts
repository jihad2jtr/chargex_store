import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { WalletTransaction, WalletTransactionDocument } from '../../database/schemas/wallet-transaction.schema';
import { Role } from '../../common/interfaces/role.enum';
import { NotificationsService } from '../notifications/notifications.service';
export declare class AgentService {
    private userModel;
    private transactionModel;
    private notificationsService;
    private readonly logger;
    constructor(userModel: Model<UserDocument>, transactionModel: Model<WalletTransactionDocument>, notificationsService: NotificationsService);
    private generateUniqueUserId;
    getDashboardStats(agentId: string): Promise<{
        agent: {
            id: Types.ObjectId;
            userId: string | undefined;
            name: string;
            email: string;
            phone: string | undefined;
            balance: number;
            role: Role;
        };
        stats: {
            totalSubUsers: number;
            activeSubUsers: number;
            suspendedSubUsers: number;
            totalTransferred: number;
            transferCount: any;
        };
        recentTransfers: (import("mongoose").Document<unknown, {}, WalletTransactionDocument, {}, import("mongoose").DefaultSchemaOptions> & WalletTransaction & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        })[];
    }>;
    getMyUsers(agentId: string, search?: string, statusFilter?: 'all' | 'active' | 'suspended'): Promise<{
        _id: Types.ObjectId;
        userId: string | undefined;
        name: string;
        email: string;
        phone: string | undefined;
        balance: number;
        isActive: boolean;
        deactivatedByAgent: boolean;
        agentDeactivationReason: string | undefined;
        agentNotes: string | undefined;
        createdAt: any;
    }[]>;
    createUserUnderAgent(agentId: string, data: {
        name: string;
        email: string;
        password: string;
        phone?: string;
        initialBalance?: number;
        notes?: string;
    }): Promise<{
        message: string;
        user: {
            _id: Types.ObjectId;
            userId: string | undefined;
            name: string;
            email: string;
            phone: string | undefined;
            balance: number;
            isActive: boolean;
            createdAt: any;
        };
        agentRemainingBalance: number;
    }>;
    linkUserToAgent(agentId: string, userIdentifier: string): Promise<{
        message: string;
        user: import("mongoose").Document<unknown, {}, UserDocument, {}, import("mongoose").DefaultSchemaOptions> & User & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    } | {
        message: string;
        user: {
            _id: Types.ObjectId;
            userId: string | undefined;
            name: string;
            email: string;
            phone: string | undefined;
            balance: number;
            isActive: boolean;
        };
    }>;
    transferBalance(agentId: string, targetUserId: string, amount: number, note?: string): Promise<{
        message: string;
        newAgentBalance: number;
        user: {
            _id: Types.ObjectId;
            userId: string | undefined;
            name: string;
            newBalance: number;
        };
        transactionId: Types.ObjectId;
    }>;
    toggleUserStatus(agentId: string, targetUserId: string, isActive: boolean, reason?: string): Promise<{
        message: string;
        user: {
            _id: Types.ObjectId;
            userId: string | undefined;
            name: string;
            isActive: boolean;
            deactivatedByAgent: boolean;
            agentDeactivationReason: string;
        };
    } | {
        message: string;
        user: {
            _id: Types.ObjectId;
            userId: string | undefined;
            name: string;
            isActive: boolean;
            deactivatedByAgent: boolean;
            agentDeactivationReason: null;
        };
    }>;
    getTransferHistory(agentId: string): Promise<(import("mongoose").Document<unknown, {}, WalletTransactionDocument, {}, import("mongoose").DefaultSchemaOptions> & WalletTransaction & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
}
