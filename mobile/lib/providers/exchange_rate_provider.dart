import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/services/cache_service.dart';
import '../models/exchange_rate_model.dart';

/// سعر صرف الدولار مقابل الليرة السورية.
/// يُعرض فوراً من الذاكرة/القرص ثم يُحدَّث من الخادم، والخادم نفسه يجدّد
/// السعر من liranews مرة كل 24 ساعة ويخزنه في قاعدة البيانات.
class ExchangeRateProvider extends ChangeNotifier {
  static const String _cacheKey = 'exchange_rate';

  final ApiClient _api = ApiClient();

  ExchangeRateModel? _rate;
  bool _isLoading = false;

  ExchangeRateModel? get rate => _rate;
  bool get hasRate => _rate != null && _rate!.isValid;
  bool get isLoading => _isLoading;

  /// كم ليرة مقابل 1 دولار (0 إن لم يُعرف السعر بعد)
  double get usdToSyp => _rate?.rate ?? 0;

  ExchangeRateProvider() {
    _loadFromCache();
  }

  void _loadFromCache() {
    final raw = CacheService.instance.get(_cacheKey);
    if (raw is Map) {
      try {
        _rate = ExchangeRateModel.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {
        _rate = null;
      }
    }
  }

  Future<void> fetch({bool force = false}) async {
    if (_isLoading) return;
    if (!force && _rate != null && !_rate!.stale) {
      // سعر محفوظ وحديث — لا داعي لطلب شبكة عند كل فتح للصفحة
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.get(ApiConstants.exchangeRate);
      if (res is Map) {
        final parsed = ExchangeRateModel.fromJson(
          Map<String, dynamic>.from(res),
        );
        if (parsed.isValid) {
          _rate = parsed;
          await CacheService.instance.set(_cacheKey, parsed.toJson());
        }
      }
    } catch (_) {
      // يفشل الاتصال؟ نُبقي آخر سعر محفوظ
    }

    _isLoading = false;
    notifyListeners();
  }

  /// تحميل السعر عند إقلاع التطبيق إن لم يكن محفوظاً وحديثاً
  Future<void> ensureLoaded() async {
    if (_rate != null && !_rate!.stale) return;
    await fetch(force: true);
  }

  /// "139 ل.س" لسعر بالدولار — نص فارغ إن لم يتوفر السعر
  String sypText(double usd) => _rate?.sypText(usd) ?? '';
}
