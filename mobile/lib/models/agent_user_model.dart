class AgentUserModel {
  final String id;
  final String? userId; // e.g. chx26102082359
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
  bool get isSuspendedByAgent => deactivatedByAgent || (!isActive && agentDeactivationReason != null);

  factory AgentUserModel.fromJson(Map<String, dynamic> json) {
    return AgentUserModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: json['userId']?.toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      balance: (json['balance'] is num) ? (json['balance'] as num).toDouble() : 0.0,
      isActive: json['isActive'] == true,
      deactivatedByAgent: json['deactivatedByAgent'] == true,
      agentDeactivationReason: json['agentDeactivationReason']?.toString(),
      agentNotes: json['agentNotes']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
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
      agentDeactivationReason: agentDeactivationReason ?? this.agentDeactivationReason,
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

  AgentTransferRecord({
    required this.id,
    required this.amount,
    this.note,
    this.createdAt,
    required this.recipientName,
    required this.recipientUserId,
    required this.recipientEmail,
  });

  factory AgentTransferRecord.fromJson(Map<String, dynamic> json) {
    final r = json['recipient'];
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

    return AgentTransferRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      note: json['note']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      recipientName: name,
      recipientUserId: uId,
      recipientEmail: mail,
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

  AgentDashboardStats({
    this.totalSubUsers = 0,
    this.activeSubUsers = 0,
    this.suspendedSubUsers = 0,
    this.totalTransferred = 0.0,
    this.transferCount = 0,
    this.agentBalance = 0.0,
  });

  factory AgentDashboardStats.fromJson(Map<String, dynamic> json, {double agentBalance = 0.0}) {
    final s = json['stats'] as Map<String, dynamic>? ?? {};
    final a = json['agent'] as Map<String, dynamic>? ?? {};
    final bal = (a['balance'] is num) ? (a['balance'] as num).toDouble() : agentBalance;

    return AgentDashboardStats(
      totalSubUsers: (s['totalSubUsers'] as num?)?.toInt() ?? 0,
      activeSubUsers: (s['activeSubUsers'] as num?)?.toInt() ?? 0,
      suspendedSubUsers: (s['suspendedSubUsers'] as num?)?.toInt() ?? 0,
      totalTransferred: (s['totalTransferred'] is num) ? (s['totalTransferred'] as num).toDouble() : 0.0,
      transferCount: (s['transferCount'] as num?)?.toInt() ?? 0,
      agentBalance: bal,
    );
  }
}
