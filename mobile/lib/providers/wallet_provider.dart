import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/payment_account_model.dart';
import '../models/manual_order_model.dart';

class WalletProvider extends ChangeNotifier {
  double _balance = 0.0;
  List<dynamic> _transactions = [];
  List<PaymentAccountModel> _shamCashAccounts = [];
  List<PaymentAccountModel> _binanceAccounts = [];
  List<ManualOrderModel> _myTopupRequests = [];

  bool _isLoading = false;
  String? _errorMessage;

  double get balance => _balance;
  List<dynamic> get transactions => _transactions;
  List<PaymentAccountModel> get shamCashAccounts => _shamCashAccounts;
  List<PaymentAccountModel> get binanceAccounts => _binanceAccounts;
  List<ManualOrderModel> get myTopupRequests => _myTopupRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final ApiClient _api = ApiClient();

  Future<void> fetchBalance() async {
    try {
      final res = await _api.get(ApiConstants.walletBalance);
      _balance = (res['balance'] is num) ? (res['balance'] as num).toDouble() : 0.0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchTransactions() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get(ApiConstants.walletTransactions);
      if (res is List) {
        _transactions = res;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPaymentAccounts() async {
    try {
      final resSham = await _api.get(ApiConstants.topupAccounts, queryParams: {'type': 'sham_cash'});
      if (resSham is List) {
        _shamCashAccounts = resSham.map((e) => PaymentAccountModel.fromJson(e)).toList();
      }

      final resBinance = await _api.get(ApiConstants.topupAccounts, queryParams: {'type': 'binance'});
      if (resBinance is List) {
        _binanceAccounts = resBinance.map((e) => PaymentAccountModel.fromJson(e)).toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchMyTopupRequests() async {
    try {
      final res = await _api.get(ApiConstants.topupMyRequests);
      if (res is List) {
        _myTopupRequests = res.map((e) => ManualOrderModel.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  // Verify shipping code without redeeming
  Future<Map<String, dynamic>?> verifyCode(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(ApiConstants.codesVerify, body: {'code': code.trim().toUpperCase()});
      _isLoading = false;
      notifyListeners();
      return (res is Map<String, dynamic>) ? res : Map<String, dynamic>.from(res);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Upload receipt image
  Future<String?> uploadReceiptImage(String base64Data) async {
    try {
      final res = await _api.post(ApiConstants.uploadImage, body: {'base64': base64Data});
      return res['url'] ?? res['secure_url'];
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  // Redeem shipping code (كود شحن)
  Future<String?> redeemCode(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(ApiConstants.codesRedeem, body: {'code': code.trim().toUpperCase()});
      await fetchBalance();
      await fetchTransactions();
      _isLoading = false;
      notifyListeners();
      return res['message'] ?? 'تم شحن الرصيد بنجاح';
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Submit manual topup (شام كاش / بيناس / آيدي)
  Future<bool> submitTopupRequest({
    required String type,
    required double amount,
    required Map<String, dynamic> details,
    String? receiptImageUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post(ApiConstants.topupRequest, body: {
        'type': type,
        'amount': amount,
        'details': details,
        'receiptImageUrl': receiptImageUrl,
      });
      await fetchMyTopupRequests();
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
}
