// لوحة إدارة الطلبات والشحن: هيدر عمليات بعدّادات، مبدّل أقسام، فلاتر
// بعدد الطلبات، وتبويب الشحن بالآيدي داخل الصفحة.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/manual_order_model.dart';
import 'package:layan_chargex/models/order_model.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/screens/admin/orders_management_screen.dart';
import 'package:layan_chargex/widgets/brand_logo.dart';

/// الشبكة معطّلة: تحميل الطلبات يفشل فوراً ويبقى الهيكل ظاهراً
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

/// مزوّد ببيانات محلية جاهزة: يسمح بفحص البطاقات ونوافذ الإجراءات دون شبكة
class _SeededAdmin extends AdminProvider {
  _SeededAdmin(this.orders, this.topups);

  final List<OrderModel> orders;
  final List<ManualOrderModel> topups;

  @override
  List<OrderModel> get adminOrders => orders;

  @override
  List<ManualOrderModel> get manualTopupRequests => topups;

  @override
  bool get isLoading => false;
}

OrderModel _order({String status = 'pending', String number = 'ORD-1001'}) {
  return OrderModel(
    id: 'o1',
    orderNumber: number,
    userId: 'u1',
    userName: 'أحمد محمد',
    userEmail: 'a@b.com',
    appId: 'a1',
    appName: 'Fortnite',
    productId: 'p1',
    productName: 'Fortnite 2800 V-Bucks',
    type: 'manual',
    amount: 12.5,
    status: status,
    accountInput: const {'player_id': '123456789'},
    createdAt: DateTime(2026, 10, 27, 10, 15),
  );
}

ManualOrderModel _topup({
  String status = 'pending',
  String type = 'sham_cash',
  String id = 't1',
  Map<String, dynamic> details = const {'transfer': 'SHAM-7788'},
  String? adminNotes,
  double amount = 20,
  DateTime? createdAt,
}) {
  return ManualOrderModel(
    id: id,
    userId: 'u1',
    userName: 'أحمد محمد',
    userEmail: 'a@b.com',
    type: type,
    amount: amount,
    details: details,
    status: status,
    adminNotes: adminNotes,
    createdAt: createdAt ?? DateTime(2026, 10, 27, 9, 0),
  );
}

Future<List<Object>> _pumpScreen(
  WidgetTester w, {
  double width = 400,
  AdminProvider? provider,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  w.view.physicalSize = Size(width, 900);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    ChangeNotifierProvider<AdminProvider>(
      create: (_) => provider ?? AdminProvider(),
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: OrdersManagementScreen(),
        ),
      ),
    ),
  );
  await w.pump(const Duration(milliseconds: 400));
  // نستهلك أخطاء الشبكة/الخط ونُبقي أخطاء التخطيط فقط للفحص
  final List<Object> errors = [];
  Object? e = w.takeException();
  while (e != null) {
    errors.add(e);
    e = w.takeException();
  }
  return errors
      .where((err) => !err.toString().contains('google_fonts'))
      .toList();
}

/// تفكيك الشاشة لإلغاء مؤقت التحديث التلقائي (Timer.periodic)
Future<void> _disposeScreen(WidgetTester w) async {
  await w.pumpWidget(const SizedBox.shrink());
  await w.pump(const Duration(seconds: 13));
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('الهيدر يعرض العدّادات الثلاثة ومؤشر التحديث', (w) async {
    await _pumpScreen(w);

    expect(find.text('إدارة الطلبات والشحن'), findsOneWidget);
    expect(find.text('تحديث تلقائي كل 12 ثانية'), findsOneWidget);
    expect(find.text('طلب قيد الانتظار'), findsOneWidget);
    expect(find.text('شحن رصيد معلّق'), findsOneWidget);
    expect(find.text('مكتمل اليوم'), findsOneWidget);

    await _disposeScreen(w);
  });

  testWidgets('مبدّل الأقسام الثلاثة وفلاتر الحالات موجودة', (w) async {
    // عرض أعرض كي تُبنى كل فلاتر الشريط الأفقي مرة واحدة
    await _pumpScreen(w, width: 560);

    expect(find.text('المشتريات'), findsOneWidget);
    expect(find.text('شحن الرصيد'), findsOneWidget);
    expect(find.text('شحن بالآيدي'), findsOneWidget);

    // الفلاتر تخص قسم المشتريات
    await w.tap(find.text('المشتريات'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 500));

    expect(find.text('الكل'), findsOneWidget);
    expect(find.text('قيد الانتظار'), findsOneWidget);
    expect(find.text('مكتملة'), findsOneWidget);
    expect(find.text('مرفوضة'), findsOneWidget);

    // الحالة الفارغة بعد انتهاء التحميل
    expect(find.text('لا توجد طلبات هنا'), findsOneWidget);

    await _disposeScreen(w);
  });

  testWidgets('الافتراضي هو شحن الرصيد ثم المشتريات', (w) async {
    await _pumpScreen(w);

    // شحن الرصيد أولاً (التبويب المفتوح افتراضياً)
    expect(find.text('لا توجد عمليات شحن'), findsOneWidget);
    expect(find.text('لا توجد طلبات هنا'), findsNothing);

    await w.tap(find.text('المشتريات'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 500));

    expect(find.text('لا توجد طلبات هنا'), findsOneWidget);
    expect(find.text('لا توجد عمليات شحن'), findsNothing);

    await _disposeScreen(w);
  });

  testWidgets('أداة الشحن بالآيدي تفتح وتقبل المبالغ السريعة', (w) async {
    await _pumpScreen(w);

    await w.tap(find.text('شحن بالآيدي'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 500));

    expect(find.text('شحن رصيد مباشر بالآيدي'), findsOneWidget);
    expect(find.text('إتمام الشحن الفوري'), findsOneWidget);

    await w.tap(find.text('+\$10'));
    await w.pump();
    expect(find.text('10'), findsOneWidget);

    await _disposeScreen(w);
  });

  testWidgets('لا يفيض التخطيط على الشاشات الضيقة', (w) async {
    final errors320 = await _pumpScreen(w, width: 320);
    expect(errors320, isEmpty);
    await _disposeScreen(w);

    final errors360 = await _pumpScreen(w, width: 360);
    expect(errors360, isEmpty);
    await _disposeScreen(w);
  });

  testWidgets('بطاقة الطلب تعرض بياناته وتفتح نافذة القبول', (w) async {
    await _pumpScreen(w, provider: _SeededAdmin([_order()], [_topup()]));

    await w.tap(find.text('المشتريات'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 500));

    expect(find.text('ORD-1001'), findsOneWidget);
    expect(find.text('\$12.50'), findsOneWidget);
    expect(find.text('قبول'), findsOneWidget);

    await w.tap(find.text('قبول'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 500));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('قبول وتنفيذ الطلب'), findsOneWidget);
    expect(find.text('تأكيد القبول والتنفيذ'), findsOneWidget);

    await w.tap(find.byIcon(Icons.close_rounded).last);
    await w.pump(const Duration(milliseconds: 400));

    await _disposeScreen(w);
  });

  testWidgets('عدّاد «طلب قيد الانتظار» ينقل إلى المشتريات مع الفلتر', (
    w,
  ) async {
    await _pumpScreen(w, provider: _SeededAdmin([_order()], [_topup()]));

    await w.tap(find.text('طلب قيد الانتظار'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 500));

    expect(find.text('ORD-1001'), findsOneWidget);
    expect(find.text('شام كاش'), findsNothing);

    await _disposeScreen(w);
  });

  testWidgets('طلب شحن الرصيد يعرض طريقته ويفتح نافذة الموافقة', (w) async {
    await _pumpScreen(w, provider: _SeededAdmin([_order()], [_topup()]));

    // شحن الرصيد هو التبويب الافتراضي
    expect(find.text('طلب شحن رصيد'), findsOneWidget);
    expect(find.text('SHAM-7788'), findsOneWidget);

    await w.tap(find.text('موافقة'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 500));

    expect(find.text('الموافقة على طلب شحن الرصيد'), findsOneWidget);
    expect(find.text('تأكيد الموافقة وشحن الرصيد'), findsOneWidget);

    await _disposeScreen(w);
  });

  testWidgets('سجل الشحن يجمع كل الوسائل ويُفلتر بينها', (w) async {
    await _pumpScreen(
      w,
      width: 560,
      provider: _SeededAdmin([], [
        _topup(id: 't1', createdAt: DateTime(2026, 10, 27, 9, 0)),
        _topup(
          id: 't2',
          type: 'code',
          details: const {'code': 'CHG-1111-2222'},
          status: 'approved',
          amount: 5,
          createdAt: DateTime(2026, 10, 26, 9, 0),
        ),
        _topup(
          id: 't3',
          type: 'id_topup',
          details: const {'آيدي العميل': 'jgo26101512345'},
          status: 'approved',
          adminNotes: 'شحن مباشر عبر الآيدي',
          amount: 7,
          createdAt: DateTime(2026, 10, 25, 9, 0),
        ),
      ]),
    );

    // الثلاثة ظاهرون في سجل واحد
    expect(find.text('SHAM-7788'), findsOneWidget);
    expect(find.text('CHG-1111-2222'), findsOneWidget);
    expect(find.text('jgo26101512345'), findsOneWidget);
    // شعار شام كاش يحل مكان الأيقونة العامة داخل بطاقة التذكرة
    expect(find.byType(BrandLogo), findsWidgets);

    // فلتر كروت الشحن يُظهر الكود فقط
    await w.tap(find.text('كروت الشحن'));
    await w.pump(const Duration(milliseconds: 300));

    expect(find.text('CHG-1111-2222'), findsOneWidget);
    expect(find.text('SHAM-7788'), findsNothing);
    expect(find.text('jgo26101512345'), findsNothing);

    await _disposeScreen(w);
  });

  testWidgets('تبويب الشحن بالآيدي يعرض سجل العمليات السابقة', (w) async {
    await _pumpScreen(
      w,
      width: 560,
      provider: _SeededAdmin([], [
        _topup(
          id: 't3',
          type: 'id_topup',
          details: const {'آيدي العميل': 'jgo26101512345'},
          status: 'approved',
          amount: 7,
          createdAt: DateTime(2026, 10, 25, 9, 0),
        ),
      ]),
    );

    // مبدّل الأقسام أعلى الصفحة، وأول تطابق هو القسم وليس بطاقة السجل
    await w.tap(find.text('شحن بالآيدي').first);
    await w.pump();
    await w.pump(const Duration(milliseconds: 500));

    expect(find.text('سجل الشحن ID'), findsOneWidget);
    // الآيدي المخزّنة تظهر كما هي في سطر بيانات العملية
    expect(find.text('jgo26101512345'), findsWidgets);
    // تلميح حقل الآيدي يقدّم الصيغة الجديدة بأحرف كبيرة
    expect(find.text('JGO26101512345'), findsOneWidget);
    expect(find.text('\$7.00'), findsOneWidget);

    await _disposeScreen(w);
  });
}
