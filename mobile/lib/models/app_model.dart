class AppItemModel {
  final String id;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final String appType; // 'game' | 'app' | 'service' | 'subscription'
  final String iconUrl;
  final bool isActive;
  final int sortOrder;
  final String? category;
  final String? description;

  AppItemModel({
    required this.id,
    required this.name,
    this.nameAr,
    this.nameEn,
    this.appType = 'game',
    required this.iconUrl,
    this.isActive = true,
    this.sortOrder = 0,
    this.category,
    this.description,
  });

  /// النوع الرئيسي الذي تحدده لوحة الإدارة: game / app / service / subscription.
  /// أي قيمة غير معروفة أو قديمة تُعاد كسلسلة فارغة لكي يستنتج العميل النوع
  /// من اسم العنصر بدلاً من إخفائه من كل الصفحات.
  static String normalizeAppType(dynamic value) {
    switch ((value ?? '').toString().trim().toLowerCase()) {
      case 'game':
      case 'games':
      case 'لعبة':
      case 'ألعاب':
      case 'العاب':
        return 'game';
      case 'app':
      case 'apps':
      case 'application':
      case 'تطبيق':
      case 'تطبيقات':
      case 'برامج':
        return 'app';
      case 'service':
      case 'services':
      case 'خدمة':
      case 'خدمات':
      case 'بطاقة':
      case 'بطاقات':
        return 'service';
      case 'subscription':
      case 'subscriptions':
      case 'اشتراك':
      case 'اشتراكات':
        return 'subscription';
      default:
        return '';
    }
  }

  factory AppItemModel.fromJson(Map<String, dynamic> json) {
    return AppItemModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr'],
      nameEn: json['nameEn'],
      appType: normalizeAppType(json['appType'] ?? json['category']),
      iconUrl: json['iconUrl'] ?? json['image'] ?? '',
      isActive: json['isActive'] ?? true,
      sortOrder: json['sortOrder'] ?? 0,
      category: json['category'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'appType': appType,
      'iconUrl': iconUrl,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'category': category,
      'description': description,
    };
  }
}
