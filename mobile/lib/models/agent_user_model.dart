class AgentUserModel {
  final String id;
  final String? userId; // e.g. JGO26102082359
  final String name;
  final String email;
  final String? phone;
  final double balance;
  final bool isActive;
  final bool deactivatedByAgent;
  final String? agentDeactivationReason;
  final String? agentNotes;
  final DateTime? createdAt;

  AgentUserModel({
    required this.id,
    this.userId,
    required this.name,
    required this.email,
    this.phone,
    required this.balance,
    required this.isActive,
    this.deactivatedByAgent = false,
    this.agentDeactivationReason,
    this.agentNotes,
    this.createdAt,
  });

  String get displayId => (userId != null && userId!.isNotEmpty) ? userId! : id;

  /// Whether user was explicitly frozen by this agent for scam / debt
  bool get isSuspendedByAgent =>
      deactivatedByAgent || (!isActive && agentDeactivationReason != null);

  factory AgentUserModel.fromJson(Map<String, dynamic> json) {
    return AgentUserModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: json['userId']?.toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      balance: (json['balance'] is num)
          ? (json['balance'] as num).toDouble()
          : 0.0,
      isActive: json['isActive'] == true,
      deactivatedByAgent: json['deactivatedByAgent'] == true,
      agentDeactivationReason: json['agentDeactivationReason']?.toString(),
      agentNotes: json['agentNotes']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'balance': balance,
      'isActive': isActive,
      'deactivatedByAgent': deactivatedByAgent,
      'agentDeactivationReason': agentDeactivationReason,
      'agentNotes': agentNotes,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  AgentUserModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    double? balance,
    bool? isActive,
    bool? deactivatedByAgent,
    String? agentDeactivationReason,
    String? agentNotes,
    DateTime? createdAt,
  }) {
    return AgentUserModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
      deactivatedByAgent: deactivatedByAgent ?? this.deactivatedByAgent,
      agentDeactivationReason:
          agentDeactivationReason ?? this.agentDeactivationReason,
      agentNotes: agentNotes ?? this.agentNotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AgentTransferRecord {
  final String id;
  final double amount;
  final String? note;
  final DateTime? createdAt;
  final String recipientName;
  final String recipientUserId;
  final String recipientEmail;
  final String description;

  AgentTransferRecord({
    required this.id,
    required this.amount,
    this.note,
    this.createdAt,
    required this.recipientName,
    required this.recipientUserId,
    required this.recipientEmail,
    this.description = '',
    this.isIncoming = false,
  });

  /// وارد من الإدارة (شحن رصيد) — وإلا فهو صادر إلى أحد العملاء
  final bool isIncoming;

  /// اسم الطرف الآخر: اسم العميل أو «الإدارة»
  String get counterpartyName => recipientName.isNotEmpty
      ? recipientName
      : (isIncoming ? 'الإدارة' : 'عميل تابع');

  // وصف العملية يحمل دائماً اسم العميل وتابعه: «تحويل رصيد للعميل Name (ID)»
  static final RegExp _descRecipientPattern = RegExp(
    r'(?:للعميل|للمستخدم الجديد)\s+([^()]+?)\s*\(([^()]+)\)',
  );

  List<String> get _parsedDescription {
    final match = _descRecipientPattern.firstMatch(description);
    return [
      match?.group(1)?.trim() ?? '',
      // المجموعة 2 تحمل المعرّف: آيدي JGO أو بريد العميل
      match?.group(2)?.trim() ?? '',
    ];
  }

  /// اسم العميل التابع: من المستقبلين، وإلا من تفاصيل وصف العملية
  String get resolvedRecipientName {
    if (recipientName.isNotEmpty) return recipientName;
    if (isIncoming) return '';
    return _parsedDescription[0];
  }

  /// آيدي/بريد العميل التابع: من المستقبلين، وإلا من تفاصيل وصف العملية
  String get resolvedRecipientId {
    if (recipientUserId.isNotEmpty) return recipientUserId;
    if (recipientEmail.isNotEmpty) return recipientEmail;
    if (isIncoming) return '';
    return _parsedDescription[1];
  }

  factory AgentTransferRecord.fromJson(Map<String, dynamic> json) {
    final r = json['counterparty'] ?? json['recipient'];
    String name = '';
    String uId = '';
    String mail = '';

    if (r is Map<String, dynamic>) {
      name = r['name']?.toString() ?? '';
      uId = r['userId']?.toString() ?? '';
      mail = r['email']?.toString() ?? '';
    } else if (r != null) {
      name = r.toString();
    }

    final rawAmount = (json['amount'] is num)
        ? (json['amount'] as num).toDouble()
        : 0.0;
    // الخادم الحديث يرسل direction + مقداراً موجباً، والقديم يرسل إشارة سالبة للصادر
    final String? direction = json['direction']?.toString();
    final bool isIncoming = direction != null
        ? direction == 'in'
        : rawAmount > 0 && json['referenceType']?.toString() != 'AgentTransfer';

    return AgentTransferRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      amount: rawAmount.abs(),
      note: json['note']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      recipientName: name,
      recipientUserId: uId,
      recipientEmail: mail,
      description: json['description']?.toString() ?? '',
      isIncoming: isIncoming,
    );
  }
}

class AgentDashboardStats {
  final int totalSubUsers;
  final int activeSubUsers;
  final int suspendedSubUsers;
  final double totalTransferred;
  final int transferCount;
  final double agentBalance;
  final double totalReceived;
  final int receivedCount;

  AgentDashboardStats({
    this.totalSubUsers = 0,
    this.activeSubUsers = 0,
    this.suspendedSubUsers = 0,
    this.totalTransferred = 0.0,
    this.transferCount = 0,
    this.agentBalance = 0.0,
    this.totalReceived = 0.0,
    this.receivedCount = 0,
  });

  factory AgentDashboardStats.fromJson(
    Map<String, dynamic> json, {
    double agentBalance = 0.0,
  }) {
    final s = json['stats'] as Map<String, dynamic>? ?? {};
    final a = json['agent'] as Map<String, dynamic>? ?? {};
    final bal = (a['balance'] is num)
        ? (a['balance'] as num).toDouble()
        : agentBalance;

    return AgentDashboardStats(
      totalSubUsers: (s['totalSubUsers'] as num?)?.toInt() ?? 0,
      activeSubUsers: (s['activeSubUsers'] as num?)?.toInt() ?? 0,
      suspendedSubUsers: (s['suspendedSubUsers'] as num?)?.toInt() ?? 0,
      totalTransferred: (s['totalTransferred'] is num)
          ? (s['totalTransferred'] as num).toDouble()
          : 0.0,
      transferCount: (s['transferCount'] as num?)?.toInt() ?? 0,
      agentBalance: bal,
      totalReceived: (s['totalReceived'] is num)
          ? (s['totalReceived'] as num).toDouble()
          : 0.0,
      receivedCount: (s['receivedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
