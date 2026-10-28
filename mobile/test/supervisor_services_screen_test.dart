// صفحة الخدمات المسندة لمقدم الخدمة (انقلت من اللوحة إلى شاشة مستقلة):
// تُفتح بلمسة على بطاقة «خدماتي المسندة»، وتحمل تذاكر الخدمات مع
// الإيقاف المؤقت/إعادة التفعيل وأزرار النسخ، بلا طفو على الشاشات الضيقة.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:layan_chargex/models/order_model.dart';
import 'package:layan_chargex/models/product_model.dart';
import 'package:layan_chargex/models/user_model.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/manual_services_provider.dart';
import 'package:layan_chargex/screens/supervisor/supervisor_dashboard_screen.dart';
import 'package:layan_chargex/screens/supervisor/supervisor_services_screen.dart';
import 'package:layan_chargex/widgets/digital_pass_card.dart';

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

OrderModel _order() {
  return OrderModel(
    id: 'o1',
    orderNumber: 'ORD-4471',
    userId: 'c-1',
    userName: 'أحمد سيد',
    appId: 'app-1',
    appName: 'Chargex',
    productId: 's1',
    productName: 'تعبئة رصيد فري فاير 1000 جمة',
    type: 'manual',
    amount: 24.75,
    status: 'assigned',
    createdAt: DateTime(2026, 10, 27, 9, 30),
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

/// يفرّغ الشجرة (تذاكر اللوحة فيها مؤقّت تحديث دوري)
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

Future<void> _pumpServices(
  WidgetTester w, {
  double width = 400,
  double height = 2400,
  List<ProductModel>? services,
}) async {
  w.view.physicalSize = Size(width, height);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  final manual = _FakeManual(services ?? _services(), [_order()]);
  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
        ChangeNotifierProvider<ManualServicesProvider>.value(value: manual),
      ],
      child: MaterialApp(
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const SupervisorServicesScreen(),
      ),
    ),
  );
  await _settle(w);
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

  testWidgets('بطاقة اللوحة تفتح صفحة الخدمات المسندة', (w) async {
    w.view.physicalSize = const Size(400, 3200);
    w.view.devicePixelRatio = 1.0;
    addTearDown(w.view.resetPhysicalSize);
    addTearDown(w.view.resetDevicePixelRatio);

    await w.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
          ChangeNotifierProvider<ManualServicesProvider>.value(
            value: _FakeManual(_services(), [_order()]),
          ),
        ],
        child: MaterialApp(
          // RTL على مستوى MaterialApp: الطريق المدفوع يرثه كما في التطبيق
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SupervisorDashboardScreen(),
        ),
      ),
    );
    await _settle(w);

    // اللوحة صارت بطاقة دخول مضغوطة بلا تذاكر الخدمات نفسها
    expect(find.text('خدماتي المسندة'), findsOneWidget); // عنوان بطاقة الدخول
    expect(find.text('MY SERVICES · 2'), findsOneWidget);
    expect(find.text('1 متاحة للعملاء'), findsOneWidget);
    expect(find.text('1 موقوفة مؤقتاً'), findsOneWidget);
    expect(find.text('نسخ بيانات الخدمة'), findsNothing);
    // هوية التذكرة: بطاقة الحالة المدمجة + بطاقة الدخول فقط
    expect(_ticketClips(), findsNWidgets(2));

    await w.tap(find.text('خدماتي المسندة')); // عنوان بطاقة الدخول في اللوحة
    await _settle(w);

    expect(find.byType(SupervisorServicesScreen), findsOneWidget);
    expect(find.text('الخدمات المسندة إليك'), findsOneWidget);
    expect(find.text('SERVICES · 2'), findsOneWidget);
    expect(find.text('نسخ بيانات الخدمة'), findsNWidgets(2)); // زر لكل خدمة
    expect(find.text('إيقاف مؤقت'), findsOneWidget);
    expect(find.text('إعادة تفعيل'), findsOneWidget);
    // اللوحة صارت خلف الطريق الجديد (offstage): تتبقى تذاكر الخدمات الاثنتان
    expect(_ticketClips(), findsNWidgets(2));

    await _dispose(w);
  });

  testWidgets('الصفحة تجلب الخدمات والطلبات معاً عند الفتح', (w) async {
    w.view.physicalSize = const Size(400, 2400);
    w.view.devicePixelRatio = 1.0;
    addTearDown(w.view.resetPhysicalSize);
    addTearDown(w.view.resetDevicePixelRatio);

    final manual = _FakeManual(_services(), [_order()]);
    await w.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
          ChangeNotifierProvider<ManualServicesProvider>.value(value: manual),
        ],
        child: MaterialApp(
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SupervisorServicesScreen(),
        ),
      ),
    );
    await _settle(w);

    // تعمل مستقلة (فتح مباشر) فتجلب ما تحتاجه: الخدمات + عدّاد الطلب النشط
    expect(manual.servicesFetches, greaterThanOrEqualTo(1));
    expect(manual.ordersFetches, greaterThanOrEqualTo(1));
    expect(find.text('1 طلب نشط'), findsOneWidget);

    await _dispose(w);
  });

  testWidgets('الخدمة تُوقف مؤقتاً ثم تُعاد تفعيلها من التذكرة', (w) async {
    await _pumpServices(w);

    expect(find.text('متاحة للعملاء'), findsOneWidget);
    expect(find.text('موقوفة مؤقتاً'), findsOneWidget);
    expect(find.text('إيقاف مؤقت'), findsOneWidget);
    expect(find.text('إعادة تفعيل'), findsOneWidget);
    expect(find.text('نشطة'), findsOneWidget);
    expect(find.text('موقوفة'), findsOneWidget);
    expect(find.textContaining('لا تظهر في واجهة العملاء'), findsOneWidget);

    await w.tap(find.text('إيقاف مؤقت'));
    await _settle(w);

    expect(find.text('إيقاف مؤقت'), findsNothing);
    expect(find.text('إعادة تفعيل'), findsNWidgets(2));
    expect(find.text('موقوفة مؤقتاً'), findsNWidgets(2));
    expect(find.textContaining('تم إيقاف'), findsOneWidget);

    await _clearSnack(w);
    await w.tap(find.text('إعادة تفعيل').first);
    await _settle(w);

    expect(find.text('إيقاف مؤقت'), findsOneWidget);
    expect(find.textContaining('تم تفعيل'), findsOneWidget);

    await _dispose(w);
  });

  testWidgets('نسخ بيانات الخدمة والنقر على الحقول المطلوبة', (w) async {
    _mockClipboard();
    await _pumpServices(w);

    await w.tap(find.text('نسخ بيانات الخدمة').first);
    await _settle(w);

    final copied = _lastClipboard();
    expect(copied, contains('تعبئة رصيد فري فاير 1000 جمة'));
    expect(copied, contains(r'السعر: $24.75'));
    expect(copied, contains('مدة التنفيذ: 45 دقيقة'));
    expect(copied, contains('الكمية: 1000 جمة'));
    expect(copied, contains('البيانات المطلوبة: Player ID / Server ID'));
    expect(copied, contains('تأكد من صحة رقم اللاعب'));
    expect(find.textContaining('تم نسخ بيانات الخدمة'), findsOneWidget);

    await _clearSnack(w);
    await w.tap(find.byTooltip('نسخ البيانات المطلوبة').first);
    await _settle(w);
    expect(_lastClipboard(), 'Player ID\nServer ID');

    await _dispose(w);
  });

  testWidgets('لا طفو على 320/360/400 مع اسم طويل وسعر ضخم', (w) async {
    for (final width in [320.0, 360.0, 400.0]) {
      _collected.clear();
      await _pumpServices(
        w,
        width: width,
        height: 2600,
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
          _service(
            id: 's2',
            name: 'خدمة قصيرة',
            isActive: false,
            requiredFields: const ['ID'],
          ),
        ],
      );

      expect(
        find.text('نسخ بيانات الخدمة'),
        findsNWidgets(2),
        reason: '$width dp',
      );
      expect(find.text('إيقاف مؤقت'), findsOneWidget, reason: '$width dp');
      expect(find.text('إعادة تفعيل'), findsOneWidget, reason: '$width dp');
      _expectClean();
      await _dispose(w);
    }
  });

  testWidgets('الصفحة فارغة: تذكرة ترحيب بلا خدمات بدل القائمة', (w) async {
    await _pumpServices(w, services: <ProductModel>[]);

    expect(find.text('SERVICES · 0'), findsOneWidget);
    expect(find.textContaining('عند إسناد خدمة يدوية إليك'), findsOneWidget);
    expect(find.text('إيقاف مؤقت'), findsNothing);

    await _dispose(w);
  });
}
