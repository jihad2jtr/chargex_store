import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
  }

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> _buildHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final base = ApiConstants.baseUrl;
    final url = '$base$path';
    if (queryParams != null && queryParams.isNotEmpty) {
      final strParams = queryParams.map((k, v) => MapEntry(k, v.toString()));
      return Uri.parse(url).replace(queryParameters: strParams);
    }
    return Uri.parse(url);
  }

  dynamic _processResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      body = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      String errorMessage = 'حدث خطأ في الاتصال بالخادم';
      if (body is Map) {
        if (body['message'] is List) {
          errorMessage = (body['message'] as List).join('، ');
        } else if (body['message'] is String) {
          errorMessage = body['message'];
        } else if (body['error'] is String) {
          errorMessage = body['error'];
        }
      }
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await http.get(_buildUri(path, queryParams), headers: _buildHeaders());
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('تعذر الاتصال بالخادم، تأكد من اتصال الإنترنت: $e');
    }
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    try {
      final response = await http.post(
        _buildUri(path),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('تعذر إرسال الطلب: $e');
    }
  }

  Future<dynamic> put(String path, {dynamic body}) async {
    try {
      final response = await http.put(
        _buildUri(path),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('تعذر تحديث البيانات: $e');
    }
  }

  Future<dynamic> patch(String path, {dynamic body}) async {
    try {
      final response = await http.patch(
        _buildUri(path),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('تعذر إكمال العملية: $e');
    }
  }

  Future<dynamic> delete(String path, {dynamic body}) async {
    try {
      final response = await http.delete(
        _buildUri(path),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('تعذر حذف العنصر: $e');
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
