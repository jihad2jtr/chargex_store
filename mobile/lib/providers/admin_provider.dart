import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/provider_model.dart';
import '../models/app_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/payment_account_model.dart';
import '../models/shipping_code_model.dart';
import '../models/manual_order_model.dart';
import '../models/banner_model.dart';
import '../models/service_template_model.dart';
import '../models/dashboard_stats_model.dart';
import '../core/services/cache_service.dart';

class AdminProvider extends ChangeNotifier {
  List<ProviderModel> _providers = [];
  List<AppItemModel> _adminApps = [];
  List<ProductModel> _adminProducts = [];
  List<ProductModel> _currentAppProducts = [];
  String? _currentAppId;
  List<BannerModel> _adminBanners = [];
  List<ServiceTemplateModel> _serviceTemplates = [];
  List<OrderModel> _adminOrders = [];
  List<OrderModel> _manualOrders = [];
  List<PaymentAccountModel> _paymentAccounts = [];
  List<ShippingCodeModel> _shippingCodes = [];
  List<ManualOrderModel> _manualTopupRequests = [];
  DashboardStatsModel? _dashboardStats;
  DateTime? _statsFetchedAt;
  int _pendingOrdersCount = 0;
  int _pendingTopupsCount = 0;

  bool _isLoading = false;
  String? _errorMessage;

  List<ProviderModel> get providers => _providers;
  List<AppItemModel> get adminApps => _adminApps;
  List<ProductModel> get adminProducts => _adminProducts;
  List<ProductModel> get currentAppProducts => _currentAppProducts.isNotEmpty
      ? _currentAppProducts
      : (_currentAppId != null
            ? _adminProducts.where((p) => p.appId == _currentAppId).toList()
            : _adminProducts);
  List<BannerModel> get adminBanners => _adminBanners;
  List<ServiceTemplateModel> get serviceTemplates => _serviceTemplates;
  List<OrderModel> get adminOrders => _adminOrders;
  List<OrderModel> get manualOrders => _manualOrders.isNotEmpty
      ? _manualOrders
      : _adminOrders.where((o) => o.productType == 'manual').toList();
  List<PaymentAccountModel> get paymentAccounts => _paymentAccounts;
  List<ShippingCodeModel> get shippingCodes => _shippingCodes;
  List<ManualOrderModel> get manualTopupRequests => _manualTopupRequests;
  DashboardStatsModel? get dashboardStats => _dashboardStats;
  DateTime? get statsFetchedAt => _statsFetchedAt;
  int get pendingOrdersCount => _pendingOrdersCount;
  int get pendingTopupsCount => _pendingTopupsCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final ApiClient _api = ApiClient();

  AdminProvider() {
    _loadFromCache();
  }

  void _loadFromCache() {
    final cachedProviders = CacheService.instance.getList(
      'admin_providers',
      ProviderModel.fromJson,
    );
    if (cachedProviders != null && cachedProviders.isNotEmpty) {
      _providers = cachedProviders;
    }
    final cachedApps = CacheService.instance.getList(
      'admin_apps',
      AppItemModel.fromJson,
    );
    if (cachedApps != null && cachedApps.isNotEmpty) {
      _adminApps = cachedApps;
    }
    final cachedProducts = CacheService.instance.getList(
      'admin_products',
      ProductModel.fromJson,
    );
    if (cachedProducts != null && cachedProducts.isNotEmpty) {
      _adminProducts = cachedProducts;
    }
  }

  // === Providers ===
  Future<void> fetchProviders({bool forceRefresh = false}) async {
    if (_providers.isEmpty) {
      _loadFromCache();
    }
    if (_providers.isEmpty || forceRefresh) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final res = await _api.get(ApiConstants.providers);
      if (res is List) {
        _providers = res.map((e) => ProviderModel.fromJson(e)).toList();
        CacheService.instance.setList(
          'admin_providers',
          _providers,
          (p) => p.toJson(),
        );
      }
    } catch (e) {
      if (_providers.isEmpty) {
        _errorMessage = e.toString();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createProvider(Map<String, dynamic> data) async {
    try {
      await _api.post(ApiConstants.providers, body: data);
      await fetchProviders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProvider(String id, Map<String, dynamic> data) async {
    try {
      await _api.put('${ApiConstants.providers}/$id', body: data);
      await fetchProviders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProvider(String id) async {
    try {
      await _api.delete('${ApiConstants.providers}/$id');
      await fetchProviders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkProviderStatus(String id) async {
    try {
      await _api.post('${ApiConstants.providers}/$id/check-status');
      await fetchProviders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// إيقاف/تفعيل مزود: الإيقاف يُخفي كل التطبيقات والألعاب المرتبطة به فوراً
  Future<bool> toggleProviderActive(String id) async {
    try {
      final res = await _api.patch(
        '${ApiConstants.providers}/$id/toggle-active',
      );
      if (res is Map) {
        final updated = ProviderModel.fromJson(Map<String, dynamic>.from(res));
        final idx = _providers.indexWhere((p) => p.id == id);
        if (idx != -1) {
          _providers[idx] = updated;
          notifyListeners();
        }
      }
      await fetchProviders(forceRefresh: true);
      return true;
    } catch (e) {
      // 404 يعني أن نسخة الخادم المنشورة لا تحتوي المسار بعد (نسخة قديمة)
      _errorMessage = e is ApiException && e.statusCode == 404
          ? 'نسخة الخادم الحالية لا تدعم إيقاف المزود بعد — يجب تحديث خادم الخدمة (Backend) ثم إعادة المحاولة'
          : _failMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<List<dynamic>> fetchProviderProducts(
    String id, {
    bool forceRefresh = false,
  }) async {
    final cached = CacheService.instance.getRawList('provider_products_$id');
    if (cached != null && cached.isNotEmpty && !forceRefresh) {
      // Revalidate in background silently
      _api
          .get('${ApiConstants.providers}/$id/products')
          .then((res) {
            if (res is List) {
              CacheService.instance.setRawList('provider_products_$id', res);
            }
          })
          .catchError((_) {});
      return cached;
    }

    try {
      final res = await _api.get('${ApiConstants.providers}/$id/products');
      if (res is List) {
        CacheService.instance.setRawList('provider_products_$id', res);
        return res;
      }
      return cached ?? [];
    } catch (_) {
      return cached ?? [];
    }
  }

  Future<Map<String, dynamic>?> syncProviderProducts(
    String id, [
    List<String>? gameCodes,
  ]) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.post(
        '${ApiConstants.providers}/$id/sync',
        body: gameCodes != null && gameCodes.isNotEmpty
            ? {'gameCodes': gameCodes}
            : {},
      );
      await CacheService.instance.remove('provider_products_$id');
      await fetchProviders(forceRefresh: true);
      _isLoading = false;
      notifyListeners();
      return res is Map<String, dynamic>
          ? res
          : {'message': 'تمت المزامنة بنجاح'};
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<List<dynamic>> fetchProviderCategories(String id) async {
    try {
      final res = await _api.get('${ApiConstants.providers}/$id/categories');
      if (res is List) return res;
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> importProviderProduct({
    required String providerId,
    required String providerProductId,
    required String appId,
    String? name,
    String? serviceTemplateId,
    String? quantityLabel,
  }) async {
    try {
      await _api.post(
        '${ApiConstants.providers}/$providerId/import-product',
        body: {
          'providerProductId': providerProductId,
          'appId': appId,
          if (name != null && name.isNotEmpty) 'name': name,
          if (serviceTemplateId != null && serviceTemplateId.isNotEmpty)
            'serviceTemplateId': serviceTemplateId,
          if (quantityLabel != null && quantityLabel.isNotEmpty)
            'quantityLabel': quantityLabel,
        },
      );
      await fetchAdminProducts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> batchImportProviderProducts({
    required String providerId,
    required List<String> providerProductIds,
    required String appId,
    String? name,
    String? serviceTemplateId,
    String? quantityLabel,
  }) async {
    try {
      await _api.post(
        '${ApiConstants.providers}/$providerId/batch-import',
        body: {
          'providerProductIds': providerProductIds,
          'appId': appId,
          if (name != null && name.isNotEmpty) 'name': name,
          if (serviceTemplateId != null && serviceTemplateId.isNotEmpty)
            'serviceTemplateId': serviceTemplateId,
          if (quantityLabel != null && quantityLabel.isNotEmpty)
            'quantityLabel': quantityLabel,
        },
      );
      await fetchAdminProducts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Alias used in provider_products_screen when adding a new app from import flow
  Future<bool> createAdminApp(Map<String, dynamic> data) => createApp(data);

  // === Apps ===
  Future<void> fetchAdminApps({bool forceRefresh = false}) async {
    if (_adminApps.isEmpty) {
      _loadFromCache();
    }
    if (_adminApps.isEmpty || forceRefresh) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final res = await _api.get(ApiConstants.adminApps);
      if (res is List) {
        _adminApps = res.map((e) => AppItemModel.fromJson(e)).toList();
        CacheService.instance.setList(
          'admin_apps',
          _adminApps,
          (a) => a.toJson(),
        );
      }
    } catch (e) {
      if (_adminApps.isEmpty) {
        _errorMessage = e.toString();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createApp(Map<String, dynamic> data) async {
    try {
      await _api.post(ApiConstants.apps, body: data);
      await fetchAdminApps();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateApp(String id, Map<String, dynamic> data) async {
    try {
      await _api.put('${ApiConstants.apps}/$id', body: data);
      await fetchAdminApps();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleAppActive(String id) async {
    try {
      final res = await _api.patch('${ApiConstants.apps}/$id/toggle-active');
      if (res is Map) {
        final updated = AppItemModel.fromJson(Map<String, dynamic>.from(res));
        final idx = _adminApps.indexWhere((a) => a.id == id);
        if (idx != -1) {
          _adminApps[idx] = updated;
          notifyListeners();
        }
      }
      await fetchAdminApps();
      return true;
    } catch (e) {
      _errorMessage = _failMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteApp(String id) async {
    try {
      await _api.delete('${ApiConstants.apps}/$id');
      await fetchAdminApps();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // === Products ===
  Future<void> fetchAdminProducts([String? appId]) async {
    if (appId != null && appId.isNotEmpty) {
      await fetchAppProducts(appId);
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get(ApiConstants.adminProducts);
      if (res is List) {
        _adminProducts = res.map((e) => ProductModel.fromJson(e)).toList();
        if (_currentAppId != null) {
          _currentAppProducts = _adminProducts
              .where((p) => p.appId == _currentAppId)
              .toList();
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAppProducts(String appId) async {
    _currentAppId = appId;
    // Pre-populate immediately from master list if available
    final cached = _adminProducts.where((p) => p.appId == appId).toList();
    if (cached.isNotEmpty) {
      _currentAppProducts = cached;
      notifyListeners();
    }
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get(
        ApiConstants.adminProducts,
        queryParams: {'appId': appId},
      );
      if (res is List) {
        _currentAppProducts = res.map((e) => ProductModel.fromJson(e)).toList();
        // Sync these items into master _adminProducts list without dropping other apps' products
        for (final p in _currentAppProducts) {
          final idx = _adminProducts.indexWhere((x) => x.id == p.id);
          if (idx != -1) {
            _adminProducts[idx] = p;
          } else {
            _adminProducts.add(p);
          }
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createProduct(Map<String, dynamic> data) async {
    try {
      await _api.post('/products', body: data);
      await fetchAdminProducts();
      if (_currentAppId != null) {
        await fetchAppProducts(_currentAppId!);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      await _api.put('/products/$id', body: data);
      await fetchAdminProducts();
      if (_currentAppId != null) {
        await fetchAppProducts(_currentAppId!);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleProductActive(String id, [String? currentAppId]) async {
    try {
      final res = await _api.patch('/products/$id/toggle-active');
      if (res is Map) {
        final updated = ProductModel.fromJson(Map<String, dynamic>.from(res));
        final idx = _adminProducts.indexWhere((p) => p.id == id);
        if (idx != -1) {
          _adminProducts[idx] = updated;
        }
        final appIdx = _currentAppProducts.indexWhere((p) => p.id == id);
        if (appIdx != -1) {
          _currentAppProducts[appIdx] = updated;
        }
        notifyListeners();
      }
      await fetchAdminProducts();
      final targetApp = currentAppId ?? _currentAppId;
      if (targetApp != null) {
        await fetchAppProducts(targetApp);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await _api.delete('/products/$id');
      _adminProducts.removeWhere((p) => p.id == id);
      _currentAppProducts.removeWhere((p) => p.id == id);
      notifyListeners();
      await fetchAdminProducts();
      if (_currentAppId != null) {
        await fetchAppProducts(_currentAppId!);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addCodesToInventory(String id, List<String> codes) async {
    try {
      await _api.post('/products/$id/inventory', body: {'codes': codes});
      await fetchAdminProducts();
      if (_currentAppId != null) {
        await fetchAppProducts(_currentAppId!);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Button: "تحديث الأسعار من المزودين"
  Future<String?> syncProviderPrices() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.post(ApiConstants.syncProviderPrices);
      await fetchAdminProducts();
      _isLoading = false;
      notifyListeners();
      return res['message'] ?? 'تم تحديث الأسعار بنجاح';
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // === Payment Accounts (Sham Cash & Binance) ===
  Future<void> fetchPaymentAccounts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get(ApiConstants.adminTopupAccounts);
      if (res is List) {
        _paymentAccounts = res
            .map((e) => PaymentAccountModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createPaymentAccount(Map<String, dynamic> data) async {
    try {
      await _api.post(ApiConstants.adminTopupAccounts, body: data);
      await fetchPaymentAccounts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePaymentAccount(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _api.put('${ApiConstants.adminTopupAccounts}/$id', body: data);
      await fetchPaymentAccounts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> togglePaymentAccount(String id) async {
    try {
      await _api.patch('${ApiConstants.adminTopupAccounts}/$id/toggle');
      await fetchPaymentAccounts();
    } catch (_) {}
  }

  Future<bool> deletePaymentAccount(String id) async {
    try {
      await _api.delete('${ApiConstants.adminTopupAccounts}/$id');
      await fetchPaymentAccounts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // === Shipping Codes ===
  Future<void> fetchShippingCodes() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get(ApiConstants.adminCodes);
      if (res is List) {
        _shippingCodes = res.map((e) => ShippingCodeModel.fromJson(e)).toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// يولّد دفعة قسائم ويرجع معرّف الدفعة (null عند الفشل) لعرض خيار التصدير فوراً
  Future<String?> generateShippingCodes(
    double amount,
    int count, {
    String? note,
  }) async {
    try {
      final res = await _api.post(
        ApiConstants.adminCodesGenerate,
        body: {
          'amount': amount,
          'count': count,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      final batchId = res is Map ? res['batchId']?.toString() : null;
      await fetchShippingCodes();
      return batchId ?? '';
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> toggleShippingCode(String id) async {
    try {
      await _api.patch(
        '${ApiConstants.adminCodes.replaceAll('/all', '')}/$id/toggle',
      );
      await fetchShippingCodes();
    } catch (_) {}
  }

  Future<bool> deleteShippingCode(String id) async {
    try {
      await _api.delete(
        '${ApiConstants.adminCodes.replaceAll('/all', '')}/$id',
      );
      await fetchShippingCodes();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // === Orders & Manual Reviews ===
  Future<void> fetchAdminOrders({
    String? status,
    String? type,
    bool silent = false,
  }) async {
    if (type == 'manual') {
      await fetchManualOrders(silent: silent);
      return;
    }
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final query = <String, dynamic>{};
      if (status != null && status.isNotEmpty) query['status'] = status;

      final res = await _api.get(
        ApiConstants.adminOrders,
        queryParams: query.isNotEmpty ? query : null,
      );
      if (res is List) {
        final parsed = res.map((e) => OrderModel.fromJson(e)).toList();
        if (status != null && status.isNotEmpty) {
          // Merge / update matching status without dropping other orders
          for (final o in parsed) {
            final idx = _adminOrders.indexWhere((x) => x.id == o.id);
            if (idx != -1) {
              _adminOrders[idx] = o;
            } else {
              _adminOrders.add(o);
            }
          }
        } else {
          _adminOrders = parsed;
        }
        _manualOrders = _adminOrders
            .where((o) => o.productType == 'manual')
            .toList();
      }
    } catch (e) {
      if (!silent) _errorMessage = e.toString();
    }
    if (!silent) {
      _isLoading = false;
    }
    notifyListeners();
  }

  /// إحصاءات لوحة التحكم (اليوم/الأمس، المعلّق، المتأخر، آخر 7 أيام، صحة النظام)
  Future<void> fetchDashboardStats({bool silent = false}) async {
    try {
      final res = await _api.get(ApiConstants.adminDashboardStats);
      if (res is Map) {
        _dashboardStats = DashboardStatsModel.fromJson(
          Map<String, dynamic>.from(res),
        );
        _statsFetchedAt = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      if (!silent) {
        _errorMessage = e.toString();
        notifyListeners();
      }
    }
  }

  /// عدّادات خفيفة (طلبات وإيداعات معلّقة) لتحديث اللوحة دون تحميل القوائم الكاملة
  Future<void> fetchPendingCounts({bool silent = false}) async {
    try {
      final res = await _api.get(ApiConstants.adminDashboardPendingCounts);
      if (res is Map) {
        _pendingOrdersCount = (res['ordersPending'] as num?)?.toInt() ?? 0;
        _pendingTopupsCount = (res['topupsPending'] as num?)?.toInt() ?? 0;
        notifyListeners();
      }
    } catch (e) {
      if (!silent) {
        _errorMessage = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> fetchManualOrders({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final res = await _api.get(
        ApiConstants.adminOrders,
        queryParams: {'type': 'manual'},
      );
      if (res is List) {
        _manualOrders = res.map((e) => OrderModel.fromJson(e)).toList();
        // Update master _adminOrders list without clearing direct_api and voucher orders
        for (final m in _manualOrders) {
          final idx = _adminOrders.indexWhere((o) => o.id == m.id);
          if (idx != -1) {
            _adminOrders[idx] = m;
          } else {
            _adminOrders.add(m);
          }
        }
      }
    } catch (e) {
      if (!silent) _errorMessage = e.toString();
    }
    if (!silent) {
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<bool> acceptManualOrder(String id, String? notes) async {
    try {
      await _api.post('/orders/admin/$id/accept', body: {'notes': notes});
      await fetchAdminOrders(silent: true);
      await fetchManualOrders(silent: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectManualOrder(String id, String notes) async {
    try {
      await _api.post('/orders/admin/$id/reject', body: {'notes': notes});
      await fetchAdminOrders(silent: true);
      await fetchManualOrders(silent: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // === Topup Log ===
  /// سجل شحن الرصيد الموحّد: شام كاش / Binance / كود شحن / شحن بالآيدي.
  /// يأتي من الخادم مدموجاً ومرتّباً زمنياً، والفلترة بالنوع تتم في الواجهة.
  Future<void> fetchTopupLog() async {
    try {
      final res = await _api.get(ApiConstants.adminTopupLog);
      if (res is List) {
        _manualTopupRequests = res
            .map((e) => ManualOrderModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  /// اسم قديم مُبقى للتوافق (إشعارات FCM)
  Future<void> fetchManualTopupRequests() => fetchTopupLog();

  Future<bool> approveTopupRequest(
    String id, {
    double? approvedAmount,
    String? notes,
  }) async {
    try {
      await _api.post(
        '${ApiConstants.adminTopupRequests}/$id/approve',
        body: {'approvedAmount': approvedAmount, 'notes': notes},
      );
      await fetchTopupLog();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectTopupRequest(String id, String notes) async {
    try {
      await _api.post(
        '${ApiConstants.adminTopupRequests}/$id/reject',
        body: {'notes': notes},
      );
      await fetchTopupLog();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Admin ID Top-up — يُسجَّل في سجل الشحن كعملية مستقلة
  // يُقبل رقم العميل (JGO...) أو مُعرِّفه، والمبلغ السالب = خصم رصيد
  Future<bool> adjustUserBalance(
    String userId,
    double amount,
    String description,
  ) async {
    try {
      await _api.post(
        ApiConstants.adminIdTopup,
        body: {'userId': userId, 'amount': amount, 'description': description},
      );
      // تحديث سجل الشحن وقائمة المستخدمين معاً ليظهر الرصيد الجديد فوراً
      await Future.wait([fetchTopupLog(), fetchAllUsers(silent: true)]);
      return true;
    } catch (e) {
      _errorMessage = _failMessage(e);
      notifyListeners();
      return false;
    }
  }

  // === Banners / Billboard ===
  Future<void> fetchAdminBanners() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get(ApiConstants.adminBanners);
      if (res is List) {
        _adminBanners = res
            .map((e) => BannerModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createBanner(Map<String, dynamic> data) async {
    try {
      await _api.post(ApiConstants.banners, body: data);
      await fetchAdminBanners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBanner(String id, Map<String, dynamic> data) async {
    try {
      await _api.put('${ApiConstants.banners}/$id', body: data);
      await fetchAdminBanners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleBannerActive(String id) async {
    try {
      final res = await _api.patch('${ApiConstants.banners}/$id/toggle-active');
      if (res is Map) {
        final updated = BannerModel.fromJson(Map<String, dynamic>.from(res));
        final idx = _adminBanners.indexWhere((b) => b.id == id);
        if (idx != -1) {
          _adminBanners[idx] = updated;
          notifyListeners();
        }
      }
      await fetchAdminBanners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBanner(String id) async {
    try {
      await _api.delete('${ApiConstants.banners}/$id');
      await fetchAdminBanners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// رفع صورة الإعلان إلى الخادم وإرجاع رابطها العام
  Future<String?> uploadBannerImage(List<int> bytes, String fileName) async {
    try {
      final res = await _api.postMultipart(
        ApiConstants.uploadImage,
        fileBytes: bytes,
        fileName: fileName,
      );
      if (res is Map) {
        final url = res['url'] ?? res['secure_url'];
        if (url != null) return url.toString();
      }
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // === Service Templates (أنواع قوالب الخدمة) ===
  Future<void> fetchServiceTemplates() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get(ApiConstants.adminServiceTemplates);
      if (res is List) {
        _serviceTemplates = res
            .map(
              (e) =>
                  ServiceTemplateModel.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createServiceTemplate(Map<String, dynamic> data) async {
    try {
      await _api.post(ApiConstants.serviceTemplates, body: data);
      await fetchServiceTemplates();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateServiceTemplate(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _api.put('${ApiConstants.serviceTemplates}/$id', body: data);
      await fetchServiceTemplates();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleServiceTemplateActive(String id) async {
    try {
      await _api.patch('${ApiConstants.serviceTemplates}/$id/toggle-active');
      await fetchServiceTemplates();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteServiceTemplate(String id) async {
    try {
      await _api.delete('${ApiConstants.serviceTemplates}/$id');
      await fetchServiceTemplates();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // === Users Management ===
  List<Map<String, dynamic>> _allUsers = [];

  /// رسالة مفهومة للوحة بدلاً من نص الاستثناء الخام ("Exception: ...")
  String _failMessage(Object error) =>
      error is ApiException ? error.message : error.toString();

  /// كل المستخدمين القابلين للإسناد (كل العملاء + المشرفين + الأدمن)
  List<Map<String, dynamic>> get allUsers => _allUsers;

  Future<void> fetchAllUsers({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final res = await _api.get(ApiConstants.usersList);
      if (res is List) {
        _allUsers = res.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      if (!silent) _errorMessage = e.toString();
    }
    if (!silent) {
      _isLoading = false;
    }
    notifyListeners();
  }

  /// ترقية/إرجاع مستخدم (عميل ↔ مشرف ↔ وكيل) يدوياً من صفحة إدارة المستخدمين
  Future<bool> updateUserRole(String userId, String role) async {
    try {
      await _api.patch(
        '${ApiConstants.usersList}/$userId/role',
        body: {'role': role},
      );
      await fetchAllUsers(silent: true);
      return true;
    } catch (e) {
      _errorMessage = _failMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleUserActive(String userId) async {
    try {
      await _api.patch('${ApiConstants.usersList}/$userId/toggle-active');
      await fetchAllUsers(silent: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// تعديل بيانات المستخدم الأساسية (الاسم / البريد / الهاتف)
  Future<bool> updateUserDetails(
    String userId, {
    String? name,
    String? email,
    String? phone,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      await _api.patch('${ApiConstants.usersList}/$userId/details', body: body);
      await fetchAllUsers(silent: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> reassignOrderSupervisor(
    String orderId,
    String newSupervisorId, [
    String? reason,
  ]) async {
    try {
      await _api.post(
        '${ApiConstants.orders}/$orderId/admin-reassign',
        body: {'newSupervisorId': newSupervisorId, 'reason': reason},
      );
      await fetchAdminOrders(silent: true);
      await fetchManualOrders(silent: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> refundOrderAdmin(String orderId, String reason) async {
    try {
      await _api.post(
        '${ApiConstants.orders}/$orderId/admin-refund',
        body: {'reason': reason},
      );
      await fetchAdminOrders(silent: true);
      await fetchManualOrders(silent: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
