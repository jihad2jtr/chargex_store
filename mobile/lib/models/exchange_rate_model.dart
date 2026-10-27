import 'package:intl/intl.dart';

/// سعر صرف الدولار مقابل الليرة السورية كما يجلبه الخادم من liranews.
/// السعر للعرض الاسترشادي فقط — لا يدخل في رصيد المحفظة ولا في عملية الدفع.
class ExchangeRateModel {
  final String pair;
  final double rate; // كم ليرة سورية يقابلها 1 دولار
  final double buy;
  final double sell;
  final double? previousRate;
  final double change;
  final double changePercent;
  final String source;
  final DateTime? updatedAt;
  final bool stale;

  const ExchangeRateModel({
    this.pair = 'usdsypd',
    required this.rate,
    this.buy = 0,
    this.sell = 0,
    this.previousRate,
    this.change = 0,
    this.changePercent = 0,
    this.source = 'liranews',
    this.updatedAt,
    this.stale = false,
  });

  bool get isValid => rate > 0;

  factory ExchangeRateModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) => value is num ? value.toDouble() : 0.0;
    final updated = json['updatedAt'] ?? json['fetchedAt'];

    return ExchangeRateModel(
      pair: json['pair']?.toString() ?? 'usdsypd',
      rate: toDouble(json['rate']),
      buy: toDouble(json['buy']),
      sell: toDouble(json['sell']),
      previousRate: json['previousRate'] is num
          ? (json['previousRate'] as num).toDouble()
          : null,
      change: toDouble(json['change']),
      changePercent: toDouble(json['changePercent']),
      source: json['source']?.toString() ?? 'liranews',
      updatedAt: updated == null ? null : DateTime.tryParse(updated.toString()),
      stale: json['stale'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pair': pair,
      'rate': rate,
      'buy': buy,
      'sell': sell,
      'previousRate': previousRate,
      'change': change,
      'changePercent': changePercent,
      'source': source,
      'updatedAt': updatedAt?.toIso8601String(),
      'stale': stale,
    };
  }

  static final NumberFormat _grouped = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _decimal = NumberFormat('#,##0.##', 'en_US');
  static final DateFormat _shortDate = DateFormat('d/M/yyyy');

  /// تحويل مبلغ بالدولار إلى الليرة السورية
  double toSyp(double usd) => usd * rate;

  /// نص سعر الصرف نفسه: "143.5"
  String get rateText => isValid ? _decimal.format(rate) : '—';

  /// تاريخ آخر تحديث: "26/10/2026"
  String get updatedAtText =>
      updatedAt == null ? '' : _shortDate.format(updatedAt!);

  /// المقابل بالليرة لسعر بالدولار: "139 ل.س" — فارغ إن لم يُعرف السعر
  /// الليرة السورية الجديدة (بعد حذف آخر صفرين)، فتُقرَّب لأقرب ليرة كاملة.
  String sypText(double usd) {
    if (!isValid || usd <= 0) return '';
    final value = toSyp(usd);
    final formatted = value >= 1
        ? _grouped.format(value)
        : _decimal.format(value);
    return '$formatted ل.س';
  }
}
