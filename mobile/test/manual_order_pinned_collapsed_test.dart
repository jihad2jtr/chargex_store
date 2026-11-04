// «بيانات الطلب» والمحادثة في تذكرة الخدمة اليدوية ب«طلباتي»: مطويتان مع
// التذكرة افتراضياً — تظهران بالضغط على الطلب، والضغط على اللوحة يفتح المحادثة.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:layan_chargex/models/order_model.dart';
import 'package:layan_chargex/models/user_model.dart';
import 'package:layan_chargex/models/virtual_number_model.dart';
import 'package:layan_chargex/providers/app_catalog_provider.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/manual_services_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/screens/user/orders_history_screen.dart';

/// الشبكة معطّلة: أي استدعاء حقيقي يفشل فوراً ويبقى الهيكل ظاهراً
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

class _FakeAuth extends AuthProvider {
  @override
  UserModel? get currentUser => UserModel(
    id: 'c-1',
    userId: 'JGO26110412345',
    name: 'أحمد',
    email: 'ahmed@example.com',
    role: 'user',
    balance: 12,
  );

  // getters الصلاحية تقرأ الحقول الخاصة لا currentUser المُتجاوز
  @override
  bool get isAdmin => false;

  @override
  bool get isSupervisor => false;

  @override
  bool get isAgent => false;

  @override
  bool get isAuthenticated => true;
}

/// الطلبات مُزرَّعة بلا شبكة: المؤقّت الدوري ل«طلباتي» ينادي fetch بلا أثر
/// فلا تعلّق شبكي يُغرق الاختبار (نفس نمط orders_merged_numbers_type_test)
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
  @override
  List<VirtualNumberRequestModel> get myRequests =>
      const <VirtualNumberRequestModel>[];

  @override
  bool get isLoadingRequests => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchMyRequests({bool quiet = false}) async {}
}

/// المزوّد محلي: المحادثة فارغة والتحديث الصامت يعيد نفس الطلب
class _FakeManual extends ManualServicesProvider {
  _FakeManual(this._order);

  final OrderModel _order;

  @override
  Future<List<OrderChatMessageModel>> fetchOrderMessages(
    String orderId,
  ) async => <OrderChatMessageModel>[];

  @override
  Future<OrderModel?> fetchOrderById(String orderId) async => _order;

  @override
  Future<Map<String, dynamic>?> fetchDecryptedCredentials(
    String orderId,
  ) async => null;

  @override
  String? get errorMessage => null;
}

const String _product = 'خدمة يدوية — تركيب واتساب بزنس';

OrderModel _manualOrder() {
  return OrderModel(
    id: 'o-manual-1',
    orderNumber: 'ORD-2026-5555',
    userId: 'c-1',
    appId: 'app-1',
    appName: 'Chargex',
    productId: 's1',
    productName: _product,
    type: 'manual',
    amount: 6.5,
    status: 'pending',
    createdAt: DateTime(2026, 11, 3, 12, 0),
    pinnedData: [
      OrderPinnedDataModel(
        label: 'كود تحقق',
        value: '123456',
        createdAt: DateTime(2026, 11, 3, 12, 5),
      ),
      OrderPinnedDataModel(
        label: 'رقم هاتف',
        value: '+963999123456',
        createdAt: DateTime(2026, 11, 3, 12, 6),
      ),
    ],
  );
}

Future<void> _pumpOrders(WidgetTester w, OrderModel order) async {
  w.view.physicalSize = const Size(380, 1600);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppCatalogProvider>(
          create: (_) => _SeededCatalog([order]),
        ),
        // «طلباتي» تدمج سجل الأرقام الوهمية، فهي تحتاج مزوّد الأرقام
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => _SeededNumbers(),
        ),
        // الدخول إلى المحادثة يفتح شاشة التفاصيل وتحتاج هذين المزوّدين
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<ManualServicesProvider>(
          create: (_) => _FakeManual(order),
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
  await w.pump(const Duration(milliseconds: 400));
}

/// يفرد التذكرة بالضغط على اسم الخدمة (تبلّغ والدة التذكرة)
Future<void> _expandTicket(WidgetTester w) async {
  await w.tap(find.text(_product).first);
  await w.pump(const Duration(milliseconds: 250));
  await w.pump(const Duration(milliseconds: 250));
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('التذكرة مطوية: لوحة «بيانات الطلب» ومحادبتها لا تظهران', (
    w,
  ) async {
    await _pumpOrders(w, _manualOrder());

    expect(find.text(_product), findsWidgets);
    expect(find.text('بيانات الطلب'), findsNothing);
    expect(find.text('المحادثة'), findsNothing);
    expect(find.text('123456'), findsNothing);
  });

  testWidgets('الضغط على الطلب يُظهر اللوحة بقيمها المثبتة', (w) async {
    await _pumpOrders(w, _manualOrder());
    await _expandTicket(w);

    expect(find.text('بيانات الطلب'), findsOneWidget);
    expect(find.text('المحادثة'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('+963999123456'), findsOneWidget);
  });

  testWidgets('الضغط على اللوحة يفتح المحادثة', (w) async {
    await _pumpOrders(w, _manualOrder());
    await _expandTicket(w);

    await w.tap(find.text('بيانات الطلب'));
    await w.pump(const Duration(milliseconds: 400));
    await w.pump(const Duration(milliseconds: 400));

    // ترويسة المحادثة تحمل عنواناً بلون الهوية الأساسي
    expect(find.text('فريق الدعم الفني'), findsOneWidget);
  });
}
