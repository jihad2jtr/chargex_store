import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/services/fcm_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isSupervisor => _currentUser?.isSupervisor ?? false;
  bool get isAgent => _currentUser?.isAgent ?? false;

  final ApiClient _api = ApiClient();

  Future<bool> initAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null && token.isNotEmpty) {
        _api.setToken(token);
        final res = await _api.get(ApiConstants.authMe);
        _currentUser = UserModel.fromJson(res, token: token);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (_) {
      await logout();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(ApiConstants.authLogin, body: {
        'email': email.trim(),
        'password': password,
      });

      final accessToken = res['accessToken'] as String;
      final refreshToken = res['refreshToken'] as String?;
      final userData = res['user'] as Map<String, dynamic>;

      _currentUser = UserModel.fromJson(userData, token: accessToken, refreshToken: refreshToken);
      _api.setToken(accessToken);
      FcmService.instance.syncTokenWithBackend();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      if (refreshToken != null) {
        await prefs.setString('refresh_token', refreshToken);
      }

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

  Future<bool> register({required String name, required String email, required String password, String? phone}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(ApiConstants.authRegister, body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'phone': phone?.trim(),
      });

      final accessToken = res['accessToken'] as String;
      final refreshToken = res['refreshToken'] as String?;
      final userData = res['user'] as Map<String, dynamic>;

      _currentUser = UserModel.fromJson(userData, token: accessToken, refreshToken: refreshToken);
      _api.setToken(accessToken);
      FcmService.instance.syncTokenWithBackend();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      if (refreshToken != null) {
        await prefs.setString('refresh_token', refreshToken);
      }

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

  Future<void> refreshProfile() async {
    try {
      final res = await _api.get(ApiConstants.authMe);
      _currentUser = _currentUser?.copyWith(
        balance: (res['balance'] is num) ? (res['balance'] as num).toDouble() : _currentUser?.balance,
        name: res['name'] ?? _currentUser?.name,
        role: res['role'] ?? _currentUser?.role,
        userId: res['userId'] ?? _currentUser?.userId,
      );
      notifyListeners();
    } catch (_) {}
  }

  void updateBalanceLocally(double newBalance) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(balance: newBalance);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await FcmService.instance.removeTokenFromBackend();
      await _api.post('/auth/logout');
    } catch (_) {}
    _currentUser = null;
    _api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    notifyListeners();
  }
}
