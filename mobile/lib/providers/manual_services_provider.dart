import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

class ManualServicesProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<OrderModel> _supervisorOrders = [];
  List<ProductModel> _assignedServices = [];
  bool _isLoading = false;
  bool _isTogglingService = false;
  String? _errorMessage;

  List<OrderModel> get supervisorOrders => _supervisorOrders;
  List<ProductModel> get assignedServices => _assignedServices;
  bool get isLoading => _isLoading;
  bool get isTogglingService => _isTogglingService;
  String? get errorMessage => _errorMessage;

  // --- Supervisor: Fetch assigned orders ---
  Future<void> fetchSupervisorOrders([
    String? status,
    bool silent = false,
  ]) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final endpoint = status != null && status != 'all'
          ? '${ApiConstants.supervisorOrders}?status=$status'
          : ApiConstants.supervisorOrders;
      final res = await _api.get(endpoint);
      if (res is List) {
        _supervisorOrders = res
            .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
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

  // --- Supervisor: الخدمات (المنتجات) المسندة إليه ---
  /// تُجلب مع الخدمات الموقوفة مؤقتاً ليراها مقدم الخدمة ويعيد تفعيلها
  Future<void> fetchAssignedServices({bool silent = false}) async {
    try {
      final res = await _api.get(ApiConstants.supervisorAssignedServices);
      if (res is List) {
        _assignedServices = res
            .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      if (!silent) _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// إيقاف مؤقت / إعادة تفعيل: الخدمة الموقوفة تختفي من واجهة العميل
  Future<bool> toggleServiceActive(String serviceId) async {
    _isTogglingService = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await _api.patch('/products/$serviceId/supervisor-toggle');
      if (res is Map) {
        final updated = ProductModel.fromJson(Map<String, dynamic>.from(res));
        final idx = _assignedServices.indexWhere((p) => p.id == updated.id);
        if (idx >= 0) _assignedServices[idx] = updated;
      }
      _isTogglingService = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isTogglingService = false;
      notifyListeners();
      return false;
    }
  }

  // Supervisor: Accept Order
  Future<bool> supervisorAcceptOrder(String orderId) async {
    try {
      await _api.post('${ApiConstants.orders}/$orderId/supervisor-accept');
      await fetchSupervisorOrders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Supervisor: Reject Order with reason
  Future<bool> supervisorRejectOrder(String orderId, String reason) async {
    try {
      await _api.post(
        '${ApiConstants.orders}/$orderId/supervisor-reject',
        body: {'reason': reason},
      );
      await fetchSupervisorOrders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Supervisor: Start execution
  Future<bool> supervisorStartOrder(String orderId) async {
    try {
      await _api.post('${ApiConstants.orders}/$orderId/supervisor-start');
      await fetchSupervisorOrders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Supervisor: Request additional info / files from customer
  Future<bool> supervisorRequestInfo(
    String orderId,
    String note, [
    String? attachmentUrl,
  ]) async {
    try {
      await _api.post(
        '${ApiConstants.orders}/$orderId/supervisor-request-info',
        body: {'note': note, 'attachmentUrl': attachmentUrl},
      );
      await fetchSupervisorOrders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Supervisor: Deliver final result (with optional credentials & attachments)
  Future<bool> supervisorDeliverOrder({
    required String orderId,
    String? resultNotes,
    Map<String, dynamic>? credentials,
    List<String>? attachments,
  }) async {
    try {
      await _api.post(
        '${ApiConstants.orders}/$orderId/supervisor-deliver',
        body: {
          'resultNotes': resultNotes,
          'credentials': credentials,
          'attachments': attachments,
        },
      );
      await fetchSupervisorOrders();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // --- Customer Actions ---
  // Customer confirms receipt & closes order (triggers auto-purge of secret data)
  Future<bool> customerConfirmOrder(String orderId) async {
    try {
      await _api.post('${ApiConstants.orders}/$orderId/customer-confirm');
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Customer requests revision
  Future<bool> customerRequestRevision(
    String orderId,
    String revisionNotes,
  ) async {
    try {
      await _api.post(
        '${ApiConstants.orders}/$orderId/customer-revision',
        body: {'revisionNotes': revisionNotes},
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Customer opens dispute
  Future<bool> customerOpenDispute(String orderId, String disputeReason) async {
    try {
      await _api.post(
        '${ApiConstants.orders}/$orderId/customer-dispute',
        body: {'disputeReason': disputeReason},
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // --- Order Chat & Communication ---
  Future<List<OrderChatMessageModel>> fetchOrderMessages(String orderId) async {
    try {
      final res = await _api.get('${ApiConstants.orders}/$orderId/messages');
      if (res is List) {
        return res
            .map(
              (e) =>
                  OrderChatMessageModel.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    return [];
  }

  Future<OrderChatMessageModel?> sendOrderMessage({
    required String orderId,
    required String message,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
    bool isSensitive = false,
  }) async {
    try {
      final res = await _api.post(
        '${ApiConstants.orders}/$orderId/messages',
        body: {
          'message': message,
          'attachmentUrl': attachmentUrl,
          'attachmentName': attachmentName,
          'attachmentType': attachmentType,
          'isSensitive': isSensitive,
        },
      );
      if (res is Map) {
        return OrderChatMessageModel.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
    return null;
  }

  // --- Secure Credentials Reveal ---
  Future<Map<String, dynamic>?> fetchDecryptedCredentials(
    String orderId,
  ) async {
    try {
      final res = await _api.get('${ApiConstants.orders}/$orderId/credentials');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
    return null;
  }

  // يفك تشفير مدخلات العميل (accountInput) للمشرف المسند/الأدمن
  Future<Map<String, dynamic>?> fetchDecryptedInput(String orderId) async {
    try {
      final res = await _api.get('${ApiConstants.orders}/$orderId/input');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
    return null;
  }

  // Upload attachment file (base64 data URI)
  Future<String?> uploadAttachment(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    try {
      final base64String = base64Encode(bytes);
      return 'data:$mimeType;base64,$base64String';
    } catch (_) {
      return null;
    }
  }

  // Fetch single order details
  Future<OrderModel?> fetchOrderById(String orderId) async {
    try {
      final res = await _api.get('${ApiConstants.orders}/$orderId');
      if (res is Map) {
        return OrderModel.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (_) {}
    return null;
  }
}
