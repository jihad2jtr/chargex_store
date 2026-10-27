import { Document, Types } from 'mongoose';
import { ProductType } from './product.schema';
export type OrderDocument = Order & Document;
export declare enum OrderStatus {
    PENDING = "pending",
    ASSIGNED = "assigned",
    ACCEPTED = "accepted",
    IN_PROGRESS = "in_progress",
    INFO_REQUESTED = "info_requested",
    DELIVERED = "delivered",
    REVISION_REQUESTED = "revision_requested",
    DISPUTED = "disputed",
    COMPLETED = "completed",
    REJECTED = "rejected",
    REFUNDED = "refunded"
}
export declare class OrderTimelineEvent {
    action: string;
    title: string;
    description?: string;
    performerId?: Types.ObjectId;
    performerName: string;
    performerRole: string;
    timestamp: Date;
}
export declare const OrderTimelineEventSchema: import("mongoose").Schema<OrderTimelineEvent, import("mongoose").Model<OrderTimelineEvent, any, any, any, any, any, OrderTimelineEvent & {
    _id: Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, OrderTimelineEvent, Document<unknown, {}, OrderTimelineEvent, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<OrderTimelineEvent & {
    _id: Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    action?: import("mongoose").SchemaDefinitionProperty<string, OrderTimelineEvent, Document<unknown, {}, OrderTimelineEvent, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderTimelineEvent & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    title?: import("mongoose").SchemaDefinitionProperty<string, OrderTimelineEvent, Document<unknown, {}, OrderTimelineEvent, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderTimelineEvent & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    description?: import("mongoose").SchemaDefinitionProperty<string | undefined, OrderTimelineEvent, Document<unknown, {}, OrderTimelineEvent, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderTimelineEvent & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    performerId?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId | undefined, OrderTimelineEvent, Document<unknown, {}, OrderTimelineEvent, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderTimelineEvent & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    performerName?: import("mongoose").SchemaDefinitionProperty<string, OrderTimelineEvent, Document<unknown, {}, OrderTimelineEvent, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderTimelineEvent & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    performerRole?: import("mongoose").SchemaDefinitionProperty<string, OrderTimelineEvent, Document<unknown, {}, OrderTimelineEvent, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderTimelineEvent & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    timestamp?: import("mongoose").SchemaDefinitionProperty<Date, OrderTimelineEvent, Document<unknown, {}, OrderTimelineEvent, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderTimelineEvent & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, OrderTimelineEvent>;
export declare class OrderChatMessage {
    senderId: Types.ObjectId;
    senderName: string;
    senderRole: string;
    message: string;
    attachmentUrl?: string;
    attachmentName?: string;
    attachmentType?: string;
    isSensitive?: boolean;
    createdAt: Date;
}
export declare const OrderChatMessageSchema: import("mongoose").Schema<OrderChatMessage, import("mongoose").Model<OrderChatMessage, any, any, any, any, any, OrderChatMessage & {
    _id: Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, OrderChatMessage, Document<unknown, {}, OrderChatMessage, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<OrderChatMessage & {
    _id: Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    senderId?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId, OrderChatMessage, Document<unknown, {}, OrderChatMessage, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderChatMessage & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    senderName?: import("mongoose").SchemaDefinitionProperty<string, OrderChatMessage, Document<unknown, {}, OrderChatMessage, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderChatMessage & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    senderRole?: import("mongoose").SchemaDefinitionProperty<string, OrderChatMessage, Document<unknown, {}, OrderChatMessage, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderChatMessage & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    message?: import("mongoose").SchemaDefinitionProperty<string, OrderChatMessage, Document<unknown, {}, OrderChatMessage, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderChatMessage & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    attachmentUrl?: import("mongoose").SchemaDefinitionProperty<string | undefined, OrderChatMessage, Document<unknown, {}, OrderChatMessage, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderChatMessage & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    attachmentName?: import("mongoose").SchemaDefinitionProperty<string | undefined, OrderChatMessage, Document<unknown, {}, OrderChatMessage, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderChatMessage & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    attachmentType?: import("mongoose").SchemaDefinitionProperty<string | undefined, OrderChatMessage, Document<unknown, {}, OrderChatMessage, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderChatMessage & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    isSensitive?: import("mongoose").SchemaDefinitionProperty<boolean | undefined, OrderChatMessage, Document<unknown, {}, OrderChatMessage, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderChatMessage & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    createdAt?: import("mongoose").SchemaDefinitionProperty<Date, OrderChatMessage, Document<unknown, {}, OrderChatMessage, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<OrderChatMessage & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, OrderChatMessage>;
export declare class Order {
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
    providerSettledAt?: Date;
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
}
export declare const OrderSchema: import("mongoose").Schema<Order, import("mongoose").Model<Order, any, any, any, any, any, Order & {
    _id: Types.ObjectId;
} & {
    __v: number;
}>, {}, {}, {}, {}, import("mongoose").DefaultSchemaOptions, Order, Document<unknown, {}, Order, {
    id: string;
}, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
    _id: Types.ObjectId;
} & {
    __v: number;
}, "id"> & import("mongoose").HydratedDocumentOverrides<{
    id: string;
}>, {
    orderNumber?: import("mongoose").SchemaDefinitionProperty<string, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    userId?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    appId?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    productId?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    providerId?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    type?: import("mongoose").SchemaDefinitionProperty<ProductType, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    amount?: import("mongoose").SchemaDefinitionProperty<number, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    cost?: import("mongoose").SchemaDefinitionProperty<number, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    profit?: import("mongoose").SchemaDefinitionProperty<number, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    status?: import("mongoose").SchemaDefinitionProperty<OrderStatus, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    accountInput?: import("mongoose").SchemaDefinitionProperty<Record<string, any>, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    adminNotes?: import("mongoose").SchemaDefinitionProperty<string | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    deliveredCode?: import("mongoose").SchemaDefinitionProperty<string | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    providerReference?: import("mongoose").SchemaDefinitionProperty<string | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    providerResponse?: import("mongoose").SchemaDefinitionProperty<Record<string, any> | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    providerSettledAt?: import("mongoose").SchemaDefinitionProperty<Date | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    assignedSupervisorId?: import("mongoose").SchemaDefinitionProperty<Types.ObjectId | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    estimatedMinutes?: import("mongoose").SchemaDefinitionProperty<number | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    deadlineAt?: import("mongoose").SchemaDefinitionProperty<Date | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    acceptedAt?: import("mongoose").SchemaDefinitionProperty<Date | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    startedAt?: import("mongoose").SchemaDefinitionProperty<Date | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    deliveredAt?: import("mongoose").SchemaDefinitionProperty<Date | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    completedAt?: import("mongoose").SchemaDefinitionProperty<Date | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    isSensitive?: import("mongoose").SchemaDefinitionProperty<boolean | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    sensitiveFields?: import("mongoose").SchemaDefinitionProperty<string[] | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    encryptedResultData?: import("mongoose").SchemaDefinitionProperty<string | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    resultNotes?: import("mongoose").SchemaDefinitionProperty<string | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    resultAttachments?: import("mongoose").SchemaDefinitionProperty<string[] | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    isResultPurged?: import("mongoose").SchemaDefinitionProperty<boolean | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    purgedAt?: import("mongoose").SchemaDefinitionProperty<Date | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    rejectionReason?: import("mongoose").SchemaDefinitionProperty<string | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    disputeReason?: import("mongoose").SchemaDefinitionProperty<string | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    revisionNotes?: import("mongoose").SchemaDefinitionProperty<string | undefined, Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    timeline?: import("mongoose").SchemaDefinitionProperty<OrderTimelineEvent[], Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
    chatMessages?: import("mongoose").SchemaDefinitionProperty<OrderChatMessage[], Order, Document<unknown, {}, Order, {
        id: string;
    }, import("mongoose").DefaultSchemaOptions> & Omit<Order & {
        _id: Types.ObjectId;
    } & {
        __v: number;
    }, "id"> & import("mongoose").HydratedDocumentOverrides<{
        id: string;
    }>> | undefined;
}, Order>;
