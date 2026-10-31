// صفحة «تفعيل الأرقام الوهمية» التي حلّت محل صفحة شحن الاشتراكات.
// الشبكة محظورة في الاختبار، لذلك يُزرع الكتالوج والسجل في CacheService قبل بناء
// الصفحة (وهذا مسار_PROVIDER_ الحقيقي بعد أول نجاح)، ثم تُفحص الحالات الأربع:
// شبكة الخدمات، رقم حيّ بانتظار الرمز، رمز وصل، وسجل مُرجَع بلا إعادة تنبيه.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/services/cache_service.dart';
import 'package:layan_chargex/providers/app_catalog_provider.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/providers/wallet_provider.dart';
import 'package:layan_chargex/screens/user/virtual_numbers_screen.dart';
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
}) => {
  'code': code,
  'name': name,
  'fromPrice': countries
      .map((c) => c['salePrice'] as double)
      .reduce((a, b) => a < b ? a : b),
  'countries': countries,
};

final List<Map<String, dynamic>> _catalog = <Map<String, dynamic>>[
  _service(
    code: 'telegram',
    name: 'Telegram',
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
}) => {
  'id': id,
  'name': name,
  'price': price,
  'requiredFields': requiredFields,
  'estimatedMinutes': 90,
  'appName': 'Telegram',
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

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('الصفحة تعرض شبكة الخدمات بدل شحن الاشتراكات', (
    WidgetTester w,
  ) async {
    await _pumpPage(w, options: _catalog);

    expect(find.text('اختر الخدمة'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    // بطاقة الخدمة تذكر عدد الدول وأرخص سعر
    expect(find.textContaining('دولة • من \$0.50'), findsOneWidget);
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

  testWidgets('قسم تفعيل مضمون يسبق شبكة الأيقونات الكبيرة', (
    WidgetTester w,
  ) async {
    await _pumpPage(w, options: _catalog, manual: [_manualService()]);

    // القسم الأول: كروت الخدمات اليدوية
    expect(find.text('تفعيل مضمون'), findsOneWidget);
    expect(find.text('تفعيل تيليجرام يدوي'), findsOneWidget);
    // شارة السعر وشارة «التنفيذ البشري» داخل الكرت
    expect(find.text('\$2.50'), findsOneWidget);
    expect(find.text('تنفيذ يدوي مضمون'), findsOneWidget);
    // القسم الثاني: كتالوج المزود يبقى بشبكته المعهودة
    expect(find.text('اختر الخدمة'), findsOneWidget);
    expect(find.textContaining('دولة • من \$0.50'), findsOneWidget);

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

  testWidgets('بلا كتالوج تُعرض حالة فراغ مع زر إعادة الجلب', (
    WidgetTester w,
  ) async {
    await _pumpPage(w);

    expect(find.text('لا توجد أرقام متاحة'), findsOneWidget);
    expect(find.text('إعادة جلب القائمة'), findsOneWidget);
    expect(find.text('اختر الخدمة'), findsOneWidget);

    _expectNoOverflow(w);
  });

  testWidgets('الرقم الحيّ يستبدل الشبكة ويعرض العدّاد ولوحة الانتظار', (
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

    expect(find.text('رقمك النشط'), findsOneWidget);
    expect(find.text('اختر الخدمة'), findsNothing);
    expect(find.text('2015550007777'), findsOneWidget);
    expect(find.text('أدخل هذا الرقم في التطبيق'), findsOneWidget);
    expect(find.text('بانتظار وصول رسالة التحقق…'), findsOneWidget);
    expect(find.text('متبقٍ'), findsOneWidget);
    // لم يصل الرمز: زر الإلغاء هو خيار استرجاع المبلغ
    expect(find.text('إلغاء واسترجاع'), findsOneWidget);
    expect(find.text('تم — إغلاق'), findsNothing);
    expect(find.text('نسخ الرقم'), findsOneWidget);

    _expectNoOverflow(w);
    await _teardown(w);
  });

  testWidgets('وصول الرمز يعرضه في الصفحة بدل لوحة الانتظار', (
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

    expect(find.text('رمز التحقق وصل'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, '481920'), findsOneWidget);
    expect(find.text('بانتظار وصول رسالة التحقق…'), findsNothing);
    expect(find.text('نافذة العرض'), findsOneWidget);
    expect(find.text('تم — إغلاق'), findsOneWidget);

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
    // محتوى الحوار نص واحد بأسطر: الدولة/المشغّل/السعر — فالمطابقة الجزئية
    expect(find.textContaining('المشغّل: أي مشغّل متاح'), findsOneWidget);
    expect(find.textContaining('الدولة: مصر'), findsOneWidget);
    expect(find.text('تفعيل الرقم'), findsOneWidget);

    _expectNoOverflow(w);
  });

  testWidgets('اختيار مشغّل يبدّل السعر المعروض في زر التفعيل', (
    WidgetTester w,
  ) async {
    await _pumpPage(w, options: _catalog, richWallet: true);
    await _openSheet(w, 'Telegram');

    expect(find.text('تفعيل الرقم \$0.50'), findsOneWidget);

    await w.tap(find.text('كندا'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 250));

    expect(find.text('تفعيل الرقم \$1.00'), findsOneWidget);
    expect(find.textContaining('متاح 40 رقم'), findsOneWidget);

    _expectNoOverflow(w);
  });
}
