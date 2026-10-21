class PaymentAccountModel {
  final String id;
  final String type; // 'sham_cash' | 'binance'
  final String accountName;
  final String accountId;
  final String barcodeUrl;
  final bool isActive;

  PaymentAccountModel({
    required this.id,
    required this.type,
    required this.accountName,
    required this.accountId,
    required this.barcodeUrl,
    this.isActive = true,
  });

  factory PaymentAccountModel.fromJson(Map<String, dynamic> json) {
    return PaymentAccountModel(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? 'sham_cash',
      accountName: json['accountName'] ?? '',
      accountId: json['accountId'] ?? '',
      barcodeUrl: json['barcodeUrl'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'accountName': accountName,
      'accountId': accountId,
      'barcodeUrl': barcodeUrl,
      'isActive': isActive,
    };
  }
}
