// شاشة «أنواع قوالب الخدمة»: القوالب تُعرض كتذاكر بكعب عدد الحقول، والمحرّر
// شيت سفلي بهوية التذكرة (شرائح نوع العملية + رقائق مطلوب/حساس).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/service_template_model.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/screens/admin/service_templates_screen.dart';
import 'package:layan_chargex/widgets/digital_pass_card.dart';

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

/// مزوّد محلي: بلا شبكة، ويسجّل استدعاءات الحفظ والحذف والتبديل
class _FakeAdmin extends AdminProvider {
  _FakeAdmin(this._templates);

  final List<ServiceTemplateModel> _templates;

  int createCalls = 0;
  Map<String, dynamic>? createPayload;
  final List<String> updateIds = <String>[];
  Map<String, dynamic>? updatePayload;
  final List<String> deleteIds = <String>[];
  final List<String> toggleIds = <String>[];
  bool nextResult = true;

  @override
  List<ServiceTemplateModel> get serviceTemplates => _templates;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchServiceTemplates() async {}

  @override
  Future<bool> createServiceTemplate(Map<String, dynamic> data) async {
    createCalls++;
    createPayload = data;
    return nextResult;
  }

  @override
  Future<bool> updateServiceTemplate(
    String id,
    Map<String, dynamic> data,
  ) async {
    updateIds.add(id);
    updatePayload = data;
    return nextResult;
  }

  @override
  Future<bool> deleteServiceTemplate(String id) async {
    deleteIds.add(id);
    return nextResult;
  }

  @override
  Future<bool> toggleServiceTemplateActive(String id) async {
    toggleIds.add(id);
    return nextResult;
  }
}

ServiceTemplateModel _accountTemplate() => ServiceTemplateModel(
  id: 't1',
  name: 'شحن عبر الحساب',
  description: 'يحتاج ايدي اللاعب فقط ويُنفّذ يدوياً من الإدارة',
  operationType: 'manual',
  isActive: true,
  fields: [
    ServiceFieldDef(type: 'player_id', label: 'الايدي', required: true),
    ServiceFieldDef(type: 'phone', label: 'رقم الهاتف', required: false),
    ServiceFieldDef(type: 'password', label: 'كلمة المرور', isSensitive: true),
  ],
);

ServiceTemplateModel _codeTemplate() => ServiceTemplateModel(
  id: 't2',
  name: 'بطاقات رقمية',
  operationType: 'codes',
  isActive: false,
  fields: const [],
);

/// يصرّف أخطاء تحميل الخطوط (متوقّعة مع حظر الشبكة) ويجمّعها لفحص الطفو
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

/// يغلق أي SnackBar ناجح حتى لا يبقى مؤقّت معلّق عند نهاية الاختبار
Future<void> _flushSnackBars(WidgetTester w) async {
  await w.pump(const Duration(seconds: 5));
  await w.pump();
  _drain(w);
}

_FakeAdmin? _lastFake;

Future<void> _pumpScreen(WidgetTester w, {double width = 420}) async {
  w.view.physicalSize = Size(width, 820);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  final fake = _FakeAdmin([_accountTemplate(), _codeTemplate()]);
  _lastFake = fake;

  await w.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider<AdminProvider>.value(value: fake)],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const ServiceTemplatesScreen(),
        ),
      ),
    ),
  );
  await _settle(w);
}

Finder _ticketClips() => find.byWidgetPredicate(
  (widget) => widget is ClipPath && widget.clipper is TicketPassClipper,
);

Finder _sheet() => find.byKey(const Key('template-editor-sheet'));

Future<void> _openTemplateMenu(WidgetTester w, int index) async {
  await w.tap(find.byType(PopupMenuButton<String>).at(index));
  await w.pumpAndSettle();
  _drain(w);
}

Future<void> _openEditorFromFab(WidgetTester w) async {
  await w.tap(find.text('قالب جديد'));
  await w.pumpAndSettle();
  _drain(w);
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  setUp(() async {
    _collected.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferences.getInstance();
  });

  testWidgets('القوالب تُعرض كتذاكر: قصّ + كعب عدد الحقول + خط تثقيب', (
    w,
  ) async {
    await _pumpScreen(w);

    expect(find.text('شحن عبر الحساب'), findsOneWidget);
    expect(find.text('بطاقات رقمية'), findsOneWidget);

    // تذكرة لكل قالب
    expect(_ticketClips(), findsNWidgets(2));

    // الكعب يحمل عدد الحقول: 3 للحساب و0 للبطاقات
    expect(find.text('3'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('حقول'), findsNWidgets(2));
    expect(find.text('بدون حقول إدخال · تسليم فوري'), findsOneWidget);

    // رقائق الحقول ومعرفات التذكرة التقنية
    expect(find.text('الايدي'), findsOneWidget);
    expect(find.text('ENCRYPTED'), findsOneWidget);
    expect(find.text('INSTANT'), findsOneWidget);

    final tears = w
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((p) => p.painter is VerticalDashedLinePainter)
        .toList();
    expect(tears.length, greaterThanOrEqualTo(2));
  });

  testWidgets('شريط العدّادات يعكس الإجمالي والمفعّل والمعطّل', (w) async {
    await _pumpScreen(w);

    expect(find.text('القوالب'), findsOneWidget);
    expect(find.text('مفعّلة'), findsOneWidget);
    expect(find.text('معطّلة'), findsOneWidget);
    // 2 قالب، واحد مفعّل وواحد معطّل، وكعب القالب الثاني يعرض 0
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);
    expect(find.text('TEMPLATES · 2'), findsOneWidget);
  });

  testWidgets('المحرّر شيت بترويسة تذكرة: الاسم الفارغ خطأ inline بلا حفظ', (
    w,
  ) async {
    await _pumpScreen(w);
    await _openEditorFromFab(w);

    expect(_sheet(), findsOneWidget);
    expect(find.text('قالب خدمة جديد'), findsOneWidget);
    expect(find.text('SERVICE TEMPLATE // CREATE'), findsOneWidget);
    expect(find.text('هوية القالب'), findsOneWidget);
    expect(find.text('IDENTITY'), findsOneWidget);
    expect(find.text('نوع العملية'), findsOneWidget);
    expect(find.text('إضافة حقل إدخال'), findsOneWidget);

    await w.tap(find.text('إنشاء'));
    await _settle(w);

    expect(find.text('اسم القالب مطلوب'), findsOneWidget);
    expect(_lastFake!.createCalls, 0);

    await w.tap(find.text('إلغاء'));
    await _settle(w);
    expect(_sheet(), findsNothing);
  });

  testWidgets('شرائح نوع العملية ورقائق الحقول تُرسل الحمولة الصحيحة', (
    w,
  ) async {
    await _pumpScreen(w);
    await _openEditorFromFab(w);

    await w.enterText(
      find.descendant(of: _sheet(), matching: find.byType(TextField)).first,
      'شحن سريع',
    );
    await w.tap(find.text('شحن مباشر (API)'));
    await _settle(w, ms: 250);

    await w.tap(find.text('إضافة حقل إدخال'));
    await _settle(w);
    expect(find.text('نوع الحقل'), findsOneWidget);

    // الحقل الجديد مطلوب افتراضياً — الضغط يُلغي الإلزام
    await w.tap(find.text('مطلوب'));
    await _settle(w);

    await w.tap(find.text('إنشاء'));
    await w.pumpAndSettle();
    _drain(w);

    final fake = _lastFake!;
    expect(fake.createCalls, 1);
    expect(fake.createPayload!['name'], 'شحن سريع');
    expect(fake.createPayload!['operationType'], 'direct_api');
    final fields = fake.createPayload!['fields'] as List<dynamic>;
    expect(fields, hasLength(1));
    expect(fields.single['type'], 'player_id');
    expect(fields.single['required'], isFalse);

    // الشيت أُغلق بعد النجاح وظهر تنبيه الحفظ
    expect(_sheet(), findsNothing);
    expect(find.text('تم إنشاء القالب ✅'), findsOneWidget);
    await _flushSnackBars(w);
  });

  testWidgets('التعديل يفتح معبّأً ويستدعي updateServiceTemplate', (w) async {
    await _pumpScreen(w);
    await _openTemplateMenu(w, 0);

    expect(find.text('تعديل القالب'), findsOneWidget);
    await w.tap(find.text('تعديل القالب'));
    await w.pumpAndSettle();
    _drain(w);

    expect(find.text('تعديل قالب الخدمة'), findsOneWidget);
    expect(find.text('SERVICE TEMPLATE // EDIT'), findsOneWidget);
    final nameField = w.widget<TextField>(
      find.descendant(of: _sheet(), matching: find.byType(TextField)).first,
    );
    expect(nameField.controller!.text, 'شحن عبر الحساب');
    // شرائح نوع العملية تحدّد اختيار «شحن يدوي» مسبقاً، وثلاثة حقول معبّأة
    expect(find.text('حساس (مشفّر)'), findsNWidgets(3));

    await w.tap(find.text('حفظ'));
    await w.pumpAndSettle();
    _drain(w);

    final fake = _lastFake!;
    expect(fake.updateIds, <String>['t1']);
    expect(fake.updatePayload!['name'], 'شحن عبر الحساب');
    expect((fake.updatePayload!['fields'] as List<dynamic>), hasLength(3));
    expect(_sheet(), findsNothing);
    expect(find.text('تم تحديث القالب ✅'), findsOneWidget);
    await _flushSnackBars(w);
  });

  testWidgets('الحذف يطلب تأكيداً مثقّباً ثم يستدعي deleteServiceTemplate', (
    w,
  ) async {
    await _pumpScreen(w);
    await _openTemplateMenu(w, 1);

    await w.tap(find.text('حذف القالب'));
    await w.pumpAndSettle();
    _drain(w);

    expect(find.text('DELETE // NOT RESTORABLE'), findsOneWidget);
    expect(find.textContaining('حذف «بطاقات رقمية»'), findsOneWidget);
    // تذكرة التأكيد تضيف قصّها الخاص فوق قصّ التذاكر القائمة
    expect(_ticketClips(), findsNWidgets(3));

    await w.tap(find.text('حذف نهائي'));
    await w.pumpAndSettle();
    _drain(w);

    expect(_lastFake!.deleteIds, <String>['t2']);
  });

  testWidgets('مفتاح التفعيل في تذييل التذكرة يستدعي toggle', (w) async {
    await _pumpScreen(w);

    await w.tap(find.byType(Switch).first);
    await _settle(w);

    expect(_lastFake!.toggleIds, <String>['t1']);
  });

  testWidgets('على 320dp: القائمة والمحرّر بلا طفو تخطيط', (w) async {
    await _pumpScreen(w, width: 320);

    expect(find.text('شحن عبر الحساب'), findsOneWidget);
    expect(find.text('أنواع قوالب الخدمة'), findsOneWidget);

    await _openEditorFromFab(w);
    expect(_sheet(), findsOneWidget);
    await _settle(w);

    expect(
      _collected.where((e) => '$e'.contains('RenderFlex')),
      isEmpty,
      reason: _collected.map((e) => '$e').join('\n'),
    );
  });
}
