// فصل «مزودي الأرقام الوهمية» عن «مزودي المتاجر»:
// كل صفحة تعرض نصفها فقط، ونافذة الإضافة تعرض اختصارات نصفها فقط،
// حتى لا يختلط مزود إصدار الأرقام بمنتجات كتالوج التطبيقات، مع بقاء
// مسار الانتقاء لكل نصف: منتجات المتجر أو دول أرقام من كتالوج مزودها.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/provider_model.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/screens/admin/provider_form_dialog.dart';
import 'package:layan_chargex/screens/admin/providers_management_screen.dart';

/// الشبكة معطّلة: لا نريد أي طلب حقيقي أثناء الاختبار
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

class _SeededAdmin extends AdminProvider {
  _SeededAdmin(this._items);

  final List<ProviderModel> _items;
  final List<Map<String, dynamic>> created = <Map<String, dynamic>>[];
  int checkCalls = 0;

  @override
  List<ProviderModel> get providers => _items;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchProviders({bool forceRefresh = false}) async {}

  @override
  Future<bool> createProvider(Map<String, dynamic> data) async {
    created.add(data);
    return true;
  }

  @override
  Future<bool> checkProviderStatus(String id) async {
    checkCalls++;
    return true;
  }
}

ProviderModel _storeProvider(String id, String name) {
  return ProviderModel(
    id: id,
    name: name,
    baseUrl: 'https://public-api.foxreload.com',
    apiKey: 'key-123',
    providerType: 'foxreload',
    status: 'online',
    lastCheckAt: DateTime(2026, 10, 27, 21, 56),
    balance: 24.75,
    profitMarginType: 'percentage',
    profitMarginValue: 12.5,
  );
}

ProviderModel _smsProvider(String id, String name, String type, String url) {
  return ProviderModel(
    id: id,
    name: name,
    baseUrl: url,
    apiKey: 'sms-key-456',
    providerType: type,
    status: 'online',
    lastCheckAt: DateTime(2026, 10, 27, 21, 56),
    balance: 1.5312,
    profitMarginType: 'percentage',
    profitMarginValue: 25,
  );
}

Future<_SeededAdmin> _pump(
  WidgetTester w, {
  required bool virtualNumbersOnly,
  required List<ProviderModel> providers,
  double width = 400,
  double height = 1000,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final admin = _SeededAdmin(providers);

  w.view.physicalSize = Size(width, height);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminProvider>(create: (_) => admin),
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => VirtualNumbersProvider(),
        ),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ProvidersManagementScreen(
            virtualNumbersOnly: virtualNumbersOnly,
          ),
        ),
      ),
    ),
  );
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
  return admin;
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  final List<ProviderModel> mixed = <ProviderModel>[
    _storeProvider('p1', 'Fox Reload'),
    _smsProvider('p2', '5sim', 'fivesim', 'https://5sim.net/v1'),
    _smsProvider(
      'p3',
      'Hero-SMS',
      'herosms',
      'https://hero-sms.com/stubs/handler_api.php',
    ),
  ];

  testWidgets('صفحة المزودين العادية تعرض مزودي المتاجر فقط', (w) async {
    await _pump(w, virtualNumbersOnly: false, providers: mixed);

    expect(find.text('إدارة المزودين'), findsOneWidget);
    expect(find.text('Fox Reload'), findsOneWidget);

    // مزودا الأرقام لا يظهران بين مزودي المتاجر
    expect(find.text('5sim'), findsNothing);
    expect(find.text('Hero-SMS'), findsNothing);
    expect(find.text('PROVIDERS · 1'), findsOneWidget);

    // إجراءات المتاجر باقية كما هي
    expect(find.text('عرض المنتجات'), findsOneWidget);
    expect(find.byTooltip('مزامنة المنتجات والأسعار'), findsOneWidget);
    expect(find.byTooltip('إضافة مزود جديد'), findsOneWidget);

    expect(w.takeException(), isNull);
  });

  testWidgets('صفحة مزودي الأرقام تعرض 5sim و Hero-SMS فقط', (w) async {
    await _pump(w, virtualNumbersOnly: true, providers: mixed);

    expect(find.text('مزودو الأرقام الوهمية'), findsOneWidget);
    expect(find.text('5sim'), findsOneWidget);
    expect(find.text('Hero-SMS'), findsOneWidget);
    expect(find.text('Fox Reload'), findsNothing);
    expect(find.text('SMS PROVIDERS · 2'), findsOneWidget);

    // لا منتجات ولا مزامنة كتالوج لمزودي الأرقام
    expect(find.text('عرض المنتجات'), findsNothing);
    expect(find.byTooltip('مزامنة المنتجات والأسعار'), findsNothing);
    expect(find.text('انتقاء الدول والتطبيقات'), findsNWidgets(2));
    expect(find.text('فحص الرصيد'), findsNWidgets(2));
    expect(find.text('تُطبَّق على أسعار الأرقام'), findsNWidgets(2));

    expect(w.takeException(), isNull);
  });

  testWidgets('نافذة الإضافة في صفحة الأرقام بلا اختصارات المتاجر', (w) async {
    final admin = await _pump(w, virtualNumbersOnly: true, providers: mixed);

    await w.tap(find.byTooltip('إضافة مزود أرقام'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProviderFormDialog), findsOneWidget);
    expect(find.text('SMS PROVIDER · CREATE'), findsOneWidget);
    expect(find.text('5sim للأرقام الوهمية'), findsOneWidget);
    expect(find.text('Hero-SMS للأرقام الوهمية'), findsOneWidget);

    // اختصارات مزودي المتاجر مخفية هنا
    expect(find.text('Fox Reload'), findsNothing);
    expect(find.text('Bay2Game'), findsNothing);

    final Finder dialog = find.byType(ProviderFormDialog);
    await w.tap(
      find.descendant(of: dialog, matching: find.text('5sim للأرقام الوهمية')),
    );
    await w.pump();

    // حقل الاسم الوهمي خاص بمزودي الأرقام، ويقترح «Server N» بالتتابع:
    // مزودا أرقام موجودان في البذرة، فيُقترح الثالث
    expect(find.text('اسم السيرفر الظاهر للعميل'), findsOneWidget);
    expect(
      w
          .widget<TextField>(
            find.descendant(
              of: dialog,
              matching: find.widgetWithText(
                TextField,
                'اسم السيرفر الظاهر للعميل',
              ),
            ),
          )
          .controller!
          .text,
      'Server 3',
    );

    // مفتاح API يُحدَّد بصفحته لا بترتيبه: حقول النافذة اختلفت بإضافة الاسم الوهمي
    await w.enterText(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextField, 'API Key المفتاح البرمجي'),
      ),
      'sms-secret',
    );
    await w.pump();

    await w.tap(
      find.descendant(of: dialog, matching: find.text('حفظ البيانات')),
    );
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(admin.created, hasLength(1));
    expect(admin.created.single['name'], '5sim');
    expect(admin.created.single['baseUrl'], 'https://5sim.net/v1');
    expect(admin.created.single['apiKey'], 'sms-secret');
    // الاسم الوهمي يُرسل مع الإنشاء، فهو ما سيُطبع على بطاقات العميل
    expect(admin.created.single['serverLabel'], 'Server 3');
  });

  testWidgets('نافذة الإضافة في صفحة المتاجر بلا اختصارات الأرقام', (w) async {
    await _pump(w, virtualNumbersOnly: false, providers: mixed);

    await w.tap(find.byTooltip('إضافة مزود جديد'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProviderFormDialog), findsOneWidget);
    expect(find.text('PROVIDER · CREATE'), findsOneWidget);
    expect(find.text('Fox Reload'), findsWidgets);
    expect(find.text('Bay2Game'), findsOneWidget);
    expect(find.text('5sim للأرقام الوهمية'), findsNothing);
    expect(find.text('Hero-SMS للأرقام الوهمية'), findsNothing);
  });

  testWidgets('بطاقة مزود الأرقام لا تفيض عند أضيق عرض', (w) async {
    for (final double width in <double>[320, 360]) {
      await _pump(w, virtualNumbersOnly: true, providers: mixed, width: width);

      final List<String> overflows = <String>[];
      Object? error;
      while ((error = w.takeException()) != null) {
        if (error.toString().contains('overflowed')) {
          overflows.add(error.toString());
        }
      }
      expect(
        overflows,
        isEmpty,
        reason: 'تداخل أفقي في صفحة مزودي الأرقام عند عرض $width',
      );
      expect(find.text('SMS PROVIDERS · 2'), findsOneWidget);
    }
  });

  testWidgets('سجل قديم بلا نوع يُستدل عليه من الاسم والرابط', (w) async {
    final ProviderModel legacyNoType = ProviderModel(
      id: 'old',
      name: 'Hero-SMS',
      baseUrl: 'https://hero-sms.com/stubs/handler_api.php',
      apiKey: 'k',
    );
    final ProviderModel legacyFive = ProviderModel(
      id: 'old2',
      name: 'مزود أرقام',
      baseUrl: 'https://5sim.net/v1',
      apiKey: 'k',
    );

    expect(legacyNoType.isVirtualNumber, isTrue);
    expect(legacyFive.isVirtualNumber, isTrue);
    expect(_storeProvider('p1', 'Fox Reload').isVirtualNumber, isFalse);

    // المزودان الجديدان: يُعترف بهما بالنوع الصريح و بالاسم/الرابط معاً
    expect(
      ProviderModel(
        id: 'd1',
        name: 'DogeSMS',
        baseUrl: '',
        apiKey: 'k',
        providerType: 'dogesms',
      ).isVirtualNumber,
      isTrue,
    );
    expect(
      ProviderModel(
        id: 'd2',
        name: 'مزود أرقام',
        baseUrl: 'https://api.smspool.net',
        apiKey: 'k',
      ).isVirtualNumber,
      isTrue,
    );
    expect(
      ProviderModel(
        id: 'd3',
        name: 'SMSPool',
        baseUrl: '',
        apiKey: 'k',
      ).isVirtualNumber,
      isTrue,
    );

    // صفحة الأرقام تصطفّهما حتى لو جاء النوع فارغاً من الخادم
    await _pump(w, virtualNumbersOnly: true, providers: mixed);
    expect(find.text('SMS PROVIDERS · 2'), findsOneWidget);
  });
}
