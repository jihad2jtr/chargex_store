import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/agent_user_model.dart';

class AgentProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  AgentDashboardStats _stats = AgentDashboardStats();
  List<AgentUserModel> _subUsers = [];
  List<AgentTransferRecord> _transfers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _activeFilter = 'all'; // 'all' | 'active' | 'suspended'
  String _searchQuery = '';
  String _transferFilter = 'all'; // 'all' | 'in' | 'out'

  AgentDashboardStats get stats => _stats;
  List<AgentUserModel> get subUsers => _subUsers;
  List<AgentTransferRecord> get transfers => _transfers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get activeFilter => _activeFilter;
  String get searchQuery => _searchQuery;
  String get transferFilter => _transferFilter;

  // سجل التحويلات مصفّى بحسب الاتجاه: من الإدارة أو إلى العملاء
  // يقرأ من الواجهة العامة `transfers` كي تمرّ التصفية على أي مصدر للبيانات.
  List<AgentTransferRecord> get filteredTransfers {
    final all = transfers;
    if (_transferFilter == 'in') {
      return all.where((t) => t.isIncoming).toList();
    }
    if (_transferFilter == 'out') {
      return all.where((t) => !t.isIncoming).toList();
    }
    return all;
  }

  int get incomingTransferCount => transfers.where((t) => t.isIncoming).length;
  int get outgoingTransferCount => transfers.where((t) => !t.isIncoming).length;

  // Filtered view of sub-users
  // يقرأ من الواجهة العامة `subUsers` كي تمرّ التصفية على أي مصدر للبيانات.
  List<AgentUserModel> get filteredSubUsers {
    return subUsers.where((u) {
      if (_activeFilter == 'active' && !u.isActive) return false;
      if (_activeFilter == 'suspended' && u.isActive) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = u.name.toLowerCase().contains(q);
        final matchesEmail = u.email.toLowerCase().contains(q);
        final matchesPhone = u.phone?.toLowerCase().contains(q) ?? false;
        final matchesId = (u.userId ?? '').toLowerCase().contains(q);
        return matchesName || matchesEmail || matchesPhone || matchesId;
      }
      return true;
    }).toList();
  }

  void setFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setTransferFilter(String filter) {
    _transferFilter = filter;
    notifyListeners();
  }

  // --- Fetch Dashboard Stats ---
  Future<void> fetchDashboard({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final res = await _api.get(ApiConstants.agentDashboard);
      if (res is Map<String, dynamic>) {
        _stats = AgentDashboardStats.fromJson(res);
      }
    } catch (e) {
      if (!silent) _errorMessage = _cleanError(e);
    }

    if (!silent) {
      _isLoading = false;
    }
    notifyListeners();
  }

  // --- Fetch Sub Users ---
  Future<void> fetchSubUsers({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      String endpoint = ApiConstants.agentMyUsers;
      final params = <String>[];
      if (_searchQuery.trim().isNotEmpty) {
        params.add('search=${Uri.encodeComponent(_searchQuery.trim())}');
      }
      if (_activeFilter != 'all') {
        params.add('status=$_activeFilter');
      }
      if (params.isNotEmpty) {
        endpoint += '?${params.join('&')}';
      }

      final res = await _api.get(endpoint);
      if (res is List) {
        _subUsers = res
            .map(
              (item) =>
                  AgentUserModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    } catch (e) {
      if (!silent) _errorMessage = _cleanError(e);
    }

    if (!silent) {
      _isLoading = false;
    }
    notifyListeners();
  }

  // --- Fetch All Transfers Log ---
  Future<void> fetchTransfers({bool silent = false}) async {
    try {
      final res = await _api.get(ApiConstants.agentTransfers);
      if (res is List) {
        _transfers = res
            .map(
              (item) =>
                  AgentTransferRecord.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching transfers: $e');
    }
  }

  // --- Refresh All Agent Data ---
  Future<void> refreshAll({bool silent = false}) async {
    await Future.wait([
      fetchDashboard(silent: silent),
      fetchSubUsers(silent: silent),
      fetchTransfers(silent: silent),
    ]);
  }

  // --- Transfer Balance to Sub-User ---
  Future<Map<String, dynamic>> transferBalance({
    required String userId,
    required double amount,
    String? note,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        ApiConstants.agentTransferBalance,
        body: {
          'userId': userId,
          'amount': amount,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );

      // Refresh data silently
      await refreshAll(silent: true);
      _isLoading = false;
      notifyListeners();

      return {
        'success': true,
        'message': res['message'] ?? 'تم تحويل الرصيد بنجاح',
        'data': res,
      };
    } catch (e) {
      _isLoading = false;
      _errorMessage = _cleanError(e);
      notifyListeners();
      return {'success': false, 'message': _errorMessage ?? 'فشل تحويل الرصيد'};
    }
  }

  // --- Toggle User Status (Scam Freeze / Reactivate) ---
  Future<Map<String, dynamic>> toggleUserStatus({
    required String userId,
    required bool isActive,
    String? reason,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.patch(
        '${ApiConstants.agentToggleUserStatus}/$userId/toggle-status',
        body: {
          'isActive': isActive,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      );

      // Refresh sub-users and stats
      await refreshAll(silent: true);
      _isLoading = false;
      notifyListeners();

      return {
        'success': true,
        'message':
            res['message'] ??
            (isActive ? 'تم تفعيل الحساب' : 'تم تجميد الحساب فوراً'),
        'data': res,
      };
    } catch (e) {
      _isLoading = false;
      _errorMessage = _cleanError(e);
      notifyListeners();
      return {
        'success': false,
        'message': _errorMessage ?? 'فشل تحديث حالة المستخدم',
      };
    }
  }

  // --- Create New User Directly Under Agent ---
  Future<Map<String, dynamic>> createUserUnderAgent({
    required String name,
    required String email,
    required String password,
    String? phone,
    double? initialBalance,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        ApiConstants.agentCreateUser,
        body: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (initialBalance != null && initialBalance > 0)
            'initialBalance': initialBalance,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );

      await refreshAll(silent: true);
      _isLoading = false;
      notifyListeners();

      return {
        'success': true,
        'message': res['message'] ?? 'تم إنشاء العميل بنجاح',
        'data': res,
      };
    } catch (e) {
      _isLoading = false;
      _errorMessage = _cleanError(e);
      notifyListeners();
      return {'success': false, 'message': _errorMessage ?? 'فشل إنشاء العميل'};
    }
  }

  // --- Link Existing User To Agent ---
  Future<Map<String, dynamic>> linkUserToAgent(String userIdentifier) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        ApiConstants.agentLinkUser,
        body: {'userIdentifier': userIdentifier.trim()},
      );

      await refreshAll(silent: true);
      _isLoading = false;
      notifyListeners();

      return {
        'success': true,
        'message': res['message'] ?? 'تم ربط العميل بنجاح',
        'data': res,
      };
    } catch (e) {
      _isLoading = false;
      _errorMessage = _cleanError(e);
      notifyListeners();
      return {'success': false, 'message': _errorMessage ?? 'فشل ربط العميل'};
    }
  }

  String _cleanError(dynamic error) {
    final str = error.toString();
    if (str.startsWith('Exception: ')) {
      return str.replaceFirst('Exception: ', '');
    }
    return str;
  }
}
