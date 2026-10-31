import { OrdersService } from './orders.service';
import { UserDocument } from '../../database/schemas/user.schema';
import { OrderStatus } from '../../database/schemas/order.schema';
import { ProductType } from '../../database/schemas/product.schema';
export declare class OrdersController {
    private readonly ordersService;
    constructor(ordersService: OrdersService);
    createOrder(user: UserDocument, body: {
        productId: string;
        accountInput?: Record<string, any>;
        requestId?: string;
    }): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
        newBalance: number;
        deliveredCode?: undefined;
    } | {
        message: string;
        order: any;
        newBalance: number;
        deliveredCode: string | undefined;
    }>;
    getMyOrders(user: UserDocument): Promise<(import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    })[]>;
    confirmOrder(id: string, user: UserDocument): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    requestRevision(id: string, user: UserDocument, revisionNotes: string): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    openDispute(id: string, user: UserDocument, disputeReason: string): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    getSupervisorOrders(user: UserDocument, status?: string): Promise<{
        isDelayed: boolean | undefined;
        orderNumber: string;
        requestId?: string;
        userId: import("mongoose").Types.ObjectId;
        appId?: import("mongoose").Types.ObjectId;
        virtualNumberAppId?: import("mongoose").Types.ObjectId;
        productId: import("mongoose").Types.ObjectId;
        providerId?: import("mongoose").Types.ObjectId;
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
        providerSettledAt?: Date;
        assignedSupervisorId?: import("mongoose").Types.ObjectId;
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
        timeline: import("../../database/schemas/order.schema").OrderTimelineEvent[];
        chatMessages: import("../../database/schemas/order.schema").OrderChatMessage[];
        _id: import("mongoose").Types.ObjectId;
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
    supervisorAcceptOrder(id: string, user: UserDocument): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    supervisorRejectOrder(id: string, user: UserDocument, reason: string): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    supervisorStartOrder(id: string, user: UserDocument): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    supervisorRequestInfo(id: string, user: UserDocument, body: {
        note: string;
        attachmentUrl?: string;
    }): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    supervisorDeliverOrder(id: string, user: UserDocument, body: {
        resultNotes?: string;
        credentials?: Record<string, any>;
        attachments?: string[];
    }): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    getOrderMessages(id: string, user: UserDocument): Promise<import("../../database/schemas/order.schema").OrderChatMessage[]>;
    sendOrderMessage(id: string, user: UserDocument, body: {
        message: string;
        attachmentUrl?: string;
        attachmentName?: string;
        attachmentType?: string;
        isSensitive?: boolean;
    }): Promise<import("../../database/schemas/order.schema").OrderChatMessage>;
    getOrderDecryptedCredentials(id: string, user: UserDocument): Promise<{
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
    getOrderDecryptedInput(id: string, user: UserDocument): Promise<{
        orderId: string;
        orderNumber: string;
        isSensitive: boolean;
        sensitiveFields: string[];
        accountInput: Record<string, any>;
    }>;
    getAllOrdersAdmin(status?: OrderStatus, type?: ProductType, supervisorId?: string, isDelayed?: string, search?: string): Promise<any[]>;
    reconcileProviderOrders(limit?: string): Promise<{
        checked: number;
        settled: number;
        refunded: number;
        pending: number;
        flagged: number;
        recovered: number;
        message: string;
    }>;
    adminReassignSupervisor(id: string, user: UserDocument, body: {
        newSupervisorId: string;
        reason?: string;
    }): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    adminRefundOrder(id: string, user: UserDocument, reason: string): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    getOrderById(id: string): Promise<import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
        _id: import("mongoose").Types.ObjectId;
    }> & {
        __v: number;
    } & {
        id: string;
    }>;
    acceptOrder(id: string, body: {
        notes?: string;
    }): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
    rejectOrder(id: string, body: {
        notes: string;
    }): Promise<{
        message: string;
        order: import("mongoose").Document<unknown, {}, import("../../database/schemas/order.schema").OrderDocument, {}, import("mongoose").DefaultSchemaOptions> & import("../../database/schemas/order.schema").Order & import("mongoose").Document<import("mongoose").Types.ObjectId, any, any, Record<string, any>, {}> & Required<{
            _id: import("mongoose").Types.ObjectId;
        }> & {
            __v: number;
        } & {
            id: string;
        };
    }>;
}
