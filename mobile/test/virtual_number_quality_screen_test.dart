// لوحة مراقبة الجودة: كل سيرفر بصفّه المستقل — شرائح السلال بعدّداتها من
// الملخص، ونسبة وصول الأكواد من المحتسب وحده (النفاد والإلغاء لا يدخلان)،
// وسجل الأحداث بأسبابه، وإعادة التفعيل التي تصفّر الفشل المتتالي وتُبقي
// العدّادات التاريخية. الشبكة وهمية مسجِّلة لأن المطلوب إثبات ما يُرسل فعلاً
// إلى الخادم: bucket وsearch وملاحظة إعادة التفعيل.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/screens/admin/virtual_number_quality_screen.dart';
import 'package:layan_chargex/widgets/ops_ticket_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/recording_http.dart';

const _boardSuffix = '/virtual-numbers/admin/quality';

// ---------------------------------------------------------------------------
// خادم لوحة مصغّر: سلاله من العدّادات، وإعادة التفعيل تصفّر المتتالي وحده
// ---------------------------------------------------------------------------

Map<String, dynamic> _product({
  required String id,
  required String serverLabel,
  String providerId = 'prv-1',
  String providerName = 'hero-sms',
  bool providerActive = true,
  String appName = 'واتساب',
  String serviceCode = 'wa',
  String countryCode = '1',
  String countryName = 'كندا',
  String flag = '🇨🇦',
  bool isActive = true,
  bool autoDisabled = false,
  int totalOrders = 0,
  int success = 0,
  int failure = 0,
  int cancelled = 0,
  int outOfStock = 0,
  int pending = 0,
  int consecutiveFailures = 0,
  String? disabledAt,
  String disabledReason = '',
  String disabledBy = '',
}) => {
  'productId': id,
  'providerId': providerId,
  'serverLabel': serverLabel,
  'providerName': providerName,
  'providerActive': providerActive,
  'appId': 'app-1',
  'appName': appName,
  'serviceCode': serviceCode,
  'countryCode': countryCode,
  'countryName': countryName,
  'flag': flag,
  'isActive': isActive,
  'autoDisabled': autoDisabled,
  'totalOrders': totalOrders,
  'success': success,
  'failure': failure,
  'cancelled': cancelled,
  'outOfStock': outOfStock,
  'pending': pending,
  'consecutiveFailures': consecutiveFailures,
  'disabledAt': ?disabledAt,
  'disabledReason': disabledReason,
  'disabledBy': disabledBy,
};

class _QualityServer {
  _QualityServer(this._products, this._events, this._requests);

  final List<Map<String, dynamic>> _products;
  final Map<String, List<Map<String, dynamic>>> _events;
  final Map<String, List<Map<String, dynamic>>> _requests;

  /// كم مرة طُلبت اللوحة: للتحقق أن إعادة التفعيل تُحدّث الصفوف
  int boardCalls = 0;

  static String bucketOf(Map<String, dynamic> p) {
    if (p['autoDisabled'] == true) return 'disabled';
    if ((p['consecutiveFailures'] as int? ?? 0) >= 1) return 'watching';
    return 'active';
  }

  StubReply handle(RecordedCall call) {
    final path = call.path;
    final events = RegExp(
      r'/virtual-numbers/admin/quality/([^/]+)/events$',
    ).firstMatch(path);
    if (events != null && call.method == 'GET') {
      return _detail(events.group(1)!);
    }
    final reactivate = RegExp(
      r'/virtual-numbers/admin/quality/([^/]+)/reactivate$',
    ).firstMatch(path);
    if (reactivate != null && call.method == 'POST') {
      return _reactivate(reactivate.group(1)!, call.field('note'));
    }
    if (path.endsWith(_boardSuffix) && call.method == 'GET') {
      return _board(call.query['bucket'] ?? 'all', call.query['search'] ?? '');
    }
    return RecordingHttp.notHandled(call);
  }

  StubReply _board(String bucket, String search) {
    boardCalls++;
    final rows = _products.where((p) {
      if (bucket != 'all' && bucketOf(p) != bucket) return false;
      if (search.isEmpty) return true;
      // نفس حقول البحث في الخادم: الاسم الوهمي والاسم الحقيقي والتطبيق والدولة
      final haystack = <Object?>[
        p['serverLabel'],
        p['providerName'],
        p['appName'],
        p['countryName'],
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(search.toLowerCase());
    }).toList();
    int countOf(String b) => _products.where((p) => bucketOf(p) == b).length;
    return StubReply({
      // الملخص يُحسب من كل المنتجات، لا من المصفاة: الشرائح تعرض حجم سلّتها
      'summary': {
        'all': _products.length,
        'active': countOf('active'),
        'watching': countOf('watching'),
        'disabled': countOf('disabled'),
      },
      'rows': rows
          .map((p) => <String, dynamic>{...p, 'bucket': bucketOf(p)})
          .toList(),
    });
  }

  StubReply _detail(String productId) {
    final product = _products.firstWhere(
      (p) => p['productId'] == productId,
      orElse: () => _products.first,
    );
    return StubReply({
      'product': <String, dynamic>{...product, 'bucket': bucketOf(product)},
      'events': _events[productId] ?? const <Map<String, dynamic>>[],
      'requests': _requests[productId] ?? const <Map<String, dynamic>>[],
    });
  }

  /// إعادة التفعيل: تصفير المتتالي ورفع الإيقاف، والعدّادات التاريخية تبقى
  StubReply _reactivate(String productId, Object? note) {
    final product = _products.firstWhere(
      (p) => p['productId'] == productId,
      orElse: () => _products.first,
    );
    product['consecutiveFailures'] = 0;
    product['autoDisabled'] = false;
    product['isActive'] = true;
    product['disabledReason'] = '';
    (_events[productId] ??= <Map<String, dynamic>>[]).insert(0, {
      'id': 'ev-react-${DateTime.now().microsecondsSinceEpoch}',
      'outcome': 'reactivated',
      'counted': false,
      'source': 'admin',
      'reason': note ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    });
    return const StubReply({'message': 'تم إعادة تفعيل السيرفر'});
  }
}

// بذرة اللوحة: نشِط بتقييم كامل، وتحت المراقبة، وموقوف جودةً، ونشِط بلا نتيجة
// محتسبة (نفاد وإلغاء فقط)
List<Map<String, dynamic>> _seedProducts() => [
  _product(
    id: 'p-1',
    serverLabel: 'Server 1',
    totalOrders: 25,
    success: 18,
    failure: 2,
    cancelled: 3,
    outOfStock: 2,
  ),
  _product(
    id: 'p-2',
    serverLabel: 'Server 2',
    providerId: 'prv-2',
    providerName: '5sim',
    appName: 'تيليجرام',
    serviceCode: 'tg',
    countryName: 'مصر',
    countryCode: '20',
    flag: '🇪🇬',
    totalOrders: 7,
    success: 4,
    failure: 2,
    pending: 1,
    consecutiveFailures: 1,
  ),
  _product(
    id: 'p-3',
    serverLabel: 'Server 3',
    providerId: 'prv-3',
    providerName: 'dogesms',
    providerActive: false,
    countryName: 'كندا',
    totalOrders: 14,
    success: 3,
    failure: 9,
    outOfStock: 2,
    consecutiveFailures: 3,
    autoDisabled: true,
    isActive: false,
    disabledAt: '2026-01-05T10:30:00.000Z',
    disabledReason: '3 فشل متتالٍ — آخر سبب: انتهت مهلة انتظار الرمز',
    disabledBy: 'النظام',
  ),
  _product(
    id: 'p-4',
    serverLabel: 'Server 4',
    providerId: 'prv-4',
    providerName: 'smspool',
    countryName: 'تركيا',
    countryCode: '90',
    flag: '🇹🇷',
    totalOrders: 10,
    cancelled: 4,
    outOfStock: 6,
  ),
];

Map<String, List<Map<String, dynamic>>> _seedEvents() => {
  'p-3': [
    {
      'id': 'e-1',
      'outcome': 'auto_disabled',
      'counted': false,
      'source': 'system',
      'reason': 'أوقف النظام السيرفر لبلوغ حدّ الفشل المتتالي',
      'createdAt': '2026-01-05T10:30:00.000Z',
    },
    {
      'id': 'e-2',
      'outcome': 'failed',
      'counted': true,
      'source': 'sweep',
      'reason': 'انتهت مهلة انتظار الرمز على رقم مُخصَّص',
      'requestNumber': 'VN-2610-0003',
      'createdAt': '2026-01-05T10:29:00.000Z',
    },
    {
      'id': 'e-3',
      'outcome': 'out_of_stock',
      'counted': false,
      'source': 'request',
      'reason': 'NO_NUMBERS',
      'requestNumber': 'VN-2610-0002',
      'createdAt': '2026-01-04T09:00:00.000Z',
    },
    {
      'id': 'e-4',
      'outcome': 'success',
      'counted': true,
      'source': 'webhook',
      'reason': 'رمز وصل من المزود',
      'requestNumber': 'VN-2610-0001',
      'createdAt': '2026-01-03T08:00:00.000Z',
    },
  ],
};

Map<String, List<Map<String, dynamic>>> _seedRequests() => {
  'p-3': [
    {
      'id': 'r-3',
      'requestNumber': 'VN-2610-0003',
      'status': 'expired',
      'phoneNumber': '15550003333',
      'hasCode': false,
      'qualityOutcome': 'failed',
      'createdAt': '2026-01-05T10:20:00.000Z',
    },
    {
      'id': 'r-1',
      'requestNumber': 'VN-2610-0001',
      'status': 'completed',
      'phoneNumber': '15550001111',
      'hasCode': true,
      'smsCode': '482193',
      'qualityOutcome': 'success',
      'createdAt': '2026-01-03T07:50:00.000Z',
    },
  ],
};

Future<_QualityServer> _pumpBoard(WidgetTester w) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  w.view.physicalSize = const Size(900, 3200);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  final server = _QualityServer(
    _seedProducts(),
    _seedEvents(),
    _seedRequests(),
  );
  RecordingHttp.responder = server.handle;

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => VirtualNumbersProvider(),
        ),
      ],
      child: const MaterialApp(home: VirtualNumberQualityScreen()),
    ),
  );
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
  return server;
}

Finder _cardOf(String serverLabel) => find.ancestor(
  of: find.text(serverLabel),
  matching: find.byType(OpsTicketCard),
);

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

  testWidgets('شرائح السلال تعرض عدد كل سلّة من الملخص وتصفّي الصفوف بالمسار', (
    w,
  ) async {
    final server = await _pumpBoard(w);

    // عدد كل سلّة من الملخص: نشِطتان، مراقَبة واحدة، موقوفة واحدة
    expect(find.text('الكل (4)'), findsOneWidget);
    expect(find.text('نشطة (2)'), findsOneWidget);
    expect(find.text('تحت المراقبة (1)'), findsOneWidget);
    expect(find.text('موقوفة (1)'), findsOneWidget);
    // البطاقة تُوسم بسلّتها كما يقرّرها الخادم من العدّادات
    expect(find.textContaining('موقوف جودةً'), findsOneWidget);
    expect(server.boardCalls, 1);

    await w.tap(find.text('موقوفة (1)'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    final RecordedCall? call = RecordingHttp.lastTo(_boardSuffix);
    expect(call!.query['bucket'], 'disabled');
    // السلّة المختارة تُبقي ملخصها: الأرقام لا تتناقص لأن الصفوف المُخفاة لا تُحسب
    expect(find.text('الكل (4)'), findsOneWidget);
    expect(find.text('Server 3'), findsOneWidget);
    expect(find.text('Server 1'), findsNothing);
    expect(find.text('Server 2'), findsNothing);

    // الرجوع للكل بلا وسيط bucket: الخادم هو من يقرّر السلّة الافتراضية
    await w.tap(find.text('الكل (4)'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));
    final RecordedCall? all = RecordingHttp.lastTo(_boardSuffix);
    expect(all!.query.containsKey('bucket'), isFalse);
    expect(find.text('Server 1'), findsOneWidget);

    _expectNoOverflow(w);
  });

  testWidgets('البحث يُرسل للخادم ولا يُصفّى محلياً', (w) async {
    await _pumpBoard(w);

    await w.enterText(
      find.widgetWithText(TextField, 'بحث بالسيرفر أو التطبيق أو الدولة'),
      'dogesms',
    );
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    final RecordedCall? call = RecordingHttp.lastTo(_boardSuffix);
    expect(call!.query['search'], 'dogesms');
    // الاسم الحقيقي للمزود يظهر في اللوحة الداخلية وحدها
    expect(find.text('Server 3'), findsOneWidget);
    expect(find.textContaining('dogesms'), findsWidgets);
    expect(find.text('Server 1'), findsNothing);

    _expectNoOverflow(w);
  });

  testWidgets(
    'نسبة الأكواد من المحتسب وحده، والنفاد والإلغاء لا يُحسبان ضد المزود',
    (w) async {
      await _pumpBoard(w);

      // Server 1: ‏18 نجاح من 20 محتسب = 90% (الإلغاء والنفاد خارج النسبة)
      expect(find.text('90%'), findsOneWidget);
      expect(
        find.textContaining('25 • محتسب 20 • غير محتسب 5'),
        findsOneWidget,
      );
      // Server 3: ‏3 من 12 محتسب = 25%
      expect(find.text('25%'), findsOneWidget);
      expect(find.textContaining('3 / 9'), findsOneWidget);

      // بلا نتيجة محتسبة: لا نسبة تُختلق، والبطاقة تشرح أن المحتسب صفر
      expect(
        find.textContaining('10 • محتسب 0 • غير محتسب 10'),
        findsOneWidget,
      );
      expect(
        find.textContaining('لا نتيجة محتسبة بعد — النفاد والإلغاء لا يُحسبان'),
        findsOneWidget,
      );

      // أربعة صفوف = أربعة رؤوس «وصول الأكواد»: كل سيرفر بتقييمه المستقل
      expect(find.text('وصول الأكواد'), findsNWidgets(4));
      // المزود الحقيقي موقوف يُبلَّح في اللوحة الإدارية
      expect(find.textContaining('dogesms (موقوف)'), findsOneWidget);

      _expectNoOverflow(w);
    },
  );

  testWidgets('ورقة التفاصيل تُفتح على سجل الأحداث بأسبابه وآخر الطلبات', (
    w,
  ) async {
    await _pumpBoard(w);

    await w.tap(
      find.descendant(of: _cardOf('Server 3'), matching: find.text('السجل')),
    );
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    final RecordedCall? call = RecordingHttp.lastTo('/p-3/events');
    expect(call, isNotNull);
    expect(call!.query['limit'], '50');

    // كل حدث باسم نتيجته ووسم احتسابه وسببه الخام وخلاصة مصدره
    expect(find.textContaining('رقم بلا رمز'), findsOneWidget);
    expect(
      find.textContaining('انتهت مهلة انتظار الرمز على رقم مُخصَّص'),
      findsOneWidget,
    );
    expect(find.textContaining('المسح الدوري'), findsOneWidget);
    expect(find.text('VN-2610-0003'), findsWidgets);
    expect(find.textContaining('إيقاف تلقائي'), findsOneWidget);
    expect(find.textContaining('نفاد المخزون'), findsOneWidget);
    // غير المحتسب موسوم كذلك صراحةً، فلا يخلط الإداري بينه وبين الفشل
    expect(find.text('غير محتسب'), findsWidgets);
    expect(find.text('في التقييم'), findsWidgets);

    // آخر الطلبات: الرمز الواصل مقابل «بلا رمز» (بالمطابقة التامة، لأن تسمية
    // حدث الفشل «رقم بلا رمز» تحوي الحرفين نفسيهما)
    expect(find.textContaining('482193'), findsOneWidget);
    expect(find.text('بلا رمز'), findsOneWidget);
    // سبب الإيقاف ظاهر في الورقة لا في البطاقة فقط
    expect(
      find.textContaining('3 فشل متتالٍ — آخر سبب: انتهت مهلة انتظار الرمز'),
      findsWidgets,
    );

    _expectNoOverflow(w);
  });

  testWidgets(
    'زر إعادة التفعيل يصفّر المتتالي وحده ويُبقي العدّادات التاريخية',
    (w) async {
      final server = await _pumpBoard(w);
      // صفّان يحتاجان انتباهاً: الموقوفة جودةً والمراقَبة بفشل متتالٍ واحد
      expect(find.text('إعادة تفعيل'), findsNWidgets(2));

      final before = server.boardCalls;
      await w.tap(
        find.descendant(
          of: _cardOf('Server 3'),
          matching: find.text('إعادة تفعيل'),
        ),
      );
      await w.pump();
      await w.pump(const Duration(milliseconds: 400));

      final RecordedCall? sent = RecordingHttp.lastTo('/p-3/reactivate');
      expect(sent, isNotNull);
      expect(sent!.field('note'), 'إعادة تفعيل من لوحة الجودة');

      // اللوحة أُعيد جلبها بعد الإجراء، فالصف لا يُعدَّل محلياً على حساب الخادم
      expect(server.boardCalls, greaterThan(before));
      // التاريخ بقي: نسبة الـ 25% ما زالت محسوبة من 3 نجاح و9 فشل
      expect(find.text('25%'), findsOneWidget);
      expect(find.textContaining('3 / 9'), findsOneWidget);
      // زال وسم الإيقاف وبقى زر المراقَبة وحدها
      expect(find.textContaining('موقوف جودةً'), findsNothing);
      expect(find.text('إعادة تفعيل'), findsOneWidget);
      // رسالة موحّدة كما في بقية شاشات الانتقاء
      expect(find.textContaining('تم إعادة تفعيل السيرفر'), findsOneWidget);

      _expectNoOverflow(w);
    },
  );
}
