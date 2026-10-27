import 'service_template_model.dart';

class OrderTimelineEventModel {
  final String action;
  final String title;
  final String? description;
  final String performerName;
  final String performerRole;
  final DateTime timestamp;

  OrderTimelineEventModel({
    required this.action,
    required this.title,
    this.description,
    required this.performerName,
    required this.performerRole,
    required this.timestamp,
  });

  factory OrderTimelineEventModel.fromJson(Map<String, dynamic> json) {
    return OrderTimelineEventModel(
      action: json['action'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      performerName: json['performerName'] ?? 'النظام',
      performerRole: json['performerRole'] ?? 'system',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class OrderChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String message;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType;
  final bool isSensitive;
  final DateTime createdAt;

  OrderChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    this.isSensitive = false,
    required this.createdAt,
  });

  factory OrderChatMessageModel.fromJson(Map<String, dynamic> json) {
    return OrderChatMessageModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      senderId:
          (json['senderId'] is Map ? json['senderId']['_id'] : json['senderId'])
              ?.toString() ??
          '',
      senderName: json['senderName'] ?? '',
      senderRole: json['senderRole'] ?? 'user',
      message: json['message'] ?? '',
      attachmentUrl: json['attachmentUrl'],
      attachmentName: json['attachmentName'],
      attachmentType: json['attachmentType'],
      isSensitive: json['isSensitive'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String appId;
  final String appName;
  final String? appIcon;
  final String productId;
  final String productName;
  final String type; // 'direct_api' | 'codes' | 'manual'
  final double amount;
  final double cost;
  final double profit;
  final String status;
  final Map<String, dynamic> accountInput;
  final String? adminNotes;
  final String? deliveredCode;
  final DateTime createdAt;
  final DateTime? completedAt;

  // --- Manual Services & Supervisor Workflow ---
  final String? assignedSupervisorId;
  final String? assignedSupervisorName;
  final String? assignedSupervisorPhone;
  final int estimatedMinutes;
  final DateTime? deadlineAt;
  final bool isDelayed;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? deliveredAt;
  final bool isSensitive;
  final List<String> sensitiveFields;
  final ServiceTemplateModel? serviceTemplate;
  final String? resultNotes;
  final List<String> resultAttachments;
  final bool isResultPurged;
  final String? rejectionReason;
  final String? disputeReason;
  final String? revisionNotes;
  final List<OrderTimelineEventModel> timeline;
  final List<OrderChatMessageModel> chatMessages;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.userId,
    this.userName,
    this.userEmail,
    required this.appId,
    required this.appName,
    this.appIcon,
    required this.productId,
    required this.productName,
    required this.type,
    required this.amount,
    this.cost = 0.0,
    this.profit = 0.0,
    required this.status,
    this.accountInput = const {},
    this.adminNotes,
    this.deliveredCode,
    required this.createdAt,
    this.completedAt,
    this.assignedSupervisorId,
    this.assignedSupervisorName,
    this.assignedSupervisorPhone,
    this.estimatedMinutes = 120,
    this.deadlineAt,
    this.isDelayed = false,
    this.acceptedAt,
    this.startedAt,
    this.deliveredAt,
    this.isSensitive = false,
    this.sensitiveFields = const [],
    this.serviceTemplate,
    this.resultNotes,
    this.resultAttachments = const [],
    this.isResultPurged = false,
    this.rejectionReason,
    this.disputeReason,
    this.revisionNotes,
    this.timeline = const [],
    this.chatMessages = const [],
  });

  bool get isManual => type.toLowerCase() == 'manual';
  String get productType => type;
  String? get customerName => userName;
  bool get isCompleted => status == 'completed';
  bool get isDelivered => status == 'delivered';
  bool get isDisputed => status == 'disputed';
  bool get isRevisionRequested => status == 'revision_requested';
  bool get isInfoRequested => status == 'info_requested';
  bool get isInProgress => status == 'in_progress';
  bool get isAccepted => status == 'accepted';
  bool get isAssigned => status == 'assigned';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isRefunded => status == 'refunded';

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    String? supId;
    String? supName;
    String? supPhone;

    if (json['assignedSupervisorId'] is Map) {
      supId =
          (json['assignedSupervisorId']['_id'] ??
                  json['assignedSupervisorId']['id'])
              ?.toString();
      supName = json['assignedSupervisorId']['name']?.toString();
      supPhone = json['assignedSupervisorId']['phone']?.toString();
    } else if (json['assignedSupervisorId'] != null) {
      supId = json['assignedSupervisorId'].toString();
    }

    final dl = json['deadlineAt'] != null
        ? DateTime.tryParse(json['deadlineAt'].toString())
        : null;
    final now = DateTime.now();
    final st = json['status'] ?? 'pending';
    final delayed =
        json['isDelayed'] == true ||
        (dl != null &&
            now.isAfter(dl) &&
            st != 'completed' &&
            st != 'refunded');

    return OrderModel(
      id: json['_id'] ?? json['id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      userId: json['userId'] is Map
          ? (json['userId']['userId'] ?? json['userId']['_id'] ?? '')
          : (json['userId'] ?? ''),
      userName: json['userId'] is Map
          ? json['userId']['name']
          : json['userName'],
      userEmail: json['userId'] is Map
          ? json['userId']['email']
          : json['userEmail'],
      appId: json['appId'] is Map
          ? json['appId']['_id']
          : (json['appId'] ?? ''),
      appName:
          json['appName'] ??
          (json['appId'] is Map ? json['appId']['name'] : ''),
      appIcon:
          json['appIcon'] ??
          (json['appId'] is Map ? json['appId']['iconUrl'] : null),
      productId: json['productId'] is Map
          ? json['productId']['_id']
          : (json['productId'] ?? ''),
      productName:
          json['productName'] ??
          (json['productId'] is Map ? json['productId']['name'] : ''),
      type: json['type'] ?? 'direct_api',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : 0.0,
      cost: (json['cost'] is num) ? (json['cost'] as num).toDouble() : 0.0,
      profit: (json['profit'] is num)
          ? (json['profit'] as num).toDouble()
          : 0.0,
      status: st,
      accountInput: (json['accountInput'] as Map<String, dynamic>?) ?? {},
      adminNotes: json['adminNotes'],
      deliveredCode: json['deliveredCode'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      assignedSupervisorId: supId,
      assignedSupervisorName: supName,
      assignedSupervisorPhone: supPhone,
      estimatedMinutes: (json['estimatedMinutes'] is num)
          ? (json['estimatedMinutes'] as num).toInt()
          : 120,
      deadlineAt: dl,
      isDelayed: delayed,
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.tryParse(json['acceptedAt'].toString())
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'].toString())
          : null,
      isSensitive: json['isSensitive'] == true,
      sensitiveFields:
          (json['sensitiveFields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      serviceTemplate:
          (json['productId'] is Map &&
              json['productId']['serviceTemplateId'] is Map)
          ? ServiceTemplateModel.fromJson(
              Map<String, dynamic>.from(
                json['productId']['serviceTemplateId'] as Map,
              ),
            )
          : null,
      resultNotes: json['resultNotes'],
      resultAttachments:
          (json['resultAttachments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isResultPurged: json['isResultPurged'] == true,
      rejectionReason: json['rejectionReason'],
      disputeReason: json['disputeReason'],
      revisionNotes: json['revisionNotes'],
      timeline:
          (json['timeline'] as List<dynamic>?)
              ?.map(
                (e) =>
                    OrderTimelineEventModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      chatMessages:
          (json['chatMessages'] as List<dynamic>?)
              ?.map(
                (e) =>
                    OrderChatMessageModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'userId': userId,
      'appId': appId,
      'appName': appName,
      'productId': productId,
      'productName': productName,
      'type': type,
      'amount': amount,
      'cost': cost,
      'profit': profit,
      'status': status,
      'accountInput': accountInput,
      'adminNotes': adminNotes,
      'deliveredCode': deliveredCode,
      'assignedSupervisorId': assignedSupervisorId,
      'estimatedMinutes': estimatedMinutes,
      'isSensitive': isSensitive,
      'resultNotes': resultNotes,
      'rejectionReason': rejectionReason,
      'disputeReason': disputeReason,
      'revisionNotes': revisionNotes,
    };
  }
}
