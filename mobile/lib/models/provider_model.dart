class ProviderModel {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String? apiSecret;
  // 'bay2game' | 'foxreload' | 'fivesim' | 'herosms' | 'custom'
  final String providerType;
  final Map<String, dynamic> headers;
  final String status; // 'online' | 'offline' | 'error'
  final String? lastError;
  final DateTime? lastCheckAt;
  final double balance;
  final String profitMarginType; // 'percentage' | 'fixed'
  final double profitMarginValue;
  final bool isActive;

  ProviderModel({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    this.apiSecret,
    this.providerType = '',
    this.headers = const {},
    this.status = 'offline',
    this.lastError,
    this.lastCheckAt,
    this.balance = 0.0,
    this.profitMarginType = 'percentage',
    this.profitMarginValue = 10.0,
    this.isActive = true,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    return ProviderModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      baseUrl: json['baseUrl'] ?? '',
      apiKey: json['apiKey'] ?? '',
      apiSecret: json['apiSecret'],
      providerType: (json['providerType'] ?? '').toString(),
      headers: (json['headers'] as Map<String, dynamic>?) ?? {},
      status: json['status'] ?? 'offline',
      lastError: json['lastError'],
      lastCheckAt: json['lastCheckAt'] != null
          ? DateTime.tryParse(json['lastCheckAt'].toString())
          : null,
      balance: (json['balance'] is num)
          ? (json['balance'] as num).toDouble()
          : 0.0,
      profitMarginType: json['profitMarginType'] ?? 'percentage',
      profitMarginValue: (json['profitMarginValue'] is num)
          ? (json['profitMarginValue'] as num).toDouble()
          : 10.0,
      isActive: json['isActive'] ?? true,
    );
  }

  /// مزود أرقام التحقق الوهمية (5sim / Hero-SMS): صفحته مستقلة عن مزودي المتاجر
  /// لأنه لا يخدم منتجات ولا كتالوج تطبيقات، بل إصدار أرقام مؤقتة.
  /// السجلات القديمة قد تخلو من النوع، فيُستدل عليه من الاسم أو الرابط.
  bool get isVirtualNumber {
    final String type = providerType.trim().toLowerCase();
    if (type == 'fivesim' || type == 'herosms') return true;
    if (type == 'bay2game' || type == 'foxreload') return false;
    final String haystack = '$name $baseUrl'.toLowerCase();
    return haystack.contains('5sim') ||
        haystack.contains('herosms') ||
        haystack.contains('hero-sms');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'apiSecret': apiSecret,
      'providerType': providerType,
      'headers': headers,
      'status': status,
      'lastError': lastError,
      'balance': balance,
      'profitMarginType': profitMarginType,
      'profitMarginValue': profitMarginValue,
      'isActive': isActive,
    };
  }
}
