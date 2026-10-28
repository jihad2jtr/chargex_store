import { AgentService } from './agent.service';
import { Role } from '../../common/interfaces/role.enum';
import { UserDocument } from '../../database/schemas/user.schema';
export declare class AgentController {
    private readonly agentService;
    constructor(agentService: AgentService);
    getDashboard(agent: UserDocument): Promise<{
        agent: {
            id: import("mongoose").Types.ObjectId;
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
            totalReceived: number;
            receivedCount: any;
        };
        recentTransfers: (import("mongoose").Document<unknown, {}, import("../../database/schemas/wallet-transaction.schema").WalletTransactionDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/wallet-transaction.schema").WalletTransaction & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        })[];
    }>;
    getMyUsers(agent: UserDocument, search?: string, status?: 'all' | 'active' | 'suspended'): Promise<{
        _id: import("mongoose").Types.ObjectId;
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
    createUser(agent: UserDocument, body: {
        name: string;
        email: string;
        password: string;
        phone?: string;
        initialBalance?: number;
        notes?: string;
    }): Promise<{
        message: string;
        user: {
            _id: import("mongoose").Types.ObjectId;
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
    linkUser(agent: UserDocument, userIdentifier: string): Promise<{
        message: string;
        user: import("mongoose").Document<unknown, {}, UserDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/user.schema").User & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    } | {
        message: string;
        user: {
            _id: import("mongoose").Types.ObjectId;
            userId: string | undefined;
            name: string;
            email: string;
            phone: string | undefined;
            balance: number;
            isActive: boolean;
        };
    }>;
    transferBalance(agent: UserDocument, body: {
        userId: string;
        amount: number;
        note?: string;
    }): Promise<{
        message: string;
        newAgentBalance: number;
        user: {
            _id: import("mongoose").Types.ObjectId;
            userId: string | undefined;
            name: string;
            newBalance: number;
        };
        transactionId: import("mongoose").Types.ObjectId;
    }>;
    toggleUserStatus(agent: UserDocument, userId: string, body: {
        isActive: boolean;
        reason?: string;
    }): Promise<{
        message: string;
        user: {
            _id: import("mongoose").Types.ObjectId;
            userId: string | undefined;
            name: string;
            isActive: boolean;
            deactivatedByAgent: boolean;
            agentDeactivationReason: string;
        };
    } | {
        message: string;
        user: {
            _id: import("mongoose").Types.ObjectId;
            userId: string | undefined;
            name: string;
            isActive: boolean;
            deactivatedByAgent: boolean;
            agentDeactivationReason: null;
        };
    }>;
    getTransfers(agent: UserDocument): Promise<{
        _id: import("mongoose").Types.ObjectId;
        createdAt: any;
        direction: string;
        amount: number;
        description: string;
        referenceType: string;
        counterparty: {
            name: any;
            userId: any;
            email: any;
        };
        recipient: {
            name: any;
            userId: any;
            email: any;
        };
    }[]>;
}
