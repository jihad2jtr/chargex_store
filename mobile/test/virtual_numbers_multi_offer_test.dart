// دولة واحدة يبيعها سيرفران: شاشة العميل تعرض بطاقتي عرض مستقلتين لا سعراً
// مدمجاً ولا أرخصاً مُرشَّحاً، والشراء يكون بمعرّف المنتج لا برموز التطبيق.
// الشبكة هنا وهمية مسجِّلة (لا محجوبة) لأن المطلوب إثبات متن الطلب الواصل إلى
// الخادم: «productId» وحده كافٍ ليُوجَّه الشراء للسيرفر المختار بهامشه.
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

import 'helpers/recording_http.dart';

/// محفظة غنية: يكفي لبلوغ نافذة التأكيد بدل حوار «رصيد غير كافٍ»
class _RichWallet extends WalletProvider {
  @override
  double get balance => 10;

  @override
  Future<void> fetchBalance() async {}
}

// ---------------------------------------------------------------------------
// بذور الكتالوج: كندا معروضة عند سيرفرين بسعرين ومخزونين ومشغّلين مختلفين
// ---------------------------------------------------------------------------

Map<String, dynamic> _offer({
  required String productId,
  required String providerId,
  required String serverLabel,
  required double salePrice,
  required double cost,
  required int count,
  List<Map<String, dynamic>> operators = const [],
}) => {
  'productId': productId,
  'providerId': providerId,
  'serverLabel': serverLabel,
  'service': productId == 'p2' ? 'tg' : 'telegram',
  'country': '1',
  'countryName': 'كندا',
  'cost': cost,
  'salePrice': salePrice,
  'count': count,
  'operators': operators,
};

/// الدولة كما تُخزَّن بعد v2: العروض قائمة مستقلة، وحقول الدولة القديمة تبقى
/// لقطة أرخص عرض (توافقاً مع من لم يجدّد الكتالوج)
Map<String, dynamic> _twoServerCountry() => {
  'code': '1',
  'name': 'كندا',
  'nameAr': 'كندا',
  'nameEn': 'Canada',
  'flag': '🇨🇦',
  'iso': 'CA',
  'cost': 0.5,
  'salePrice': 0.80,
  'count': 7,
  'operators': const [
    {'code': 'vodafone', 'name': 'Vodafone'},
  ],
  'offers': <Map<String, dynamic>>[
    _offer(
      productId: 'p1',
      providerId: 'srv1',
      serverLabel: 'Server 1',
      salePrice: 1.00,
      cost: 0.80,
      count: 40,
      operators: const [
        {'code': 'any', 'name': 'Any'},
        {'code': 'movistar', 'name': 'Movistar'},
      ],
    ),
    _offer(
      productId: 'p2',
      providerId: 'srv2',
      serverLabel: 'Server 2',
      salePrice: 0.80,
      cost: 0.50,
      count: 7,
      operators: const [
        {'code': 'vodafone', 'name': 'Vodafone'},
      ],
    ),
  ],
};

/// الدولة كما في كتالوج مخزَّن قبل تعدد المزودين: بلا قائمة عروض
Map<String, dynamic> _legacyCountry() => const {
  'code': '20',
  'name': 'مصر',
  'nameAr': 'مصر',
  'cost': 0.4,
  'salePrice': 0.5,
  'count': 12,
  'operators': [],
};

Map<String, dynamic> _service({
  required List<Map<String, dynamic>> countries,
  required double fromPrice,
}) => {
  'code': 'telegram',
  'name': 'Telegram',
  'nameAr': 'تيليجرام',
  'fromPrice': fromPrice,
  'countries': countries,
};

Future<void> _pumpPage(
  WidgetTester w, {
  required List<Map<String, dynamic>> options,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await CacheService.instance.clearAll();
  await CacheService.instance.setRawList('vn_options_v2', options);

  w.view.physicalSize = const Size(400, 1200);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>(create: (_) => _RichWallet()),
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => VirtualNumbersProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<AppCatalogProvider>(
          create: (_) => AppCatalogProvider(),
        ),
      ],
      child: MaterialApp(
        // Scaffold宿主: الشاشة تُبلّغ نتيجة الشراء عبر ScaffoldMessenger،
        // وفي التطبيق الحقيقي يوفّره هيكل التنقّل حول الصفحة
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: const VirtualNumbersScreen(showAppBar: false)),
        ),
      ),
    ),
  );
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
}

/// يفك الشجرة فيُلغى مؤقّت الفحص الدوري (لا مؤقتات معلّقة عند نهاية الاختبار)
Future<void> _teardown(WidgetTester w) async {
  await w.pumpWidget(const SizedBox());
  await w.pump(const Duration(milliseconds: 400));
}

Future<void> _openSheet(WidgetTester w) async {
  await w.tap(find.text('تيليجرام').first);
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
}

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

void main() {
  setUpAll(RecordingHttp.install);
  setUp(RecordingHttp.reset);
  tearDownAll(RecordingHttp.uninstall);

  testWidgets('الدولة ذات السيرفرين تُعرض بطاقتين بسعرين ومخزونين مستقلين', (
    w,
  ) async {
    await _pumpPage(
      w,
      options: <Map<String, dynamic>>[
        _service(
          countries: <Map<String, dynamic>>[_twoServerCountry()],
          fromPrice: 0.8,
        ),
      ],
    );

    // بطاقة الخدمة تُذكر بأرخص ما يُباع، لا بسعر سيرفر بعينه
    expect(find.textContaining('من \$0.80'), findsOneWidget);

    await _openSheet(w);

    // صف الدولة: «متاحة من 2 سيرفر» و«من $0.80» بدل سعر واحد
    expect(find.text('متاحة من 2 سيرفر'), findsOneWidget);
    expect(find.text('من \$0.80'), findsOneWidget);
    expect(find.text('السيرفر'), findsOneWidget);

    // بطاقتان مستقلتان: لكل سيرفر اسمه الوهمي وسعره ومخزونه
    expect(find.text('Server 1'), findsOneWidget);
    expect(find.text('Server 2'), findsOneWidget);
    expect(find.text('\$1.00'), findsOneWidget);
    expect(find.text('\$0.80'), findsWidgets);
    expect(find.text('متاح 40 رقم'), findsOneWidget);
    expect(find.text('متاح 7 رقم'), findsOneWidget);
    // اسم المزود الحقيقي لا يظهر في أي موضع من شاشة العميل
    expect(find.textContaining('srv2'), findsNothing);

    _expectNoOverflow(w);
  });

  testWidgets(
    'المختار أولاً هو أول السيرفرات لا أرخصها، والتبديل يبدّل السعر',
    (w) async {
      await _pumpPage(
        w,
        options: <Map<String, dynamic>>[
          _service(
            countries: <Map<String, dynamic>>[_twoServerCountry()],
            fromPrice: 0.8,
          ),
        ],
      );
      await _openSheet(w);

      // لا ترشيح أرخص: أول عرض في القائمة هو المختار، وسعره يمشي في الزر
      expect(find.text('تفعيل الرقم \$1.00'), findsOneWidget);
      // ومشغّلات ذلك السيرفر وحدها
      expect(find.text('Movistar'), findsOneWidget);
      expect(find.text('Vodafone'), findsNothing);

      await w.tap(find.text('Server 2'));
      await w.pump();
      await w.pump(const Duration(milliseconds: 250));

      expect(find.text('تفعيل الرقم \$0.80'), findsOneWidget);
      // المشغّل صفة السيرفر المختار: قائمة السيرفر الثاني غير قائمة الأول
      expect(find.text('Vodafone'), findsOneWidget);
      expect(find.text('Movistar'), findsNothing);

      _expectNoOverflow(w);
    },
  );

  testWidgets(
    'الشراء من بطاقة سيرفر يُرسل معرّف منتجها وحده بلا service/country',
    (w) async {
      await _pumpPage(
        w,
        options: <Map<String, dynamic>>[
          _service(
            countries: <Map<String, dynamic>>[_twoServerCountry()],
            fromPrice: 0.8,
          ),
        ],
      );

      RecordingHttp.responder = (RecordedCall call) =>
          call.method == 'POST' &&
              call.path.endsWith('/virtual-numbers/request')
          ? StubReply(_createdNumberReply())
          : RecordingHttp.notHandled(call);

      await _openSheet(w);
      await w.tap(find.text('Server 2'));
      await w.pump();
      await w.pump(const Duration(milliseconds: 250));
      // المشغّل من قائمة السيرفر المختار وحده، فيُرسل برمه لا باسمه
      await w.tap(find.text('Vodafone'));
      await w.pump();
      await w.pump(const Duration(milliseconds: 250));
      await w.tap(find.text('تفعيل الرقم \$0.80'));
      await w.pump();
      await w.pump(const Duration(milliseconds: 400));

      // نافذة التأكيد تُسمّي السيرفر المختار بصريح العبارة
      expect(find.textContaining('السيرفر: Server 2'), findsOneWidget);
      expect(find.textContaining('المشغّل: Vodafone'), findsOneWidget);
      await w.tap(find.text('تفعيل الرقم'));
      await w.pump();
      await w.pump(const Duration(milliseconds: 400));
      // انتظار اكتمال سلسلة الشراء قبل أي تفكيك: وإلا سبق الإغلاقُ إرسالَ
      // رسالة النتيجة إلى الـ Scaffold فاشتكى من غيابه
      await w.pump(const Duration(milliseconds: 800));

      final RecordedCall? sent = RecordingHttp.lastTo(
        '/virtual-numbers/request',
      );
      expect(sent, isNotNull);
      expect(sent!.field('productId'), 'p2');
      // لا رموز تطبيق ولا دولة: الخادم يقرأ كل ذلك من المنتج، فاختيار سيرفر
      // آخر لا يمكن أن يسقط على المزود الخطأ
      expect(sent.json!.containsKey('service'), isFalse);
      expect(sent.json!.containsKey('country'), isFalse);
      expect(sent.field('operator'), 'vodafone');
      expect(sent.field('clientRequestId'), isA<String>());

      // بطاقة الرقم النشط تحمل الاسم الوهمي للسيرفر الذي باع الرقم
      expect(find.textContaining('Server 2'), findsWidgets);

      _expectNoOverflow(w);
      await _teardown(w);
    },
  );

  testWidgets('كتالوج مخزَّن بلا عروض يشتري بالمسار القديم ويخفي قسم السيرفر', (
    w,
  ) async {
    await _pumpPage(
      w,
      options: <Map<String, dynamic>>[
        _service(
          countries: <Map<String, dynamic>>[_legacyCountry()],
          fromPrice: 0.5,
        ),
      ],
    );

    RecordingHttp.responder = (RecordedCall call) =>
        call.method == 'POST' && call.path.endsWith('/virtual-numbers/request')
        ? StubReply(_createdNumberReply(service: 'telegram', country: '20'))
        : RecordingHttp.notHandled(call);

    await _openSheet(w);

    // سيرفر واحد: لا بطاقات عروض ولا عنوان «السيرفر»
    expect(find.text('السيرفر'), findsNothing);
    expect(find.text('متاحة من 2 سيرفر'), findsNothing);

    await w.tap(find.text('تفعيل الرقم \$0.50'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));
    await w.tap(find.text('تفعيل الرقم'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));
    await w.pump(const Duration(milliseconds: 800));

    final RecordedCall? sent = RecordingHttp.lastTo('/virtual-numbers/request');
    expect(sent, isNotNull);
    expect(sent!.field('service'), 'telegram');
    expect(sent.field('country'), '20');
    // بلا معرّف منتج: لا يُرسل حقلًا فارغاً يرتبك أمامه الخادم
    expect(sent.json!.containsKey('productId'), isFalse);

    _expectNoOverflow(w);
    await _teardown(w);
  });

  testWidgets('سيرفر بلا مخزون يبقى معروضاً باسمه ومخزونه المجهول', (w) async {
    await _pumpPage(
      w,
      options: <Map<String, dynamic>>[
        _service(
          countries: <Map<String, dynamic>>[
            {
              'code': '1',
              'name': 'كندا',
              'nameAr': 'كندا',
              'cost': 0.5,
              'salePrice': 0.8,
              'count': 0,
              'operators': const <Map<String, dynamic>>[],
              'offers': <Map<String, dynamic>>[
                _offer(
                  productId: 'p1',
                  providerId: 'srv1',
                  serverLabel: 'Server 1',
                  salePrice: 1.00,
                  cost: 0.8,
                  count: 40,
                ),
                _offer(
                  productId: 'p3',
                  providerId: 'srv3',
                  serverLabel: 'Server 3',
                  salePrice: 0.90,
                  cost: 0.6,
                  count: 0,
                ),
              ],
            },
          ],
          fromPrice: 0.9,
        ),
      ],
    );
    await _openSheet(w);

    // العرض الثالث ظاهر باسمه ومخزونه المجهول، والشراء عليه يبقى ممكناً:
    // نفاد المخزون يُعرف عند الخادم وحده فيسجَّل OUT_OF_STOCK لا فشل
    expect(find.text('مخزون غير معروف'), findsOneWidget);
    expect(find.text('Server 3'), findsOneWidget);

    _expectNoOverflow(w);
  });
}

/// ردّ الخادم على POST /virtual-numbers/request: رقم حيّ من السيرفر المختار
Map<String, dynamic> _createdNumberReply({
  String service = 'tg',
  String country = '1',
}) => {
  'message': 'تم تجهيز الرقم، سيصل الرمز تلقائياً',
  'request': <String, dynamic>{
    'id': 'req-1',
    'requestNumber': 'VN-2610-0001',
    'productId': service == 'tg' ? 'p2' : '',
    'serverLabel': service == 'tg' ? 'Server 2' : '',
    'service': service,
    'serviceName': 'Telegram',
    'country': country,
    'countryName': 'كندا',
    'amount': 0.80,
    'phoneNumber': '15550001111',
    'status': 'waiting',
    'isLive': true,
    'expiresAt': DateTime.now()
        .add(const Duration(minutes: 5))
        .toIso8601String(),
    'createdAt': DateTime.now().toIso8601String(),
  },
};
