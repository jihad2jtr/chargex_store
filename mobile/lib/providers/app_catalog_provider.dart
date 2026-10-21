import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
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

  Future<void> fetchBanners() async {
    try {
      final res = await _api.get(ApiConstants.banners);
      if (res is List) {
        _banners = res.map((e) => BannerModel.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchApps() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      fetchBanners(); // Load banners in parallel
      final res = await _api.get(ApiConstants.apps);
      if (res is List) {
        _apps = res.map((e) => AppItemModel.fromJson(e)).toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchProductsByApp(String appId) async {
    _isLoading = true;
    _currentProducts = [];
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.get('${ApiConstants.productsByApp}/$appId');
      if (res is List) {
        _currentProducts = res.map((e) => ProductModel.fromJson(e)).toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
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

    try {
      final res = await _api.post(ApiConstants.orders, body: {
        'productId': productId,
        'accountInput': accountInput ?? {},
      });
      await fetchMyOrders();
      _isOrdering = false;
      notifyListeners();
      return res;
    } catch (e) {
      _errorMessage = e.toString();
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
