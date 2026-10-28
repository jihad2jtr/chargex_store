// شاشة «إدارة المزودين»: عدّادات البوابة تجتمع في تذكرة واحدة، وكل مزود تذكرة
// بكعب رصيد على الحافة وخط تثقيب رأسي وفوتر إجراءات مفصول بخط مثقّب.
// الاختبار يثبّت الهوية الجديدة ويثبّت أن نوافذ الحفظ تملك حقولها.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/provider_model.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/screens/admin/provider_form_dialog.dart';
import 'package:layan_chargex/screens/admin/providers_management_screen.dart';
import 'package:layan_chargex/widgets/digital_pass_card.dart';

/// الشبكة معطّلة: أي استدعاء فعلي يفشل فوراً ويبقى الهيكل ظاهراً
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

class _SeededAdmin extends AdminProvider {
  _SeededAdmin(this._items);

  final List<ProviderModel> _items;
  final List<Map<String, dynamic>> created = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> updated = <Map<String, dynamic>>[];

  @override
  List<ProviderModel> get providers => _items;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchProviders({bool forceRefresh = false}) async {}

  @override
  Future<bool> createProvider(Map<String, dynamic> data) async {
    created.add(data);
    return true;
  }

  @override
  Future<bool> updateProvider(String id, Map<String, dynamic> data) async {
    updated.add(data);
    return true;
  }

  @override
  Future<bool> checkProviderStatus(String id) async => true;
}

ProviderModel _provider({
  required String id,
  required String name,
  bool isActive = true,
  double balance = 24.75,
}) {
  return ProviderModel(
    id: id,
    name: name,
    baseUrl: 'https://public-api.foxreload.com',
    apiKey: 'key-123',
    status: isActive ? 'online' : 'error',
    lastError: isActive ? null : 'الرصيد \$0.00 أقل من تكلفة الطلب \$1.50',
    lastCheckAt: DateTime(2026, 10, 27, 21, 56),
    balance: balance,
    profitMarginType: 'percentage',
    profitMarginValue: 12.5,
    isActive: isActive,
  );
}

final List<Object> _collected = <Object>[];

void _drain(WidgetTester w) {
  for (;;) {
    final Object? error = w.takeException();
    if (error == null) break;
    _collected.add(error);
  }
}

Future<void> _settle(WidgetTester w) async {
  await w.pump();
  await w.pump(const Duration(milliseconds: 600));
  _drain(w);
}

Future<_SeededAdmin> _pump(
  WidgetTester w, {
  required List<ProviderModel> providers,
  double width = 400,
  double height = 900,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final admin = _SeededAdmin(providers);

  w.view.physicalSize = Size(width, height);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    ChangeNotifierProvider<AdminProvider>(
      create: (_) => admin,
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const ProvidersManagementScreen(),
        ),
      ),
    ),
  );
  await _settle(w);
  return admin;
}

Finder get _ticketClips => find.byWidgetPredicate(
  (widget) => widget is ClipPath && widget.clipper is TicketPassClipper,
);

List<CustomPaint> _paintersWhere(
  WidgetTester w,
  bool Function(CustomPaint) test,
) => w.widgetList<CustomPaint>(find.byType(CustomPaint)).where(test).toList();

/// شريط التنبيه المؤقت يُنهى قبل نهاية الاختبار حتى لا يبقى مؤقّت معلّق
Future<void> _finish(WidgetTester w) async {
  await w.pumpWidget(const SizedBox.shrink());
  await w.pump(const Duration(seconds: 4));
}

/// لا أخطاء تخطيط (طفو) ولا تصريف خاطئ للحقول
void _expectClean(WidgetTester w) {
  final List<String> layout = _collected
      .where((e) => '$e'.contains('RenderFlex') || '$e'.contains('overflowed'))
      .map((e) => '$e')
      .toList();
  expect(layout, isEmpty, reason: layout.join('\n'));
  expect(
    _collected
        .where((e) => '$e'.contains('used after being disposed'))
        .toList(),
    isEmpty,
    reason: _collected.map((e) => '$e').join('\n'),
  );
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  setUp(() => _collected.clear());

  final seeded = <ProviderModel>[
    _provider(id: 'p1', name: 'Fox Reload'),
    _provider(id: 'p2', name: 'Bay2Game', isActive: false, balance: 0),
  ];

  testWidgets('العدّادات الأربعة تجتمع في تذكرة واحدة مع زر الفحص', (w) async {
    await _pump(w, providers: seeded, width: 560);

    expect(find.text('بوابة اتصال المزودين'), findsOneWidget);
    expect(find.text('PROVIDERS LEDGER · 1/2 متصل'), findsOneWidget);
    expect(find.text('المزودين المربوطين بالنظام'), findsOneWidget);
    expect(find.text('PROVIDERS · 2'), findsOneWidget);

    // التسميات الأربع كلها داخل غلاف التذكرة الأولى: لا بطاقات منفصلة
    for (final String label in <String>[
      'المزودون',
      'متصلون',
      'موقوفون',
      'إجمالي الأرصدة',
    ]) {
      expect(
        find.descendant(of: _ticketClips.first, matching: find.text(label)),
        findsOneWidget,
        reason: '$label يجب أن يكون داخل بطاقة العدّادات الواحدة',
      );
    }

    // زر الفحص صار داخل التذكرة لا شريطاً منفصلاً فوق الصفحة
    expect(
      find.descendant(
        of: _ticketClips.first,
        matching: find.text('فحص الأرصدة'),
      ),
      findsOneWidget,
    );

    // تذكرة العدّادات + تذكرة لكل مزود
    expect(_ticketClips, findsNWidgets(3));

    // فواصل خانات العدّادات خطوط مثقّبة رأسية لا Divider صلبة
    expect(
      _paintersWhere(w, (p) => p.painter is VerticalDashedLinePainter).length,
      greaterThanOrEqualTo(3),
    );
    expect(
      find.descendant(of: _ticketClips.first, matching: find.byType(Divider)),
      findsNothing,
    );
    _expectClean(w);
  });

  testWidgets('تذكرة المزود: كعب رصيد وخط تثقيب وفوتر بخط مثقّب', (w) async {
    await _pump(w, providers: seeded, width: 560);

    // كعب لكل تذكرة يعرض الرصيد على الحافة
    expect(find.text('الرصيد'), findsNWidgets(2));
    expect(find.text(r'$24.75'), findsNWidgets(2)); // كعب + إجمالي العدّادات
    expect(find.text(r'$0.00'), findsOneWidget);

    // بيانات الجسم: الهامش والمفتاح المُقنَّع لا يتكرر الرصيد
    expect(find.text('هامش الربح'), findsNWidgets(2));
    expect(find.text('مفتاح API'), findsNWidgets(2));
    expect(find.text('•••-123'), findsNWidgets(2));
    expect(find.text('12.5%'), findsNWidgets(2));

    // فاصل الجسم/الكعب رأسي + فاصل الفوتر أفقي مثقّب، ولا Divider صلبة
    expect(
      _paintersWhere(w, (p) => p.painter is VerticalDashedLinePainter).length,
      greaterThanOrEqualTo(7), // 3 خانات عدّادات + 2 لكل تذكرة
    );
    expect(
      _paintersWhere(w, (p) => p.painter is DashedLinePainter).length,
      greaterThanOrEqualTo(7),
    );
    for (final int i in <int>[1, 2]) {
      expect(
        find.descendant(of: _ticketClips.at(i), matching: find.byType(Divider)),
        findsNothing,
      );
    }

    // كل اسم مزود داخل تذكرة مستقلة لا داخل تذكرة العدّادات
    expect(
      find.descendant(
        of: _ticketClips.at(1),
        matching: find.text('Fox Reload'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _ticketClips.at(2), matching: find.text('Bay2Game')),
      findsOneWidget,
    );
    _expectClean(w);
  });

  testWidgets('عرض 320px: مزود موقوف بتنبيه طويل بلا أي طفو', (w) async {
    await _pump(
      w,
      width: 320,
      height: 2400,
      providers: <ProviderModel>[
        _provider(id: 'p1', name: 'Fox Reload', balance: 999999.99),
        _provider(id: 'p2', name: 'Bay2Game', isActive: false, balance: 0),
        _provider(
          id: 'p3',
          name: 'مزود خدمة ألعاب باسم طويل جداً للمراجعة',
          balance: -12.5,
        ),
      ],
    );

    expect(find.text('المزودون'), findsOneWidget);
    expect(find.text('موقوف'), findsOneWidget);
    expect(
      find.text(
        'المزود موقوف — كل التطبيقات والألعاب المرتبطة به لا تظهر للعملاء',
      ),
      findsOneWidget,
    );
    expect(find.text(r'$-12.50'), findsOneWidget);
    // لا عدّاد ولا كعب يفيض خارج التذكرة
    expect(find.byTooltip('مزامنة المنتجات والأسعار'), findsNWidgets(3));
    _expectClean(w);
  });

  testWidgets('نافذة إضافة مزود: حقول فاتحة تملكها النافذة والحفظ يمر', (
    w,
  ) async {
    final admin = await _pump(w, providers: seeded, width: 400, height: 1200);

    await w.tap(find.byTooltip('إضافة مزود جديد'));
    await _settle(w);
    expect(find.byType(ProviderFormDialog), findsOneWidget);
    expect(find.text('PROVIDER · CREATE'), findsOneWidget);

    final Finder dialog = find.byType(ProviderFormDialog);
    await w.tap(find.descendant(of: dialog, matching: find.text('Fox Reload')));
    await _settle(w);

    // مفتاح API هو الحقل الثالث: الاسم والرابط معموران من الاختيار السريع
    await w.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)).at(2),
      'secret-key',
    );
    await _settle(w);

    await w.tap(
      find.descendant(of: dialog, matching: find.text('حفظ البيانات')),
    );
    await _settle(w);

    expect(admin.created, hasLength(1));
    expect(admin.created.single['name'], 'Fox Reload');
    expect(admin.created.single['apiKey'], 'secret-key');
    expect(admin.created.single['profitMarginValue'], 10.0);
    expect(find.byType(ProviderFormDialog), findsNothing);
    expect(find.text('تم حفظ بيانات المزود بنجاح ✅'), findsOneWidget);

    _expectClean(w);
    await _finish(w);
  });

  testWidgets('نافذة تعديل مزود تستدعي updateProvider بنفس الحقول', (w) async {
    final admin = await _pump(w, providers: seeded, width: 400, height: 1200);

    await w.tap(find.byTooltip('تعديل المزود').first);
    await _settle(w);
    expect(find.text('PROVIDER · UPDATE'), findsOneWidget);

    await w.tap(
      find.descendant(
        of: find.byType(ProviderFormDialog),
        matching: find.text('حفظ البيانات'),
      ),
    );
    await _settle(w);

    expect(admin.updated, hasLength(1));
    expect(admin.updated.single['name'], 'Fox Reload');
    expect(find.text('تم حفظ بيانات المزود بنجاح ✅'), findsOneWidget);

    _expectClean(w);
    await _finish(w);
  });
}
