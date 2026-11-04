// صفحة «تفعيل الأرقام الوهمية» التي حلّت محل صفحة شحن الاشتراكات.
// الشبكة محظورة في الاختبار، لذلك يُزرع الكتالوج والسجل في CacheService قبل بناء
// الصفحة (وهذا مسار_PROVIDER_ الحقيقي بعد أول نجاح)، ثم تُفحص الحالات الأربع:
// شبكة الخدمات، رقم حيّ بانتظار الرمز، رمز وصل، وسجل مُرجَع بلا إعادة تنبيه.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/services/cache_service.dart';
import 'package:layan_chargex/core/theme/app_colors.dart';
import 'package:layan_chargex/providers/app_catalog_provider.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/providers/wallet_provider.dart';
import 'package:layan_chargex/screens/user/virtual_number_wait_screen.dart';
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

/// محفظة غنية: يسمح ببلوغ نافذة التأكيد بدل حوار «رصيد غير كافٍ»
class _RichWallet extends WalletProvider {
  @override
  double get balance => 10;

  @override
  Future<void> fetchBalance() async {}
}

// ---------------------------------------------------------------------------
// بذور الكتالوج والسجل (نفس ما يخزنه المزود بعد GET /virtual-numbers/options)
// ---------------------------------------------------------------------------

Map<String, dynamic> _country({
  required String code,
  required String name,
  required double salePrice,
  int count = 12,
  List<Map<String, dynamic>> operators = const [],
}) => {
  'code': code,
  'name': name,
  'cost': double.parse((salePrice / 1.25).toStringAsFixed(2)),
  'salePrice': salePrice,
  'count': count,
  'operators': operators,
};

Map<String, dynamic> _service({
  required String code,
  required String name,
  required List<Map<String, dynamic>> countries,
  String nameAr = '',
  String nameEn = '',
  String icon = '',
}) => {
  'code': code,
  'name': name,
  'nameAr': nameAr,
  'nameEn': nameEn,
  // الرمز المُخزّن كما في القاموس: مسار أصل يملأ كرت التذكرة
  'icon': icon,
  'fromPrice': countries
      .map((c) => c['salePrice'] as double)
      .reduce((a, b) => a < b ? a : b),
  'countries': countries,
};

final List<Map<String, dynamic>> _catalog = <Map<String, dynamic>>[
  _service(
    code: 'telegram',
    name: 'Telegram',
    icon: 'assets/icons/telegram.png',
    countries: <Map<String, dynamic>>[
      _country(code: '20', name: 'مصر', salePrice: 0.50),
      _country(
        code: '1',
        name: 'كندا',
        salePrice: 1.00,
        count: 40,
        operators: const [
          {'code': 'any', 'name': 'Any'},
        ],
      ),
    ],
  ),
  _service(
    code: 'whatsapp',
    name: 'WhatsApp',
    icon: 'assets/icons/whatsapp.png',
    // كما في الخادم الحيّ: اسم معروض لاتيني + nameAr عربي + nameEn أجنبي
    nameAr: 'واتساب',
    nameEn: 'Whatsapp',
    countries: <Map<String, dynamic>>[
      _country(code: '91', name: 'الهند', salePrice: 0.60),
    ],
  ),
];

/// بذرة خدمة يدوية («تفعيل مضمون») كما يرسلها الخادم في `manualServices`
Map<String, dynamic> _manualService({
  String id = 'ms1',
  String name = 'تفعيل تيليجرام يدوي',
  double price = 2.50,
  List<String> requiredFields = const ['رقم الهاتف'],
  bool isSensitive = false,
  String appIcon = 'assets/icons/telegram.png',
}) => {
  'id': id,
  'name': name,
  'price': price,
  'requiredFields': requiredFields,
  'estimatedMinutes': 90,
  'appName': 'Telegram',
  'appIcon': appIcon,
  'isSensitive': isSensitive,
};

Map<String, dynamic> _request({
  required String id,
  required String status,
  required bool isLive,
  String phoneNumber = '2015550007777',
  String? smsCode,
  String? smsText,
  double amount = 0.50,
  String note = '',
  Duration? expiresIn,
  DateTime? refundedAt,
}) => {
  'id': id,
  'requestNumber': 'VN-2610-$id',
  'service': 'telegram',
  'serviceName': 'Telegram',
  'country': '20',
  'countryName': 'مصر',
  'operator': '',
  'amount': amount,
  'phoneNumber': phoneNumber.isEmpty ? null : phoneNumber,
  'smsCode': smsCode,
  'smsText': smsText,
  'status': status,
  'isLive': isLive,
  'note': note,
  'expiresAt': expiresIn == null
      ? null
      : DateTime.now().add(expiresIn).toIso8601String(),
  'codeReceivedAt': smsCode == null
      ? null
      : DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
  'refundedAt': refundedAt?.toIso8601String(),
  'createdAt': DateTime.now()
      .subtract(const Duration(minutes: 2))
      .toIso8601String(),
};

Future<void> _pumpPage(
  WidgetTester w, {
  List<Map<String, dynamic>> options = const [],
  List<Map<String, dynamic>> manual = const [],
  List<Map<String, dynamic>> requests = const [],
  bool richWallet = false,
  double width = 380,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await CacheService.instance.clearAll();
  if (options.isNotEmpty) {
    // نسخة المفتاح v2: المزود يخزّن العروض مع الدولة، والمخزّن القديم كان
    // يعرض سيرفرات بلا معرّف منتج فلا يمكن شراء رقم منها
    await CacheService.instance.setRawList('vn_options_v2', options);
  }
  if (manual.isNotEmpty) {
    await CacheService.instance.setRawList('vn_manual_services', manual);
  }
  if (requests.isNotEmpty) {
    await CacheService.instance.set('vn_my_requests', requests);
  }

  w.view.physicalSize = Size(width, 1200);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>(
          create: (_) => richWallet ? _RichWallet() : WalletProvider(),
        ),
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => VirtualNumbersProvider(),
        ),
        // قسم «تفعيل مضمون» يرسل طلبه عبر /orders نفسه (AppCatalogProvider)
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

/// يفك شجرة الأرقام فيُلغى المؤقّت وجولة الفحص الدوري (لا مؤقتات معلّقة)
Future<void> _teardown(WidgetTester w) async {
  await w.pumpWidget(const SizedBox());
  await w.pump(const Duration(milliseconds: 400));
}

/// فيض الطباعة عيب، أما استثناءات خط google_fonts (بلا شبكة) فمتوقعة
void _expectNoOverflow(WidgetTester w) {
  final List<String> overflow = <String>[];
  Object? error;
  while ((error = w.takeException()) != null) {
    final String text = error.toString();
    if (text.contains('overflow') || text.contains('OVERFLOW')) {
      overflow.add(text);
    }
  }
  expect(overflow, isEmpty);
}

Future<void> _openSheet(WidgetTester w, String service) async {
  await w.tap(find.text(service).first);
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
}

/// غلاف التذكرة (فتحات التثقيب على الحافتين) — هوية بطاقات التطبيق
Finder _ticketClips() => find.byWidgetPredicate(
  (widget) => widget is ClipPath && widget.clipper is TicketPassClipper,
);

/// مربّع شارة النوع: خلفية ملونة وطفلها نص الوسم وحده
final Finder _tagBoxFinder = find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      (widget.decoration! as BoxDecoration).color != null &&
      widget.child is Text,
);

/// عدد خطوط «DashedLinePainter» الأفقية داخل عنصر بعينه (خط التمزّق)
int _horizontalTears(WidgetTester w, Finder within) {
  return w
      .widgetList<CustomPaint>(
        find.descendant(of: within, matching: find.byType(CustomPaint)),
      )
      .where((p) => p.painter is DashedLinePainter)
      .length;
}

/// صورة تملأ الكرت (BoxFit.cover) — الطلب: الصورة تملأ التذكرة
final Finder _coverImages = find.byWidgetPredicate(
  (widget) => widget is Image && widget.fit == BoxFit.cover,
);

/// ترتيب كروت الشبكة: الأول هو الأقرب إلى جهة البداية (RTL: اليمين)،
/// وحين يختلف الصف فالأعلى أولاً
// ignore: unused_element
bool _comesBefore(WidgetTester w, Finder a, Finder b) {
  final TextDirection dir = Directionality.of(
    w.element(find.byType(GridView).first),
  );
  final double aY = w.getTopLeft(a).dy;
  final double bY = w.getTopLeft(b).dy;
  if ((aY - bY).abs() > 8) return aY < bY;
  final double aStart = dir == TextDirection.rtl
      ? w.getTopRight(a).dx
      : w.getTopLeft(a).dx;
  final double bStart = dir == TextDirection.rtl
      ? w.getTopRight(b).dx
      : w.getTopLeft(b).dx;
  return dir == TextDirection.rtl ? aStart > bStart : aStart < bStart;
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('الصفحة تعرض شبكة الخدمات بدل شحن الاشتراكات', (
    WidgetTester w,
  ) async {
    await _pumpPage(w, options: _catalog);

    expect(find.text('اختر الخدمة'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    // الاسم العربي هو الظاهر، و«WhatsApp» اللاتينية لا تُكرر سطرًا ثانيًا
    expect(find.text('واتساب'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
    // كرت الخدمة يذكر دوله في سطر، وسعره في تبويب أسفل الكرت وحده
    expect(find.text('2 دولة'), findsOneWidget);
    expect(find.text('من \$0.50'), findsOneWidget);
    // الكارت التعريفي العلوي أُزيل: الصفحة تبدأ بالشبكة مباشرة
    expect(find.text('تفعيل الأرقام الوهمية'), findsNothing);
    expect(
      find.text('رقم يُستخدم مرة واحدة لاستلام رموز التحقق'),
      findsNothing,
    );
    expect(find.textContaining('مهلة الانتظار'), findsNothing);
    expect(find.text('لا توجد أرقام متاحة'), findsNothing);

    _expectNoOverflow(w);
  });

  testWidgets('التبديل بين الخدمات التلقائية واليدوية مع شرح لكل نوع وإزالة شريط البحث', (
    WidgetTester w,
  ) async {
    await _pumpPage(w, options: _catalog, manual: [_manualService()]);

    // إزالة شريط البحث
    expect(find.byType(TextField), findsNothing);

    // زرّان للتبديل بين الخدمات التلقائية واليدوية
    expect(find.text('الخدمات التلقائية'), findsOneWidget);
    expect(find.text('الخدمات اليدوية'), findsOneWidget);

    // شرح النوع التلقائي ظاهر
    expect(find.text('الخدمات التلقائية (أرقام فورية)'), findsOneWidget);
    expect(find.text('تلقائي'), findsNWidgets(2));
    expect(find.text('1 دولة'), findsOneWidget);
    expect(find.text('من \$0.60'), findsOneWidget);

    // التبديل إلى الخدمات اليدوية
    await w.tap(find.text('الخدمات اليدوية'));
    await w.pump();

    // شرح النوع اليدوي
    expect(find.text('الخدمات اليدوية (تفعيل مضمون)'), findsOneWidget);
    expect(find.text('تفعيل تيليجرام يدوي'), findsOneWidget);
    expect(find.text('\$2.50'), findsOneWidget);
    expect(find.text('يدوي مضمون'), findsOneWidget);

    // الخدمة غير السرية لا قفل على كرتّها
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);

    // النقر على الكرت يفتح نافذة طلب الخدمة اليدوية بحقولها المطلوبة
    await w.tap(find.text('تفعيل تيليجرام يدوي'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('رقم الهاتف'), findsOneWidget);
    // الرصيد صفر: زر التأكيد محجوب ويطلب الشحن أولاً
    expect(find.text('رصيد غير كافٍ (\$2.50)'), findsOneWidget);
    final confirmButton = w.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'رصيد غير كافٍ (\$2.50)'),
    );
    expect(confirmButton.onPressed, isNull);

    _expectNoOverflow(w);
  });

  testWidgets('بلا شريط علوي: لا عدّات خدمات ولا دول ولا مهلة', (
    WidgetTester w,
  ) async {
    await _pumpPage(w, options: _catalog, manual: [_manualService()]);

    // الشريط الذي كان يعرض (خدمة متاحة / دولة / دقيقة مهلة) أُلغي
    expect(find.text('خدمة متاحة'), findsNothing);
    expect(find.text('دقيقة مهلة'), findsNothing);
    expect(find.text('دولة'), findsNothing);
    // عنوان الشبكة والزرّان
    expect(find.text('اختر الخدمة'), findsOneWidget);
    expect(find.text('الخدمات التلقائية'), findsOneWidget);
    expect(find.text('الخدمات اليدوية'), findsOneWidget);

    _expectNoOverflow(w);
  });

  testWidgets('كروت تذكرة صورتها تملؤها والفرق في شارة الزاوية', (
    WidgetTester w,
  ) async {
    await _pumpPage(w, options: _catalog, manual: [_manualService()]);

    // في التبويب التلقائي: كرتان
    expect(_ticketClips(), findsNWidgets(2));
    expect(_coverImages, findsNWidgets(2));
    expect(_horizontalTears(w, find.byType(GridView)), 0);

    BoxDecoration tagBox(String label) =>
        w
                .widget<Container>(
                  find
                      .ancestor(of: find.text(label), matching: _tagBoxFinder)
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(tagBox('تلقائي').color, AppColors.ticketAmber);
    expect(
      find.ancestor(
        of: find.text('تلقائي').first,
        matching: find.byType(PositionedDirectional),
      ),
      findsOneWidget,
    );

    // التبديل إلى التبويب اليدوي
    await w.tap(find.text('الخدمات اليدوية'));
    await w.pump();

    expect(_ticketClips(), findsNWidgets(1));
    final Text manualTag = w.widget<Text>(find.text('يدوي مضمون'));
    expect(manualTag.style?.color, Colors.white);
    expect(manualTag.maxLines, 1);
    expect(tagBox('يدوي مضمون').color, AppColors.emerald);
    expect(
      w.widget<Text>(find.text('تفعيل تيليجرام يدوي')).style?.color,
      Colors.white,
    );
    expect(
      w.widget<Text>(find.text('\$2.50')).style?.color,
      AppColors.ticketAmber,
    );
    expect(
      find.ancestor(
        of: find.text('يدوي مضمون'),
        matching: find.byType(PositionedDirectional),
      ),
      findsOneWidget,
    );

    _expectNoOverflow(w);
  });

  testWidgets('خدمة يدوية ببيانات سرية: قفل في زاوية الكرت', (
    WidgetTester w,
  ) async {
    await _pumpPage(
      w,
      options: _catalog,
      manual: [_manualService(isSensitive: true)],
    );

    // التبديل إلى التبويب اليدوي
    await w.tap(find.text('الخدمات اليدوية'));
    await w.pump();

    // التحذير رمزاً في الزاوية
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.text('يدوي مضمون'), findsOneWidget);

    _expectNoOverflow(w);
  });

  testWidgets('اسم التطبيق بالعربي وتحته الأجنبي في شبكة الأرقام', (
    WidgetTester w,
  ) async {
    await _pumpPage(w, options: _catalog);

    // «واتساب» عربي سطر أول و«Whatsapp» أجنبي سطر ثانٍ تحته
    expect(find.text('واتساب'), findsOneWidget);
    expect(find.text('Whatsapp'), findsOneWidget);
    // السطر الأجنبي يأخذ nameEn ولا يكرر الاسم المعروض
    expect(find.text('WhatsApp'), findsNothing);
    final Text foreign = w.widget<Text>(find.text('Whatsapp'));
    expect(foreign.textDirection, TextDirection.ltr);
    // الاسم اللاتيني الصريح لا يُكرَّر في سطر أجنبي ثانٍ
    expect(find.text('Telegram'), findsOneWidget);

    _expectNoOverflow(w);
  });

  testWidgets('بلا كتالوج تُعرض حالة فراغ مع زر إعادة الجلب', (
    WidgetTester w,
  ) async {
    await _pumpPage(w);

    expect(find.text('لا توجد أرقام متاحة'), findsOneWidget);
    expect(find.text('إعادة جلب القائمة'), findsOneWidget);
    expect(find.text('اختر الخدمة'), findsOneWidget);

    _expectNoOverflow(w);
  });

  testWidgets('الرقم الحيّ شريط مختصر والكتالوج يبقى متاحاً للشراء التالي', (
    WidgetTester w,
  ) async {
    await _pumpPage(
      w,
      options: _catalog,
      requests: <Map<String, dynamic>>[
        _request(
          id: 'live',
          status: 'waiting',
          isLive: true,
          expiresIn: const Duration(minutes: 5),
        ),
      ],
    );

    expect(find.text('أرقامك الجارية'), findsOneWidget);
    expect(find.text('1 LIVE'), findsOneWidget);
    expect(find.text('2015550007777'), findsOneWidget);
    expect(find.text('بانتظار الرمز'), findsOneWidget);
    // لم تعد الصفحة تحتكر الرقم: شبكة الخدمات تبقى تحت الشريط الجاري
    expect(find.text('اختر الخدمة'), findsOneWidget);
    // الإلغاء لم يعد في صفحة الأرقام: لكل رقم صفحة انتظاره الخاصة
    expect(find.text('إلغاء واسترجاع'), findsNothing);
    expect(find.text('تم — إغلاق'), findsNothing);

    _expectNoOverflow(w);
    await _teardown(w);
  });

  testWidgets('الضغط على شريط الرقم الحيّ يفتح صفحة انتظاره المستقلة', (
    WidgetTester w,
  ) async {
    await _pumpPage(
      w,
      options: _catalog,
      requests: <Map<String, dynamic>>[
        _request(
          id: 'live',
          status: 'waiting',
          isLive: true,
          expiresIn: const Duration(minutes: 5),
        ),
      ],
    );

    await w.tap(find.text('بانتظار الرمز'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(VirtualNumberWaitScreen), findsOneWidget);
    expect(find.text('انتظار الرمز'), findsOneWidget);
    expect(find.text('متبقٍ'), findsOneWidget);
    expect(find.text('كيف يعمل؟'), findsOneWidget);
    // بذرة بلا cancelAfterAt (خادم قديم): الإلغاء مسموح فوراً كما كان
    expect(find.textContaining('إلغاء الرقم واسترجاع'), findsOneWidget);

    _expectNoOverflow(w);
    await _teardown(w);
  });

  testWidgets('وصول الرمز ينعكس في الشريط، وصفحة الانتظار تعرضه لنسخه', (
    WidgetTester w,
  ) async {
    await _pumpPage(
      w,
      options: _catalog,
      requests: <Map<String, dynamic>>[
        _request(
          id: 'coded',
          status: 'received',
          isLive: true,
          smsCode: '481920',
          smsText: 'Telegram code: 481920',
          expiresIn: const Duration(minutes: 3),
        ),
      ],
    );

    // الشريط المختصر يحمل الرمز بدل لوحة الانتظار القديمة
    expect(find.text('الرمز: 481920'), findsOneWidget);
    expect(find.text('اضغط للرمز'), findsOneWidget);
    expect(find.text('بانتظار وصول رسالة التحقق…'), findsNothing);
    expect(find.text('اختر الخدمة'), findsOneWidget);

    await w.tap(find.text('اضغط للرمز'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(VirtualNumberWaitScreen), findsOneWidget);
    expect(find.widgetWithText(SelectableText, '481920'), findsOneWidget);
    expect(find.text('نافذة العرض'), findsOneWidget);
    expect(find.text('تم — إغلاق الرقم'), findsOneWidget);

    _expectNoOverflow(w);
    await _teardown(w);
  });

  testWidgets('سجل مُرجَع سابقاً لا يعيد تنبيه الإرجاع عند فتح الصفحة', (
    WidgetTester w,
  ) async {
    await _pumpPage(
      w,
      options: _catalog,
      requests: <Map<String, dynamic>>[
        _request(
          id: 'old',
          status: 'expired',
          isLive: false,
          phoneNumber: '2015550009999',
          refundedAt: DateTime.now().subtract(const Duration(minutes: 1)),
          note: 'انتهت مهلة الانتظار بدون رمز',
        ),
      ],
    );

    // سجل الأرقام لم يعد منعزلاً هنا: الرقم المنتهي لا يعيد تنبيه الإرجاع،
    // والسجل انتقل إلى «طلباتي» فلا تظهر بطاقاته في صفحة الأرقام
    expect(find.text('سجل الأرقام'), findsNothing);
    expect(find.text('انتهت المهلة'), findsNothing);
    expect(find.textContaining('أُرجع المبلغ إلى محفظتك'), findsNothing);
    expect(find.text('اختر الخدمة'), findsOneWidget);

    _expectNoOverflow(w);
  });

  testWidgets('الرصيد غير الكافي يوقف التفعيل ويحوّل إلى الشحن', (
    WidgetTester w,
  ) async {
    await _pumpPage(w, options: _catalog);
    await _openSheet(w, 'Telegram');

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('أرقام Telegram'), findsOneWidget);
    expect(find.text('رصيدك \$0.00'), findsOneWidget);
    expect(find.text('تفعيل الرقم \$0.50'), findsOneWidget);

    await w.tap(find.text('تفعيل الرقم \$0.50'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.text('رصيد غير كافٍ'), findsOneWidget);
    expect(
      find.text('السعر \$0.50 ورصيدك \$0.00. اشحن رصيدك ثم أعد المحاولة.'),
      findsOneWidget,
    );
    expect(find.text('الذهاب للشحن'), findsOneWidget);
    // لم يُطلب أي رقم: تبقى شبكة الخدمات تحت النافذة
    expect(find.text('اختر الخدمة'), findsOneWidget);

    _expectNoOverflow(w);
  });

  testWidgets('باختصار كافٍ تُعرض نافذة تأكيد الخصم قبل الطلب', (
    WidgetTester w,
  ) async {
    await _pumpPage(w, options: _catalog, richWallet: true);
    await _openSheet(w, 'Telegram');

    await w.tap(find.text('تفعيل الرقم \$0.50'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.text('رصيد غير كافٍ'), findsNothing);
    expect(find.text('تفعيل رقم Telegram'), findsOneWidget);
    expect(find.textContaining('يُخصم من رصيدك'), findsOneWidget);
    // محتوى الحوار نص واحد بأسطر: الدولة/السيرفر/السعر — فاختيار المشغّل
    // صار صفة المنتج نفسه لا شريحة مستقلة داخل السيرفر
    expect(find.textContaining('السيرفر:'), findsOneWidget);
    expect(find.textContaining('الدولة: مصر'), findsOneWidget);
    expect(find.text('تفعيل الرقم'), findsOneWidget);

    _expectNoOverflow(w);
  });

  testWidgets(
    'اختيار دولة أخرى يبدّل السعر في زر التفعيل (بلا عرض عدد الأرقام)',
    (WidgetTester w) async {
      await _pumpPage(w, options: _catalog, richWallet: true);
      await _openSheet(w, 'Telegram');

      expect(find.text('تفعيل الرقم \$0.50'), findsOneWidget);

      await w.tap(find.text('كندا'));
      await w.pump();
      await w.pump(const Duration(milliseconds: 250));

      expect(find.text('تفعيل الرقم \$1.00'), findsOneWidget);
      // وقت التشغيل لا يعرض عدد الأرقام المتاحة للعميل بعد إلغاء الكتالوج الحيّ
      expect(find.textContaining('متاح 40 رقم'), findsNothing);

      _expectNoOverflow(w);
    },
  );

  testWidgets('خدمة يدوية بلا حقول: نافذة الشراء لا تطلب «المعرف» ولا أي حقل', (
    WidgetTester w,
  ) async {
    await _pumpPage(
      w,
      options: _catalog,
      manual: [_manualService(requiredFields: const [])],
      richWallet: true,
    );
    await w.tap(find.text('الخدمات اليدوية'));
    await w.pump();
    await _openSheet(w, 'تفعيل تيليجرام يدوي');

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    // إدارة الخدمة لم تُعرّف حقولاً: لا حقل إدخال داخل النافذة إطلاقاً،
    // فإجبار «المعرف» كان يُلزم العميل ببيانات لا تحتاجها الخدمة
    expect(
      find.descendant(of: sheet, matching: find.byType(TextField)),
      findsNothing,
    );
    expect(find.text('المعرف'), findsNothing);
    // تُستبدل الحقول بعبارة طمأنة واحدة، ويظل زر التأكيد هو خطوة الطلب
    expect(
      find.textContaining('لا تحتاج هذه الخدمة أي بيانات'),
      findsOneWidget,
    );
    expect(
      w
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'تأكيد الطلب (\$2.50)'),
          )
          .onPressed,
      isNotNull,
    );

    _expectNoOverflow(w);
    await _teardown(w);
  });
}
