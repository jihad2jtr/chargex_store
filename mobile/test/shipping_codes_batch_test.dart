// صفحة قسائم الشحن المسبق: الدفعات تُعرض مجمّعة، وكل دفعة لها أزرار تصدير
// (قائمة منسوخة / PDF) تبقى داخل حدود الشاشة على أضيق عرض، بلا تداخل.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/shipping_code_model.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/screens/admin/shipping_codes_screen.dart';

/// الشبكة معطّلة: اختبار تخطيط فقط
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
  _SeededAdmin(this._codes);

  final List<ShippingCodeModel> _codes;

  @override
  List<ShippingCodeModel> get shippingCodes => _codes;

  @override
  bool get isLoading => false;

  @override
  Future<void> fetchShippingCodes() async {}

  @override
  Future<bool> deleteShippingCode(String id) async => true;
}

/// يحاكي رد الخادم: التوليد يضيف القسائم فعلاً ويرجع معرّف الدفعة
class _GenAdmin extends _SeededAdmin {
  _GenAdmin(super.codes);

  @override
  Future<String?> generateShippingCodes(
    double amount,
    int count, {
    String? note,
  }) async {
    for (int i = 1; i <= count; i++) {
      shippingCodes.add(
        ShippingCodeModel(
          id: 'n$i',
          code: 'CHG-9482-KL$i$i',
          amount: amount,
          isUsed: false,
          batchId: newBatchId,
          batchNote: note,
          createdAt: DateTime(2026, 10, 28, 9, 30, i),
        ),
      );
    }
    notifyListeners();
    return newBatchId;
  }
}

const String longNote = 'قسائم منصة البيع الأسبوعية للدفعات الكبيرة رقم أربعة';
const String newBatchId = 'B-20261028-7A2B';

List<ShippingCodeModel> _codes() => <ShippingCodeModel>[
  for (int i = 1; i <= 3; i++)
    ShippingCodeModel(
      id: 'n$i',
      code: 'CHG-9482-KL$i$i',
      amount: 10,
      isUsed: i == 3,
      usedByName: i == 3 ? 'عميل تجريبي طويل الاسم جداً' : null,
      batchId: newBatchId,
      batchNote: longNote,
      createdAt: DateTime(2026, 10, 28, 9, 30, i),
    ),
  ShippingCodeModel(
    id: 'l1',
    code: 'CHG-OLD-0001',
    amount: 5,
    isUsed: true,
    createdAt: DateTime(2026, 10, 20, 8),
  ),
  ShippingCodeModel(
    id: 'l2',
    code: 'CHG-OLD-0002',
    amount: 5,
    isUsed: true,
    createdAt: DateTime(2026, 10, 20, 9),
  ),
];

Finder get _exportButton => find.ancestor(
  of: find.text('تصدير الدفعة'),
  matching: find.byWidgetPredicate((Widget w) => w is OutlinedButton),
);

Finder get _copyButton => find.ancestor(
  of: find.text('نسخ القائمة (3)'),
  matching: find.byWidgetPredicate((Widget w) => w is OutlinedButton),
);

Future<List<Object>> _pumpScreen(
  WidgetTester w, {
  double width = 360,
  required _SeededAdmin admin,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  w.view.physicalSize = Size(width, 1000);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    ChangeNotifierProvider<AdminProvider>(
      create: (_) => admin,
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ShippingCodesScreen(),
        ),
      ),
    ),
  );
  await w.pump(const Duration(milliseconds: 400));
  return _drainErrors(w);
}

List<Object> _drainErrors(WidgetTester w) {
  final List<Object> errors = <Object>[];
  Object? e = w.takeException();
  while (e != null) {
    errors.add(e);
    e = w.takeException();
  }
  return errors
      .where((Object err) => !err.toString().contains('google_fonts'))
      .toList();
}

void _expectNoOverflow(List<Object> errors, int width, String where) {
  // أي خطأ تخطيط (تجاوز أفقي أو ParentData خاطئ) يعني عناصر متداخلة
  expect(
    errors,
    isEmpty,
    reason: 'مشكلة تخطيط في $where عند عرض $width: $errors',
  );
}

void _expectWithinScreen(
  WidgetTester w,
  Finder finder,
  double width,
  String label,
) {
  expect(finder, findsWidgets, reason: '$label غير موجود');
  for (final Element element in finder.evaluate()) {
    final RenderBox box = element.renderObject! as RenderBox;
    final Rect rect = box.localToGlobal(Offset.zero) & box.size;
    expect(
      rect.left,
      greaterThanOrEqualTo(-0.5),
      reason: '$label خارج الشاشة من اليسار',
    );
    expect(
      rect.right,
      lessThanOrEqualTo(width + 0.5),
      reason: '$label خارج الشاشة من اليمين (تجاوز أفقي)',
    );
  }
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  for (final width in <double>[320, 360, 400]) {
    testWidgets(
      'دفعة باسم طويل تبقى أزرار تصديرها داخل الشاشة عند ${width.toInt()}',
      (w) async {
        final errors = await _pumpScreen(
          w,
          width: width,
          admin: _SeededAdmin(_codes()),
        );
        _expectNoOverflow(errors, width.toInt(), 'قائمة الدفعات');

        // دفعتان: الجديدة باسمها، والقديمة بلا معرّف تُجمَّع بيومها
        expect(find.text('دفعات القسائم (2)'), findsOneWidget);
        expect(find.text(longNote), findsOneWidget);
        expect(find.text('تصدير الدفعة'), findsNWidgets(2));

        _expectWithinScreen(w, _exportButton, width, 'زر تصدير الدفعة');
        _expectWithinScreen(w, _copyButton, width, 'زر نسخ القائمة');

        // الزران لا يتراكبان
        final Rect export = w.getRect(_exportButton.first);
        final Rect copy = w.getRect(_copyButton.first);
        expect(
          export.overlaps(copy),
          isFalse,
          reason: 'زر التصدير يتراكب مع زر النسخ',
        );
      },
    );
  }

  testWidgets('الدفعة تبدأ مطوية والضغط على عنوانها يعرض قسائمها', (w) async {
    await _pumpScreen(w, width: 360, admin: _SeededAdmin(_codes()));

    expect(find.text('CHG-9482-KL11'), findsNothing);

    await w.tap(find.text(longNote));
    await w.pump(const Duration(milliseconds: 400));

    expect(find.text('CHG-9482-KL11'), findsOneWidget);
    expect(find.text('CHG-9482-KL33'), findsOneWidget);
    _expectNoOverflow(_drainErrors(w), 360, 'بعد فتح الدفعة');

    await w.tap(find.text(longNote));
    await w.pump(const Duration(milliseconds: 400));
    expect(find.text('CHG-9482-KL11'), findsNothing);
  });

  testWidgets('ورقة التصدير تعرض القائمة المنسوخة و PDF للدفعة نفسها', (
    w,
  ) async {
    await _pumpScreen(w, width: 360, admin: _SeededAdmin(_codes()));

    await w.tap(_exportButton.first);
    await w.pump(const Duration(milliseconds: 500));
    await w.pumpAndSettle();

    expect(find.text('تصدير دفعة قسائم'), findsOneWidget);
    expect(find.textContaining('نسخ قائمة منسوخة (3)'), findsOneWidget);
    expect(find.textContaining('تصدير PDF (3)'), findsOneWidget);
    // الدفعة فيها قسيمة متاحة ⇒ يظهر خيار المتاحة فقط
    expect(find.textContaining('PDF للقسائم المتاحة فقط'), findsOneWidget);

    await w.tap(find.textContaining('نسخ الأكواد فقط'));
    await w.pump(const Duration(milliseconds: 400));

    expect(find.text('تم نسخ 3 كود جاهزة للّصق'), findsOneWidget);
    _expectNoOverflow(_drainErrors(w), 360, 'بعد نسخ الأكواد');

    await w.pumpWidget(const SizedBox.shrink());
    await w.pump(const Duration(seconds: 3));
  });

  testWidgets('فلاتر الدفعات تُظهر المجموعة الصحيحة فقط', (w) async {
    await _pumpScreen(w, width: 360, admin: _SeededAdmin(_codes()));

    // الدفعة القديمة استُهلكت كلها: تبقى في «مستخدمة بالكامل» وحده
    await w.tap(find.text('مستخدمة بالكامل'));
    await w.pump(const Duration(milliseconds: 400));

    expect(find.text('دفعات القسائم (1)'), findsOneWidget);
    expect(find.text('نسخ القائمة (2)'), findsOneWidget);
    expect(find.text(longNote), findsNothing);

    await w.tap(find.text('فيها متاحة'));
    await w.pump(const Duration(milliseconds: 400));

    expect(find.text('دفعات القسائم (1)'), findsOneWidget);
    expect(find.text(longNote), findsOneWidget);
    expect(find.text('نسخ القائمة (2)'), findsNothing);

    await w.tap(find.text('كل الدفعات'));
    await w.pump(const Duration(milliseconds: 400));
    expect(find.text('دفعات القسائم (2)'), findsOneWidget);
    _expectNoOverflow(_drainErrors(w), 360, 'بعد الفلترة');
  });

  // التدفق الكامل الذي أوقع الشاشة الحمراء سابقاً: فتح نافذة التوليد من زر
  // «توليد دفعة»، إدخال اسم دفعة طويل، ثم التوليد وورقة التصدير بعدها.
  testWidgets('توليد دفعة جديدة يفتح ورقة تصديرها بلا أي استثناء', (w) async {
    final _GenAdmin admin = _GenAdmin(<ShippingCodeModel>[]);
    await _pumpScreen(w, width: 360, admin: admin);

    await w.tap(find.text('توليد دفعة'));
    await w.pump(const Duration(milliseconds: 400));
    await w.pumpAndSettle();
    _expectNoOverflow(_drainErrors(w), 360, 'نافذة التوليد مفتوحة');

    final Finder fields = find.byType(TextField);
    expect(
      fields,
      findsNWidgets(3),
      reason: 'نافذة التوليد لم تفتح بثلاثة حقول',
    );
    await w.enterText(fields.at(0), '10');
    await w.enterText(fields.at(1), '3');
    await w.enterText(fields.at(2), longNote);
    await w.pump(const Duration(milliseconds: 200));
    _expectNoOverflow(_drainErrors(w), 360, 'أثناء الكتابة');

    await w.tap(find.text('توليد القسائم'));
    await w.pump(const Duration(milliseconds: 400));
    _expectNoOverflow(_drainErrors(w), 360, 'لحظة إغلاق نافذة التوليد');

    await w.pump(const Duration(milliseconds: 900));
    _expectNoOverflow(_drainErrors(w), 360, 'بعد فتح ورقة التصدير');

    expect(find.textContaining('تم إنشاء'), findsOneWidget);
    expect(admin.shippingCodes, hasLength(3));
    expect(find.text('تصدير دفعة قسائم'), findsOneWidget);
    expect(find.textContaining('نسخ قائمة منسوخة (3)'), findsOneWidget);
  });
}
