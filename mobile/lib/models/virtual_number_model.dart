/// نماذج الأرقام الوهمية (تفعيل أرقام التحقق عبر مزود خارجي).
/// الحقول مطابقة لما يُعيده `/virtual-numbers` في الخادم:
/// - `toView` للكتالوج وحالة الطلب الخاصة بالعميل
/// - `toAdminView` يضيف التكلفة والربح وبيانات العميل لشاشة الإدارة
class VirtualNumberCountryOption {
  final String code;
  final String name;
  final String nameAr;
  final String nameEn;
  final String flag;
  final String isoCode;
  final double cost;
  final double salePrice;
  final int count;
  final List<VirtualNumberOperator> operators;

  const VirtualNumberCountryOption({
    required this.code,
    required this.name,
    this.nameAr = '',
    this.nameEn = '',
    this.flag = '🌐',
    this.isoCode = '',
    required this.cost,
    required this.salePrice,
    this.count = 0,
    this.operators = const [],
  });

  factory VirtualNumberCountryOption.fromJson(Map<String, dynamic> json) {
    return VirtualNumberCountryOption(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? json['code'] ?? '').toString(),
      nameAr: (json['nameAr'] ?? '').toString(),
      nameEn: (json['nameEn'] ?? '').toString(),
      flag: (json['flag'] ?? '🌐').toString(),
      isoCode: (json['iso'] ?? json['code'] ?? '').toString(),
      cost: _num(json['cost']),
      salePrice: _num(json['salePrice']),
      count: _num(json['count']).toInt(),
      operators: _operators(json['operators']),
    );
  }
}

class VirtualNumberOperator {
  final String code;
  final String name;

  const VirtualNumberOperator({required this.code, required this.name});

  factory VirtualNumberOperator.fromJson(Map<String, dynamic> json) {
    return VirtualNumberOperator(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? json['code'] ?? '').toString(),
    );
  }
}

class VirtualNumberServiceOption {
  final String code;
  final String name;
  final String nameAr;
  final String nameEn;
  final String icon;
  final String herosmsCode;
  final String fivesimCode;
  final double fromPrice;
  final List<VirtualNumberCountryOption> countries;

  const VirtualNumberServiceOption({
    required this.code,
    required this.name,
    this.nameAr = '',
    this.nameEn = '',
    this.icon = '',
    this.herosmsCode = '',
    this.fivesimCode = '',
    required this.fromPrice,
    required this.countries,
  });

  factory VirtualNumberServiceOption.fromJson(Map<String, dynamic> json) {
    final countries = (json['countries'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (e) =>
              VirtualNumberCountryOption.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
    return VirtualNumberServiceOption(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? json['code'] ?? '').toString(),
      nameAr: (json['nameAr'] ?? '').toString(),
      nameEn: (json['nameEn'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      herosmsCode: (json['herosmsCode'] ?? '').toString(),
      fivesimCode: (json['fivesimCode'] ?? '').toString(),
      fromPrice: _num(json['fromPrice']),
      countries: countries,
    );
  }

  /// أرخص سعر معروض على البطاقة
  double get bestPrice => fromPrice > 0
      ? fromPrice
      : (countries.isEmpty ? 0 : countries.first.salePrice);
}

/// خدمة يدوية للأرقام (تفعيل مضمون) — القسم الأول في صفحة أرقام العميل.
/// هي منتج (type=manual) بلا تطبيق متجر، مرتبطة بتطبيق أرقام ومُسندة لمشرف؛
/// طلبها يمر عبر `/orders` نفسه فيظهر في «طلباتي» وفي مساحة المشرف.
class VirtualNumberManualServiceModel {
  final String id;
  final String name;
  final String description;
  final String instructions;
  final double price;
  final List<String> requiredFields;
  final List<String> sensitiveFields;
  final bool isSensitive;
  final int estimatedMinutes;
  final bool isActive;
  final String appId;
  final String appName;
  final String appIcon;
  final String appServiceCode;
  final String supervisorId;
  final String supervisorName;
  final int openOrders;

  const VirtualNumberManualServiceModel({
    required this.id,
    required this.name,
    this.description = '',
    this.instructions = '',
    required this.price,
    this.requiredFields = const [],
    this.sensitiveFields = const [],
    this.isSensitive = false,
    this.estimatedMinutes = 120,
    this.isActive = true,
    this.appId = '',
    this.appName = '',
    this.appIcon = '',
    this.appServiceCode = '',
    this.supervisorId = '',
    this.supervisorName = '',
    this.openOrders = 0,
  });

  factory VirtualNumberManualServiceModel.fromJson(Map<String, dynamic> json) {
    return VirtualNumberManualServiceModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      instructions: (json['instructions'] ?? '').toString(),
      price: _num(json['price']),
      requiredFields: (json['requiredFields'] as List? ?? const <dynamic>[])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      sensitiveFields: (json['sensitiveFields'] as List? ?? const <dynamic>[])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      isSensitive: json['isSensitive'] == true,
      estimatedMinutes: _num(json['estimatedMinutes']).toInt(),
      isActive: json['isActive'] != false,
      appId: (json['appId'] ?? '').toString(),
      appName: (json['appName'] ?? '').toString(),
      appIcon: (json['appIcon'] ?? '').toString(),
      appServiceCode: (json['appServiceCode'] ?? '').toString(),
      supervisorId: (json['supervisorId'] ?? '').toString(),
      supervisorName: (json['supervisorName'] ?? '').toString(),
      openOrders: _num(json['openOrders']).toInt(),
    );
  }

  /// الوقت المتوقع للتنفيذ بصيغة مختصرة عربية
  String get etaLabel {
    if (estimatedMinutes <= 0) return '';
    if (estimatedMinutes < 60) return '$estimatedMinutes دقيقة';
    final hours = (estimatedMinutes / 60).floor();
    final mins = estimatedMinutes % 60;
    return mins == 0 ? '$hours ساعة' : '$hours س و $mins د';
  }
}

/// استجابة `GET /virtual-numbers/options`
class VirtualNumberOptions {
  /// مهلة الانتظار المعتمدة في الخادم (VIRTUAL_NUMBER_TTL_MINUTES)
  static const int _defaultWaitMinutes = 20;

  final bool available;
  final bool providerOnline;

  /// المزود مُسجَّل لكنه موقوف: تُخفى الصفحة ويُمسح المخزّن
  final bool providerStopped;
  final int waitMinutes;
  final List<VirtualNumberServiceOption> services;

  /// القسم الأول في صفحة الأرقام: خدمات التفعيل المضمون (يدوية بمشرف)
  final List<VirtualNumberManualServiceModel> manualServices;

  // لا اسم للمزود ولا رسائله الداخلية هنا: الصفحة للعميل، ومورد الخدمة
  // شأن داخلي؛ لذا تُتجاهل أي حقول أسماء تصل من الخادم
  const VirtualNumberOptions({
    this.available = false,
    this.providerOnline = false,
    this.providerStopped = false,
    this.waitMinutes = _defaultWaitMinutes,
    this.services = const [],
    this.manualServices = const [],
  });

  factory VirtualNumberOptions.fromJson(Map<String, dynamic> json) {
    final wait = _num(json['waitMinutes']).toInt();
    return VirtualNumberOptions(
      available: json['available'] == true,
      providerOnline: json['providerOnline'] == true,
      providerStopped: json['providerStopped'] == true,
      // صفر أو غياب: تبقى مهلة الخادم الافتراضية حتى لا تقرأ الصفحة «0 دقيقة»
      waitMinutes: wait > 0 ? wait : _defaultWaitMinutes,
      services: (json['services'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (e) => VirtualNumberServiceOption.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
      manualServices: (json['manualServices'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (e) => VirtualNumberManualServiceModel.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }

  static VirtualNumberOptions empty() => const VirtualNumberOptions();
}

/// طلب رقم واحد — سواء من `GET /virtual-numbers/my` أو من شاشة الإدارة
class VirtualNumberRequestModel {
  final String id;
  final String requestNumber;
  final String service;
  final String serviceName;
  final String nameAr;
  final String nameEn;
  final String icon;
  final String country;
  final String countryName;
  final String flag;
  final String operator;
  final double amount;
  final String? phoneNumber;
  final String? smsCode;
  final String? smsText;
  final String status;
  final bool isLive;
  final String note;

  /// سبب الإدارة الداخلي: يُقرأ في اللوحة وحدها، فلا يظهر في سجل العميل
  final String adminNote;
  final DateTime? expiresAt;
  final DateTime? codeReceivedAt;
  final DateTime? refundedAt;
  final DateTime? createdAt;

  // حقول الإدارة فقط
  final double cost;
  final double profit;
  final String providerRef;
  final String userName;
  final String customUserId;
  final String userEmail;
  final String userPhone;

  const VirtualNumberRequestModel({
    required this.id,
    required this.requestNumber,
    this.service = '',
    this.serviceName = '',
    this.nameAr = '',
    this.nameEn = '',
    this.icon = '',
    this.country = '',
    this.countryName = '',
    this.flag = '🌐',
    this.operator = '',
    this.amount = 0,
    this.phoneNumber,
    this.smsCode,
    this.smsText,
    this.status = 'pending',
    this.isLive = false,
    this.note = '',
    this.adminNote = '',
    this.expiresAt,
    this.codeReceivedAt,
    this.refundedAt,
    this.createdAt,
    this.cost = 0,
    this.profit = 0,
    this.providerRef = '',
    this.userName = '',
    this.customUserId = '',
    this.userEmail = '',
    this.userPhone = '',
  });

  factory VirtualNumberRequestModel.fromJson(Map<String, dynamic> json) {
    return VirtualNumberRequestModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      requestNumber: (json['requestNumber'] ?? '').toString(),
      service: (json['service'] ?? '').toString(),
      serviceName: (json['serviceName'] ?? '').toString(),
      nameAr: (json['nameAr'] ?? '').toString(),
      nameEn: (json['nameEn'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      countryName: (json['countryName'] ?? '').toString(),
      flag: (json['flag'] ?? '🌐').toString(),
      operator: (json['operator'] ?? '').toString(),
      amount: _num(json['amount']),
      phoneNumber: _text(json['phoneNumber']),
      smsCode: _text(json['smsCode']),
      smsText: _text(json['smsText']),
      status: (json['status'] ?? 'pending').toString(),
      isLive: json['isLive'] == true,
      note: (json['note'] ?? '').toString(),
      adminNote: (json['adminNote'] ?? '').toString(),
      expiresAt: _date(json['expiresAt']),
      codeReceivedAt: _date(json['codeReceivedAt']),
      refundedAt: _date(json['refundedAt']),
      createdAt: _date(json['createdAt']),
      cost: _num(json['cost']),
      profit: _num(json['profit']),
      providerRef: (json['providerRef'] ?? '').toString(),
      userName: (json['userName'] ?? '').toString(),
      customUserId: (json['customUserId'] ?? '').toString(),
      userEmail: (json['userEmail'] ?? '').toString(),
      userPhone: (json['userPhone'] ?? '').toString(),
    );
  }

  static const String pending = 'pending';
  static const String waiting = 'waiting';
  static const String received = 'received';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String expired = 'expired';
  static const String failed = 'failed';

  /// الرمز جاهز للعرض: يصل فور قراءة الرسالة ويبقى معروضاً بعد إغلاق الطلب
  bool get hasCode => smsCode != null && smsCode!.isNotEmpty;

  bool get isRefunded => refundedAt != null;

  bool get isWaitingForCode =>
      isLive && !hasCode && (status == pending || status == waiting);

  /// هل سُلّمت الخدمة فعلاً أم أُرجع المبلغ؟ تُستعمل في تلوين بطاقة السجل
  bool get isSettled => status == completed || hasCode;

  String get title => serviceName.isNotEmpty ? serviceName : service;

  String get subtitle {
    final parts = <String>[
      if (countryName.isNotEmpty) countryName,
      if (operator.isNotEmpty) operator,
    ];
    return parts.join(' • ');
  }

  String get statusLabel {
    switch (status) {
      case pending:
        return 'جارٍ التجهيز';
      case waiting:
        return 'بانتظار الرمز';
      case received:
        return 'وصل الرمز';
      case completed:
        return 'تم الاستلام';
      case cancelled:
        return 'ملغى';
      case expired:
        return 'انتهت المهلة';
      case failed:
        return 'فشل';
      default:
        return status;
    }
  }

  /// ثوانٍ متبقية للمهلة، أو null إن لا مهلة قائمة
  int? remainingSeconds([DateTime? now]) {
    final end = expiresAt;
    if (end == null || !isLive) return null;
    final reference = now ?? DateTime.now();
    final left = end.difference(reference).inSeconds;
    return left > 0 ? left : 0;
  }
}

/// إحصاءات شاشة الإدارة (`GET /virtual-numbers/admin/stats`)
class VirtualNumberStats {
  final int total;
  final double revenue;
  final double cost;
  final double profit;
  final Map<String, VirtualNumberStatusStat> byStatus;
  final VirtualNumberProviderInfo? provider;

  const VirtualNumberStats({
    this.total = 0,
    this.revenue = 0,
    this.cost = 0,
    this.profit = 0,
    this.byStatus = const {},
    this.provider,
  });

  factory VirtualNumberStats.fromJson(Map<String, dynamic> json) {
    final raw = json['byStatus'];
    final byStatus = <String, VirtualNumberStatusStat>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          byStatus[key.toString()] = VirtualNumberStatusStat.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }
    final provider = json['provider'];
    return VirtualNumberStats(
      total: _num(json['total']).toInt(),
      revenue: _num(json['revenue']),
      cost: _num(json['cost']),
      profit: _num(json['profit']),
      byStatus: byStatus,
      provider: provider is Map
          ? VirtualNumberProviderInfo.fromJson(
              Map<String, dynamic>.from(provider),
            )
          : null,
    );
  }

  int countOf(String status) => byStatus[status]?.count ?? 0;

  static VirtualNumberStats empty() => const VirtualNumberStats();
}

class VirtualNumberStatusStat {
  final int count;
  final double amount;
  final double cost;

  const VirtualNumberStatusStat({
    this.count = 0,
    this.amount = 0,
    this.cost = 0,
  });

  factory VirtualNumberStatusStat.fromJson(Map<String, dynamic> json) =>
      VirtualNumberStatusStat(
        count: _num(json['count']).toInt(),
        amount: _num(json['amount']),
        cost: _num(json['cost']),
      );
}

class VirtualNumberProviderInfo {
  final String id;
  final String name;
  final String status;
  final bool isActive;
  final double balance;
  final String lastError;

  const VirtualNumberProviderInfo({
    this.id = '',
    this.name = '',
    this.status = '',
    this.isActive = false,
    this.balance = 0,
    this.lastError = '',
  });

  factory VirtualNumberProviderInfo.fromJson(Map<String, dynamic> json) =>
      VirtualNumberProviderInfo(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        isActive: json['isActive'] == true,
        balance: _num(json['balance']),
        lastError: (json['lastError'] ?? '').toString(),
      );
}

// ===========================================================================
// المُنتقَى في لوحة الإدارة: تطبيقات الأرقام (خدمة) ودولها (منتجات)
// نفس نموذج المتجر: التطبيق يُنشأ فارغاً من «إدارة الأرقام»، ثم تُنتقى دوله
// من كتالوج المزود في صفحة مزودي الأرقام، وتُفعَّل أو تُعطَّل لكل دولة.
// ===========================================================================

/// عنصر من `GET /virtual-numbers/admin/apps`
class VirtualNumberAppModel {
  final String id;
  final String name;
  final String iconUrl;
  final String serviceCode;
  final bool isActive;
  final int sortOrder;
  final int productCount;
  final int activeProductCount;
  final List<VirtualNumberAppCountry> countries;

  const VirtualNumberAppModel({
    required this.id,
    required this.name,
    this.iconUrl = '',
    required this.serviceCode,
    this.isActive = true,
    this.sortOrder = 0,
    this.productCount = 0,
    this.activeProductCount = 0,
    this.countries = const [],
  });

  factory VirtualNumberAppModel.fromJson(Map<String, dynamic> json) =>
      VirtualNumberAppModel(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        iconUrl: (json['iconUrl'] ?? '').toString(),
        serviceCode: (json['serviceCode'] ?? '').toString(),
        isActive: json['isActive'] != false,
        sortOrder: _num(json['sortOrder']).toInt(),
        productCount: _num(json['productCount']).toInt(),
        activeProductCount: _num(json['activeProductCount']).toInt(),
        countries:
            (json['countries'] as List?)
                ?.map(
                  (e) => VirtualNumberAppCountry.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList() ??
            const [],
      );

  /// العميل لا يرى الخدمة إلا إذا كان للتطبيق دولة مفعّلة واحدة على الأقل
  bool get visibleToClients => isActive && activeProductCount > 0;
}

/// دولة داخل بطاقة تطبيق الأرقام (تُعرض مباشرة بدون فتح الكتالوج)
class VirtualNumberAppCountry {
  final String code;
  final String name;
  final bool active;

  const VirtualNumberAppCountry({
    required this.code,
    required this.name,
    this.active = true,
  });

  factory VirtualNumberAppCountry.fromJson(Map<String, dynamic> json) =>
      VirtualNumberAppCountry(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? json['code'] ?? '').toString(),
        active: json['active'] != false,
      );
}

/// دولة داخل كتالوج المزود مع حالة انتقائها (من `admin/catalog`)
class VirtualNumberCatalogCountry {
  final String code;
  final String name;
  final String nameAr;
  final String nameEn;
  final String flag;
  final double cost;
  final int count;
  final List<VirtualNumberOperator> operators;
  final double salePrice;
  final bool added;
  final String productId;
  final bool productActive;

  const VirtualNumberCatalogCountry({
    required this.code,
    required this.name,
    this.nameAr = '',
    this.nameEn = '',
    this.flag = '🌐',
    this.cost = 0,
    this.count = 0,
    this.operators = const [],
    this.salePrice = 0,
    this.added = false,
    this.productId = '',
    this.productActive = false,
  });

  factory VirtualNumberCatalogCountry.fromJson(Map<String, dynamic> json) =>
      VirtualNumberCatalogCountry(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? json['code'] ?? '').toString(),
        nameAr: (json['nameAr'] ?? '').toString(),
        nameEn: (json['nameEn'] ?? '').toString(),
        flag: (json['flag'] ?? '🌐').toString(),
        cost: _num(json['cost']),
        count: _num(json['count']).toInt(),
        operators: _operators(json['operators']),
        salePrice: _num(json['salePrice']),
        added: json['added'] == true,
        productId: (json['productId'] ?? '').toString(),
        productActive: json['productActive'] == true,
      );
}

/// خدمة كاملة بدولها في كتالوج الإدارة، مع تطبيقها المرافق إن وُجد
class VirtualNumberCatalogService {
  final String code;
  final String name;
  final String nameAr;
  final String nameEn;
  final String icon;
  final int countryCount;
  final String appId;
  final String appName;
  final bool appActive;
  final List<VirtualNumberCatalogCountry> countries;

  const VirtualNumberCatalogService({
    required this.code,
    required this.name,
    this.nameAr = '',
    this.nameEn = '',
    this.icon = '',
    this.countryCount = 0,
    this.appId = '',
    this.appName = '',
    this.appActive = false,
    this.countries = const [],
  });

  factory VirtualNumberCatalogService.fromJson(Map<String, dynamic> json) =>
      VirtualNumberCatalogService(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? json['code'] ?? '').toString(),
        nameAr: (json['nameAr'] ?? '').toString(),
        nameEn: (json['nameEn'] ?? '').toString(),
        icon: (json['icon'] ?? '').toString(),
        countryCount: _num(json['countryCount']).toInt(),
        appId: (json['appId'] ?? '').toString(),
        appName: (json['appName'] ?? '').toString(),
        appActive: json['appActive'] == true,
        countries: (json['countries'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (e) => VirtualNumberCatalogCountry.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(),
      );

  int get addedCount => countries.where((c) => c.added).length;
}

/// استجابة `GET /virtual-numbers/admin/catalog`
class VirtualNumberAdminCatalog {
  final String providerId;
  final String providerName;
  final String providerStatus;
  final String marginType;
  final double marginValue;
  final List<VirtualNumberCatalogService> services;

  const VirtualNumberAdminCatalog({
    this.providerId = '',
    this.providerName = '',
    this.providerStatus = '',
    this.marginType = 'percentage',
    this.marginValue = 0,
    this.services = const [],
  });

  factory VirtualNumberAdminCatalog.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] is Map
        ? Map<String, dynamic>.from(json['provider'] as Map)
        : const <String, dynamic>{};
    final margin = json['margin'] is Map
        ? Map<String, dynamic>.from(json['margin'] as Map)
        : const <String, dynamic>{};
    return VirtualNumberAdminCatalog(
      providerId: (provider['id'] ?? '').toString(),
      providerName: (provider['name'] ?? '').toString(),
      providerStatus: (provider['status'] ?? '').toString(),
      marginType: (margin['type'] ?? 'percentage').toString(),
      marginValue: _num(margin['value']),
      services: (json['services'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (e) => VirtualNumberCatalogService.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }

  static VirtualNumberAdminCatalog empty() => const VirtualNumberAdminCatalog();
}

double _num(dynamic value) => value is num ? value.toDouble() : 0.0;

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

List<VirtualNumberOperator> _operators(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => VirtualNumberOperator.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
