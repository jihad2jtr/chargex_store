// «طلباتي» صارت موحّدة: تذاكر المتجر (تطبيقات/ألعاب/خدمات) وتذاكر الأرقام
// الوهمية في قائمة واحدة مرتّبة زمنياً. شريط فلتر النوع أُزيل وبقي فلتر
// الحالة والبحث. سجل الأرقام لم يعد منعزلاً في صفحة الأرقام.
// الاختبار بلا شبكة (الشبكة محجومة).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/order_model.dart';
import 'package:layan_chargex/models/virtual_number_model.dart';
import 'package:layan_chargex/providers/app_catalog_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/providers/wallet_provider.dart';
import 'package:layan_chargex/screens/user/orders_history_screen.dart';
import 'package:layan_chargex/screens/user/virtual_number_wait_screen.dart';

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
        // صفحة انتظار الرقم الحيّ تقرأ المحفظة لتقرير زر «شراء رقم آخر»
        ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider()),
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

  testWidgets('شريط فلتر النوع أُزيل وكل التذاكر تظهر معاً', (w) async {
    await _pump(w, orders: orders, numbers: numbers);

    // رقائق النوع لم تعد موجودة
    expect(find.text('تطبيقات'), findsNothing);
    expect(find.text('ألعاب'), findsNothing);
    expect(find.text('أرقام'), findsNothing);

    // الطلبات والأرقام تُعرض مدموجة بلا طبقة نوع، وسجل الأرقام مدمج
    // مع تذاكر المتجر في قائمة واحدة (بنفس شكل التذاكر)
    expect(find.text('Netflix Monthly'), findsOneWidget);
    expect(find.text('Free Fire Diamonds'), findsOneWidget);
    expect(find.text('Gmail Recovery'), findsOneWidget);
    expect(find.text('telegram'), findsOneWidget);
    expect(find.text('whatsapp'), findsOneWidget);
    expect(find.textContaining('VN #VN-AAA'), findsOneWidget);

    expect(w.takeException(), isNull);
  });

  testWidgets('رقم حيّ في «طلباتي»: يُدرج والضغط يفتح صفحة انتظاره لا الطي', (
    w,
  ) async {
    final live = VirtualNumberRequestModel(
      id: 'live1',
      requestNumber: 'VN-LIVE',
      service: 'telegram',
      serviceName: 'Telegram',
      countryName: 'مصر',
      amount: 0.5,
      status: 'waiting',
      isLive: true,
      phoneNumber: '2015550007777',
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      expiresAt: DateTime.now().add(const Duration(minutes: 13)),
    );
    await _pump(
      w,
      orders: orders,
      numbers: <VirtualNumberRequestModel>[live, ...numbers],
    );

    // الحيّ يُعرض مع المنتهية: لم يعد مفقوداً من «طلباتي»
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.textContaining('VN #VN-LIVE'), findsOneWidget);

    // الضغط على تذكرة الحيّ ينقل إلى صفحة انتظاره المستقلة
    await w.tap(find.textContaining('VN #VN-LIVE'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));
    expect(find.byType(VirtualNumberWaitScreen), findsOneWidget);
    expect(find.text('انتظار الرمز'), findsOneWidget);
    // بذرة بلا cancelAfterAt (خادم قديم): زر الإلغاء ظاهر كما كان مسموحاً
    expect(find.textContaining('إلغاء الرقم واسترجاع'), findsOneWidget);

    await w.pumpWidget(const SizedBox());
    await w.pump(const Duration(milliseconds: 400));
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
