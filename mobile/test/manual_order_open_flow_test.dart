// فتح صفحة الطلب (الدردشة) في المسارات التي كانت مغلقة:
// — شراء خدمة يدوية من صفحة الأرقام أو صفحة الباقات: كان يحدّث السجل ويُبقي
//   العميل في القائمة، فصار ينتقل إلى صفحة الطلب ليُتمّ المتابعة مع المقدّم
// — الضغط على إشعار طلب: كان معالج التنقل debugPrint فقط، فصار يفتح صفحة
//   الطلب نفسها؛ والطلبات التلقائية تُوجَّه إلى سجل الطلبات، والإشعارات بلا
//   orderId (المالية/العامة) تبقى بلا تنقل
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/services/cache_service.dart';
import 'package:layan_chargex/core/services/fcm_service.dart';
import 'package:layan_chargex/models/order_model.dart';
import 'package:layan_chargex/providers/app_catalog_provider.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/manual_services_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/providers/wallet_provider.dart';
import 'package:layan_chargex/screens/user/manual_order_details_screen.dart';
import 'package:layan_chargex/screens/user/orders_history_screen.dart';
import 'package:layan_chargex/screens/user/virtual_numbers_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _RichWallet extends WalletProvider {
  @override
  double get balance => 10;

  @override
  Future<void> fetchBalance() async {}
}

/// شراء ناجح بلا شبكة: الاستجابة تُعيد الطلب كما يصفه الخادم بعد populate،
/// و`idOnly` تحاكي ردّاً بالمعرّف وحده فيُلتقط الطلب من سجل «طلباتي»
class _StubCatalog extends AppCatalogProvider {
  _StubCatalog({this.idOnly = false});

  final bool idOnly;

  @override
  List<OrderModel> get myOrders => <OrderModel>[_order()];

  @override
  Future<Map<String, dynamic>?> purchaseProduct({
    required String productId,
    Map<String, dynamic>? accountInput,
  }) async => <String, dynamic>{
    'message': 'تم استلام طلبك وجاري تحويله للمشرف المختص',
    'order': idOnly ? 'o-9' : _orderJson(orderNumber: 'ORD-7001'),
    'newBalance': 7.5,
  };

  @override
  Future<void> fetchMyOrders() async {}
}

/// الدردشة تُقرأ من المزوّد: بلا شبكة تبقى المحادثة فارغة والحالة معلومة
class _StubManual extends ManualServicesProvider {
  _StubManual([this._order]);

  final OrderModel? _order;

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
  Future<Map<String, dynamic>?> fetchDecryptedInput(String orderId) async =>
      null;
}

final DateTime _now = DateTime(2026, 11, 4, 10, 0);

Map<String, dynamic> _orderJson({String orderNumber = 'ORD-7001'}) =>
    <String, dynamic>{
      '_id': 'o-9',
      'orderNumber': orderNumber,
      'userId': 'c-1',
      'appId': 'app-1',
      'productId': 'ms1',
      'type': 'manual',
      'amount': 2.5,
      'status': 'assigned',
      'createdAt': _now.toIso8601String(),
      'estimatedMinutes': 90,
    };

OrderModel _order({String status = 'assigned'}) =>
    OrderModel.fromJson(_orderJson()..['status'] = status);

/// طلب تلقائي (شحن حساب أو كود): وجهته سجل الطلبات لا تذكرة المحادثة
OrderModel _autoOrder() =>
    OrderModel.fromJson(_orderJson()..['type'] = 'direct_api');

Map<String, dynamic> _manualService({
  String id = 'ms1',
  String name = 'تفعيل تيليجرام يدوي',
  double price = 2.50,
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'price': price,
  'requiredFields': <String>[],
  'estimatedMinutes': 90,
  'appName': 'Telegram',
  'appIcon': 'assets/icons/telegram.png',
  'isSensitive': false,
};

void _setSize(WidgetTester w, {double height = 2600}) {
  w.view.physicalSize = Size(400, height);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);
}

Future<void> _dispose(WidgetTester w) async {
  await w.pumpWidget(const SizedBox());
  await w.pump(const Duration(milliseconds: 400));
}

/// صفحة الأرقام بمزوّداتها: الطلب اليدوي يمر عبر AppCatalogProvider
Future<void> _pumpNumbersPage(WidgetTester w) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await CacheService.instance.clearAll();
  await CacheService.instance.setRawList(
    'vn_manual_services',
    <Map<String, dynamic>>[_manualService()],
  );
  _setSize(w);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>(create: (_) => _RichWallet()),
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => VirtualNumbersProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<AppCatalogProvider>(
          create: (_) => _StubCatalog(),
        ),
        ChangeNotifierProvider<ManualServicesProvider>(
          create: (_) => _StubManual(_order()),
        ),
      ],
      child: MaterialApp(
        // الصفحة نفسها ListView بلا Scaffold: في التطبيق تُركّب داخل scaffold
        // الشاشة الرئيسية، وshowTopSnackBar يحتاج هذا الـ Scaffold ليقدّم بانره
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const Scaffold(body: VirtualNumbersScreen(showAppBar: false)),
        ),
      ),
    ),
  );
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
}

/// شاشة رئيسية بمفتاح مُلاحة مسجَّل في FcmService، وجلب الطلب يُعيد `fetched`
Future<GlobalKey<NavigatorState>> _pumpHome(
  WidgetTester w,
  OrderModel? fetched,
) async {
  _setSize(w);
  final navKey = GlobalKey<NavigatorState>();

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<AppCatalogProvider>(
          create: (_) => AppCatalogProvider(),
        ),
        // سجل الطلبات يقرأ سجل الأرقام الوهمية في initState، فهو شريكه في
        // الشاشة الرئيسية لا بديل عنه
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => VirtualNumbersProvider(),
        ),
        ChangeNotifierProvider<ManualServicesProvider>(
          create: (_) => _StubManual(fetched),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Center(child: Text('الرئيسية'))),
      ),
    ),
  );
  await w.pump();
  FcmService.instance.navigatorKey = navKey;
  return navKey;
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() {
    HttpOverrides.global = null;
    FcmService.instance.navigatorKey = null;
  });

  testWidgets('شراء خدمة يدوية من صفحة الأرقام ينقل مباشرة إلى صفحة الطلب', (
    WidgetTester w,
  ) async {
    await _pumpNumbersPage(w);

    await w.tap(find.text('الخدمات اليدوية'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));
    await w.tap(find.text('تفعيل تيليجرام يدوي').first);
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(BottomSheet), findsOneWidget);
    await w.tap(find.widgetWithText(ElevatedButton, 'تأكيد الطلب (\$2.50)'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 600));

    // النافذة أُغلقت والعميل داخل تذكرة الطلب/الدردشة، لا في قائمة الخدمات
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(ManualOrderDetailsScreen), findsOneWidget);

    await _dispose(w);
  });

  testWidgets('الضغط على إشعار طلب يفتح صفحة الطلب نفسها', (
    WidgetTester w,
  ) async {
    await _pumpHome(w, _order(status: 'delivered'));

    await FcmService.instance.handleNotificationNavigation(<String, dynamic>{
      'orderId': 'o-9',
      'type': 'order_delivered',
    });
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(ManualOrderDetailsScreen), findsOneWidget);
    // الطلب فُتح بنسخته الكاملة لا بمعرّفه فقط: رقم الطلب ظاهر في الرأس
    expect(find.textContaining('ORD-7001'), findsWidgets);

    await _dispose(w);
  });

  testWidgets('إشعار طلب تلقائي لا يفتح محادثة اليدوي بل سجل الطلبات', (
    WidgetTester w,
  ) async {
    // باقة شُحنت أو كود: لا تذكرة دردشة له، وفتح محادثة فارغة يوهم العميل
    await _pumpHome(w, _autoOrder());

    await FcmService.instance.handleNotificationNavigation(<String, dynamic>{
      'orderId': 'o-9',
      'type': 'order_status',
    });
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(ManualOrderDetailsScreen), findsNothing);
    expect(find.byType(OrdersHistoryScreen), findsOneWidget);

    await _dispose(w);
  });

  testWidgets('إشعار بلا معرّف طلب (مالي/عام) لا يفتح صفحة طلب', (
    WidgetTester w,
  ) async {
    await _pumpHome(w, _order());

    await FcmService.instance.handleNotificationNavigation(<String, dynamic>{
      'type': 'wallet_topup',
      'amount': 5,
    });
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(ManualOrderDetailsScreen), findsNothing);
    expect(find.text('الرئيسية'), findsOneWidget);

    await _dispose(w);
  });

  test('طلبات الشراء تُلتقط من الاستجابة أو من سجل «طلباتي»', () async {
    // الخادم يعيد الطلب كاملاً بعد populate: هذه نسخة الاستجابة الكاملة
    final full = _StubCatalog();
    expect(
      full
          .lastPurchasedOrder(await full.purchaseProduct(productId: 'ms1'))!
          .orderNumber,
      'ORD-7001',
    );

    // ولو أعاد المعرّف وحده، فالسجل المحدَّث حديثاً يفي بالغرض
    final idOnly = _StubCatalog(idOnly: true);
    final picked = idOnly.lastPurchasedOrder(
      await idOnly.purchaseProduct(productId: 'ms1'),
    );
    expect(picked!.id, 'o-9');
    expect(picked.isManual, isTrue);

    // بلا ردّ شراء ناجح لا يُختلق طلب
    expect(full.lastPurchasedOrder(null), isNull);
  });
}
