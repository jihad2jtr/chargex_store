class AppItemModel {
  final String id;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final String appType; // 'game' | 'app' | 'service'
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

  factory AppItemModel.fromJson(Map<String, dynamic> json) {
    return AppItemModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['nameAr'],
      nameEn: json['nameEn'],
      appType: json['appType'] ?? json['category'] ?? 'game',
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
