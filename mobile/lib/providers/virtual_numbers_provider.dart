import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/services/cache_service.dart';
import '../models/virtual_number_model.dart';

/// حالة الأرقام الوهمية عند العميل ولوحة الإدارة.
///
/// الطبيعة هنا مختلفة عن بقية المشتريات: الطلب يبقى حيّاً دقائق انتظاراً لرمز
/// التحقق، فيُستعمل مسح دوري من الواجهة (Polling) بدل انتظار رد واحد طويل،
/// ويُحفظ معرّف الإرسال (clientRequestId) كي لا تُكرر المحاولة بعد انقطاع.
class VirtualNumbersProvider extends ChangeNotifier {
  static const Duration _pollInterval = Duration(seconds: 8);

  VirtualNumberOptions _options = VirtualNumberOptions.empty();
  List<VirtualNumberRequestModel> _myRequests = const [];
  List<VirtualNumberRequestModel> _adminRequests = const [];
  VirtualNumberStats _stats = VirtualNumberStats.empty();
  List<VirtualNumberAppModel> _adminApps = const [];
  VirtualNumberAdminCatalog _adminCatalog = VirtualNumberAdminCatalog.empty();
  List<VirtualNumberManualServiceModel> _adminManualServices = const [];

  bool _isLoadingOptions = false;
  bool _isLoadingRequests = false;
  bool _isSubmitting = false;
  bool _isAdminLoading = false;
  bool _isAppsLoading = false;
  bool _isCatalogLoading = false;
  bool _isManualLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  Timer? _pollTimer;
  bool _polling = false;

  final ApiClient _api = ApiClient();

  VirtualNumberOptions get options => _options;
  List<VirtualNumberRequestModel> get myRequests => _myRequests;
  List<VirtualNumberRequestModel> get adminRequests => _adminRequests;
  VirtualNumberStats get stats => _stats;
  List<VirtualNumberAppModel> get adminApps => _adminApps;
  VirtualNumberAdminCatalog get adminCatalog => _adminCatalog;
  List<VirtualNumberManualServiceModel> get adminManualServices =>
      _adminManualServices;
  bool get isLoadingOptions => _isLoadingOptions;
  bool get isLoadingRequests => _isLoadingRequests;
  bool get isSubmitting => _isSubmitting;
  bool get isAdminLoading => _isAdminLoading;
  bool get isAppsLoading => _isAppsLoading;
  bool get isCatalogLoading => _isCatalogLoading;
  bool get isManualLoading => _isManualLoading;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  /// الرقم الحيّ المعروض في أعلى الصفحة (طلب واحد فقط لكل عميل)
  VirtualNumberRequestModel? get activeRequest {
    for (final request in _myRequests) {
      if (request.isLive) return request;
    }
    return null;
  }

  /// آخر طلب منتهٍ — يُعرض في السجل وفي تنبيه الإرجاع التلقائي
  VirtualNumberRequestModel? get lastRequest =>
      _myRequests.isEmpty ? null : _myRequests.first;

  bool get hasActiveRequest => activeRequest != null;

  VirtualNumbersProvider() {
    _loadFromCache();
  }

  void _loadFromCache() {
    final cached = CacheService.instance.getList(
      'vn_my_requests',
      VirtualNumberRequestModel.fromJson,
    );
    if (cached != null && cached.isNotEmpty) {
      _myRequests = cached;
    }
    final cachedOptions = CacheService.instance.getList(
      'vn_options',
      _serviceFromJson,
    );
    final cachedManual = CacheService.instance.getList(
      'vn_manual_services',
      VirtualNumberManualServiceModel.fromJson,
    );
    if ((cachedOptions != null && cachedOptions.isNotEmpty) ||
        (cachedManual != null && cachedManual.isNotEmpty)) {
      _options = VirtualNumberOptions(
        available: true,
        services: cachedOptions ?? const [],
        manualServices: cachedManual ?? const [],
      );
    }
  }

  static VirtualNumberServiceOption _serviceFromJson(
    Map<String, dynamic> json,
  ) => VirtualNumberServiceOption.fromJson(json);

  void clearMessages() {
    _errorMessage = null;
    _infoMessage = null;
  }

  // ===========================================================================
  // الكتالوج
  // ===========================================================================

  Future<void> fetchOptions({bool forceRefresh = false}) async {
    if (_options.services.isEmpty) {
      _isLoadingOptions = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final res = await _api.get(ApiConstants.virtualNumberOptions);
      if (res is Map) {
        final parsed = VirtualNumberOptions.fromJson(
          Map<String, dynamic>.from(res),
        );
        _options = parsed;
        if (parsed.services.isNotEmpty) {
          CacheService.instance.setList(
            'vn_options',
            parsed.services,
            _serviceToJson,
          );
        } else if (parsed.providerStopped || !parsed.available) {
          // المزود موقوف أو لا خدمات مُنتقاة: يُمسح المخزّن حتى لا تبقى
          // أرقام قديمة معروضة للعميل بعد الإخفاء أو تعطيل المزود.
          await CacheService.instance.remove('vn_options');
        }
        // خدمات «تفعيل مضمون» تُخزّن وحدها: offline يبقى القسم الأول معروضاً
        if (parsed.manualServices.isNotEmpty) {
          CacheService.instance.setList(
            'vn_manual_services',
            parsed.manualServices,
            _manualServiceToJson,
          );
        } else {
          await CacheService.instance.remove('vn_manual_services');
        }
      }
    } catch (e) {
      // المخزّن يبقى معروضاً: تعذّر التحديث لا يعني أن الصفحة فارغة
      if (_options.services.isEmpty) {
        _errorMessage = _clientError(e);
      }
    }
    _isLoadingOptions = false;
    notifyListeners();
  }

  /// خطأ يُعرض على شاشة العميل: رسالة الخادم العربية كما هي (صارت عامة ولا
  /// تحمل أسماء مزودين)، وأي استثناء آخر يستبدل عبارة موحّدة بدل تفريغ تفاصيله
  static String _clientError(Object e) => e is ApiException
      ? e.message
      : 'تعذّر الاتصال بالخدمة، يرجى المحاولة لاحقاً';

  static Map<String, dynamic> _serviceToJson(
    VirtualNumberServiceOption service,
  ) => {
    'code': service.code,
    'name': service.name,
    'nameAr': service.nameAr,
    'nameEn': service.nameEn,
    'icon': service.icon,
    'herosmsCode': service.herosmsCode,
    'fivesimCode': service.fivesimCode,
    'fromPrice': service.fromPrice,
    'countries': service.countries
        .map(
          (c) => {
            'code': c.code,
            'name': c.name,
            'nameAr': c.nameAr,
            'nameEn': c.nameEn,
            'flag': c.flag,
            'iso': c.isoCode,
            'cost': c.cost,
            'salePrice': c.salePrice,
            'count': c.count,
            'operators': c.operators
                .map((o) => {'code': o.code, 'name': o.name})
                .toList(),
          },
        )
        .toList(),
  };

  /// تخزين خدمات «تفعيل مضمون» محلياً (نفس الحقول التي يقرأها من `options`)
  static Map<String, dynamic> _manualServiceToJson(
    VirtualNumberManualServiceModel service,
  ) => {
    'id': service.id,
    'name': service.name,
    'description': service.description,
    'instructions': service.instructions,
    'price': service.price,
    'requiredFields': service.requiredFields,
    'sensitiveFields': service.sensitiveFields,
    'isSensitive': service.isSensitive,
    'estimatedMinutes': service.estimatedMinutes,
    'isActive': service.isActive,
    'appId': service.appId,
    'appName': service.appName,
    'appIcon': service.appIcon,
    'appServiceCode': service.appServiceCode,
    'supervisorId': service.supervisorId,
    'supervisorName': service.supervisorName,
  };

  // ===========================================================================
  // طلب رقم
  // ===========================================================================

  /// يُعيد رسالة النجاح من الخادم، أو null عند الفشل (في [errorMessage])
  Future<String?> requestNumber({
    required String service,
    required String country,
    String? operator,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    // معرّف ثابت لكل محاولة إرسال: يبقى بعد إغلاق التطبيق فتعيد المحاولة نفسها
    // نفس المعرّف بدل طلب رقم ثانٍ وخصم ثانٍ
    const reqKey = 'pending_vn_request';
    final stored = await CacheService.instance.getOrLoad(reqKey);
    var clientRequestId = stored is String && stored.isNotEmpty ? stored : null;
    if (clientRequestId == null) {
      clientRequestId =
          'VN-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0xFFFFFF)}';
      await CacheService.instance.set(reqKey, clientRequestId);
    }

    try {
      final res = await _api.post(
        ApiConstants.virtualNumberRequest,
        body: {
          'service': service,
          'country': country,
          if (operator != null && operator.isNotEmpty) 'operator': operator,
          'clientRequestId': clientRequestId,
        },
        // تجهيز الرقم عند المزود قد يتجاوز المهلة الافتراضية
        timeout: const Duration(seconds: 75),
      );
      await CacheService.instance.remove(reqKey);
      await _applyList(res, fallback: 'fetch');
      _isSubmitting = false;
      _startPolling();
      notifyListeners();
      return _messageFrom(res) ?? 'تم تجهيز الرقم، سيصل الرمز تلقائياً';
    } on ApiException catch (e) {
      // الخادم لم يردّ: قد يكون الرقم طُلب فعلاً — لا نُمسح المعرّف كي لا يتكرر الطلب
      final noResponse = e.statusCode == null;
      if (!noResponse) {
        await CacheService.instance.remove(reqKey);
      }
      _errorMessage = noResponse
          ? 'انقطع الاتصال أثناء تجهيز الرقم؛ طلبك محفوظ وقيد التحقق التلقائي، '
                'وقد يصلك الرقم خلال دقائق — افتح صفحة الأرقام لمتابعته.'
          : e.message;
      // الخادم قد يكون قد أنشأ الطلب رغم رسالة الخطأ (مهلة/حالة معلّقة)
      await _applyList(null, fallback: 'fetch');
      _isSubmitting = false;
      _startPolling();
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = _clientError(e);
      _isSubmitting = false;
      notifyListeners();
      return null;
    }
  }

  // ===========================================================================
  // سجل العميل والمسح الدوري للواجهة
  // ===========================================================================

  Future<void> fetchMyRequests({bool quiet = false}) async {
    if (!quiet && _myRequests.isEmpty) {
      _isLoadingRequests = true;
      notifyListeners();
    }
    try {
      final res = await _api.get(ApiConstants.virtualNumberMy);
      if (res is List) {
        _myRequests = res
            .whereType<Map>()
            .map(
              (e) => VirtualNumberRequestModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList();
        CacheService.instance.setList(
          'vn_my_requests',
          _myRequests,
          _requestToJson,
        );
      }
    } catch (e) {
      if (!quiet && _myRequests.isEmpty) _errorMessage = _clientError(e);
    }
    if (!quiet) {
      _isLoadingRequests = false;
      notifyListeners();
    }
  }

  /// [payload] قد يحمل `{message, request, newBalance}` بعد إنشاء الطلب
  Future<void> _applyList(dynamic payload, {required String fallback}) async {
    if (payload is Map && payload['request'] is Map) {
      final created = VirtualNumberRequestModel.fromJson(
        Map<String, dynamic>.from(payload['request'] as Map),
      );
      final rest = _myRequests.where((r) => r.id != created.id).toList();
      _myRequests = [created, ...rest];
      await CacheService.instance.setList(
        'vn_my_requests',
        _myRequests,
        _requestToJson,
      );
      return;
    }
    await fetchMyRequests(quiet: fallback == 'poll');
  }

  static Map<String, dynamic> _requestToJson(VirtualNumberRequestModel r) => {
    'id': r.id,
    'requestNumber': r.requestNumber,
    'service': r.service,
    'serviceName': r.serviceName,
    'country': r.country,
    'countryName': r.countryName,
    'operator': r.operator,
    'amount': r.amount,
    'phoneNumber': r.phoneNumber,
    'smsCode': r.smsCode,
    'smsText': r.smsText,
    'status': r.status,
    'isLive': r.isLive,
    'note': r.note,
    'expiresAt': r.expiresAt?.toIso8601String(),
    'codeReceivedAt': r.codeReceivedAt?.toIso8601String(),
    'refundedAt': r.refundedAt?.toIso8601String(),
    'createdAt': r.createdAt?.toIso8601String(),
  };

  static String? _messageFrom(dynamic payload) =>
      payload is Map && payload['message'] is String
      ? payload['message'] as String
      : null;

  // --- Polling ---------------------------------------------------------------

  /// تشغيل فحص دوري أثناء وجود رقم حيّ: يُظهر الرمز فور وصوله ويكشف الإرجاع
  /// التلقائي عند انتهاء المهلة حتى لو بقيت الصفحة مفتوحة.
  void startAutoPolling() {
    _startPolling();
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    if (!hasActiveRequest) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (_polling || !hasActiveRequest) {
      if (!hasActiveRequest) stopPolling();
      return;
    }
    _polling = true;
    try {
      await fetchMyRequests(quiet: true);
      if (!hasActiveRequest) stopPolling();
      notifyListeners();
    } finally {
      _polling = false;
    }
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// فحص فوري بزر التحديث في الصفحة
  Future<void> refreshActive() async {
    await fetchMyRequests();
    _startPolling();
    notifyListeners();
  }

  /// إغلاق الرقم: بعد وصول الرمز يُنهى الطلب، وقبله يُلغى ويُرجع المبلغ
  Future<String?> closeRequest(String id) async {
    _errorMessage = null;
    try {
      final res = await _api.post(
        '${ApiConstants.virtualNumbers}/$id/close',
        body: const {},
      );
      await fetchMyRequests(quiet: true);
      stopPolling();
      _startPolling();
      notifyListeners();
      return _messageFrom(res);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = _clientError(e);
      notifyListeners();
      return null;
    }
  }

  // ===========================================================================
  // لوحة الإدارة
  // ===========================================================================

  Future<void> fetchAdminRequests({
    String status = 'all',
    String search = '',
    int limit = 100,
  }) async {
    _isAdminLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await _api.get(
        ApiConstants.adminVirtualNumbers,
        queryParams: {
          if (status != 'all') 'status': status,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          'limit': limit,
        },
      );
      _adminRequests = (res is List)
          ? res
                .whereType<Map>()
                .map(
                  (e) => VirtualNumberRequestModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [];
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isAdminLoading = false;
    notifyListeners();
  }

  Future<void> fetchAdminStats() async {
    try {
      final res = await _api.get(ApiConstants.adminVirtualNumbersStats);
      if (res is Map) {
        _stats = VirtualNumberStats.fromJson(Map<String, dynamic>.from(res));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<String?> adminSyncCatalog() =>
      _adminAction(ApiConstants.adminVirtualNumbersSync);

  Future<String?> adminCheckProvider() =>
      _adminAction(ApiConstants.adminVirtualNumbersCheck);

  Future<String?> adminRunSweep() async {
    final message = await _adminAction(ApiConstants.adminVirtualNumbersSweep);
    if (message != null) {
      await fetchAdminRequests();
      await fetchAdminStats();
    }
    return message;
  }

  Future<String?> adminCancel(String id, {String? reason}) => _adminAction(
    '${ApiConstants.virtualNumbers}/admin/$id/cancel',
    body: {'reason': ?reason},
  );

  Future<String?> adminFinish(String id) =>
      _adminAction('${ApiConstants.virtualNumbers}/admin/$id/finish');

  // ===========================================================================
  // المُنتقَى في اللوحة: تطبيقات الأرقام (خدمة) ودولها (منتجات)
  // نفس مسار المتجر: تطبيق يُنشأ فارغاً ← دول تُنتقى من كتالوج المزود ←
  // تفعيل/إلغاء تفعيل لكل دولة يتحكم فيما يراه العميل في صفحة الأرقام
  // ===========================================================================

  Future<void> fetchAdminApps({bool quiet = false}) async {
    if (!quiet) {
      _isAppsLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      final res = await _api.get(ApiConstants.adminVirtualNumberApps);
      _adminApps = (res is List)
          ? res
                .whereType<Map>()
                .map(
                  (e) => VirtualNumberAppModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [];
    } catch (e) {
      if (!quiet) _errorMessage = _clientError(e);
    }
    _isAppsLoading = false;
    notifyListeners();
  }

  /// يُنشئ تطبيقاً فارغاً للخدمة (تطابق serviceCode واحدة في الخادم)
  Future<String?> createAdminApp({
    required String name,
    required String serviceCode,
    String? providerId,
    String? iconUrl,
  }) => _curationAction(
    ApiConstants.adminVirtualNumberApps,
    method: 'POST',
    body: {
      'name': name,
      'serviceCode': serviceCode,
      if (providerId != null && providerId.isNotEmpty) 'providerId': providerId,
      if (iconUrl != null && iconUrl.isNotEmpty) 'iconUrl': iconUrl,
    },
    fallback: 'تم إنشاء التطبيق',
  );

  Future<String?> updateAdminApp(
    String id, {
    String? name,
    String? iconUrl,
    int? sortOrder,
  }) => _curationAction(
    '${ApiConstants.adminVirtualNumberApps}/$id',
    method: 'PATCH',
    body: {'name': ?name, 'iconUrl': ?iconUrl, 'sortOrder': ?sortOrder},
    fallback: 'تم تحديث التطبيق',
  );

  Future<String?> toggleAdminApp(String id) => _curationAction(
    '${ApiConstants.adminVirtualNumberApps}/$id/toggle',
    method: 'PATCH',
    fallback: 'تم تحديث حالة التطبيق',
  );

  Future<String?> deleteAdminApp(String id) => _curationAction(
    '${ApiConstants.adminVirtualNumberApps}/$id',
    method: 'DELETE',
    fallback: 'تم حذف التطبيق',
  );

  /// مُسرِّع التنسيق: تطبيق لكل خدمة في كتالوج المزود لم تُضَف بعد
  Future<String?> bulkCreateAdminApps({String? providerId}) => _curationAction(
    ApiConstants.adminVirtualNumberAppsBulk,
    method: 'POST',
    body: {
      if (providerId != null && providerId.isNotEmpty) 'providerId': providerId,
    },
    fallback: 'تمت إضافة التطبيقات',
    onDone: () => fetchAdminApps(quiet: true),
  );

  /// كتالوج المزود مُثري بالمُنتقَى: كل دولة مُعلَّم عليها added/productId
  Future<void> fetchAdminCatalog({String? providerId}) async {
    _isCatalogLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await _api.get(
        ApiConstants.adminVirtualNumberCatalog,
        queryParams: {
          if (providerId != null && providerId.isNotEmpty)
            'providerId': providerId,
        },
      );
      _adminCatalog = res is Map
          ? VirtualNumberAdminCatalog.fromJson(Map<String, dynamic>.from(res))
          : VirtualNumberAdminCatalog.empty();
    } catch (e) {
      _errorMessage = _clientError(e);
    }
    _isCatalogLoading = false;
    notifyListeners();
  }

  /// إضافة دول مختارة من الكتالوج إلى تطبيق (تُتجاهل الدول الموجودة مسبقاً)
  Future<String?> addCountriesToApp({
    required String appId,
    required List<VirtualNumberCatalogCountry> countries,
    String? providerId,
  }) => _curationAction(
    ApiConstants.adminVirtualNumberAddCountries,
    method: 'POST',
    body: {
      'appId': appId,
      if (providerId != null && providerId.isNotEmpty) 'providerId': providerId,
      'countries': countries
          .map(
            (c) => {
              'code': c.code,
              'name': c.name,
              'cost': c.cost,
              'count': c.count,
              'operators': c.operators
                  .map((o) => {'code': o.code, 'name': o.name})
                  .toList(),
            },
          )
          .toList(),
    },
    fallback: 'تمت إضافة الدول',
  );

  /// تفعيل/إلغاء تفعيل دولة: تظهر أو تختفي من صفحة الأرقام عند العميل
  Future<String?> toggleAdminProduct(String id) => _curationAction(
    '${ApiConstants.virtualNumbers}/admin/products/$id/toggle',
    method: 'PATCH',
    fallback: 'تم تحديث حالة الدولة',
  );

  Future<String?> removeAdminProduct(String id) => _curationAction(
    '${ApiConstants.virtualNumbers}/admin/products/$id',
    method: 'DELETE',
    fallback: 'تم حذف الدولة',
  );

  // ===========================================================================
  // خدمات الأرقام اليدوية (تفعيل مضمون): شاشة إدارة + قسم أول عند العميل
  // ===========================================================================

  Future<void> fetchAdminManualServices({bool quiet = false}) async {
    if (!quiet) {
      _isManualLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      final res = await _api.get(ApiConstants.adminVirtualNumberManualServices);
      _adminManualServices = (res is List)
          ? res
                .whereType<Map>()
                .map(
                  (e) => VirtualNumberManualServiceModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [];
    } catch (e) {
      if (!quiet) _errorMessage = _clientError(e);
    }
    _isManualLoading = false;
    notifyListeners();
  }

  Future<String?> createAdminManualService(Map<String, dynamic> body) =>
      _manualAction(
        ApiConstants.adminVirtualNumberManualServices,
        method: 'POST',
        body: body,
        fallback: 'تمت إضافة الخدمة',
      );

  Future<String?> updateAdminManualService(
    String id,
    Map<String, dynamic> body,
  ) => _manualAction(
    '${ApiConstants.adminVirtualNumberManualServices}/$id',
    method: 'PATCH',
    body: body,
    fallback: 'تم تحديث الخدمة',
  );

  Future<String?> toggleAdminManualService(String id) => _manualAction(
    '${ApiConstants.adminVirtualNumberManualServices}/$id/toggle',
    method: 'PATCH',
    fallback: 'تم تحديث حالة الخدمة',
  );

  Future<String?> deleteAdminManualService(String id) => _manualAction(
    '${ApiConstants.adminVirtualNumberManualServices}/$id',
    method: 'DELETE',
    fallback: 'تم حذف الخدمة',
  );

  Future<String?> _manualAction(
    String path, {
    required String method,
    Object? body,
    required String fallback,
  }) async {
    _errorMessage = null;
    _infoMessage = null;
    _isManualLoading = true;
    notifyListeners();
    try {
      final res = await switch (method) {
        'POST' => _api.post(path, body: body ?? const {}),
        'PATCH' => _api.patch(path, body: body ?? const {}),
        'DELETE' => _api.delete(path),
        _ => _api.get(path),
      };
      final message = _messageFrom(res) ?? fallback;
      _infoMessage = message;
      await fetchAdminManualServices(quiet: true);
      _isManualLoading = false;
      notifyListeners();
      return message;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = _clientError(e);
    }
    _isManualLoading = false;
    notifyListeners();
    return null;
  }

  Future<String?> _curationAction(
    String path, {
    required String method,
    Object? body,
    required String fallback,
    Future<void> Function()? onDone,
  }) async {
    _errorMessage = null;
    _infoMessage = null;
    _isAppsLoading = true;
    notifyListeners();
    try {
      final res = await switch (method) {
        'POST' => _api.post(path, body: body ?? const {}),
        'PATCH' => _api.patch(path, body: body ?? const {}),
        'DELETE' => _api.delete(path),
        _ => _api.get(path),
      };
      final message = _messageFrom(res) ?? fallback;
      _infoMessage = message;
      await onDone?.call();
      _isAppsLoading = false;
      notifyListeners();
      return message;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = _clientError(e);
    }
    _isAppsLoading = false;
    notifyListeners();
    return null;
  }

  Future<String?> _adminAction(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    _errorMessage = null;
    _infoMessage = null;
    _isAdminLoading = true;
    notifyListeners();
    try {
      final res = await _api.post(path, body: body ?? const {});
      final message = _messageFrom(res);
      _infoMessage = message;
      await fetchAdminStats();
      _isAdminLoading = false;
      notifyListeners();
      return message;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isAdminLoading = false;
    notifyListeners();
    return null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
