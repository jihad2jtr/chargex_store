import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String? _token;

  // مهلات صريحة: بدونها يعلّق طلب http إلى الأبد عند انقطاع الشبكة أو بطء الخادم (H1)
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _postTimeout = Duration(seconds: 45);

  // عميل واحد دائم بدل http.post المباشرة (تُنشئ وتُغلق اتصالاً لكل طلب)
  late final IOClient _client = IOClient(HttpClient());

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    required Duration timeout,
  }) {
    final request = http.Request(method, uri);
    if (headers != null) request.headers.addAll(headers);
    if (body != null) request.body = body is String ? body : jsonEncode(body);
    return _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(timeout);
  }

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
      final response = await _send(
        'GET',
        _buildUri(path, queryParams),
        headers: _buildHeaders(),
        timeout: _defaultTimeout,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e is TimeoutException) {
        throw ApiException('انتهت مهلة الاتصال بالخادم، يرجى المحاولة مجدداً');
      }
      throw ApiException('تعذر الاتصال بالخادم، تأكد من اتصال الإنترنت: $e');
    }
  }

  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    try {
      final response = await _send(
        'POST',
        _buildUri(path),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
        timeout: timeout ?? _postTimeout,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e is TimeoutException) {
        // بلا رمز حالة: الخادم لم يرد — المعالجة الأعلى تقرر إن كان ذلك آمناً
        throw ApiException(
          'انتهت مهلة الاتصال بالخادم؛ قد تكون العملية نُفّذة فعلياً، تحقق من السجل قبل إعادة المحاولة',
        );
      }
      throw ApiException('تعذر إرسال الطلب: $e');
    }
  }

  /// رفع ملف عبر multipart/form-data (مثل صور المعرض/الكاميرا)
  Future<dynamic> postMultipart(
    String path, {
    required List<int> fileBytes,
    required String fileName,
    String fieldName = 'file',
    Map<String, String>? fields,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _buildUri(path));
      final headers = _buildHeaders();
      headers.remove('Content-Type'); // يحدده multipart تلقائياً
      request.headers.addAll(headers);
      if (fields != null) request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, fileBytes, filename: fileName),
      );
      final streamed = await request.send().timeout(_defaultTimeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(_defaultTimeout);
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e is TimeoutException) {
        throw ApiException('انتهت مهلة رفع الملف، يرجى المحاولة مجدداً');
      }
      throw ApiException('تعذر رفع الملف: $e');
    }
  }

  Future<dynamic> put(String path, {dynamic body}) async {
    try {
      final response = await _send(
        'PUT',
        _buildUri(path),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
        timeout: _defaultTimeout,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e is TimeoutException) {
        throw ApiException('انتهت مهلة الاتصال بالخادم، يرجى المحاولة مجدداً');
      }
      throw ApiException('تعذر تحديث البيانات: $e');
    }
  }

  Future<dynamic> patch(String path, {dynamic body}) async {
    try {
      final response = await _send(
        'PATCH',
        _buildUri(path),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
        timeout: _defaultTimeout,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e is TimeoutException) {
        throw ApiException('انتهت مهلة الاتصال بالخادم، يرجى المحاولة مجدداً');
      }
      throw ApiException('تعذر إكمال العملية: $e');
    }
  }

  Future<dynamic> delete(String path, {dynamic body}) async {
    try {
      final response = await _send(
        'DELETE',
        _buildUri(path),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
        timeout: _defaultTimeout,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e is TimeoutException) {
        throw ApiException('انتهت مهلة الاتصال بالخادم، يرجى المحاولة مجدداً');
      }
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
