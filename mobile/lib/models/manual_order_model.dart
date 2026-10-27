class ManualOrderModel {
  final String id;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String type; // 'sham_cash' | 'binance' | 'id_recharge'
  final double amount;
  final Map<String, dynamic> details;
  final String? receiptImageUrl;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? adminNotes;
  final DateTime createdAt;

  ManualOrderModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userEmail,
    this.userPhone,
    required this.type,
    required this.amount,
    this.details = const {},
    this.receiptImageUrl,
    required this.status,
    this.adminNotes,
    required this.createdAt,
  });

  factory ManualOrderModel.fromJson(Map<String, dynamic> json) {
    return ManualOrderModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] is Map
          ? (json['userId']['userId'] ?? json['userId']['_id'] ?? '')
          : (json['userId'] ?? ''),
      userName: json['userId'] is Map ? json['userId']['name'] : null,
      userEmail: json['userId'] is Map ? json['userId']['email'] : null,
      userPhone: json['userId'] is Map ? json['userId']['phone'] : null,
      type: json['type'] ?? 'sham_cash',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : 0.0,
      details: (json['details'] as Map<String, dynamic>?) ?? {},
      receiptImageUrl: json['receiptImageUrl'],
      status: json['status'] ?? 'pending',
      adminNotes: json['adminNotes'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
