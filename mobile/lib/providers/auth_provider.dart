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
      final res = await _api.post(
        ApiConstants.authLogin,
        body: {'email': email.trim(), 'password': password},
      );

      final accessToken = res['accessToken'] as String;
      final refreshToken = res['refreshToken'] as String?;
      final userData = res['user'] as Map<String, dynamic>;

      _currentUser = UserModel.fromJson(
        userData,
        token: accessToken,
        refreshToken: refreshToken,
      );
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

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        ApiConstants.authRegister,
        body: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'phone': phone?.trim(),
        },
      );

      final accessToken = res['accessToken'] as String;
      final refreshToken = res['refreshToken'] as String?;
      final userData = res['user'] as Map<String, dynamic>;

      _currentUser = UserModel.fromJson(
        userData,
        token: accessToken,
        refreshToken: refreshToken,
      );
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
      _currentUser = UserModel.fromJson(
        res,
        token: _currentUser?.token,
        refreshToken: _currentUser?.refreshToken,
      );
      notifyListeners();
    } catch (_) {}
  }

  /// تحديث بيانات الملف الشخصي (الاسم/الهاتف/الصورة الشخصية) لصاحب الحساب
  /// تمرير avatar فارغة يعني حذف الصورة الحالية
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? avatar,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.patch(
        ApiConstants.authMe,
        body: {
          if (name != null) 'name': name.trim(),
          if (phone != null) 'phone': phone.trim(),
          if (avatar != null) 'avatar': avatar.trim(),
        },
      );
      _currentUser = UserModel.fromJson(
        res,
        token: _currentUser?.token,
        refreshToken: _currentUser?.refreshToken,
      );
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

  /// رفع صورة إلى مسار الرفع العام وإرجاع رابطها العام (أو null عند الفشل)
  Future<String?> uploadImage(List<int> bytes, String fileName) async {
    try {
      final res = await _api.postMultipart(
        ApiConstants.uploadImage,
        fileBytes: bytes,
        fileName: fileName,
      );
      if (res is Map) {
        final url = (res['url'] ?? res['secure_url'] ?? '').toString().trim();
        if (url.isNotEmpty) return url;
      }
      _errorMessage = 'لم يُرجع الخادم رابطاً للصورة';
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
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
