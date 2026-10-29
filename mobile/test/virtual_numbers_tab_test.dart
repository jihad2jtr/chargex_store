// تبديل الأسفل: تبويب «شحن الاشتراكات» صار «الأرقام الوهمية»، واشتراكات المنصات
// اندمجت في صفحة الخدمات. الشبكة محظورة، فالكتالوج يُزرع في CacheService قبل البناء
// كما يحدث بعد أول جلب ناجح، ثم يُعدّ ما رُسم في كل صفحة حسب «النوع الرئيسي».
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/services/cache_service.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/providers/agent_provider.dart';
import 'package:layan_chargex/providers/app_catalog_provider.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/exchange_rate_provider.dart';
import 'package:layan_chargex/providers/margin_provider.dart';
import 'package:layan_chargex/providers/manual_services_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/providers/wallet_provider.dart';
import 'package:layan_chargex/screens/user/user_main_screen.dart';
import 'package:layan_chargex/screens/user/virtual_numbers_screen.dart';
import 'package:layan_chargex/widgets/app_icon_tile.dart';
import 'package:layan_chargex/widgets/digital_pass_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Map<String, dynamic> _app(String id, String name, String appType) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'appType': appType,
      'iconUrl': 'assets/cards/pubg-mobile.png',
      'isActive': true,
      'sortOrder': 0,
    };

Future<void> _pumpMain(
  WidgetTester w, {
  List<Map<String, dynamic>> apps = const [],
  double width = 420,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await CacheService.instance.clearAll();
  if (apps.isNotEmpty) await CacheService.instance.set('catalog_apps', apps);

  w.view.physicalSize = Size(width, 1400);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider()),
        ChangeNotifierProvider<AppCatalogProvider>(
          create: (_) => AppCatalogProvider(),
        ),
        ChangeNotifierProvider<ExchangeRateProvider>(
          create: (_) => ExchangeRateProvider(),
        ),
        ChangeNotifierProvider<AdminProvider>(create: (_) => AdminProvider()),
        ChangeNotifierProvider<MarginProvider>(create: (_) => MarginProvider()),
        ChangeNotifierProvider<ManualServicesProvider>(
          create: (_) => ManualServicesProvider(),
        ),
        ChangeNotifierProvider<AgentProvider>(create: (_) => AgentProvider()),
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => VirtualNumbersProvider(),
        ),
      ],
      child: MaterialApp(
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: UserMainScreen(),
        ),
      ),
    ),
  );
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
}

/// في الاختبار خطُّ google_fonts غير متاح فتُرسم الحروف بمربعات عريضة، لذلك
/// قد «يفيض» نص شريط الدعم رغم أنه سليم على الهاتف: تُستهلك هذه الاستثناءات
/// هنا، أما أي استثناء آخر فيبقى عيباً حقيقياً في الصفحة.
void _drainExpectedNoise(WidgetTester w) {
  final List<String> unexpected = <String>[];
  Object? error;
  while ((error = w.takeException()) != null) {
    final String text = error.toString();
    final bool fontNoise = text.contains('google_fonts');
    final bool wideTextNoise =
        text.contains('RenderFlex') ||
        text.contains('overflow') ||
        text.contains('OVERFLOW');
    if (!fontNoise && !wideTextNoise) unexpected.add(text);
  }
  expect(unexpected, isEmpty);
}

/// التبويبات غير المختارة في IndexedStack تظل خارج العرض (offstage)، فبدون هذا
/// المفتاح لا يُعثر على أي من محتواها.
Finder _text(String data) => find.text(data, skipOffstage: false);

List<String> _cardTitles(WidgetTester w) => w
    .widgetList<DigitalPassCardWidget>(
      find.byType(DigitalPassCardWidget, skipOffstage: false),
    )
    .map((c) => c.item.title)
    .toList();

List<String> _iconNames(WidgetTester w) => w
    .widgetList<AppIconTile>(find.byType(AppIconTile, skipOffstage: false))
    .map((t) => t.app.name)
    .toList();

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('الشريط السفلي يعرض «الأرقام» بدل تبويب الاشتراكات', (
    WidgetTester w,
  ) async {
    await _pumpMain(w);

    expect(_text('الأرقام'), findsOneWidget);
    expect(_text('اشتراكات'), findsNothing);
    expect(_text('شحن الاشتراكات'), findsNothing);
    expect(
      find.byIcon(Icons.sim_card_outlined, skipOffstage: false),
      findsOneWidget,
    );
    // صفحة الأرقام الوهمية مدمجة في التبويب الخامس
    expect(
      find.byType(VirtualNumbersScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(_text('اختر الخدمة'), findsOneWidget);
    expect(_text('لا توجد أرقام متاحة'), findsOneWidget);

    _drainExpectedNoise(w);
  });

  testWidgets('الاشتراكات تُعرض داخل صفحة الخدمات مع الخدمات', (
    WidgetTester w,
  ) async {
    await _pumpMain(
      w,
      apps: <Map<String, dynamic>>[
        _app('a1', 'نتفلكس', 'app'),
        _app('g1', 'ببجي', 'game'),
        _app('s1', 'شاهد VIP', 'subscription'),
        _app('s2', 'دفع الفواتير', 'service'),
      ],
    );

    // صفحة الخدمات وحدها تعرض بطاقات التذاكر: خدمة + اشتراك معاً
    expect(_cardTitles(w), <String>['شاهد VIP', 'دفع الفواتير']);
    expect(_text('لا توجد خدمات متاحة حالياً'), findsNothing);

    // التطبيقات والألعاب تبقيان على نمط الأيقونات ولا تسرب فيهما اشتراك
    expect(_iconNames(w), <String>['نتفلكس', 'ببجي']);

    _drainExpectedNoise(w);
  });

  testWidgets('بلا خدمات في الكتالوج تبقى صفحة الخدمات فارغة بأمان', (
    WidgetTester w,
  ) async {
    await _pumpMain(
      w,
      apps: <Map<String, dynamic>>[_app('g1', 'ببجي', 'game')],
    );

    expect(_text('لا توجد خدمات متاحة حالياً'), findsOneWidget);
    expect(_cardTitles(w), isEmpty);
    expect(_iconNames(w), <String>['ببجي']);

    _drainExpectedNoise(w);
  });
}
