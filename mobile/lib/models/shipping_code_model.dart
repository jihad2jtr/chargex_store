class ShippingCodeModel {
  final String id;
  final String code;
  final double amount;
  final bool isUsed;
  final String? usedByName;
  final DateTime? usedAt;
  final bool isActive;
  final DateTime? createdAt;

  ShippingCodeModel({
    required this.id,
    required this.code,
    required this.amount,
    required this.isUsed,
    this.usedByName,
    this.usedAt,
    this.isActive = true,
    this.createdAt,
  });

  factory ShippingCodeModel.fromJson(Map<String, dynamic> json) {
    return ShippingCodeModel(
      id: json['_id'] ?? json['id'] ?? '',
      code: json['code'] ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : 0.0,
      isUsed: json['isUsed'] ?? false,
      usedByName: json['usedBy'] is Map ? json['usedBy']['name'] : null,
      usedAt: json['usedAt'] != null
          ? DateTime.tryParse(json['usedAt'].toString())
          : null,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'amount': amount,
      'isUsed': isUsed,
      'isActive': isActive,
    };
  }
}
