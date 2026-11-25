import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/services/cache_service.dart';
import 'package:layan_chargex/core/theme/app_colors.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/providers/agent_provider.dart';
import 'package:layan_chargex/providers/app_catalog_provider.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/exchange_rate_provider.dart';
import 'package:layan_chargex/providers/manual_services_provider.dart';
import 'package:layan_chargex/providers/margin_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/providers/wallet_provider.dart';
import 'package:layan_chargex/screens/user/user_main_screen.dart';
import 'package:layan_chargex/screens/user/virtual_numbers_screen.dart';
import 'package:layan_chargex/widgets/digital_pass_card.dart';
import 'package:layan_chargex/widgets/service_ticket_card.dart';
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

void _expectNoOverflow(WidgetTester w) {
  final List<String> errors = <String>[];
  Object? error;
  while ((error = w.takeException()) != null) {
    final String text = error.toString();
    if (!text.contains('google_fonts') && !text.contains('RenderFlex overflowed by 0.0')) {
      if (text.contains('overflow') || text.contains('OVERFLOW')) {
        errors.add(text);
      }
    }
  }
  expect(errors, isEmpty);
}

void _drainUnexpectedErrors(WidgetTester w) {
  final List<String> unexpected = <String>[];
  Object? error;
  while ((error = w.takeException()) != null) {
    final String text = error.toString();
    if (text.contains('google_fonts')) continue;
    if (text.contains('overflow') || text.contains('OVERFLOW')) {
      unexpected.add(text);
    } else {
      unexpected.add(text);
    }
  }
  expect(unexpected, isEmpty);
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('ServiceTicketCard يعرض التذكرة الفاتحة وخط التثقيب دون overflow على عرض 92dp', (
    WidgetTester w,
  ) async {
    w.view.physicalSize = const Size(320, 900);
    w.view.devicePixelRatio = 1.0;
    addTearDown(w.view.resetPhysicalSize);
    addTearDown(w.view.resetDevicePixelRatio);

    await w.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 92 / (92 + 68),
              padding: const EdgeInsets.all(14),
              children: [
                ServiceTicketCard(
                  name: 'تيليجرام',
                  foreign: 'Telegram',
                  metaText: '12 دولة',
                  priceText: 'من \$0.50',
                  tag: 'تلقائي',
                  tagColor: AppColors.ticketAmber,
                  iconRaw: 'assets/icons/telegram.png',
                  onTap: () {},
                ),
                ServiceTicketCard(
                  name: 'تفعيل واتساب المضمون',
                  priceText: '\$2.50',
                  tag: 'يدوي مضمون',
                  tagColor: AppColors.emerald,
                  iconRaw: 'assets/icons/whatsapp.png',
                  sensitive: true,
                  onTap: () {},
                ),
                ServiceTicketCard(
                  name: 'كانفا برو',
                  metaText: 'تصميم ومونتاج',
                  priceText: 'باقات متعددة',
                  tag: 'اشتراك',
                  tagColor: AppColors.violet,
                  iconRaw: 'assets/cards/canva.png',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await w.pump();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is ClipPath && widget.clipper is TicketPassClipper,
      ),
      findsNWidgets(3),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is DashedLinePainter,
      ),
      findsNWidgets(3),
    );
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsNWidgets(2));
    expect(find.text('تيليجرام'), findsOneWidget);
    expect(find.text('12 دولة'), findsOneWidget);
    expect(find.text('من \$0.50'), findsOneWidget);
    expect(find.text('باقات متعددة'), findsOneWidget);

    _drainUnexpectedErrors(w);
  });

  testWidgets('صفحة الأرقام تعرض التذكرة المحدّثة والشريط الجاري بلا overflow على 320dp', (
    WidgetTester w,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await CacheService.instance.clearAll();
    await CacheService.instance.setRawList('vn_options_v2', [
      {
        'code': 'telegram',
        'name': 'Telegram',
        'nameAr': 'تيليجرام',
        'nameEn': 'Telegram',
        'icon': 'assets/icons/telegram.png',
        'fromPrice': 0.50,
        'countries': [
          {'code': '20', 'name': 'مصر', 'cost': 0.4, 'salePrice': 0.5, 'count': 5},
        ],
      },
    ]);
    await CacheService.instance.setRawList('vn_manual_services', [
      {
        'id': 'ms1',
        'name': 'تفعيل واتساب يدوي',
        'price': 2.50,
        'requiredFields': const ['رقم الهاتف'],
        'estimatedMinutes': 60,
        'appName': 'WhatsApp',
        'appIcon': 'assets/icons/whatsapp.png',
        'isSensitive': true,
      },
    ]);
    await CacheService.instance.set('vn_my_requests', [
      {
        'id': 'req1',
        'requestNumber': 'VN-1001',
        'service': 'telegram',
        'serviceName': 'تيليجرام',
        'country': '20',
        'countryName': 'مصر',
        'operator': '',
        'amount': 0.50,
        'phoneNumber': '201000000000',
        'smsCode': '49120',
        'status': 'code_received',
        'isLive': true,
        'note': '',
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      },
    ]);

    w.view.physicalSize = const Size(320, 1200);
    w.view.devicePixelRatio = 1.0;
    addTearDown(w.view.resetPhysicalSize);
    addTearDown(w.view.resetDevicePixelRatio);

    await w.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider()),
          ChangeNotifierProvider<VirtualNumbersProvider>(
            create: (_) => VirtualNumbersProvider(),
          ),
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<AppCatalogProvider>(
            create: (_) => AppCatalogProvider(),
          ),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: VirtualNumbersScreen(showAppBar: false),
          ),
        ),
      ),
    );
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(ServiceTicketCard), findsOneWidget);
    expect(find.textContaining('الرمز: 49120'), findsOneWidget);

    await w.tap(find.text('التفعيلات اليدوية'));
    await w.pump();
    expect(find.text('تفعيل واتساب يدوي'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

    _expectNoOverflow(w);

    await w.pumpWidget(const SizedBox());
    await w.pump(const Duration(milliseconds: 400));
  });

  testWidgets('تبويب خدمات يعرض كروت التذاكر بالشبكة الثلاثية المحدّثة', (
    WidgetTester w,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await CacheService.instance.clearAll();
    await CacheService.instance.set('catalog_apps', [
      {
        'id': 's1',
        'name': 'شاهد VIP',
        'appType': 'subscription',
        'iconUrl': 'assets/icons/shahid.png',
        'description': 'اشتراك شهري',
        'isActive': true,
        'sortOrder': 0,
      },
      {
        'id': 's2',
        'name': 'تصميم شعار',
        'appType': 'service',
        'iconUrl': 'assets/cards/canva.png',
        'description': 'تنفيذ يدوي سريع',
        'isActive': true,
        'sortOrder': 1,
      },
    ]);

    w.view.physicalSize = const Size(390, 1200);
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
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: UserMainScreen(),
          ),
        ),
      ),
    );
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    await w.tap(find.text('خدمات'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 200));

    expect(find.byType(ServiceTicketCard), findsNWidgets(2));
    expect(find.text('شاهد VIP'), findsOneWidget);
    expect(find.text('تصميم شعار'), findsOneWidget);
    expect(find.text('باقات متعددة'), findsNWidgets(2));

    _expectNoOverflow(w);

    await w.pumpWidget(const SizedBox());
    await w.pump(const Duration(milliseconds: 400));
  });
}
