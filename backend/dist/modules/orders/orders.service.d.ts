import { Model, Types } from 'mongoose';
import { Order, OrderDocument, OrderStatus, OrderTimelineEvent, OrderChatMessage } from '../../database/schemas/order.schema';
import { ProductDocument, ProductType } from '../../database/schemas/product.schema';
import { AppDocument } from '../../database/schemas/app.schema';
import { UserDocument } from '../../database/schemas/user.schema';
import { WalletTransactionDocument } from '../../database/schemas/wallet-transaction.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { ProvidersService } from '../providers/providers.service';
export declare class OrdersService {
    private orderModel;
    private productModel;
    private appModel;
    private userModel;
    private transactionModel;
    private notificationsService;
    private providersService;
    private readonly logger;
    constructor(orderModel: Model<OrderDocument>, productModel: Model<ProductDocument>, appModel: Model<AppDocument>, userModel: Model<UserDocument>, transactionModel: Model<WalletTransactionDocument>, notificationsService: NotificationsService, providersService: ProvidersService);
    private generateOrderNumber;
    createOrder(params: {
        userId: string;
        productId: string;
        accountInput?: Record<string, any>;
    }): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
        newBalance: number;
        deliveredCode: string | undefined;
    }>;
    getMyOrders(userId: string): Promise<(import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    getOrderById(id: string): Promise<import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    getSupervisorOrders(supervisorId: string, filter?: {
        status?: string;
    }): Promise<{
        isDelayed: boolean | undefined;
        orderNumber: string;
        userId: Types.ObjectId;
        appId: Types.ObjectId;
        productId: Types.ObjectId;
        providerId?: Types.ObjectId;
        type: ProductType;
        amount: number;
        cost: number;
        profit: number;
        status: OrderStatus;
        accountInput: Record<string, any>;
        adminNotes?: string;
        deliveredCode?: string;
        providerReference?: string;
        providerResponse?: Record<string, any>;
        assignedSupervisorId?: Types.ObjectId;
        estimatedMinutes?: number;
        deadlineAt?: Date;
        acceptedAt?: Date;
        startedAt?: Date;
        deliveredAt?: Date;
        completedAt?: Date;
        isSensitive?: boolean;
        sensitiveFields?: string[];
        encryptedResultData?: string;
        resultNotes?: string;
        resultAttachments?: string[];
        isResultPurged?: boolean;
        purgedAt?: Date;
        rejectionReason?: string;
        disputeReason?: string;
        revisionNotes?: string;
        timeline: OrderTimelineEvent[];
        chatMessages: OrderChatMessage[];
        _id: Types.ObjectId;
        $locals: Record<string, unknown>;
        $op: "save" | "validate" | "remove" | null;
        $where: Record<string, unknown>;
        baseModelName?: string;
        collection: import("mongoose").Collection;
        db: import("mongoose").Connection;
        errors?: import("mongoose").Error.ValidationError;
        isNew: boolean;
        schema: import("mongoose").Schema;
        __v: number;
    }[]>;
    getAllOrdersAdmin(filter?: {
        status?: OrderStatus;
        type?: ProductType;
        supervisorId?: string;
        isDelayed?: boolean;
        search?: string;
    }): Promise<{
        isDelayed: boolean | undefined;
        orderNumber: string;
        userId: Types.ObjectId;
        appId: Types.ObjectId;
        productId: Types.ObjectId;
        providerId?: Types.ObjectId;
        type: ProductType;
        amount: number;
        cost: number;
        profit: number;
        status: OrderStatus;
        accountInput: Record<string, any>;
        adminNotes?: string;
        deliveredCode?: string;
        providerReference?: string;
        providerResponse?: Record<string, any>;
        assignedSupervisorId?: Types.ObjectId;
        estimatedMinutes?: number;
        deadlineAt?: Date;
        acceptedAt?: Date;
        startedAt?: Date;
        deliveredAt?: Date;
        completedAt?: Date;
        isSensitive?: boolean;
        sensitiveFields?: string[];
        encryptedResultData?: string;
        resultNotes?: string;
        resultAttachments?: string[];
        isResultPurged?: boolean;
        purgedAt?: Date;
        rejectionReason?: string;
        disputeReason?: string;
        revisionNotes?: string;
        timeline: OrderTimelineEvent[];
        chatMessages: OrderChatMessage[];
        _id: Types.ObjectId;
        $locals: Record<string, unknown>;
        $op: "save" | "validate" | "remove" | null;
        $where: Record<string, unknown>;
        baseModelName?: string;
        collection: import("mongoose").Collection;
        db: import("mongoose").Connection;
        errors?: import("mongoose").Error.ValidationError;
        isNew: boolean;
        schema: import("mongoose").Schema;
        __v: number;
    }[]>;
    supervisorAcceptOrder(orderId: string, supervisor: UserDocument): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    supervisorRejectOrder(orderId: string, supervisor: UserDocument, reason: string): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    supervisorStartOrder(orderId: string, supervisor: UserDocument): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    supervisorRequestInfo(orderId: string, supervisor: UserDocument, data: {
        note: string;
        attachmentUrl?: string;
    }): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    supervisorDeliverOrder(orderId: string, supervisor: UserDocument, data: {
        resultNotes?: string;
        credentials?: Record<string, any>;
        attachments?: string[];
    }): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    customerConfirmOrder(orderId: string, user: UserDocument): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    customerRequestRevision(orderId: string, user: UserDocument, revisionNotes: string): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    customerOpenDispute(orderId: string, user: UserDocument, disputeReason: string): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    adminReassignSupervisor(orderId: string, newSupervisorId: string, admin: UserDocument, reason?: string): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    adminRefundOrder(orderId: string, admin: UserDocument, reason: string): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    getOrderMessages(orderId: string, user: UserDocument): Promise<OrderChatMessage[]>;
    sendOrderMessage(orderId: string, user: UserDocument, data: {
        message: string;
        attachmentUrl?: string;
        attachmentName?: string;
        attachmentType?: string;
        isSensitive?: boolean;
    }): Promise<OrderChatMessage>;
    getOrderDecryptedResult(orderId: string, user: UserDocument): Promise<{
        isPurged: boolean;
        purgedAt: Date | undefined;
        message: string;
        credentials: null;
    } | {
        isPurged: boolean;
        credentials: null;
        message: string;
        purgedAt?: undefined;
    } | {
        isPurged: boolean;
        credentials: any;
        purgedAt?: undefined;
        message?: undefined;
    }>;
    acceptManualOrder(id: string, notes?: string): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    rejectManualOrder(id: string, notes: string): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & Order & import("mongoose").Document<Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
}
