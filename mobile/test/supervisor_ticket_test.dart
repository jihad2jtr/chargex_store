// صفحة مقدم الخدمة (المشرف): تذكرة واحدة تجمع بوابة «خدماتي المسندة»
// (محلّ رسالة الترحيب) مع شريط مؤشرات الطلبات الذي يفلتر القائمة،
// وتذاكر الطلبات مطوية فلا تظهر تفاصيلها وأزرارها إلا عند النقر عليها.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:layan_chargex/core/theme/app_colors.dart';
import 'package:layan_chargex/models/order_model.dart';
import 'package:layan_chargex/models/product_model.dart';
import 'package:layan_chargex/models/user_model.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/manual_services_provider.dart';
import 'package:layan_chargex/screens/supervisor/supervisor_dashboard_screen.dart';
import 'package:layan_chargex/widgets/digital_pass_card.dart';
import 'package:layan_chargex/widgets/live_status_console.dart';

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
  _FakeAuth()
    : _user = UserModel(
        id: 'u-sup',
        userId: 'JGO777',
        name: 'مشرف الاختبار',
        email: 'sup@jgo.store',
        role: 'supervisor',
        balance: 0.0,
      );

  final UserModel _user;

  @override
  UserModel? get currentUser => _user;
}

/// مزوّد محلي: خدمات مسندة + طلبات، والإيقاف يقلب isActive في الذاكرة
class _FakeManual extends ManualServicesProvider {
  _FakeManual(this._services, this._orders);

  final List<ProductModel> _services;
  final List<OrderModel> _orders;

  final List<String> toggleCalls = <String>[];
  int ordersFetches = 0;
  int servicesFetches = 0;

  @override
  List<ProductModel> get assignedServices => _services;

  @override
  List<OrderModel> get supervisorOrders => _orders;

  @override
  bool get isLoading => false;

  @override
  bool get isTogglingService => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchSupervisorOrders([
    String? status,
    bool silent = false,
  ]) async {
    ordersFetches++;
  }

  @override
  Future<void> fetchAssignedServices({bool silent = false}) async {
    servicesFetches++;
  }

  @override
  Future<bool> toggleServiceActive(String serviceId) async {
    toggleCalls.add(serviceId);
    final idx = _services.indexWhere((p) => p.id == serviceId);
    if (idx >= 0) {
      final p = _services[idx];
      _services[idx] = ProductModel(
        id: p.id,
        appId: p.appId,
        name: p.name,
        quantityLabel: p.quantityLabel,
        type: p.type,
        costPrice: p.costPrice,
        salePrice: p.salePrice,
        isActive: !p.isActive,
        requiredFields: p.requiredFields,
        estimatedMinutes: p.estimatedMinutes,
        isSensitive: p.isSensitive,
        sensitiveFields: p.sensitiveFields,
        instructions: p.instructions,
      );
      notifyListeners();
    }
    return true;
  }

  @override
  Future<Map<String, dynamic>?> fetchDecryptedInput(String orderId) async {
    return <String, dynamic>{
      'accountInput': <String, dynamic>{'كلمة المرور': 'secret-9981'},
    };
  }
}

ProductModel _service({
  required String id,
  required String name,
  bool isActive = true,
  double salePrice = 24.75,
  int estimatedMinutes = 45,
  String quantityLabel = '',
  List<String> requiredFields = const [],
  bool isSensitive = false,
  List<String> sensitiveFields = const [],
  String? instructions,
}) {
  return ProductModel(
    id: id,
    appId: 'app-$id',
    name: name,
    quantityLabel: quantityLabel,
    type: 'manual',
    costPrice: 10.0,
    salePrice: salePrice,
    isActive: isActive,
    requiredFields: requiredFields,
    estimatedMinutes: estimatedMinutes,
    isSensitive: isSensitive,
    sensitiveFields: sensitiveFields,
    instructions: instructions,
  );
}

OrderModel _order({
  required String id,
  required String orderNumber,
  required String status,
  required String productId,
  required String productName,
  required double amount,
  Map<String, dynamic> accountInput = const {},
  List<String> sensitiveFields = const [],
  bool isSensitive = false,
  DateTime? deadlineAt,
  bool isDelayed = false,
}) {
  return OrderModel(
    id: id,
    orderNumber: orderNumber,
    userId: 'c-1',
    userName: 'أحمد سيد',
    appId: 'app-1',
    appName: 'Chargex',
    productId: productId,
    productName: productName,
    type: 'manual',
    amount: amount,
    status: status,
    accountInput: accountInput,
    createdAt: DateTime(2026, 10, 27, 9, 30),
    deadlineAt: deadlineAt,
    isDelayed: isDelayed,
    isSensitive: isSensitive,
    sensitiveFields: sensitiveFields,
    estimatedMinutes: 45,
  );
}

List<ProductModel> _services() => [
  _service(
    id: 's1',
    name: 'تعبئة رصيد فري فاير 1000 جمة',
    quantityLabel: '1000 جمة',
    requiredFields: const ['Player ID', 'Server ID'],
    instructions: 'تأكد من صحة رقم اللاعب قبل تنفيذ التعبئة',
  ),
  _service(
    id: 's2',
    name: 'حساب نتفليكس بريميم — تثبيت على جهازين',
    isActive: false,
    salePrice: 999999.99,
    estimatedMinutes: 1200,
    isSensitive: true,
    sensitiveFields: const ['كلمة المرور'],
    requiredFields: const ['البريد الإلكتروني', 'كلمة المرور'],
  ),
];

List<OrderModel> _orders() => [
  _order(
    id: 'o1',
    orderNumber: 'ORD-4471',
    status: 'assigned',
    productId: 's1',
    productName: 'تعبئة رصيد فري فاير 1000 جمة',
    amount: 24.75,
    accountInput: const {'Player ID': '778812', 'كلمة المرور': 'secret-9981'},
    sensitiveFields: const ['كلمة المرور'],
    isSensitive: true,
    deadlineAt: DateTime(2000, 1, 1),
    isDelayed: true,
  ),
  _order(
    id: 'o2',
    orderNumber: 'ORD-4472',
    status: 'in_progress',
    productId: 's2',
    productName: 'حساب نتفليكس بريميم — تثبيت على جهازين',
    amount: 0.0,
  ),
];

final List<Object> _collected = <Object>[];

void _drain(WidgetTester w) {
  for (;;) {
    final Object? error = w.takeException();
    if (error == null) break;
    _collected.add(error);
  }
}

Future<void> _settle(WidgetTester w, {int ms = 500}) async {
  await w.pump();
  await w.pump(Duration(milliseconds: ms));
  _drain(w);
}

/// يُسقط شريط التأكيد العائم قبل لمسة تالية كي لا يحجب الزر
Future<void> _clearSnack(WidgetTester w) async {
  await w.pump(const Duration(seconds: 5));
  await w.pump(const Duration(milliseconds: 400));
  _drain(w);
}

/// يفرّغ الشجرة فيُلغي منصّة الوكيل مؤقّت التحديث الدوري (12 ثانية)
Future<void> _dispose(WidgetTester w) async {
  await w.pumpWidget(const SizedBox.shrink());
  _drain(w);
}

void _expectClean() {
  final overflow = _collected
      .where((e) => e.toString().contains('RenderFlex overflowed'))
      .toList();
  expect(overflow, isEmpty, reason: 'طفو تخطيط: $overflow');
}

/// التذكرة تُعرَّف بفتحات التثقيب: ClipPath بحامل TicketPassClipper
Finder _ticketClips() => find.byWidgetPredicate(
  (widget) => widget is ClipPath && widget.clipper is TicketPassClipper,
);

/// نصفا التذكرة المطوية (رأس + جسم) للحامل الخاص بهما
Finder _foldedHalves() => find.byWidgetPredicate(
  (widget) =>
      widget is PhysicalShape &&
      widget.clipper.runtimeType.toString() == '_TicketHalfClipper',
);

/// ألوان حدود أنصاف تذاكر الطلبات، بترتيب الشجرة: رأسٌ فشريطٌ لكل طلب
List<Color> _edgeColors(WidgetTester w) => w
    .widgetList<CustomPaint>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.foregroundPainter?.runtimeType.toString() ==
                '_TicketEdgePainter',
      ),
    )
    .map((cp) => (cp.foregroundPainter as dynamic).color as Color)
    .toList();

/// حدّ التذكرة العلوية (غلافها بحامل حدود التذاكر) — وحيدٌ في اللوحة
Color _shellBorderColor(WidgetTester w) {
  final CustomPaint shell = w
      .widgetList<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.foregroundPainter is TicketPassBorderPainter,
        ),
      )
      .first;
  return (shell.foregroundPainter as TicketPassBorderPainter).borderColor;
}

/// يفرد تذاكر الطلبات بالترتيب: كل نقرة تفتح أول تذكرة مطوية
Future<void> _expandTickets(WidgetTester w, int count) async {
  for (var i = 0; i < count; i++) {
    await w.tap(find.byIcon(Icons.expand_more_rounded).first);
    // AnimatedSize يحتاج إطارين على الأقل ليُنهى الحركة
    await w.pump();
    await w.pump(const Duration(milliseconds: 300));
    await w.pump();
    _drain(w);
  }
}

Future<_FakeManual> _pumpScreen(
  WidgetTester w, {
  double width = 400,
  double height = 3200,
  List<ProductModel>? services,
  List<OrderModel>? orders,
}) async {
  final manual = _FakeManual(services ?? _services(), orders ?? _orders());

  w.view.physicalSize = Size(width, height);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
        ChangeNotifierProvider<ManualServicesProvider>.value(value: manual),
      ],
      child: MaterialApp(
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: SupervisorDashboardScreen(),
        ),
      ),
    ),
  );
  await _settle(w);
  return manual;
}

// ---------------------------------------------------------------------------
// الحافظة: لقطات منطقية بدل الاعتماد على تنفيذ حقيقي
// ---------------------------------------------------------------------------
final List<MethodCall> _clipboardLog = <MethodCall>[];

void _mockClipboard() {
  _clipboardLog.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') _clipboardLog.add(call);
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
}

String _lastClipboard() {
  final args = _clipboardLog.last.arguments;
  return (args is Map ? (args['text'] ?? '') : '').toString();
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  setUp(() {
    _collected.clear();
  });

  testWidgets('الترحيب وحالة الطلبات اندمجا في بطاقة تذكرة واحدة مضغوطة', (
    w,
  ) async {
    await _pumpScreen(w);

    // سطر الهوية صار زر «خدماتي المسندة»: لا ترحيب ولا رقاقة دور ولا سطر تقني
    expect(find.textContaining('أهلاً'), findsNothing);
    expect(find.text('مقدم الخدمة'), findsNothing);
    expect(find.textContaining('SUPERVISOR'), findsNothing);

    // المؤشرات صارت شريطاً داخل نفس البطاقة بدل كونسول مستقل
    expect(find.byType(LiveStatusConsole), findsNothing);
    expect(find.text('جديدة'), findsOneWidget);
    expect(find.text('قيد التنفيذ'), findsAtLeastNWidgets(1));
    expect(find.text('بانتظار العميل'), findsAtLeastNWidgets(1));
    expect(find.text('اعتراضات'), findsAtLeastNWidgets(1));
    expect(find.text('متأخرة'), findsOneWidget);

    // الخدمات المسندة لم تعد بطاقة تحت الكرت: صارت سطره الأول بلمحة حالته
    expect(find.text('خدماتي المسندة'), findsOneWidget);
    expect(find.text('MY SERVICES · 2'), findsOneWidget);
    expect(find.text('1 موقوفة'), findsOneWidget);
    expect(find.text('نسخ بيانات الخدمة'), findsNothing);
    expect(find.text('قائمة الطلبات'), findsOneWidget);
    expect(find.text('ORDERS · 2'), findsOneWidget);

    // تذكرة واحدة في اللوحة كلها: كرت الحالة (بوابة + مؤشرات)
    expect(_ticketClips(), findsOneWidget);
    // وتذاكر الطلبات مطوية: نصفان لكل طلب (رأس + شريط)
    expect(_foldedHalves(), findsNWidgets(4));
    // الخطوط الصلبة زالت من الصفحة
    expect(find.byType(Divider), findsNothing);

    // البطاقة المدمجة قصيرة: لا تستهلك ارتفاع الشاشة كما كان الكونسول
    final Size queueSize = w.getSize(_ticketClips().first);
    expect(queueSize.height, lessThan(170));

    await _dispose(w);
  });

  testWidgets('تذاكر الطلبات تمتاز عن الخلفية الورقية ومتقاربة في القائمة', (
    w,
  ) async {
    await _pumpScreen(w);

    final List<PhysicalShape> halves = w
        .widgetList<PhysicalShape>(_foldedHalves())
        .toList(); // رأسٌ فشريطٌ لكل من طلبين
    expect(halves.length, 4);

    // رأسُ كل تذكرة أرضيةٌ مصمتة مصبوغةٌ بحالة الطلب، لا أبيض على أبيض
    for (final int head in <int>[0, 2]) {
      expect(halves[head].color, isNot(AppColors.surfaceCard));
      expect(halves[head].color.a, 1.0);
      expect(halves[head].elevation, greaterThan(1.2));
    }
    // والمتأخر غيرُ الطابوري في اللون وفي الحدّ
    expect(halves[0].color, isNot(halves[2].color));
    final List<Color> edges = _edgeColors(w);
    expect(edges[0], AppColors.rose.withValues(alpha: 0.75));
    expect(edges[2], AppColors.outlineVariant);

    // المسافة بين تذكرة وأختها: هامش 4 + فاصل قائمة 2
    final Rect stripOne = w.getRect(_foldedHalves().at(1));
    final Rect headTwo = w.getRect(_foldedHalves().at(2));
    expect(headTwo.bottom - headTwo.top, greaterThan(0));
    expect(headTwo.top - stripOne.bottom, lessThan(8));

    // والتذكرة المطوية مضغوطة: رأسٌ فشريطٌ في أقل من 90px، لأن لمسة
    // IconButton المفروضة (48px) كانت تُطيل الشريط بلا سبب بصري
    final double headH = w.getSize(_foldedHalves().at(0)).height;
    final double stripH = w.getSize(_foldedHalves().at(1)).height;
    expect(headH, lessThan(56));
    expect(stripH, lessThan(36));
    expect(headH + stripH, lessThan(90));

    await _dispose(w);
  });

  testWidgets('الطلب المُستَرد أُغلق: لا عدّاد «متأخر» يعمل عليه', (w) async {
    // خدمةٌ متاحة وحيدة، فلا موقوفة تعلّل الحدّ الأحمر: حدّ التذكرة
    // العلوية يكشف وحده هل نُحسب الطلبُ المسترد ضمن المتأخرة
    await _pumpScreen(
      w,
      services: [_service(id: 's1', name: 'تعبئة رصيد فري فاير 1000 جمة')],
      orders: [
        _order(
          id: 'o1',
          orderNumber: 'ORD-4480',
          status: 'refunded',
          productId: 's1',
          productName: 'تعبئة رصيد فري فاير 1000 جمة',
          amount: 24.75,
          deadlineAt: DateTime(2000, 1, 1),
          // وسمٌ متأخر في الاستجابة: الحالة النهائية تبقى هي الحكم
          isDelayed: true,
        ),
      ],
    );

    // الرأس يقول «مسترد»، والشريط شارةُ إغلاقٍ لا عدّادٌ يتقدّم
    expect(find.text('مسترد'), findsOneWidget);
    expect(find.text('مغلق'), findsOneWidget);
    expect(find.textContaining(RegExp('متأخر ')), findsNothing);
    expect(_edgeColors(w).first, AppColors.slate500.withValues(alpha: 0.45));

    // والفلترة لم تُحسبه متأخرة: التذكرة العلوية تبقى بحدّ أزرق
    expect(_shellBorderColor(w), AppColors.primaryBlue.withValues(alpha: 0.5));

    // وعند الفرد: ملاحظةُ إغلاقٍ نهائي بدل صندوق العدّاد
    await _expandTickets(w, 1);
    expect(find.textContaining('متأخر عن الوقت المحدد'), findsNothing);
    expect(find.textContaining('الوقت المتبقي'), findsNothing);
    expect(find.textContaining('لا يُحتسب عليه وقت'), findsOneWidget);

    await _dispose(w);
  });

  testWidgets('شريط المؤشرات هو الفلتر الوحيد و«الكل» يعيد القائمة كاملة', (
    w,
  ) async {
    await _pumpScreen(w);

    // شريط الرقائق أُلغي لتكراره مع الشريط: لا عناوينه ولا مفتاح «مكتملة»
    expect(find.text('اعتراضات وتعديلات'), findsNothing);
    expect(find.text('مكتملة'), findsNothing);
    expect(find.text('ORDERS · 2'), findsOneWidget);

    // «جديدة» تترك الطلب الجديد فقط وتُخفي قيد التنفيذ
    await w.tap(find.text('جديدة'));
    await _settle(w);
    expect(find.text('ORDERS · 1'), findsOneWidget);
    expect(find.text('#ORD-4472'), findsNothing);

    // خلية «الكل» في نفس الشريط — بديل الرقائق — تُظهر الطلبين من جديد
    expect(find.text('الكل'), findsOneWidget);
    await w.tap(find.text('الكل'));
    await _settle(w);
    expect(find.text('ORDERS · 2'), findsOneWidget);
    expect(find.text('#ORD-4472'), findsOneWidget);

    await _dispose(w);
  });

  testWidgets('كرت الحالة أسود كلون الشريط العلوي ونصّه فاتح', (w) async {
    await _pumpScreen(w);

    // أرضيةُ التذكرة (بوابة الخدمات والمؤشرات) =darkNav كالشريط العلوي
    final Material queueSurface = w.widget<Material>(
      find
          .descendant(of: _ticketClips().first, matching: find.byType(Material))
          .first,
    );
    expect(queueSurface.color, AppColors.darkNav);

    // عنوانُ البوابة أبيض على السواد لا أسودٌ فيه فلا يُقرأ
    expect(
      w.widget<Text>(find.text('خدماتي المسندة')).style?.color,
      Colors.white,
    );

    await _dispose(w);
  });

  testWidgets('نقرة على مؤشر في البطاقة المدمجة تفلتر قائمة الطلبات', (
    w,
  ) async {
    await _pumpScreen(w);

    expect(find.text('#ORD-4471'), findsOneWidget);
    expect(find.text('#ORD-4472'), findsOneWidget);

    // 'جديدة' الأولى هي خلية المؤشر داخل البطاقة المدمجة (تأتي قبل الرقاقات)
    await w.tap(find.text('جديدة').first);
    await _settle(w);

    expect(find.text('ORDERS · 1'), findsOneWidget);
    expect(find.text('#ORD-4471'), findsOneWidget);
    expect(find.text('#ORD-4472'), findsNothing);

    await _dispose(w);
  });

  testWidgets('تذاكر الطلبات مطوية: الرأس فقط بلا بيانات عميل ولا أزرار', (
    w,
  ) async {
    await _pumpScreen(w);

    // الرأس المضغوط: الخدمة + الرقم + القيمة + الحالة
    expect(find.text('#ORD-4471'), findsOneWidget);
    expect(
      find.text(r'$24.75'),
      findsOneWidget,
    ); // رأس الطلب فقط (الخدمة في صفحتها)
    expect(find.text(r'$0.00'), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.lock_rounded), findsAtLeastNWidgets(1));

    // الشريط: العميل + شارة المهلة + زر نسخ واحد لكل طلب
    expect(find.text('العميل: أحمد سيد'), findsNWidgets(2));
    expect(find.textContaining('متأخر '), findsOneWidget);
    expect(find.byTooltip('نسخ بيانات الطلب'), findsNWidgets(2));

    // التفاصيل مخفية ما لم تُفرَد التذكرة
    expect(find.text('بيانات إدخال العميل'), findsNothing);
    expect(find.text('المحادثة والسجل'), findsNothing);
    expect(find.text('قبول الطلب'), findsNothing);
    expect(find.textContaining('الوقت المتوقع للتنفيذ'), findsNothing);
    // لا وجود لكعب القيمة الجانبي بعد الآن (التذكرة صارت بطية واحدة)
    expect(find.text('القيمة'), findsNothing);
    expect(find.text('ضمن الوقت'), findsNothing);

    // فرد أول تذكرة يُظهر بيانات العميل وأزرار التنفيذ
    await _expandTickets(w, 1);
    expect(find.text('بيانات إدخال العميل'), findsOneWidget);
    expect(find.text('المحادثة والسجل'), findsOneWidget);
    expect(find.text('قبول الطلب'), findsOneWidget);
    expect(find.textContaining('متأخر عن الوقت المحدد'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);

    // والطيّ يعيدها كما كانت
    await w.tap(find.byIcon(Icons.expand_less_rounded).first);
    await w.pump();
    await w.pump(const Duration(milliseconds: 300));
    await w.pump();
    _drain(w);
    expect(find.text('بيانات إدخال العميل'), findsNothing);
    expect(find.text('المحادثة والسجل'), findsNothing);

    await _dispose(w);
  });

  testWidgets('زر نسخ بيانات الطلب في الشريط ينسخ البطاقة كاملة', (w) async {
    _mockClipboard();
    await _pumpScreen(w);

    // الزر متاح دون فرد التذكرة لأنه جزء من شريط التعريف
    await w.tap(find.byTooltip('نسخ بيانات الطلب').first);
    await _settle(w);

    final copied = _lastClipboard();
    expect(copied, contains('#ORD-4471'));
    expect(copied, contains('تعبئة رصيد فري فاير 1000 جمة'));
    expect(copied, contains('العميل: أحمد سيد'));
    expect(copied, contains(r'القيمة: $24.75'));
    expect(copied, contains('Player ID: 778812'));
    expect(find.textContaining('تم نسخ بيانات الطلب'), findsOneWidget);

    await _dispose(w);
  });

  testWidgets('نسخ بيانات العميل لا يسرّب الحقل المشفّر إلا بعد الكشف', (
    w,
  ) async {
    _mockClipboard();
    await _pumpScreen(w);

    // بيانات العميل داخل التفاصيل: لا تُبنى إلا بعد فرد التذكرة
    await _expandTickets(w, 1);
    expect(find.text('بيانات إدخال العميل'), findsOneWidget);
    expect(find.text('778812'), findsOneWidget);
    expect(find.text('••••••••'), findsOneWidget);
    expect(find.text('كشف'), findsOneWidget);

    // سطر واحد: الحقل العادي قابل للنسخ مباشرة
    await w.tap(find.byTooltip('نسخ Player ID'));
    await _settle(w);
    expect(_lastClipboard(), '778812');

    // الكل: الحقل المشفّر مستبعد قبل الكشف
    await _clearSnack(w);
    await w.tap(find.byTooltip('نسخ كل البيانات').first);
    await _settle(w);
    expect(_lastClipboard(), contains('Player ID: 778812'));
    expect(_lastClipboard(), isNot(contains('secret-9981')));

    // بعد الكشف يصير الحقل الحساس قابلاً للنسخ
    await _clearSnack(w);
    await w.tap(find.text('كشف'));
    await _settle(w);
    expect(find.text('secret-9981'), findsOneWidget);
    expect(find.text('إخفاء'), findsOneWidget);

    await _clearSnack(w);
    await w.tap(find.byTooltip('نسخ كل البيانات').first);
    await _settle(w);
    expect(_lastClipboard(), contains('كلمة المرور: secret-9981'));

    await _dispose(w);
  });

  testWidgets('لا طفو على 320/360/400 مع اسم طويل وسعر ضخم', (w) async {
    for (final width in [320.0, 360.0, 400.0]) {
      _collected.clear();
      await _pumpScreen(
        w,
        width: width,
        height: 4000,
        services: [
          _service(
            id: 's1',
            name:
                'اشتراك شهري نتفليكس بريميوم مع دعم تركيب على أربعة أجهزة وتهيئة كاملة',
            salePrice: 999999.99,
            estimatedMinutes: 1200,
            quantityLabel: 'شهر واحد — 4K UHD',
            requiredFields: const [
              'البريد الإلكتروني الحالي',
              'كلمة المرور',
              'رقم آخر أربع من البطاقة',
            ],
            isSensitive: true,
            sensitiveFields: const ['كلمة المرور'],
            instructions:
                'يجب تأكيد ملكية الحساب عبر رمز التحقق المرسل قبل الشروع في أي تعديل على بيانات الاشتراك الحالي',
          ),
        ],
        orders: [
          _order(
            id: 'o1',
            orderNumber: 'ORD-9999999',
            status: 'delivered',
            productId: 's1',
            productName:
                'اشتراك شهري نتفليكس بريميوم مع دعم تركيب على أربعة أجهزة وتهيئة كاملة',
            amount: -12.5,
            accountInput: const {
              'البريد الإلكتروني الحالي':
                  'long.customer.email@example-domain.com',
            },
            deadlineAt: DateTime(2000, 1, 1),
            isDelayed: true,
          ),
          _order(
            id: 'o2',
            orderNumber: 'ORD-1',
            status: 'revision_requested',
            productId: 's1',
            productName: 'خدمة',
            amount: 0.0,
          ),
        ],
      );

      // عناصر التذييل ما زالت تُقرأ وتلمَس على أضيق عرض بعد فرد التذاكر
      await _expandTickets(w, 2);
      expect(find.text('خدماتي المسندة'), findsOneWidget, reason: '$width dp');
      // الإغلاق صار من مقدّم الخدمة: زر تأكيد الإنهاء حلّ محل ملاحظة الانتظار
      expect(
        find.text('تأكيد الإنهاء وإغلاق الطلب'),
        findsOneWidget,
        reason: '$width dp',
      );
      expect(find.text('تم التسليم - بانتظار تأكيد العميل'), findsNothing);
      expect(find.text('تسليم النتيجة'), findsOneWidget, reason: '$width dp');
      expect(
        find.text('long.customer.email@example-domain.com'),
        findsOneWidget,
        reason: '$width dp',
      );
      _expectClean();
      await _dispose(w);
    }
  });

  test('الصفحة تطلب الخدمات المسندة مع الطلبات عند كل تحديث', () async {
    final manual = _FakeManual(_services(), _orders());
    await manual.fetchSupervisorOrders();
    await manual.fetchAssignedServices();
    expect(manual.ordersFetches, 1);
    expect(manual.servicesFetches, 1);
    expect(manual.assignedServices, hasLength(2));
  });
}
