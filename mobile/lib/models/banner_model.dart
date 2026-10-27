class BannerModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String actionType; // 'none' | 'topup' | 'app' | 'url'
  final String? actionValue;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;

  BannerModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.imageUrl,
    this.actionType = 'topup',
    this.actionValue,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      actionType: json['actionType'] ?? 'topup',
      actionValue: json['actionValue']?.toString(),
      isActive: json['isActive'] ?? true,
      sortOrder: (json['sortOrder'] is num)
          ? (json['sortOrder'] as num).toInt()
          : 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'actionType': actionType,
      'actionValue': actionValue,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }
}
