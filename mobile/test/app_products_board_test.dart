// لوحة «باقات التطبيق»: هيدر داكن بعدّادات قابلة للضغط، لوحة بحث/ترتيب/فلاتر،
// وبطاقات الباقات بأسلوب التذكرة الموحّد.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/app_model.dart';
import 'package:layan_chargex/models/product_model.dart';
import 'package:layan_chargex/models/provider_model.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/screens/admin/app_products_management_screen.dart';
import 'package:layan_chargex/widgets/ops_ticket_card.dart';

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

/// مزوّد ببيانات محلية: يتيح فحص البطاقات والفلاتر دون شبكة
class _SeededAdmin extends AdminProvider {
  _SeededAdmin(this.products, [this.suppliers = const <ProviderModel>[]]);

  final List<ProductModel> products;
  final List<ProviderModel> suppliers;
  String? lastToggledId;

  @override
  List<ProductModel> get currentAppProducts => products;

  @override
  List<ProviderModel> get providers => suppliers;

  @override
  bool get isLoading => false;

  @override
  Future<void> fetchAppProducts(String appId) async {}

  @override
  Future<void> fetchAdminProducts([String? appId]) async {}

  @override
  Future<void> fetchProviders({bool forceRefresh = false}) async {}

  @override
  Future<void> fetchAllUsers({bool silent = false}) async {}

  @override
  Future<void> fetchServiceTemplates() async {}

  @override
  Future<bool> toggleProductActive(String id, [String? currentAppId]) async {
    lastToggledId = id;
    return true;
  }
}

final AppItemModel _app = AppItemModel(
  id: 'a1',
  name: 'Fortnite',
  iconUrl: '',
  category: 'game',
);

ProductModel _product({
  required String id,
  required String name,
  String type = 'direct_api',
  String kind = 'quantity',
  double cost = 10,
  double sale = 12.5,
  bool isActive = true,
  int codes = 0,
  String? providerId,
  String? providerProductCode,
  bool providerAvailable = true,
  String quantityLabel = '',
}) {
  return ProductModel(
    id: id,
    appId: _app.id,
    name: name,
    type: type,
    kind: kind,
    costPrice: cost,
    profitMarginType: 'percentage',
    profitMarginValue: 25,
    salePrice: sale,
    isActive: isActive,
    availableCodesCount: codes,
    providerId: providerId,
    providerProductCode: providerProductCode,
    providerAvailable: providerAvailable,
    quantityLabel: quantityLabel,
  );
}

/// يبني اللوحة ويعيد أخطاء التخطيط فقط (بعد استبعاد تحميل الخطوط)
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
      create: (_) => provider ?? _SeededAdmin(const <ProductModel>[]),
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AppProductsManagementScreen(app: _app),
        ),
      ),
    ),
  );
  await w.pump(const Duration(milliseconds: 400));

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

List<String> _cardTitles(WidgetTester w) => w
    .widgetList<OpsTicketCard>(find.byType(OpsTicketCard))
    .map((card) => card.title)
    .toList();

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  final List<ProductModel> seeded = <ProductModel>[
    _product(
      id: 'p1',
      name: 'شدات 1000',
      sale: 12.5,
      providerId: 'pr1',
      providerProductCode: 'FN-1000',
      quantityLabel: '1000 شد',
    ),
    _product(
      id: 'p2',
      name: 'بكج لباس',
      type: 'codes',
      kind: 'package',
      codes: 0,
      sale: 30,
    ),
    _product(id: 'p3', name: 'شدات 5000', isActive: false, sale: 55),
  ];

  testWidgets('الهيدر يعرض هوية التطبيق والبلاطات الأربع بلا أخطاء تخطيط', (
    w,
  ) async {
    final errors = await _pumpScreen(
      w,
      width: 560,
      provider: _SeededAdmin(seeded, <ProviderModel>[
        ProviderModel(id: 'pr1', name: 'GameMax', baseUrl: '', apiKey: ''),
      ]),
    );

    expect(errors, isEmpty);
    expect(find.text('باقات Fortnite'), findsOneWidget);
    expect(find.text('كل الباقات'), findsOneWidget);
    expect(find.text('ظاهرة للعملاء'), findsOneWidget);
    expect(find.text('معطّلة'), findsOneWidget);
    expect(find.text('كود متوفر'), findsOneWidget);
    // ثلاث باقات · واحدة معطّلة
    expect(find.textContaining('3 باقة'), findsWidgets);
  });

  testWidgets('البطاقات تذاكر تعرض السعر والحالة والتكلفة وتحذير المخزون', (
    w,
  ) async {
    await _pumpScreen(
      w,
      width: 560,
      provider: _SeededAdmin(seeded, <ProviderModel>[
        ProviderModel(id: 'pr1', name: 'GameMax', baseUrl: '', apiKey: ''),
      ]),
    );

    // الترتيب الافتراضي حسب الفئة: الباقات ثم العملات (اسماً)
    expect(_cardTitles(w), <String>['بكج لباس', 'شدات 1000', 'شدات 5000']);
    expect(find.text(r'$12.50'), findsOneWidget);
    expect(find.text('التكلفة:'), findsWidgets);
    expect(find.text('نشط'), findsWidgets);
    expect(find.text('معطّل'), findsOneWidget);
    expect(find.textContaining('نفد مخزون الأكواد'), findsOneWidget);
    expect(find.textContaining('CODE: FN-1000'), findsOneWidget);
  });

  testWidgets('مزود متوقف يظهر كملاحظة على البطاقة', (w) async {
    await _pumpScreen(
      w,
      provider: _SeededAdmin(<ProductModel>[
        _product(id: 'p1', name: 'شدات 100', providerAvailable: false),
      ]),
    );

    expect(find.textContaining('المزود متوقف'), findsOneWidget);
  });

  testWidgets('رقاقة النوع «أكواد» تحدّ القائمة وتُصلَّح شريط النتائج', (
    w,
  ) async {
    await _pumpScreen(w, width: 560, provider: _SeededAdmin(seeded));

    await w.tap(find.text('أكواد'));
    await w.pump(const Duration(milliseconds: 300));

    expect(_cardTitles(w), <String>['بكج لباس']);
    expect(find.text('عرض 1 من 3 باقة مطابقة'), findsOneWidget);
  });

  testWidgets('بلاطة «معطّلة» تُفلتر الحالة والضغط عليها ثانية يُعيد الكل', (
    w,
  ) async {
    await _pumpScreen(w, width: 560, provider: _SeededAdmin(seeded));

    await w.tap(find.text('معطّلة'));
    await w.pump(const Duration(milliseconds: 300));
    expect(_cardTitles(w), <String>['شدات 5000']);

    await w.tap(find.text('معطّلة'));
    await w.pump(const Duration(milliseconds: 300));
    expect(_cardTitles(w).length, 3);
  });

  testWidgets('البحث يطابق الاسم أو كود المزود', (w) async {
    await _pumpScreen(w, width: 560, provider: _SeededAdmin(seeded));

    await w.enterText(find.byType(TextField), 'FN-1000');
    await w.pump(const Duration(milliseconds: 300));
    expect(_cardTitles(w), <String>['شدات 1000']);

    await w.enterText(find.byType(TextField), 'لا شيء هنا');
    await w.pump(const Duration(milliseconds: 300));
    expect(find.text('لا باقة تطابق هذا التحديد'), findsOneWidget);

    await w.tap(find.text('مسح الفلاتر').first);
    await w.pump(const Duration(milliseconds: 300));
    expect(_cardTitles(w).length, 3);
  });

  testWidgets('قائمة الترتيب «الأغلى» تقدّم أعلى سعر', (w) async {
    await _pumpScreen(w, width: 560, provider: _SeededAdmin(seeded));

    await w.tap(find.byType(PopupMenuButton<String>));
    await w.pumpAndSettle();
    await w.tap(find.text('الأغلى'));
    await w.pump(const Duration(milliseconds: 300));

    expect(_cardTitles(w).first, 'شدات 5000');
  });

  testWidgets('زر «تعطيل» في تذييل البطاقة يستدعي تبديل الحالة', (w) async {
    final admin = _SeededAdmin(seeded);
    await _pumpScreen(w, width: 560, provider: admin);

    await w.tap(find.text('تعطيل').first);
    await w.pump(const Duration(milliseconds: 300));

    expect(admin.lastToggledId, isNotNull);
    expect(find.textContaining('تم تعطيل «'), findsOneWidget);
  });

  testWidgets('الحالة الفارغة تدعو لإضافة أول باقة', (w) async {
    await _pumpScreen(w, provider: _SeededAdmin(const <ProductModel>[]));

    expect(find.text('لا باقات في Fortnite بعد'), findsOneWidget);
    expect(find.text('إضافة أول باقة'), findsOneWidget);
  });

  testWidgets('العرض الضيق 320px بلا فيض في التذاكر ولا اللوحة', (w) async {
    final errors = await _pumpScreen(
      w,
      width: 320,
      provider: _SeededAdmin(<ProductModel>[
        _product(
          id: 'p1',
          name: 'باقة شدات الموسم الحادي عشر مع مكافآت إضافية',
          type: 'codes',
          kind: 'package',
          codes: 12,
          providerProductCode: 'FN-LONG-CODE-12345',
          quantityLabel: '13 500 شد',
        ),
      ]),
    );

    expect(errors, isEmpty);
    expect(find.byType(OpsTicketCard), findsOneWidget);
  });
}
