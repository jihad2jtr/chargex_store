class ServiceFieldDef {
  final String
  type; // 'player_id' | 'phone' | 'name' | 'email' | 'password' | 'quantity' | 'custom'
  final String label;
  final bool required;
  final bool isSensitive;
  final String placeholder;

  ServiceFieldDef({
    required this.type,
    required this.label,
    this.required = true,
    this.isSensitive = false,
    this.placeholder = '',
  });

  factory ServiceFieldDef.fromJson(Map<String, dynamic> json) {
    return ServiceFieldDef(
      type: json['type']?.toString() ?? 'custom',
      label: json['label']?.toString() ?? '',
      required: json['required'] != false,
      isSensitive: json['isSensitive'] == true,
      placeholder: json['placeholder']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'label': label,
    'required': required,
    'isSensitive': isSensitive,
    'placeholder': placeholder,
  };
}

class ServiceTemplateModel {
  final String id;
  final String name;
  final String description;
  final String operationType; // 'direct_api' | 'codes' | 'manual'
  final List<ServiceFieldDef> fields;
  final int sortOrder;
  final bool isActive;

  ServiceTemplateModel({
    required this.id,
    required this.name,
    this.description = '',
    this.operationType = 'manual',
    this.fields = const [],
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory ServiceTemplateModel.fromJson(Map<String, dynamic> json) {
    return ServiceTemplateModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      operationType: json['operationType']?.toString() ?? 'manual',
      fields:
          (json['fields'] as List<dynamic>?)
              ?.map(
                (e) => ServiceFieldDef.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
      sortOrder: (json['sortOrder'] is num)
          ? (json['sortOrder'] as num).toInt()
          : 0,
      isActive: json['isActive'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'operationType': operationType,
    'fields': fields.map((e) => e.toJson()).toList(),
    'sortOrder': sortOrder,
    'isActive': isActive,
  };
}
