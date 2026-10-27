import 'service_template_model.dart';

class ProductModel {
  final String id;
  final String appId;
  final String name;
  final String? description;
  final String? serviceTemplateId;
  final ServiceTemplateModel? serviceTemplate;
  final String quantityLabel;
  final String kind; // الفئة التفصيلية: 'quantity' | 'package' | فئة مخصصة
  final String type; // 'direct_api', 'codes', 'manual'
  final String? providerId;
  final String? providerProductCode;
  final double costPrice;
  final String profitMarginType; // 'percentage' | 'fixed'
  final double profitMarginValue;
  final double salePrice;
  final double? previousPrice;
  final bool hasPriceChanged;
  final bool isActive;
  final int availableCodesCount;
  final List<String> requiredFields; // e.g. ['Player ID', 'Server ID']
  final bool
  providerAvailable; // false when the upstream provider is down/disabled

  // Manual Services Configuration
  final String? assignedSupervisorId;
  final String? assignedSupervisorName;
  final int estimatedMinutes;
  final bool isSensitive;
  final List<String> sensitiveFields;
  final String? instructions;

  ProductModel({
    required this.id,
    required this.appId,
    required this.name,
    this.description,
    this.serviceTemplateId,
    this.serviceTemplate,
    this.quantityLabel = '',
    this.kind = 'quantity',
    this.type = 'direct_api',
    this.providerId,
    this.providerProductCode,
    required this.costPrice,
    this.profitMarginType = 'percentage',
    this.profitMarginValue = 10.0,
    required this.salePrice,
    this.previousPrice,
    this.hasPriceChanged = false,
    this.isActive = true,
    this.availableCodesCount = 0,
    this.requiredFields = const [],
    this.providerAvailable = true,
    this.assignedSupervisorId,
    this.assignedSupervisorName,
    this.estimatedMinutes = 120,
    this.isSensitive = false,
    this.sensitiveFields = const [],
    this.instructions,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    String? supId;
    String? supName;
    if (json['assignedSupervisorId'] is Map) {
      supId =
          (json['assignedSupervisorId']['_id'] ??
                  json['assignedSupervisorId']['id'])
              ?.toString();
      supName = json['assignedSupervisorId']['name']?.toString();
    } else if (json['assignedSupervisorId'] != null) {
      supId = json['assignedSupervisorId'].toString();
    }

    return ProductModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      appId: json['appId'] is Map
          ? (json['appId']['_id'] ?? json['appId']['id'] ?? '').toString()
          : (json['appId']?.toString() ?? ''),
      name: json['name'] ?? '',
      description: json['description'],
      serviceTemplateId: json['serviceTemplateId'] is Map
          ? (json['serviceTemplateId']['_id'] ??
                    json['serviceTemplateId']['id'])
                ?.toString()
          : json['serviceTemplateId']?.toString(),
      serviceTemplate: json['serviceTemplateId'] is Map
          ? ServiceTemplateModel.fromJson(
              Map<String, dynamic>.from(json['serviceTemplateId'] as Map),
            )
          : null,
      quantityLabel: json['quantityLabel']?.toString() ?? '',
      kind: (json['kind']?.toString().trim().isNotEmpty ?? false)
          ? json['kind'].toString().trim()
          : 'quantity',
      type: json['type'] ?? 'direct_api',
      providerId: json['providerId'] is Map
          ? (json['providerId']['_id'] ?? json['providerId']['id'] ?? '')
                .toString()
          : json['providerId']?.toString(),
      providerProductCode: json['providerProductCode'],
      costPrice: (json['costPrice'] is num)
          ? (json['costPrice'] as num).toDouble()
          : 0.0,
      profitMarginType: json['profitMarginType'] ?? 'percentage',
      profitMarginValue: (json['profitMarginValue'] is num)
          ? (json['profitMarginValue'] as num).toDouble()
          : 0.0,
      salePrice: (json['salePrice'] is num)
          ? (json['salePrice'] as num).toDouble()
          : 0.0,
      previousPrice: (json['previousPrice'] is num)
          ? (json['previousPrice'] as num).toDouble()
          : null,
      hasPriceChanged: json['hasPriceChanged'] ?? false,
      isActive: json['isActive'] ?? true,
      availableCodesCount: json['availableCodesCount'] ?? 0,
      requiredFields:
          (json['requiredFields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      providerAvailable: json['providerAvailable'] != false,
      assignedSupervisorId: supId,
      assignedSupervisorName: supName,
      estimatedMinutes: (json['estimatedMinutes'] is num)
          ? (json['estimatedMinutes'] as num).toInt()
          : 120,
      isSensitive: json['isSensitive'] == true,
      sensitiveFields:
          (json['sensitiveFields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      instructions: json['instructions'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appId': appId,
      'name': name,
      'description': description,
      'serviceTemplateId': serviceTemplateId,
      'quantityLabel': quantityLabel,
      'kind': kind,
      'type': type,
      'providerId': providerId,
      'providerProductCode': providerProductCode,
      'costPrice': costPrice,
      'profitMarginType': profitMarginType,
      'profitMarginValue': profitMarginValue,
      'salePrice': salePrice,
      'previousPrice': previousPrice,
      'hasPriceChanged': hasPriceChanged,
      'isActive': isActive,
      'availableCodesCount': availableCodesCount,
      'requiredFields': requiredFields,
      'providerAvailable': providerAvailable,
      'assignedSupervisorId': assignedSupervisorId,
      'estimatedMinutes': estimatedMinutes,
      'isSensitive': isSensitive,
      'sensitiveFields': sensitiveFields,
      'instructions': instructions,
    };
  }
}
