// معجم تطبيقات الأرقام: بوابة «متاح للمزودين» في لوحة الإدارة.
// الاختبار يثبّت العرض الكامل للمعجم (بلا شبكة)، والتبويبات والبحث، ونداء
// toggleDictionaryOffered بالمفتاح الصحيح — مع تأكيدٍ قبل الإخفاء لأن
// الإيقاف إخفاءٌ عرضي غير اتلافي.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/virtual_number_model.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/screens/admin/virtual_number_dictionary_screen.dart';

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
// بذور المعجم: مفاتيح معروفة بحالات توفر ووثاقات متفاوتة
// ---------------------------------------------------------------------------

const List<VirtualNumberDictionaryEntry> _seed = [
  VirtualNumberDictionaryEntry(
    key: 'telegram',
    nameAr: 'تيليجرام',
    nameEn: 'Telegram',
    offered: true,
    appId: 'a1',
    appName: 'Telegram',
    serviceCode: 'telegram',
    productCount: 2,
  ),
  VirtualNumberDictionaryEntry(
    key: 'whatsapp',
    nameAr: 'واتساب',
    nameEn: 'Whatsapp',
    offered: true,
    fivesimCode: 'whatsapp',
    herosmsCode: 'wa',
  ),
  VirtualNumberDictionaryEntry(
    key: 'discord',
    nameAr: 'ديسكورد',
    nameEn: 'Discord',
    offered: false,
  ),
  VirtualNumberDictionaryEntry(
    key: 'zoom',
    nameAr: 'زوم',
    nameEn: 'Zoom',
    offered: false,
    appId: 'a2',
    productCount: 1,
  ),
  VirtualNumberDictionaryEntry(
    key: 'signal',
    nameAr: 'سيجنال',
    nameEn: 'Signal',
    offered: true,
  ),
];

class _DictVn extends VirtualNumbersProvider {
  _DictVn({List<VirtualNumberDictionaryEntry> dictionary = _seed})
    : _dictionary = dictionary;

  final List<VirtualNumberDictionaryEntry> _dictionary;

  /// نداءات PATCH المستقبَلة: (مفتاح، قيمة التوفر المطلوبة)
  final List<(String, bool)> toggles = <(String, bool)>[];
  int dictionaryFetches = 0;
  int bulkCalls = 0;
  // نداءات التعديل على الوثاقات: معرّفات updateAdminApp + آخر إنشاء
  final List<String> updatedApps = <String>[];
  Map<String, dynamic>? lastCreateApp;

  @override
  List<VirtualNumberDictionaryEntry> get adminDictionary => _dictionary;

  @override
  bool get isDictionaryLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchAdminDictionary({bool quiet = false}) async {
    dictionaryFetches++;
  }

  @override
  Future<String?> toggleDictionaryOffered(String key, bool offered) async {
    toggles.add((key, offered));
    // يُسجَّل النداء فقط: البذر يبقى ثابتاً لبقية التوقعات في نفس الاختبار
    return offered
        ? 'تم إتاحة التطبيق للمزودين'
        : 'تم إخفاء التطبيق من المزودين';
  }

  @override
  Future<String?> bulkCreateAdminApps({String? providerId}) async {
    bulkCalls++;
    return 'أُضيفت التطبيقات';
  }

  @override
  Future<String?> updateAdminApp(
    String id, {
    String? name,
    String? iconUrl,
    int? sortOrder,
  }) async {
    updatedApps.add(id);
    return 'تم تحديث التطبيق';
  }

  @override
  Future<String?> createAdminApp({
    required String name,
    required String serviceCode,
    String? providerId,
    String? iconUrl,
  }) async {
    lastCreateApp = {'name': name, 'serviceCode': serviceCode};
    return 'تم إنشاء التطبيق';
  }

  @override
  Future<void> fetchAdminCatalog({String? providerId}) async {}
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

Future<void> _pumpDict(
  WidgetTester w,
  _DictVn vn, {
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
        ChangeNotifierProvider<VirtualNumbersProvider>(create: (_) => vn),
      ],
      child: const MaterialApp(home: VirtualNumberDictionaryScreen()),
    ),
  );
  await _settle(w);
}

/// مفتاح السطر رقم [index] في ترتيب «الكل» (تبديل التوفر)
Finder _switchAt(int index) => find.byType(Switch).at(index);

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);
  setUp(() => _collected.clear());

  group('شاشة معجم التطبيقات', () {
    testWidgets('تعرض كل المعجم بعدّة البدائل ووسم الدول وتُجلب مرة', (
      w,
    ) async {
      final vn = _DictVn();
      await _pumpDict(w, vn);

      expect(find.text('معجم التطبيقات'), findsOneWidget);
      expect(vn.dictionaryFetches, greaterThanOrEqualTo(1));

      // كل مداخل البذر ظاهرة في تبويب «الكل» الافتراضي
      for (final name in ['تيليجرام', 'واتساب', 'ديسكورد', 'زوم', 'سيجنال']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      // العدّ في التبويبات يطابق البذر: متاح = 3 من 5
      expect(find.text('الكل (5)'), findsOneWidget);
      expect(find.text('متاح (3)'), findsOneWidget);
      expect(find.text('مُضاف من المزود'), findsOneWidget);

      // وسم الدول للوثاقات المخزّنة فقط: «2 دولة» و«دولة» المفردة
      expect(find.text('2 دولة'), findsOneWidget);
      expect(find.text('دولة'), findsOneWidget);
      // سطر إنجليزي ثانٍ تحت العربي (ت convention ثنائي اللغة)
      expect(find.text('Telegram'), findsOneWidget);

      expect(
        _collected.where((e) => e.toString().contains('OVERFLOW')).toList(),
        isEmpty,
      );
    });

    testWidgets('تبويب «متاح» يرشح الموقوفين، والبحث يعمل بالمفتاح الإنجليزي', (
      w,
    ) async {
      final vn = _DictVn();
      await _pumpDict(w, vn);

      await w.tap(find.text('متاح (3)'));
      await _settle(w);
      expect(find.text('تيليجرام'), findsOneWidget);
      expect(find.text('ديسكورد'), findsNothing);
      expect(find.text('زوم'), findsNothing);

      await w.tap(find.text('الكل (5)'));
      await _settle(w);
      // البحث بمفتاح المعجم نفسه لا بالاسم فقط
      await w.enterText(find.byType(TextField), 'zoom');
      await _settle(w);
      expect(find.text('زوم'), findsOneWidget);
      expect(find.text('سيجنال'), findsNothing);
    });

    testWidgets('تبويب «مُضاف من المزود» يعرض الوثاقات ذات appId فقط', (
      w,
    ) async {
      final vn = _DictVn();
      await _pumpDict(w, vn);

      await w.tap(find.text('مُضاف من المزود'));
      await _settle(w);
      expect(find.text('تيليجرام'), findsOneWidget);
      expect(find.text('زوم'), findsOneWidget);
      expect(find.text('واتساب'), findsNothing);
    });

    testWidgets('تفعيل موقوف ينادي PATCH فوراً بلا تأكيد', (w) async {
      final vn = _DictVn();
      await _pumpDict(w, vn);

      // الترتيب كما في البذر: ديسكورد الثالث، ومتاحه false
      await w.tap(_switchAt(2));
      await _settle(w);
      expect(vn.toggles, [('discord', true)]);
      expect(find.text('تم إتاحة التطبيق للمزودين'), findsOneWidget);
    });

    testWidgets('إيقاف متاح يطلب تأكيداً: التراجع لا ينادي والإخفاء ينادي', (
      w,
    ) async {
      final vn = _DictVn();
      await _pumpDict(w, vn);

      await w.tap(_switchAt(0)); // تيليجرام متاح ← إيقاف
      await _settle(w);
      expect(find.text('إخفاء «تيليجرام» من المزودين'), findsOneWidget);

      await w.tap(find.widgetWithText(TextButton, 'تراجع'));
      await _settle(w);
      expect(vn.toggles, isEmpty);

      await w.tap(_switchAt(0));
      await _settle(w);
      await w.tap(find.widgetWithText(FilledButton, 'إخفاء'));
      await _settle(w);
      expect(vn.toggles, [('telegram', false)]);
      expect(find.text('تم إخفاء التطبيق من المزودين'), findsOneWidget);
    });

    testWidgets('زر استيراد كتالوج المزود انتقل إلى المعجم يعمل هنا', (
      w,
    ) async {
      final vn = _DictVn();
      await _pumpDict(w, vn);

      await w.tap(find.byTooltip('إضافة تطبيق لكل خدمة في كتالوج المزود'));
      await _settle(w);
      expect(find.text('استيراد كتالوج الخدمات'), findsOneWidget);
      await w.tap(find.widgetWithText(FilledButton, 'استيراد'));
      await _settle(w);
      expect(vn.bulkCalls, 1);
    });

    testWidgets('سطر موثَّق: التعديل يفتح حوار الحفظ ويرسل updateAdminApp', (
      w,
    ) async {
      final vn = _DictVn();
      await _pumpDict(w, vn);

      // تيليجرام أول سطرين موثَّقين (له appId) في البذر
      await w.tap(find.byTooltip('تعديل التطبيق').first);
      await _settle(w);
      expect(find.text('تعديل التطبيق'), findsOneWidget);
      // الاسم معبأ مسبقاً من الوثاقة: الحفظ بلا تحرير يمرّ بالمعجّل
      final fetchesBefore = vn.dictionaryFetches;
      await w.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await _settle(w);
      expect(vn.updatedApps, ['a1']);
      // بعد النجاح يُجلب المعجم من جديد فتتحدث appName/serviceCode في السطر
      expect(vn.dictionaryFetches, greaterThan(fetchesBefore));
    });

    testWidgets('سطر بلا وثاقة: التوثيق يفتح إنشاءً مسبق التعبئة برمز المزود', (
      w,
    ) async {
      final vn = _DictVn();
      await _pumpDict(w, vn);

      // واتساب أول سطر بلا appId: زر التوثيق، والرمز المقترح fivesimCode
      await w.tap(find.byTooltip('توثيق التطبيق من المزود').first);
      await _settle(w);
      expect(find.text('تطبيق أرقام جديد'), findsOneWidget);
      // التعبئة المسبقة: رمز الخدمة لدى المزود مطابقةً لكتالوجه
      expect(find.text('whatsapp'), findsOneWidget);

      await w.tap(find.widgetWithText(FilledButton, 'إنشاء'));
      await _settle(w);
      expect(vn.lastCreateApp, {'name': 'Whatsapp', 'serviceCode': 'whatsapp'});
    });
  });
}
