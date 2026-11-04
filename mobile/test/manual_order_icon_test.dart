// أيقونة الخدمة اليدوية في «طلباتي»: الطلب اليدوي لا تطبيق متجر له، بل
// «تطبيق أرقام» (virtualNumberAppId) يجلب الخادم اسمه وأيقونته مع التذكرة.
// قبل هذا المسار كانت التذكرة اليدوية تُرسم بمربّع فارغ بلا أيقونة.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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

/// الطلبات مُزرَّعة بلا شبكة: المؤقّت الدوري ل«طلباتي» ينادي fetch بلا أثر
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

/// payload تذكرة يدوية كما يرسلها /orders/my: لا appId، والتطبيق في
/// virtualNumberAppId (populate باسمه وأيقونته)
Map<String, dynamic> manualOrderJson({
  String appName = 'Telegram',
  String? iconUrl = 'builtin:telegram',
  String productName = 'تفعيل تيليجرام يدوي',
}) {
  return <String, dynamic>{
    '_id': 'o-manual-1',
    'orderNumber': 'ORD-2026-5555',
    'userId': 'c-1',
    'appId': null,
    'virtualNumberAppId': <String, dynamic>{
      '_id': 'va-1',
      'name': appName,
      'iconUrl': iconUrl,
    },
    'productId': <String, dynamic>{
      '_id': 'p-1',
      'name': productName,
      'type': 'manual',
    },
    'type': 'manual',
    'amount': 2.5,
    'cost': 0,
    'profit': 2.5,
    'status': 'pending',
    'createdAt': '2026-11-03T12:00:00.000Z',
    'accountInput': <String, dynamic>{},
  };
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
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => _SeededNumbers(),
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

/// الأيقونة المربعة المرسومة داخل التذكرة، أو null إن لم تُرسم أيقونة أصل
String? _renderedIcon(WidgetTester w, String assetName) {
  final Finder f = find.byWidgetPredicate(
    (Widget x) =>
        x is Image &&
        x.image is AssetImage &&
        (x.image as AssetImage).assetName == assetName,
  );
  return f.evaluate().isEmpty ? null : assetName;
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('OrderModel يقرأ هوية تطبيق الأرقام', () {
    test('تذكرة يدوية: الاسم والأيقونة من virtualNumberAppId', () {
      final OrderModel o = OrderModel.fromJson(manualOrderJson());
      expect(o.isManual, isTrue);
      expect(o.appName, 'Telegram');
      expect(o.appIcon, 'builtin:telegram');
      expect(o.productName, 'تفعيل تيليجرام يدوي');
    });

    test('تطبيق أرقام بلا أيقونة مخزّنة: الاسم يكفي لاستنتاج الأيقونة', () {
      final OrderModel o = OrderModel.fromJson(manualOrderJson(iconUrl: null));
      expect(o.appName, 'Telegram');
      expect(o.appIcon, isNull);
    });

    test('تفريغ ثم إعادة تخزين (الذاكرة المحلية): الأيقونة لا تُفقد', () {
      final OrderModel o = OrderModel.fromJson(manualOrderJson());
      final OrderModel r = OrderModel.fromJson(o.toJson());
      expect(r.appName, 'Telegram');
      expect(r.appIcon, 'builtin:telegram');
    });
  });

  group('أيقونة التذكرة اليدوية في «طلباتي»', () {
    testWidgets('اسم التطبيق المخدوم يظهر سطراً ثانياً في التذكرة', (w) async {
      await _pumpOrders(w, OrderModel.fromJson(manualOrderJson()));
      expect(find.text('Telegram'), findsOneWidget);
    });

    testWidgets('الأيقونة المربعة تُرسم بدل المربّع الفارغ', (w) async {
      await _pumpOrders(w, OrderModel.fromJson(manualOrderJson()));
      expect(_renderedIcon(w, 'assets/icons/telegram.png'), isNotNull);
    });

    testWidgets('اسم أيقونة غير معروف: الرمز يُستنتج من اسم التطبيق', (
      w,
    ) async {
      await _pumpOrders(
        w,
        OrderModel.fromJson(manualOrderJson(appName: 'واتساب', iconUrl: '')),
      );
      expect(_renderedIcon(w, 'assets/icons/whatsapp.png'), isNotNull);
    });

    testWidgets('سجل قديم بلا اسم تطبيق: الأيقونة تُشتق من اسم الخدمة', (
      w,
    ) async {
      // تذكرة قبل هذا الإصلاح: virtualNumberAppId محذوف وappName فارغ
      final Map<String, dynamic> legacy = OrderModel.fromJson(
        manualOrderJson(),
      ).toJson();
      legacy['appName'] = '';
      legacy['appIcon'] = null;
      await _pumpOrders(w, OrderModel.fromJson(legacy));

      expect(_renderedIcon(w, 'assets/icons/telegram.png'), isNotNull);
    });
  });
}
