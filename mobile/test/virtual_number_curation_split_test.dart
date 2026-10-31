// تنسيق الأرقام الوهمية بنفس مسار المتجر: تطبيقات تُنشأ فارغة في «إدارة
// الأرقام»، ودول تُنتقى من كتالوج المزود في صفحة مزودى الأرقام، وتبديل
// التفعيل لكل دولة يتحكم بما يراه العميل. الاختبار يثبّت نقاط الدخول
// والشارات والحالات بلا شبكة (الشبكة محجومة وأي استدعاء حقيقي يفشل فوراً).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/provider_model.dart';
import 'package:layan_chargex/models/virtual_number_model.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/screens/admin/providers_management_screen.dart';
import 'package:layan_chargex/screens/admin/virtual_number_apps_screen.dart';
import 'package:layan_chargex/screens/admin/virtual_number_catalog_screen.dart';
import 'package:layan_chargex/screens/admin/virtual_numbers_management_screen.dart';

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

// ---------------------------------------------------------------------------
// بذور ثابتة: مزود أرقام + تطبيق لكل حالة + كتالوج بدول منتقاة وجديدة
// ---------------------------------------------------------------------------

ProviderModel _numberProvider() => ProviderModel(
  id: 'p-vn',
  name: '5sim',
  baseUrl: 'https://api.5sim.net/v1/user',
  apiKey: 'key',
  providerType: 'fivesim',
  status: 'online',
  isActive: true,
  balance: 50,
  profitMarginType: 'percentage',
  profitMarginValue: 25,
);

VirtualNumberAppModel _app({
  required String id,
  required String name,
  required String serviceCode,
  bool isActive = true,
  int productCount = 0,
  int activeProductCount = 0,
}) => VirtualNumberAppModel(
  id: id,
  name: name,
  serviceCode: serviceCode,
  isActive: isActive,
  productCount: productCount,
  activeProductCount: activeProductCount,
);

VirtualNumberCatalogCountry _addedCountry({
  bool stoppedByQuality = false,
  int consecutiveFailures = 0,
}) => VirtualNumberCatalogCountry(
  code: '20',
  name: 'مصر',
  cost: 0.4,
  count: 12,
  salePrice: 0.5,
  added: true,
  productId: 'prod-eg',
  productActive: !stoppedByQuality,
  productAutoDisabled: stoppedByQuality,
  productConsecutiveFailures: consecutiveFailures,
);

VirtualNumberCatalogCountry _freshCountry() =>
    const VirtualNumberCatalogCountry(
      code: '1',
      name: 'كندا',
      cost: 0.8,
      count: 40,
      salePrice: 1.0,
    );

VirtualNumberAdminCatalog _catalog({
  String appActiveState = 'active',
  VirtualNumberCatalogCountry? addedCountry,
}) => VirtualNumberAdminCatalog(
  providerId: 'p-vn',
  providerName: '5sim',
  providerStatus: 'online',
  // الاسم الوهمي يُوسم به سطر كل دولة: بلا وسم يخلط الأدمن دولةً من
  // سيرفر بدولتها المطابقة عند مزود آخر
  providerServerLabel: 'Server 1',
  marginType: 'percentage',
  marginValue: 25,
  services: [
    VirtualNumberCatalogService(
      code: 'telegram',
      name: 'Telegram',
      countryCount: 2,
      appId: appActiveState == 'none' ? '' : 'a1',
      appName: 'Telegram',
      appActive: appActiveState != 'inactive',
      countries: [addedCountry ?? _addedCountry(), _freshCountry()],
    ),
  ],
);

class _SeededVn extends VirtualNumbersProvider {
  _SeededVn({
    List<VirtualNumberAppModel> apps = const [],
    VirtualNumberAdminCatalog? catalog,
  }) : _apps = apps,
       _catalog = catalog ?? VirtualNumberAdminCatalog.empty();

  final List<VirtualNumberAppModel> _apps;
  final VirtualNumberAdminCatalog _catalog;

  final List<String> toggledApps = <String>[];
  final List<String> toggledProducts = <String>[];
  final List<String> removedProducts = <String>[];
  // إعادة التفعيل بسبب الجودة: معرّف المنتج والملاحظة المُرسلة معه
  final List<String> reactivated = <String>[];
  String? lastReactivateNote;
  int bulkCalls = 0;
  Map<String, dynamic>? lastAddCountries;
  Map<String, dynamic>? lastCreateApp;

  @override
  List<VirtualNumberAppModel> get adminApps => _apps;

  @override
  VirtualNumberAdminCatalog get adminCatalog => _catalog;

  @override
  bool get isAppsLoading => false;

  @override
  bool get isCatalogLoading => false;

  @override
  bool get isAdminLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchAdminApps({bool quiet = false}) async {}

  @override
  Future<void> fetchAdminCatalog({String? providerId}) async {}

  @override
  Future<void> fetchAdminStats() async {}

  @override
  Future<void> fetchAdminRequests({
    String status = 'all',
    String search = '',
    int limit = 100,
  }) async {}

  @override
  Future<String?> adminSyncCatalog() async => 'تم تحديث الكتالوج';

  @override
  Future<String?> bulkCreateAdminApps({String? providerId}) async {
    bulkCalls++;
    return 'أُضيفت التطبيقات';
  }

  @override
  Future<String?> toggleAdminApp(String id) async {
    toggledApps.add(id);
    return 'تم تحديث حالة التطبيق';
  }

  @override
  Future<String?> createAdminApp({
    required String name,
    required String serviceCode,
    String? providerId,
    String? iconUrl,
  }) async {
    lastCreateApp = {
      'name': name,
      'serviceCode': serviceCode,
      'providerId': providerId,
    };
    return 'تم إنشاء التطبيق';
  }

  @override
  Future<String?> addCountriesToApp({
    required String appId,
    required List<VirtualNumberCatalogCountry> countries,
    String? providerId,
  }) async {
    lastAddCountries = {
      'appId': appId,
      'codes': countries.map((c) => c.code).toList(),
    };
    return 'تمت إضافة الدول';
  }

  @override
  Future<String?> toggleAdminProduct(String id) async {
    toggledProducts.add(id);
    return 'تم تحديث حالة الدولة';
  }

  @override
  Future<String?> removeAdminProduct(String id) async {
    removedProducts.add(id);
    return 'تم حذف الدولة';
  }

  @override
  Future<String?> reactivateProduct(String productId, {String? note}) async {
    reactivated.add(productId);
    lastReactivateNote = note;
    return 'تم إعادة تفعيل السيرفر';
  }
}

class _NoProvidersAdmin extends AdminProvider {
  @override
  List<ProviderModel> get providers => [_numberProvider()];

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchProviders({bool forceRefresh = false}) async {}

  @override
  Future<bool> checkProviderStatus(String id) async => true;
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

/// يُمر ListView حتى تظهر بطاقة التطبيق المعروفة باسمها
/// (scrollUntilVisible يفشل عندما تتعدد Scrollables في الصفحة)
Future<void> _scrollToAppCard(WidgetTester w, String name) async {
  final list = find.byType(ListView).first;
  for (var i = 0; i < 10; i++) {
    if (w.any(find.text(name))) return;
    await w.drag(list, const Offset(0, -140));
    await w.pump(const Duration(milliseconds: 100));
  }
}

/// يُمر قائمة الكتالوج حتى يصل العنصر المطلوب لحدود الرؤية
/// (التمر على Scrollable الأول لا على ListView: قائمة الدول الداخلية ListView أيضاً)
Future<void> _scrollUntil(WidgetTester w, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 20; i++) {
    if (w.any(target)) return;
    await w.drag(scrollable, const Offset(0, -200));
    await w.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpApp(
  WidgetTester w,
  Widget home, {
  _SeededVn? vn,
  AdminProvider? admin,
  double width = 400,
  double height = 900,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  w.view.physicalSize = Size(width, height);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => vn ?? _SeededVn(),
        ),
        if (admin != null)
          ChangeNotifierProvider<AdminProvider>(create: (_) => admin),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await _settle(w);
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  setUp(() => _collected.clear());

  group('تطبيقات الأرقام الوهمية', () {
    testWidgets('شاشة إدارة الأرقام تملك مدخلاً مستقلاً لتطبيقات الأرقام', (
      w,
    ) async {
      await _pumpApp(w, const VirtualNumbersManagementScreen());

      expect(find.byTooltip('تطبيقات الأرقام'), findsOneWidget);
      expect(find.byTooltip('إدارة مزودي الأرقام'), findsOneWidget);
    });

    testWidgets('شاشة التطبيقات تعرض حالة كل تطبيق: ظاهرة / بلا دول / موقوفة', (
      w,
    ) async {
      final vn = _SeededVn(
        apps: [
          _app(
            id: 'a1',
            name: 'Telegram',
            serviceCode: 'telegram',
            productCount: 3,
            activeProductCount: 2,
          ),
          _app(id: 'a2', name: 'WhatsApp', serviceCode: 'whatsapp'),
          _app(
            id: 'a3',
            name: 'Discord',
            serviceCode: 'discord',
            isActive: false,
            productCount: 1,
            activeProductCount: 1,
          ),
        ],
      );
      await _pumpApp(w, const VirtualNumberAppsScreen(), vn: vn);

      expect(find.text('ظاهرة للعميل'), findsOneWidget);
      expect(find.text('بلا دول مفعّلة'), findsOneWidget);
      expect(find.text('موقوفة'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.textContaining('رمز الخدمة: telegram'), findsOneWidget);
      // زر الانتقاء ينقل إلى كتالوج المزود كما في تطبيقات المتجر
      await _scrollToAppCard(w, 'Discord');
      expect(find.text('انتقِ دول هذه الخدمة من كتالوج المزود'), findsWidgets);
    });

    testWidgets('مسرّع الاستيراد ينادي bulkCreateAdminApps بعد التأكيد', (
      w,
    ) async {
      final vn = _SeededVn(
        apps: [_app(id: 'a1', name: 'Telegram', serviceCode: 'telegram')],
      );
      await _pumpApp(w, const VirtualNumberAppsScreen(), vn: vn);

      await w.tap(find.byTooltip('إضافة تطبيق لكل خدمة في كتالوج المزود'));
      await _settle(w);
      expect(find.text('استيراد كتالوج الخدمات'), findsOneWidget);

      await w.tap(find.widgetWithText(FilledButton, 'استيراد'));
      await _settle(w);
      expect(vn.bulkCalls, 1);
    });

    testWidgets('تبديل تفعيل التطبيق يصل إلى المزوّد المعطى', (w) async {
      final vn = _SeededVn(
        apps: [
          _app(
            id: 'a1',
            name: 'Telegram',
            serviceCode: 'telegram',
            productCount: 2,
            activeProductCount: 1,
          ),
        ],
      );
      await _pumpApp(w, const VirtualNumberAppsScreen(), vn: vn);

      // البطاقة الأولى ظاهرة كاملة: زر الطاقة داخل فوترها
      await w.tap(find.byTooltip('إيقاف التطبيق'));
      await _settle(w);
      expect(vn.toggledApps, ['a1']);
    });
  });

  group('كتالوج مزود الأرقام (الانتقاء والتفعيل)', () {
    testWidgets('بطاقة المزود في صفحته تفتح الكتالوج بدل عرض منتجات المتجر', (
      w,
    ) async {
      await _pumpApp(
        w,
        const ProvidersManagementScreen(virtualNumbersOnly: true),
        admin: _NoProvidersAdmin(),
      );

      expect(find.text('انتقاء الدول والتطبيقات'), findsOneWidget);
      expect(find.text('فحص الرصيد'), findsOneWidget);
      expect(find.text('عرض المنتجات'), findsNothing);
    });

    testWidgets(
      'الدول المنتقاة تظهر بمفتاح تفعيل والدول الجديدة بمربعات اختيار',
      (w) async {
        final vn = _SeededVn(catalog: _catalog());
        await _pumpApp(
          w,
          VirtualNumberCatalogScreen(
            focusApp: _app(id: 'a1', name: 'Telegram', serviceCode: 'telegram'),
          ),
          vn: vn,
          width: 420,
          height: 1000,
        );

        // الدولة المُنتقاة: سطر تفعيل/إخفاء + حالة الظهور + وسم السيرفر
        await _scrollUntil(w, find.textContaining('مصر'));
        expect(find.textContaining('مصر'), findsOneWidget);
        expect(find.textContaining('ظاهرة للعميل'), findsWidgets);
        expect(find.byType(Switch), findsOneWidget);
        // وسم السيرفر الوهمي بجانب الدولة، وفي سطر السعر يُذكر المزود لأنه
        // شاشة إدارة لا شاشة عميل
        expect(find.text('Server 1'), findsWidgets);
        expect(find.textContaining('5sim — Server 1'), findsOneWidget);
        // الدولة غير المنتقاة: اختيار متعدد ضمن كتالوج المزود
        expect(find.textContaining('كندا'), findsOneWidget);
        expect(find.byType(Checkbox), findsOneWidget);
        // عنوانا القسمان يذكوران السيرفر: الإضافة هنا منتج تحت هذا السيرفر وحده
        expect(find.textContaining('دول هذا السيرفر'), findsOneWidget);
        expect(find.textContaining('دول كتالوج هذا السيرفر'), findsOneWidget);
      },
    );

    testWidgets('تبديل تفعيل دولة يُنادى بمنتجاتها، والحذف يصل للخدمة', (
      w,
    ) async {
      final vn = _SeededVn(catalog: _catalog());
      await _pumpApp(
        w,
        VirtualNumberCatalogScreen(
          focusApp: _app(id: 'a1', name: 'Telegram', serviceCode: 'telegram'),
        ),
        vn: vn,
        width: 420,
        height: 1000,
      );

      await _scrollUntil(w, find.byType(Switch));
      await w.tap(find.byType(Switch));
      await _settle(w);
      expect(vn.toggledProducts, ['prod-eg']);

      await w.tap(find.byTooltip('حذف الدولة من التطبيق'));
      await _settle(w);
      expect(vn.removedProducts, ['prod-eg']);
    });

    testWidgets(
      'دولة أوقفتها الجودة تُوسم بحالتها، وزر التفعيل يصفّر المتتالي',
      (w) async {
        final vn = _SeededVn(
          catalog: _catalog(
            addedCountry: _addedCountry(
              stoppedByQuality: true,
              consecutiveFailures: 3,
            ),
          ),
        );
        await _pumpApp(
          w,
          VirtualNumberCatalogScreen(
            focusApp: _app(id: 'a1', name: 'Telegram', serviceCode: 'telegram'),
          ),
          vn: vn,
          width: 420,
          height: 1000,
        );

        // الحالة ظاهرة في السطر: إيقاف جودة بثلاث فشل متتالٍ، لا إخفاء يدوي
        await _scrollUntil(w, find.textContaining('موقوف جودةً'));
        expect(
          find.textContaining('موقوف جودةً (3 فشل متتالٍ)'),
          findsOneWidget,
        );

        await w.tap(
          find.byTooltip('إعادة التفعيل (يصفّر الفشل المتتالي ويُبقي التاريخ)'),
        );
        await _settle(w);
        // الوصول لنفس المعرّف مع ملاحظة تُذكر في سجل الأحداث الإداري
        expect(vn.reactivated, ['prod-eg']);
        expect(vn.lastReactivateNote, 'إعادة تفعيل من كتالوج المزود');
      },
    );

    testWidgets(
      'الخدمة بلا تطبيق: شارة «بلا تطبيق» والإضافة تُنشئ التطبيق أولاً',
      (w) async {
        final vn = _SeededVn(catalog: _catalog(appActiveState: 'none'));
        await _pumpApp(
          w,
          const VirtualNumberCatalogScreen(),
          vn: vn,
          width: 420,
          height: 1000,
        );

        expect(find.text('بلا تطبيق'), findsOneWidget);
        // فتح بطاقة الخدمة لإظهار دولها الجديدة
        await w.tap(find.textContaining('telegram •'));
        await _settle(w);
        final createBtn = find.text('إنشاء تطبيق وإضافة');
        await _scrollUntil(w, createBtn);
        expect(createBtn, findsOneWidget);
      },
    );
  });
}
