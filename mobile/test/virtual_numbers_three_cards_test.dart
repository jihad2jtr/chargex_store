// صفحة «الأرقام»: شبكة واحدة وثلاثة كروت في الصف تجمع التفعيل المضمون
// (اليدوي) وشراء الأرقام (تلقائي)، والفرق شارة على زاوية كل كرت. الشبكة محظورة
// فالكتالوج يُزرع في CacheService كما يفعل المزود بعد أول نجاح.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/services/cache_service.dart';
import 'package:layan_chargex/providers/app_catalog_provider.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/providers/wallet_provider.dart';
import 'package:layan_chargex/screens/user/virtual_numbers_screen.dart';
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

Map<String, dynamic> _service(int n) => <String, dynamic>{
  'code': 'svc$n',
  'name': 'Service $n',
  'nameAr': '',
  'nameEn': 'Service $n',
  // رمز مُخزّن كمسار أصل كما يفعل الأدمن في «قاموس التطبيقات»
  'icon': 'assets/icons/telegram.png',
  'fromPrice': 0.5 + n,
  'countries': <Map<String, dynamic>>[
    <String, dynamic>{
      'code': '${20 + n}',
      'name': 'دولة $n',
      'cost': 0.4,
      'salePrice': 0.5 + n,
      'count': 10,
      'operators': const <Map<String, dynamic>>[],
    },
  ],
};

Map<String, dynamic> _manual(int n) => <String, dynamic>{
  'id': 'ms$n',
  'name': 'خدمة يدوية $n',
  'price': 1.5 * n,
  'requiredFields': const ['رقم الهاتف'],
  'estimatedMinutes': 60,
  'appName': 'Telegram',
  'appIcon': 'assets/icons/whatsapp.png',
};

Future<void> _pumpPage(
  WidgetTester w, {
  required List<Map<String, dynamic>> options,
  required List<Map<String, dynamic>> manual,
  double width = 380,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await CacheService.instance.clearAll();
  await CacheService.instance.setRawList('vn_options_v2', options);
  await CacheService.instance.setRawList('vn_manual_services', manual);

  w.view.physicalSize = Size(width, 1400);
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
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const VirtualNumbersScreen(showAppBar: false),
        ),
      ),
    ),
  );
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
}

/// الشبكة الوحيدة في الصفحة: عدد أعمدتها، وإلا فالقسمين لم يدمجا بعد
int _gridColumns(WidgetTester w) {
  final List<GridView> grids = w
      .widgetList<GridView>(find.byType(GridView))
      .toList();
  expect(grids, hasLength(1), reason: 'شبكة واحدة للخدمات كلها');
  final SliverGridDelegateWithFixedCrossAxisCount delegate =
      grids.single.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  return delegate.crossAxisCount;
}

/// الأقرب إلى بداية الصف (RTL: اليمين) يسبق غيره في ترتيب الكروت
double _startEdge(WidgetTester w, String label) =>
    w.getTopRight(find.text(label)).dx;

/// غلاف التذكرة (فتحتان على الحافتين) — كل خانة كرت تذكرة
final Finder _ticketClips = find.byWidgetPredicate(
  (widget) => widget is ClipPath && widget.clipper is TicketPassClipper,
);

/// صورة تملأ الكرت (BoxFit.cover)
final Finder _coverImages = find.byWidgetPredicate(
  (widget) => widget is Image && widget.fit == BoxFit.cover,
);

Finder _gridTickets() =>
    find.descendant(of: find.byType(GridView), matching: _ticketClips);

/// لا فيض طباعة في الصفحة؛ استثناءات خط google_fonts (بلا شبكة) متوقعة
void _expectNoOverflow(WidgetTester w) {
  Object? error;
  final List<String> overflow = <String>[];
  while ((error = w.takeException()) != null) {
    final String text = error.toString();
    if (text.contains('overflow') || text.contains('OVERFLOW')) {
      overflow.add(text);
    }
  }
  expect(overflow, isEmpty);
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets(
    'زران للتبديل بين التلقائي واليدوي مع شرح لكل نوع وثلاثة كروت في الصف',
    (WidgetTester w) async {
      await _pumpPage(
        w,
        options: <Map<String, dynamic>>[
          _service(1),
          _service(2),
          _service(3),
          _service(4),
        ],
        manual: <Map<String, dynamic>>[_manual(1), _manual(2)],
      );

      // زران للتبديل
      expect(find.text('الخدمات التلقائية'), findsOneWidget);
      expect(find.text('الخدمات اليدوية'), findsOneWidget);

      // شاشة التلقائي أولاً: 4 كروت بتنسيق 3 كروت في الصف
      expect(_gridColumns(w), 3);
      expect(find.text('الخدمات التلقائية (أرقام فورية)'), findsOneWidget);
      expect(find.text('تلقائي'), findsNWidgets(4));
      expect(find.text('1 دولة'), findsNWidgets(4));
      expect(find.text('من \$1.50'), findsOneWidget);

      // التبديل إلى اليدوي
      await w.tap(find.text('الخدمات اليدوية'));
      await w.pump();

      // شرح اليدوي وكروته
      expect(find.text('الخدمات اليدوية (تفعيل مضمون)'), findsOneWidget);
      expect(find.text('يدوي مضمون'), findsNWidgets(2));
      expect(_gridColumns(w), 3);
      expect(find.text('\$1.50'), findsOneWidget);
    },
  );

  testWidgets('ترتيب الكروت في كل تبويب يبدأ من البداية', (
    WidgetTester w,
  ) async {
    await _pumpPage(
      w,
      options: <Map<String, dynamic>>[_service(1), _service(2)],
      manual: <Map<String, dynamic>>[_manual(1)],
    );

    // التلقائي أولاً
    expect(_startEdge(w, 'Service 1'), greaterThan(_startEdge(w, 'Service 2')));

    // التبديل إلى اليدوي
    await w.tap(find.text('الخدمات اليدوية'));
    await w.pump();
    expect(find.text('خدمة يدوية 1'), findsOneWidget);
  });

  testWidgets('كروت تذكرة: غلاف بفتحتين وصورة تملأ الكرت', (
    WidgetTester w,
  ) async {
    await _pumpPage(
      w,
      options: <Map<String, dynamic>>[_service(1), _service(2)],
      manual: <Map<String, dynamic>>[_manual(1)],
    );

    // كل خانة غلاف تذكرة بفتحتين على الحافتين، لا بطاقة مسطّحة ولا أيقونة عارية
    expect(_gridTickets(), findsNWidgets(2));

    double? cardWidth;
    double? cardHeight;
    for (int i = 0; i < 2; i++) {
      final Rect card = w.getRect(_gridTickets().at(i));
      // الصورة تملأ التذكرة: لا مربّع أيقونة صغير ولا بياض تحت النص
      final Rect image = w.getRect(
        find.descendant(of: _gridTickets().at(i), matching: _coverImages).first,
      );
      expect(image.width, greaterThanOrEqualTo(card.width));
      expect(image.height, greaterThanOrEqualTo(card.height));
      // الكرت أطول من عرضه: صورة + سطر اسم + سطر سعر أو دول
      expect(card.height, greaterThan(card.width));
      // والكروت متساوية القياس (كسر البكسل في قسمة العرض لا يُعَدّ فرقاً)
      cardWidth ??= card.width;
      cardHeight ??= card.height;
      expect(card.width, closeTo(cardWidth, 0.5));
      expect(card.height, closeTo(cardHeight, 0.5));
    }

    _expectNoOverflow(w);
  });

  testWidgets('تبويبا الكرت: شريط اسم فوق شريط سعر وفتحتان على خطّهما', (
    WidgetTester w,
  ) async {
    await _pumpPage(
      w,
      options: <Map<String, dynamic>>[_service(1), _service(2)],
      manual: <Map<String, dynamic>>[_manual(1)],
    );

    const List<String> labels = <String>['Service 1', 'Service 2'];
    const List<String> prices = <String>['من \$1.50', 'من \$2.50'];

    for (int i = 0; i < 2; i++) {
      final Finder ticket = _gridTickets().at(i);
      final Rect card = w.getRect(ticket);
      final Finder tabs = find.descendant(
        of: ticket,
        matching: find.byType(PositionedDirectional),
      );
      final Rect nameTab = w.getRect(tabs.at(0));
      final Rect priceTab = w.getRect(tabs.at(1));
      expect(priceTab.bottom, closeTo(card.bottom, 23.0));
      expect(nameTab.bottom, closeTo(priceTab.top, 0.5));
      expect(nameTab.width, closeTo(card.width, 0.5));
      expect(priceTab.width, closeTo(card.width, 0.5));
      expect(nameTab.height + priceTab.height, lessThan(card.height * 0.4));
      expect(nameTab.contains(w.getRect(find.text(labels[i])).center), isTrue);
      expect(
        priceTab.contains(w.getRect(find.text(prices[i])).center),
        isTrue,
        reason: 'سعر ${labels[i]} في تبويبه',
      );
    }

    // سعر كتالوج المزود
    expect(find.text('من \$1.50'), findsOneWidget);

    _expectNoOverflow(w);
  });

  testWidgets('كروت الشبكة والتبديل لا تفيض على شاشة ضيّقة (320dp)', (
    WidgetTester w,
  ) async {
    await _pumpPage(
      w,
      width: 320,
      options: <Map<String, dynamic>>[_service(1), _service(2), _service(3)],
      manual: <Map<String, dynamic>>[_manual(1), _manual(2), _manual(3)],
    );

    expect(_gridColumns(w), 3);
    expect(find.text('تلقائي'), findsNWidgets(3));

    // التبديل إلى اليدوي
    await w.tap(find.text('الخدمات اليدوية'));
    await w.pump();

    expect(_gridColumns(w), 3);
    expect(find.text('يدوي مضمون'), findsNWidgets(3));

    _expectNoOverflow(w);
  });
}
