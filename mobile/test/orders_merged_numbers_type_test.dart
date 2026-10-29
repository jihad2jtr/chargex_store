// «طلباتي» صارت موحّدة: تذاكر المتجر (تطبيقات/ألعاب/خدمات) وتذاكر الأرقام
// الوهمية في قائمة واحدة مرتّبة زمنياً، مع شريط نوع يفصل بينهما. سجل الأرقام
// لم يعد منعزلاً في صفحة الأرقام. الاختبار بلا شبكة (الشبكة محجومة).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/order_model.dart';
import 'package:layan_chargex/models/virtual_number_model.dart';
import 'package:layan_chargex/providers/app_catalog_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/screens/user/orders_history_screen.dart';

class _BlockedHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _BlockingHttpClient();
}

class _BlockingHttpClient implements HttpClient {
  @override
  noSuchMethod(Invocation invocation) =>
      throw const SocketException('network is blocked in widget tests');
}

OrderModel _order({
  required String id,
  required String appType,
  required String product,
  required DateTime at,
}) => OrderModel(
  id: id,
  orderNumber: 'ORD-$id',
  userId: 'u1',
  appId: 'a-$id',
  appName: 'App $id',
  appType: appType,
  productId: 'p-$id',
  productName: product,
  type: 'direct_api',
  amount: 9.9,
  status: 'completed',
  createdAt: at,
);

VirtualNumberRequestModel _number({
  required String id,
  required String service,
  required String country,
  required DateTime at,
}) => VirtualNumberRequestModel(
  id: id,
  requestNumber: id,
  service: service,
  serviceName: service,
  countryName: country,
  amount: 0.5,
  status: 'completed',
  isLive: false,
  smsCode: '123456',
  createdAt: at,
);

class _SeededCatalog extends AppCatalogProvider {
  _SeededCatalog(this._orders);
  final List<OrderModel> _orders;

  @override
  List<OrderModel> get myOrders => _orders;

  @override
  bool get isLoading => false;

  @override
  Future<void> fetchMyOrders() async {}
}

class _SeededNumbers extends VirtualNumbersProvider {
  _SeededNumbers(this._requests);
  final List<VirtualNumberRequestModel> _requests;

  @override
  List<VirtualNumberRequestModel> get myRequests => _requests;

  @override
  bool get isLoadingRequests => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchMyRequests({bool quiet = false}) async {}
}

Future<void> _pump(
  WidgetTester w, {
  required List<OrderModel> orders,
  required List<VirtualNumberRequestModel> numbers,
  double width = 600,
  double height = 1400,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  w.view.physicalSize = Size(width, height);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppCatalogProvider>(
          create: (_) => _SeededCatalog(orders),
        ),
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => _SeededNumbers(numbers),
        ),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const OrdersHistoryScreen(),
        ),
      ),
    ),
  );
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
}

/// يفرد النوع المطلوب داخل الشريط الأفقي ثم ينقر عليه
Future<void> _tapChip(WidgetTester w, String label) async {
  final Finder chip = find.text(label).first;
  await w.ensureVisible(chip);
  await w.pump(const Duration(milliseconds: 200));
  await w.tap(chip);
  await w.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  final base = DateTime(2026, 10, 20, 12);
  final orders = <OrderModel>[
    _order(id: 'app1', appType: 'app', product: 'Netflix Monthly', at: base),
    _order(
      id: 'game1',
      appType: 'game',
      product: 'Free Fire Diamonds',
      at: base.add(const Duration(days: 1)),
    ),
    _order(
      id: 'svc1',
      appType: 'service',
      product: 'Gmail Recovery',
      at: base.add(const Duration(days: 2)),
    ),
  ];
  final numbers = <VirtualNumberRequestModel>[
    _number(
      id: 'VN-AAA',
      service: 'telegram',
      country: 'مصر',
      at: base.add(const Duration(days: 3)),
    ),
    _number(
      id: 'VN-BBB',
      service: 'whatsapp',
      country: 'كندا',
      at: base.add(const Duration(days: 4)),
    ),
  ];

  testWidgets('شريط النوع يظهر بأعداد الأرقام والأنواع', (w) async {
    await _pump(w, orders: orders, numbers: numbers);

    expect(find.text('تطبيقات'), findsOneWidget);
    expect(find.text('ألعاب'), findsOneWidget);
    expect(find.text('خدمات'), findsOneWidget);
    expect(find.text('أرقام'), findsOneWidget);
    expect(find.textContaining('VN #VN-AAA'), findsOneWidget);

    expect(w.takeException(), isNull);
  });

  testWidgets('سجل الأرقام مدمج مع تذاكر المتجر في قائمة واحدة', (w) async {
    await _pump(w, orders: orders, numbers: numbers);

    // تذاكر المتجر
    expect(find.text('Netflix Monthly'), findsOneWidget);
    expect(find.text('Free Fire Diamonds'), findsOneWidget);
    expect(find.text('Gmail Recovery'), findsOneWidget);
    // تذاكر الأرقام (بنفس شكل التذاكر)
    expect(find.text('telegram'), findsOneWidget);
    expect(find.text('whatsapp'), findsOneWidget);
    expect(find.textContaining('VN #VN-AAA'), findsOneWidget);

    expect(w.takeException(), isNull);
  });

  testWidgets('فلترة الأرقام تُبقي تذاكر الأرقام فقط', (w) async {
    await _pump(w, orders: orders, numbers: numbers);

    await _tapChip(w, 'أرقام');

    expect(find.text('telegram'), findsOneWidget);
    expect(find.text('whatsapp'), findsOneWidget);
    expect(find.text('Netflix Monthly'), findsNothing);
    expect(find.text('Free Fire Diamonds'), findsNothing);
    expect(find.text('Gmail Recovery'), findsNothing);

    expect(w.takeException(), isNull);
  });

  testWidgets('فلترة التطبيقات تُبقي نوع التطبيق المطابق فقط', (w) async {
    await _pump(w, orders: orders, numbers: numbers);

    await _tapChip(w, 'تطبيقات');

    expect(find.text('Netflix Monthly'), findsOneWidget);
    expect(find.text('Free Fire Diamonds'), findsNothing);
    expect(find.text('Gmail Recovery'), findsNothing);
    expect(find.text('telegram'), findsNothing);

    expect(w.takeException(), isNull);
  });

  testWidgets('الألعاب نوع مستقل والخدمات تجمع الخدمات', (w) async {
    await _pump(w, orders: orders, numbers: numbers);

    await _tapChip(w, 'ألعاب');
    expect(find.text('Free Fire Diamonds'), findsOneWidget);
    expect(find.text('Netflix Monthly'), findsNothing);

    await _tapChip(w, 'خدمات');
    expect(find.text('Gmail Recovery'), findsOneWidget);
    expect(find.text('telegram'), findsNothing);

    expect(w.takeException(), isNull);
  });

  testWidgets('فلتر الحالة يُطبَّق على الطلبات والأرقام معاً', (w) async {
    await _pump(w, orders: orders, numbers: numbers);

    // كلها مكتملة: «قيد الانتظار» يُخفي الطلبات والأرقام
    await w.tap(find.text('قيد الانتظار'));
    await w.pump(const Duration(milliseconds: 300));
    expect(find.text('Netflix Monthly'), findsNothing);
    expect(find.text('telegram'), findsNothing);

    expect(w.takeException(), isNull);
  });
}
