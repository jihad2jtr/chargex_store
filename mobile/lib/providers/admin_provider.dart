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

class AdminProvider extends ChangeNotifier {
  List<ProviderModel> _providers = [];
  List<AppItemModel> _adminApps = [];
  List<ProductModel> _adminProducts = [];
  List<ProductModel> _currentAppProducts = [];
  String? _currentAppId;
  List<BannerModel> _adminBanners = [];
  List<OrderModel> _adminOrders = [];
  List<OrderModel> _manualOrders = [];
  List<PaymentAccountModel> _paymentAccounts = [];
  List<ShippingCodeModel> _shippingCodes = [];
  List<ManualOrderModel> _manualTopupRequests = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<ProviderModel> get providers => _providers;
  List<AppItemModel> get adminApps => _adminApps;
  List<ProductModel> get adminProducts => _adminProducts;
  List<ProductModel> get currentAppProducts => _currentAppProducts.isNotEmpty
      ? _currentAppProducts
      : (_currentAppId != null ? _adminProducts.where((p) => p.appId == _currentAppId).toList() : _adminProducts);
  List<BannerModel> get adminBanners => _adminBanners;
  List<OrderModel> get adminOrders => _adminOrders;
  List<OrderModel> get manualOrders => _manualOrders.isNotEmpty
      ? _manualOrders
      : _adminOrders.where((o) => o.productType == 'manual').toList();
  List<PaymentAccountModel> get paymentAccounts => _paymentAccounts;
  List<ShippingCodeModel> get shippingCodes => _shippingCodes;
  List<ManualOrderModel> get manualTopupRequests => _manualTopupRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final ApiClient _api = ApiClient();

  // === Providers ===
  Future<void> fetchProviders() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get(ApiConstants.providers);
      if (res is List) {
        _providers = res.map((e) => ProviderModel.fromJson(e)).toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
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

  Future<List<dynamic>> fetchProviderProducts(String id) async {
    try {
      final res = await _api.get('${ApiConstants.providers}/$id/products');
      if (res is List) return res;
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> syncProviderProducts(String id, [List<String>? gameCodes]) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.post(
        '${ApiConstants.providers}/$id/sync',
        body: gameCodes != null && gameCodes.isNotEmpty ? {'gameCodes': gameCodes} : {},
      );
      await fetchProviders();
      _isLoading = false;
      notifyListeners();
      return res is Map<String, dynamic> ? res : {'message': 'تمت المزامنة بنجاح'};
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
    String marginType = 'percentage',
    double marginValue = 0.0, // No markup at import; set from dashboard later
  }) async {
    try {
      await _api.post('${ApiConstants.providers}/$providerId/import-product', body: {
        'providerProductId': providerProductId,
        'appId': appId,
        'marginType': marginType,
        'marginValue': marginValue,
      });
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
    String marginType = 'percentage',
    double marginValue = 0.0, // No markup at import; set from dashboard later
  }) async {
    try {
      await _api.post('${ApiConstants.providers}/$providerId/batch-import', body: {
        'providerProductIds': providerProductIds,
        'appId': appId,
        'marginType': marginType,
        'marginValue': marginValue,
      });
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
  Future<void> fetchAdminApps() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get(ApiConstants.adminApps);
      if (res is List) {
        _adminApps = res.map((e) => AppItemModel.fromJson(e)).toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
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
          _currentAppProducts = _adminProducts.where((p) => p.appId == _currentAppId).toList();
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
      final res = await _api.get(ApiConstants.adminProducts, queryParams: {'appId': appId});
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
        _paymentAccounts = res.map((e) => PaymentAccountModel.fromJson(e)).toList();
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

  Future<bool> updatePaymentAccount(String id, Map<String, dynamic> data) async {
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

  Future<bool> generateShippingCodes(double amount, int count) async {
    try {
      await _api.post(ApiConstants.adminCodesGenerate, body: {
        'amount': amount,
        'count': count,
      });
      await fetchShippingCodes();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleShippingCode(String id) async {
    try {
      await _api.patch('${ApiConstants.adminCodes.replaceAll('/all', '')}/$id/toggle');
      await fetchShippingCodes();
    } catch (_) {}
  }

  Future<bool> deleteShippingCode(String id) async {
    try {
      await _api.delete('${ApiConstants.adminCodes.replaceAll('/all', '')}/$id');
      await fetchShippingCodes();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // === Orders & Manual Reviews ===
  Future<void> fetchAdminOrders({String? status, String? type, bool silent = false}) async {
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

      final res = await _api.get(ApiConstants.adminOrders, queryParams: query.isNotEmpty ? query : null);
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
        _manualOrders = _adminOrders.where((o) => o.productType == 'manual').toList();
      }
    } catch (e) {
      if (!silent) _errorMessage = e.toString();
    }
    if (!silent) {
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> fetchManualOrders({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final res = await _api.get(ApiConstants.adminOrders, queryParams: {'type': 'manual'});
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

  // === Topup Requests ===
  Future<void> fetchManualTopupRequests([String? status]) async {
    try {
      final res = await _api.get(ApiConstants.adminTopupRequests, queryParams: status != null ? {'status': status} : null);
      if (res is List) {
        _manualTopupRequests = res.map((e) => ManualOrderModel.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> approveTopupRequest(String id, {double? approvedAmount, String? notes}) async {
    try {
      await _api.post('${ApiConstants.adminTopupRequests}/$id/approve', body: {
        'approvedAmount': approvedAmount,
        'notes': notes,
      });
      await fetchManualTopupRequests();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectTopupRequest(String id, String notes) async {
    try {
      await _api.post('${ApiConstants.adminTopupRequests}/$id/reject', body: {
        'notes': notes,
      });
      await fetchManualTopupRequests();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Admin ID Top-up
  Future<bool> adjustUserBalance(String userId, double amount, String description) async {
    try {
      await _api.post(ApiConstants.adminAdjustBalance, body: {
        'userId': userId,
        'amount': amount,
        'description': description,
      });
      return true;
    } catch (e) {
      _errorMessage = e.toString();
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
        _adminBanners = res.map((e) => BannerModel.fromJson(Map<String, dynamic>.from(e))).toList();
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

  // === Supervisors & Manual Services Management ===
  List<Map<String, dynamic>> _supervisors = [];
  List<Map<String, dynamic>> get supervisors => _supervisors;

  Future<void> fetchSupervisors() async {
    try {
      final res = await _api.get(ApiConstants.supervisorsList);
      if (res is List) {
        _supervisors = res.map((e) => Map<String, dynamic>.from(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> createSupervisor({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.post(ApiConstants.createSupervisor, body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'phone': phone?.trim(),
      });
      await fetchSupervisors();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> reassignOrderSupervisor(String orderId, String newSupervisorId, [String? reason]) async {
    try {
      await _api.post('${ApiConstants.orders}/$orderId/admin-reassign', body: {
        'newSupervisorId': newSupervisorId,
        'reason': reason,
      });
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
      await _api.post('${ApiConstants.orders}/$orderId/admin-refund', body: {
        'reason': reason,
      });
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
