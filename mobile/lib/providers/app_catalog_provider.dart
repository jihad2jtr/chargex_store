import 'dart:math';

import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/services/cache_service.dart';
import '../models/app_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/banner_model.dart';

class AppCatalogProvider extends ChangeNotifier {
  List<AppItemModel> _apps = [];
  List<BannerModel> _banners = [];
  List<ProductModel> _currentProducts = [];
  List<OrderModel> _myOrders = [];
  List<dynamic> _notifications = [];

  bool _isLoading = false;
  bool _isOrdering = false;
  String? _errorMessage;

  List<AppItemModel> get apps => _apps;
  List<BannerModel> get banners => _banners;
  List<ProductModel> get currentProducts => _currentProducts;
  List<OrderModel> get myOrders => _myOrders;
  List<dynamic> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get isOrdering => _isOrdering;
  String? get errorMessage => _errorMessage;

  final ApiClient _api = ApiClient();

  AppCatalogProvider() {
    _loadFromCache();
  }

  void _loadFromCache() {
    final cachedApps = CacheService.instance.getList(
      'catalog_apps',
      AppItemModel.fromJson,
    );
    if (cachedApps != null && cachedApps.isNotEmpty) {
      _apps = cachedApps;
    }
    final cachedBanners = CacheService.instance.getList(
      'catalog_banners',
      BannerModel.fromJson,
    );
    if (cachedBanners != null && cachedBanners.isNotEmpty) {
      _banners = cachedBanners;
    }
    final cachedOrders = CacheService.instance.getList(
      'my_orders',
      OrderModel.fromJson,
    );
    if (cachedOrders != null && cachedOrders.isNotEmpty) {
      _myOrders = cachedOrders;
    }
  }

  Future<void> fetchBanners() async {
    try {
      final res = await _api.get(ApiConstants.banners);
      if (res is List) {
        _banners = res.map((e) => BannerModel.fromJson(e)).toList();
        CacheService.instance.setList(
          'catalog_banners',
          _banners,
          (b) => b.toJson(),
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchApps({bool forceRefresh = false}) async {
    if (_apps.isEmpty) {
      _loadFromCache();
    }

    // Only show full loading spinner if cache is completely empty or explicitly forced
    if (_apps.isEmpty || forceRefresh) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      fetchBanners(); // Load banners in parallel
      final res = await _api.get(ApiConstants.apps);
      if (res is List) {
        _apps = res.map((e) => AppItemModel.fromJson(e)).toList();
        CacheService.instance.setList('catalog_apps', _apps, (a) => a.toJson());
      }
    } catch (e) {
      if (_apps.isEmpty) {
        _errorMessage = e.toString();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchProductsByApp(
    String appId, {
    bool forceRefresh = false,
  }) async {
    final cached = CacheService.instance.getList(
      'app_products_$appId',
      ProductModel.fromJson,
    );
    if (cached != null && cached.isNotEmpty) {
      _currentProducts = cached;
    }

    if (_currentProducts.isEmpty || forceRefresh) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final res = await _api.get('${ApiConstants.productsByApp}/$appId');
      if (res is List) {
        _currentProducts = res.map((e) => ProductModel.fromJson(e)).toList();
        CacheService.instance.setList(
          'app_products_$appId',
          _currentProducts,
          (p) => p.toJson(),
        );
      }
    } catch (e) {
      if (_currentProducts.isEmpty) {
        _errorMessage = e.toString();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> purchaseProduct({
    required String productId,
    Map<String, dynamic>? accountInput,
  }) async {
    _isOrdering = true;
    _errorMessage = null;
    notifyListeners();

    // مفتاح إرسال فريد ثابت لكل منتج: يبقى بعد إعادة تشغيل التطبيق فتعيد المحاولة نفس
    // المعرّف بدل إنشاء طلب مزدوج، ولا يُمسح إلا عند ردّ قاطع من الخادم (idempotency)
    final reqKey = 'pending_req_$productId';
    var requestId = await CacheService.instance.getOrLoad(reqKey) as String?;
    if (requestId == null || requestId.isEmpty) {
      requestId =
          'PUR-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0xFFFFFF)}';
      await CacheService.instance.set(reqKey, requestId);
    }

    try {
      // مهلة أطول من المعتاد: الشراء قد يستهلك مهلة المزود الكاملة في الخادم
      final res = await _api.post(
        ApiConstants.orders,
        body: {
          'productId': productId,
          'accountInput': accountInput ?? {},
          'requestId': requestId,
        },
        timeout: const Duration(seconds: 90),
      );
      // نجح الطلب بصفة قاطعة: ابدأ معرّفاً جديداً للمحاولة القادمة
      await CacheService.instance.remove(reqKey);
      await fetchMyOrders();
      _isOrdering = false;
      notifyListeners();
      return res;
    } catch (e) {
      // A missing status code means the server never answered (slow provider or a
      // gateway timeout) — the order may still be running server-side
      final isNoResponse = e is ApiException && e.statusCode == null;
      if (!isNoResponse) {
        // ردّ قاطع بفشل تجاري: لا خطر تكرار، أمهّد معرّفاً جديداً للمحاولة التالية
        await CacheService.instance.remove(reqKey);
      }
      _errorMessage = isNoResponse
          ? 'انقطع الاتصال أثناء تنفيذ الطلب؛ طلبك محفوظ وقيد التحقق التلقائي — افتح «طلباتي» لمتابعة حالته، ولا تُرسله مرتين. إذا فشل التنفيذ سيُعاد المبلغ تلقائياً.'
          : e.toString();
      _isOrdering = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> fetchMyOrders() async {
    try {
      final res = await _api.get(ApiConstants.myOrders);
      if (res is List) {
        _myOrders = res.map((e) => OrderModel.fromJson(e)).toList();
        CacheService.instance.setList(
          'my_orders',
          _myOrders,
          (o) => o.toJson(),
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchNotifications() async {
    try {
      final res = await _api.get(ApiConstants.myNotifications);
      if (res is List) {
        _notifications = res;
        notifyListeners();
      }
    } catch (_) {}
  }
}
