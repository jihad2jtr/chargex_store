/// إحصاءات لوحة تحكم الأدمن القادمة من `GET /dashboard/admin`
class DashboardDayPoint {
  final String date;
  final double revenue;
  final int orders;

  const DashboardDayPoint({
    required this.date,
    required this.revenue,
    required this.orders,
  });

  factory DashboardDayPoint.fromJson(Map<String, dynamic> json) {
    return DashboardDayPoint(
      date: json['date']?.toString() ?? '',
      revenue: _toDouble(json['revenue']),
      orders: _toInt(json['orders']),
    );
  }
}

class DashboardTopApp {
  final String name;
  final int orders;
  final double revenue;

  const DashboardTopApp({
    required this.name,
    required this.orders,
    required this.revenue,
  });

  factory DashboardTopApp.fromJson(Map<String, dynamic> json) {
    return DashboardTopApp(
      name: json['name']?.toString() ?? '',
      orders: _toInt(json['orders']),
      revenue: _toDouble(json['revenue']),
    );
  }
}

class DashboardStatsModel {
  final DateTime? generatedAt;

  // اليوم / الأمس
  final int ordersToday;
  final int ordersYesterday;
  final double revenueToday;
  final double revenueYesterday;
  final double profitToday;
  final double profitYesterday;

  // ما ينتظر تدخلًا
  final int pendingOrders;
  final double pendingOrdersAmount;
  final int delayedOrders;
  final int oldestPendingMinutes;
  final int pendingTopups;
  final double pendingTopupsAmount;
  final int oldestTopupMinutes;

  // نافذة 30 يومًا
  final int orders30d;
  final double revenue30d;
  final double profit30d;
  final double aov;
  final double failureRate;
  final double completionRate;

  // سلاسل ورسم بياني
  final List<DashboardDayPoint> last7Days;
  final List<DashboardTopApp> topApps;

  // صحة النظام
  final int codesAvailable;
  final int codesUsed;
  final int bannersActive;
  final int accountsActive;
  final int productsActive;
  final int appsActive;
  final int serviceTemplates;
  final int providersTotal;
  final int providersOnline;
  final int usersTotal;
  final int usersNewToday;
  final int usersSupervisors;

  const DashboardStatsModel({
    this.generatedAt,
    this.ordersToday = 0,
    this.ordersYesterday = 0,
    this.revenueToday = 0,
    this.revenueYesterday = 0,
    this.profitToday = 0,
    this.profitYesterday = 0,
    this.pendingOrders = 0,
    this.pendingOrdersAmount = 0,
    this.delayedOrders = 0,
    this.oldestPendingMinutes = 0,
    this.pendingTopups = 0,
    this.pendingTopupsAmount = 0,
    this.oldestTopupMinutes = 0,
    this.orders30d = 0,
    this.revenue30d = 0,
    this.profit30d = 0,
    this.aov = 0,
    this.failureRate = 0,
    this.completionRate = 0,
    this.last7Days = const [],
    this.topApps = const [],
    this.codesAvailable = 0,
    this.codesUsed = 0,
    this.bannersActive = 0,
    this.accountsActive = 0,
    this.productsActive = 0,
    this.appsActive = 0,
    this.serviceTemplates = 0,
    this.providersTotal = 0,
    this.providersOnline = 0,
    this.usersTotal = 0,
    this.usersNewToday = 0,
    this.usersSupervisors = 0,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> today = _asMap(json['today']);
    final Map<String, dynamic> pending = _asMap(json['pending']);
    final Map<String, dynamic> topups = _asMap(json['topups']);
    final Map<String, dynamic> last30 = _asMap(json['last30d']);
    final Map<String, dynamic> catalog = _asMap(json['catalog']);
    final Map<String, dynamic> providers = _asMap(json['providers']);
    final Map<String, dynamic> users = _asMap(json['users']);

    return DashboardStatsModel(
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      ordersToday: _toInt(today['orders']),
      ordersYesterday: _toInt(today['ordersYesterday']),
      revenueToday: _toDouble(today['revenue']),
      revenueYesterday: _toDouble(today['revenueYesterday']),
      profitToday: _toDouble(today['profit']),
      profitYesterday: _toDouble(today['profitYesterday']),
      pendingOrders: _toInt(pending['count']),
      pendingOrdersAmount: _toDouble(pending['amount']),
      delayedOrders: _toInt(pending['delayed']),
      oldestPendingMinutes: _toInt(pending['oldestMinutes']),
      pendingTopups: _toInt(topups['count']),
      pendingTopupsAmount: _toDouble(topups['amount']),
      oldestTopupMinutes: _toInt(topups['oldestMinutes']),
      orders30d: _toInt(last30['orders']),
      revenue30d: _toDouble(last30['revenue']),
      profit30d: _toDouble(last30['profit']),
      aov: _toDouble(last30['aov']),
      failureRate: _toDouble(last30['failureRate']),
      completionRate: _toDouble(last30['completionRate']),
      last7Days: (json['last7Days'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => DashboardDayPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      topApps: (json['topApps'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => DashboardTopApp.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      codesAvailable: _toInt(catalog['codesAvailable']),
      codesUsed: _toInt(catalog['codesUsed']),
      bannersActive: _toInt(catalog['bannersActive']),
      accountsActive: _toInt(catalog['accountsActive']),
      productsActive: _toInt(catalog['productsActive']),
      appsActive: _toInt(catalog['appsActive']),
      serviceTemplates: _toInt(catalog['serviceTemplates']),
      providersTotal: _toInt(providers['total']),
      providersOnline: _toInt(providers['online']),
      usersTotal: _toInt(users['total']),
      usersNewToday: _toInt(users['newToday']),
      usersSupervisors: _toInt(users['supervisors']),
    );
  }

  /// هل يوجد عمل ينتظر الأدمن الآن؟
  bool get needsAction =>
      pendingOrders > 0 || pendingTopups > 0 || delayedOrders > 0;

  /// إجمالي العناصر التي تحتاج تدخلًا
  int get actionCount => pendingOrders + pendingTopups + delayedOrders;

  /// نسبة تغيّر إيراد اليوم مقارنة بالأمس
  double get revenueDeltaPct {
    if (revenueYesterday <= 0) return revenueToday > 0 ? 100 : 0;
    return ((revenueToday - revenueYesterday) / revenueYesterday) * 100;
  }

  /// إجمالي إيرادات آخر 7 أيام
  double get weekRevenue =>
      last7Days.fold<double>(0, (sum, d) => sum + d.revenue);

  /// أطول انتظار بين الطلبات والإيداعات (بالدقائق)
  int get longestWaitMinutes => oldestPendingMinutes > oldestTopupMinutes
      ? oldestPendingMinutes
      : oldestTopupMinutes;

  /// ذروة إيراد اليوم في آخر 7 أيام (لرسم الأعمدة)
  double get weekPeak =>
      last7Days.fold<double>(0, (m, d) => d.revenue > m ? d.revenue : m);
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
