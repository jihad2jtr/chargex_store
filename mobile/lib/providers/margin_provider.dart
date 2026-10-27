import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarginProvider extends ChangeNotifier {
  static const String _prefKeyMarginPercent = 'user_profit_margin_percent';
  static const String _prefKeyMarginEnabled = 'user_profit_margin_enabled';

  double _marginPercent = 0.0;
  bool _isEnabled = false;
  bool _isLoaded = false;

  double get marginPercent => _marginPercent;
  bool get isEnabled => _isEnabled;
  bool get isLoaded => _isLoaded;

  MarginProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _marginPercent = prefs.getDouble(_prefKeyMarginPercent) ?? 0.0;
      _isEnabled = prefs.getBool(_prefKeyMarginEnabled) ?? false;
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading margin settings: $e');
    }
  }

  Future<void> saveMargin({
    required double percent,
    required bool enabled,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _marginPercent = percent;
      _isEnabled = enabled;
      await prefs.setDouble(_prefKeyMarginPercent, percent);
      await prefs.setBool(_prefKeyMarginEnabled, enabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving margin settings: $e');
    }
  }

  /// Calculates the customer selling price given the wholesale/cost price.
  double calculateCustomerPrice(double costPrice) {
    if (!_isEnabled || _marginPercent <= 0) {
      return costPrice;
    }
    return costPrice * (1 + (_marginPercent / 100.0));
  }

  /// Calculates the profit amount on top of the wholesale price.
  double calculateProfit(double costPrice) {
    if (!_isEnabled || _marginPercent <= 0) {
      return 0.0;
    }
    return costPrice * (_marginPercent / 100.0);
  }
}
