// حماية تصميم «طلباتي»: قائمة قصيرة (تذاكر مطوية) + بلا فيض أفقي ولا تداخل
// عند بيانات طويلة (اسم تطبيق/باقة/ID/كود/ملاحظة إدارة) وفي الشاشات الضيقة.
// ملاحظة: استثناءات google_fonts متوقعة بلا شبكة في الاختبارات، لذلك
// نجمع استثناءات الطباعة (overflow) فقط — وهي العيب الحقيقي.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/core/services/cache_service.dart';
import 'package:layan_chargex/models/order_model.dart';
import 'package:layan_chargex/providers/app_catalog_provider.dart';
import 'package:layan_chargex/screens/user/orders_history_screen.dart';
import 'package:layan_chargex/widgets/app_thumb.dart';

/// الشبكة معطّلة في الاختبارات: أي طلب يفشل فوراً بدل أن يعلّق المجموعة
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

const String _longProduct =
    '4800 CoCP Points + Limited Edition Bonus Bundle Pack';

/// طلب ببيانات مطوّطة عمدًا لاختبار حدود العرض
OrderModel _hostileOrder({
  String status = 'pending',
  String type = 'direct_api',
  String? deliveredCode,
  String? adminNotes,
  String? appIcon,
  bool withInputs = true,
}) {
  return OrderModel(
    id: 'o-$status-$type-${deliveredCode == null ? 0 : 1}',
    orderNumber: 'ORD-2026-000001234567890',
    userId: 'u1',
    appId: 'a1',
    appName: 'Call of Duty Mobile — Regional Operations Server Zone',
    appIcon: appIcon,
    productId: 'p1',
    productName: _longProduct,
    type: type,
    amount: 1234.56,
    status: status,
    createdAt: DateTime(2026, 10, 27, 23, 45),
    deliveredCode: deliveredCode,
    adminNotes: adminNotes,
    accountInput: withInputs
        ? const {
            'رقم اللاعب (Player ID) في السيرفر الرئيسي':
                '123456789012345678901234567890',
            'Server / Zone Identifier': '98765432109876543210987654321',
          }
        : const {},
  );
}

Future<void> _pumpOrders(
  WidgetTester w,
  List<OrderModel> orders, {
  double width = 360,
}) async {
  // ذاكرة Provider الصرفة يقرأها AppCatalogProvider عند إنشائه
  await CacheService.instance.setList('my_orders', orders, (o) => o.toJson());

  w.view.physicalSize = Size(width, 900);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    ChangeNotifierProvider<AppCatalogProvider>(
      create: (_) => AppCatalogProvider(),
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

/// يفرد تفاصيل أول تذكرة (الضغط على اسم الباقة يبلّغ والدة التذكرة)
Future<void> _expandFirstTicket(WidgetTester w) async {
  await w.tap(find.text(_longProduct).first);
  await w.pump(const Duration(milliseconds: 250));
  await w.pump(const Duration(milliseconds: 250));
}

/// يستهلك استثناءات الطباعة (فيض الأفقي/الرأسي) فقط
List<String> _layoutFailures(WidgetTester w) {
  final List<String> errors = <String>[];
  Object? error;
  while ((error = w.takeException()) != null) {
    final String text = error.toString();
    if (text.contains('overflow') || text.contains('OVERFLOW')) {
      errors.add(text);
    }
  }
  return errors;
}

/// يتأكد أن مستطيلين لا يتقاطعان (أي لا تداخل بصري بين عنصرين)
void _expectNoOverlap(WidgetTester w, Finder a, Finder b, String label) {
  expect(
    a.evaluate().isNotEmpty && b.evaluate().isNotEmpty,
    isTrue,
    reason: label,
  );
  final Rect ra = w.getRect(a);
  final Rect rb = w.getRect(b);
  expect(
    ra.intersect(rb).isEmpty,
    isTrue,
    reason: '$label متداخلة: $ra مقابل $rb',
  );
}

Finder _ticketCard(WidgetTester w) => find
    .ancestor(
      of: find.textContaining('TKT #', findRichText: true).first,
      matching: find.byType(Container),
    )
    .first;

/// مسار الأصول المرسوم داخل أول مصغّرة تطبيق في القائمة
String? _firstThumbAsset(WidgetTester w) {
  final Image thumb = w
      .widgetList<Image>(
        find.descendant(
          of: find.byType(AppThumb),
          matching: find.byType(Image),
        ),
      )
      .first;
  final ImageProvider provider = thumb.image;
  return provider is AssetImage ? provider.assetName : null;
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _BlockedHttpOverrides();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await CacheService.instance.clearAll();
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  testWidgets('التذكرة مطوية افتراضياً: تفاصيلها مخفية وكرتها قصيرة', (
    WidgetTester w,
  ) async {
    await _pumpOrders(w, [
      _hostileOrder(
        deliveredCode: 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE-FFFFF-GGGGG-HHHHH',
        adminNotes:
            'ملاحظة إدارية طويلة جداً توضّح سبب الرفض وتطلب إعادة التحقق من بيانات الحساب المُدخل',
      ),
    ]);

    // البيانات التفصيلية لا تظهر قبل الفرد => قائمة السجل قصيرة
    expect(find.text('بيانات الحساب المدخلة للشحن:'), findsNothing);
    expect(find.text('كود البطاقة الرقمية المستلمة'), findsNothing);
    expect(find.text('نسخ الملخص'), findsNothing);

    // ارتفاع التذكرة المطوية صغير (كان ~250px قبل التصميم المدمج)
    final Size card = w.getSize(_ticketCard(w));
    expect(card.height, lessThan(100), reason: 'بط=$card');

    expect(_layoutFailures(w), isEmpty);
  });

  testWidgets('فرد التذكرة يُظهر بياناتها دون فيض', (WidgetTester w) async {
    await _pumpOrders(w, [
      _hostileOrder(
        deliveredCode: 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE-FFFFF-GGGGG-HHHHH',
        adminNotes:
            'ملاحظة إدارية طويلة جداً توضّح سبب الرفض وتطلب إعادة التحقق من بيانات الحساب المُدخل',
      ),
      _hostileOrder(status: 'delivered', type: 'manual'),
    ]);

    await _expandFirstTicket(w);

    expect(find.text('بيانات الحساب المدخلة للشحن:'), findsOneWidget);
    expect(find.text('كود البطاقة الرقمية المستلمة'), findsOneWidget);
    expect(find.text('نسخ الملخص'), findsOneWidget);
    expect(_layoutFailures(w), isEmpty);
  });

  testWidgets('تذاكر مطوية مع بيانات طويلة بدون فيض', (WidgetTester w) async {
    await _pumpOrders(w, [
      _hostileOrder(),
      _hostileOrder(status: 'rejected'),
      _hostileOrder(status: 'completed', type: 'codes'),
    ]);

    expect(_layoutFailures(w), isEmpty);
  });

  testWidgets('شريحة رقم التذكرة والتاريخ لا يتداخلان', (WidgetTester w) async {
    await _pumpOrders(w, [_hostileOrder()]);

    final Finder ticketChip = find.textContaining('TKT #', findRichText: true);
    // التاريخ وحده: نمط yyyy/MM/dd لا يشارك رقم الطلب في شيء
    final Finder dateMeta = find.textContaining(
      RegExp(r'\d{4}/\d{2}/\d{2}'),
      findRichText: true,
    );
    _expectNoOverlap(w, ticketChip, dateMeta, 'رقم التذكرة والتاريخ');

    // السعر/الحالة في عمود جانبي لا يلامسان العنوان
    _expectNoOverlap(
      w,
      find.text(_longProduct),
      find.text(r'$1234.56'),
      'العنوان والسعر',
    );

    expect(_layoutFailures(w), isEmpty);
  });

  testWidgets('شاشة ضيقة 320px بدون فيض أو تداخل', (WidgetTester w) async {
    await _pumpOrders(w, [
      _hostileOrder(
        deliveredCode: 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE',
        adminNotes: 'ملاحظة إدارة قصيرة',
      ),
      _hostileOrder(status: 'rejected', type: 'manual'),
    ], width: 320);

    expect(_layoutFailures(w), isEmpty);

    // التفاصيل أيضاً بلا فيض على شاشة ضيقة
    await _expandFirstTicket(w);
    expect(_layoutFailures(w), isEmpty);
  });

  testWidgets('قائمة الطلبات تعرض الأيقونة المربعة بدل صورة البطاقة', (
    WidgetTester w,
  ) async {
    // سواء كان المخزّن بطاقة عريضة أو رابطاً خارجياً أو لا شيء
    for (final String? stored in <String?>[
      null,
      'assets/cards/call-of-duty-mobile.png',
      'https://cdn.example.com/cod.png',
    ]) {
      await _pumpOrders(w, [_hostileOrder(appIcon: stored)]);
      expect(
        _firstThumbAsset(w),
        'assets/icons/call-of-duty-mobile.png',
        reason: 'المخزّن: $stored',
      );
      expect(_layoutFailures(w), isEmpty);
    }
  });

  testWidgets('لمسة التذكرة: فتحتا نصف دائرة مقتطعتان فعلياً في الحافتين', (
    WidgetTester w,
  ) async {
    await _pumpOrders(w, [_hostileOrder()]);

    // نصفا التذكرة: الرأس والذيل، وكلاهما مقطوع بنفس الشكل
    final Finder halves = find.descendant(
      of: _ticketCard(w),
      matching: find.byType(PhysicalShape),
    );
    expect(halves, findsNWidgets(2));

    // النصف العلوي: عند حافته السفلية اليسرى نقطة **خارج** الشكل (فتحة)
    final Size headSize = w.getSize(halves.first);
    final Path headClip = w
        .widgetList<PhysicalShape>(halves)
        .first
        .clipper
        .getClip(headSize);
    expect(
      headClip.contains(Offset(1, headSize.height - 2)),
      isFalse,
      reason: 'لا فتحة في الحافة اليسرى للرأس',
    );
    expect(
      headClip.contains(Offset(headSize.width / 2, headSize.height - 2)),
      isTrue,
      reason: 'وسط الحافة يجب أن يبقى داخل الكرت',
    );
    expect(
      headClip.contains(Offset(headSize.width - 1, headSize.height - 2)),
      isFalse,
      reason: 'لا فتحة في الحافة اليمنى للرأس',
    );

    // النصف السفلي: يكمل نفس الفتحتين عند حافته العليا
    final Size bodySize = w.getSize(halves.last);
    final Path bodyClip = w
        .widgetList<PhysicalShape>(halves)
        .last
        .clipper
        .getClip(bodySize);
    expect(bodyClip.contains(const Offset(1, 2)), isFalse);
    expect(bodyClip.contains(Offset(bodySize.width / 2, 2)), isTrue);
    expect(bodyClip.contains(Offset(bodySize.width - 1, 2)), isFalse);

    expect(_layoutFailures(w), isEmpty);
  });

  testWidgets('رقائق بيانات الحساب تنحصر داخل إطارها', (WidgetTester w) async {
    await _pumpOrders(w, [_hostileOrder()]);
    await _expandFirstTicket(w);

    final Finder inputsBox = find.ancestor(
      of: find.text('بيانات الحساب المدخلة للشحن:'),
      matching: find.byType(Container),
    );
    final Rect boxRect = w.getRect(inputsBox.first);
    for (final Widget widget in w.widgetList(find.byType(Text))) {
      if (widget is! Text) continue;
      final String data = widget.data ?? '';
      if (!data.contains('123456789012345678901234567890')) continue;
      final Rect r = w.getRect(find.byWidget(widget));
      expect(
        r.left >= boxRect.left - 0.5 && r.right <= boxRect.right + 0.5,
        isTrue,
        reason: 'قيمة ID تخرج من صندوق البيانات: $r مقابل $boxRect',
      );
    }

    expect(_layoutFailures(w), isEmpty);
  });
}
