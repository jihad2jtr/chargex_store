// صفحة إدارة المزودين: ضمان عدم تداخل عناصر بطاقة المزود (الرصيد/الهامش/الأزرار/الشارات)
// على أضيق عرض للشاشة، وسلامة زر إيقاف/تفعيل المزود.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/provider_model.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/screens/admin/providers_management_screen.dart';

/// الشبكة معطّلة: لا نريد أي طلب حقيقي أثناء اختبار التخطيط
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

/// مزوّد ببيانات محلية جاهزة: يعرض بطاقات المزودين دون شبكة
class _SeededAdmin extends AdminProvider {
  _SeededAdmin(this._items);

  final List<ProviderModel> _items;
  int toggleCalls = 0;

  @override
  List<ProviderModel> get providers => _items;

  @override
  bool get isLoading => false;

  @override
  Future<void> fetchProviders({bool forceRefresh = false}) async {}

  @override
  Future<bool> toggleProviderActive(String id) async {
    toggleCalls++;
    return true;
  }

  @override
  Future<bool> checkProviderStatus(String id) async => true;
}

ProviderModel _provider({
  required String id,
  required String name,
  bool isActive = true,
}) {
  return ProviderModel(
    id: id,
    name: name,
    baseUrl: 'https://public-api.foxreload.com',
    apiKey: 'key-123',
    status: isActive ? 'online' : 'error',
    lastError: isActive ? null : 'الرصيد \$0.00 أقل من تكلفة الطلب \$1.50',
    lastCheckAt: DateTime(2026, 10, 27, 21, 56),
    balance: isActive ? 24.75 : 0,
    profitMarginType: 'percentage',
    profitMarginValue: 12.5,
    isActive: isActive,
  );
}

Future<List<Object>> _pumpScreen(
  WidgetTester w, {
  double width = 360,
  required _SeededAdmin admin,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  w.view.physicalSize = Size(width, 900);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    ChangeNotifierProvider<AdminProvider>(
      create: (_) => admin,
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ProvidersManagementScreen(),
        ),
      ),
    ),
  );
  await w.pump(const Duration(milliseconds: 400));

  // نستهلك أخطاء الشبكة/الخط ونُبقي أخطاء التخطيط (تداخل العناصر) فقط
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

/// ضمن حدود الشاشة أفقياً: التجاوز (overflow) يدفع العنصر خارجها فيظهر متداخلاً
void _expectWithinScreen(
  WidgetTester w,
  Finder finder,
  double width,
  String label,
) {
  expect(finder, findsWidgets, reason: '$label غير موجود');
  for (final element in finder.evaluate()) {
    final box = element.renderObject! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
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

/// زر "عرض المنتجات" داخل بطاقة المزود.
/// ملاحظة: `ElevatedButton.icon` يبني نوعاً خاصاً غير ظاهر، لذلك لا يطابقه
/// `find.byType(ElevatedButton)`؛ نبحث عن أي أب يرث ElevatedButton.
Finder get _productsButton => find.ancestor(
  of: find.text('عرض المنتجات'),
  matching: find.byWidgetPredicate((w) => w is ElevatedButton),
);

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  for (final width in <double>[320, 360, 400]) {
    testWidgets(
      'أزرار بطاقة المزود تبقى داخل الشاشة عند عرض ${width.toInt()}',
      (w) async {
        final admin = _SeededAdmin([
          _provider(id: 'p1', name: 'Fox Reload'),
          _provider(id: 'p2', name: 'Bay2Game', isActive: false),
        ]);

        final errors = await _pumpScreen(w, width: width, admin: admin);

        // لا يوجد أي تجاوز أفقي (تداخل) في أي صف داخل الصفحة
        expect(
          errors.where((e) => e.toString().contains('overflowed')).toList(),
          isEmpty,
          reason:
              'يوجد تجاوز أفقي في تخطيط الصفحة عند عرض '
              '${width.toInt()} (العناصر متداخلة)',
        );

        // الصفحة بُنيت كاملة ببطاقاتها
        expect(find.byType(ProvidersManagementScreen), findsOneWidget);

        expect(find.text('Fox Reload'), findsOneWidget);
        expect(find.text('Bay2Game'), findsOneWidget);
        expect(find.text('موقوف'), findsOneWidget);
        expect(
          find.text(
            'المزود موقوف — كل التطبيقات والألعاب المرتبطة به لا تظهر للعملاء',
          ),
          findsOneWidget,
        );

        // كل إجراءات البطاقة داخل حدود الشاشة (لا تجاوز أفقي)
        _expectWithinScreen(w, _productsButton, width, 'زر عرض المنتجات');
        _expectWithinScreen(
          w,
          find.byTooltip('إيقاف المزود وإخفاء تطبيقاته'),
          width,
          'زر إيقاف المزود',
        );
        _expectWithinScreen(
          w,
          find.byTooltip('تفعيل المزود'),
          width,
          'زر تفعيل المزود',
        );
        _expectWithinScreen(
          w,
          find.byTooltip('مزامنة المنتجات والأسعار'),
          width,
          'زر المزامنة',
        );
        _expectWithinScreen(w, find.byTooltip('حذف المزود'), width, 'زر الحذف');

        // زر المنتجات وزر التفعيل لا يتراكبان، والأدوات في صف تحتها
        final products = w.getRect(_productsButton.first);
        final power = w.getRect(
          find.byTooltip('إيقاف المزود وإخفاء تطبيقاته').first,
        );
        final sync = w.getRect(
          find.byTooltip('مزامنة المنتجات والأسعار').first,
        );
        expect(
          power.overlaps(products),
          isFalse,
          reason: 'زر التفعيل يتراكب مع زر عرض المنتجات',
        );
        expect(
          products.bottom,
          lessThanOrEqualTo(sync.top + 0.5),
          reason: 'أدوات الإدارة تتراكب مع الصف الرئيسي',
        );
      },
    );
  }

  testWidgets('التفعيل مباشر والإيقاف يطلب تأكيداً', (w) async {
    final admin = _SeededAdmin([
      _provider(id: 'p1', name: 'Fox Reload'),
      _provider(id: 'p2', name: 'Bay2Game', isActive: false),
    ]);
    await _pumpScreen(w, admin: admin);

    // مزود موقوف: التفعيل لا يحتاج تأكيداً
    await w.tap(find.byTooltip('تفعيل المزود'));
    await w.pump(const Duration(milliseconds: 300));
    expect(admin.toggleCalls, 1);
    expect(find.text('إيقاف مزود الخدمة'), findsNothing);

    // مزود مفعّل: الإيقاف يمر عبر نافذة تأكيد
    await w.tap(find.byTooltip('إيقاف المزود وإخفاء تطبيقاته'));
    await w.pump(const Duration(milliseconds: 300));
    expect(find.text('إيقاف مزود الخدمة'), findsOneWidget);

    await w.tap(find.text('إيقاف المزود'));
    await w.pump(const Duration(milliseconds: 300));
    expect(admin.toggleCalls, 2);

    // إنهاء مؤقت شريط التنبيه قبل انتهاء الاختبار
    await w.pumpWidget(const SizedBox.shrink());
    await w.pump(const Duration(seconds: 4));
  });
}
