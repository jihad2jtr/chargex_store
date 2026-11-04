// النداء (بادئة الدولة +963 مثلاً) يُعرض فوق الرقم لا ذائبًا فيه: الخادم يرسل
// callingCode وحده والرقم دوليًا كاملًا، والصفحة تفصلهما بصريًا وقت الشراء.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/services/cache_service.dart';
import 'package:layan_chargex/models/virtual_number_model.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/providers/wallet_provider.dart';
import 'package:layan_chargex/screens/user/virtual_number_wait_screen.dart';
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

class _RichWallet extends WalletProvider {
  @override
  double get balance => 10;

  @override
  Future<void> fetchBalance() async {}
}

Map<String, dynamic> _request({
  String phoneNumber = '+963999123456',
  String? callingCode = '+963',
}) => {
  'id': 'dial-1',
  'requestNumber': 'VN-2611-dial',
  'service': 'telegram',
  'serviceName': 'Telegram',
  'country': 'syria',
  'countryName': 'سوريا',
  'operator': '',
  'amount': 0.50,
  'phoneNumber': phoneNumber,
  'callingCode': callingCode,
  'status': 'waiting',
  'isLive': true,
  'note': '',
  'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
  'createdAt': DateTime.now()
      .subtract(const Duration(minutes: 2))
      .toIso8601String(),
};

Future<void> _pumpWait(WidgetTester w, Map<String, dynamic> seed) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await CacheService.instance.clearAll();
  await CacheService.instance.set('vn_my_requests', <Map<String, dynamic>>[
    seed,
  ]);

  w.view.physicalSize = const Size(380, 1400);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  final request = VirtualNumberRequestModel.fromJson(seed);
  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>(create: (_) => _RichWallet()),
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => VirtualNumbersProvider(),
        ),
      ],
      child: MaterialApp(
        home: VirtualNumberWaitScreen(
          requestId: request.id,
          initialRequest: request,
        ),
      ),
    ),
  );
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('النداء فوق الرقم: +963 سطرٌ والرقم المحلي سطرٌ غيره', (
    WidgetTester w,
  ) async {
    await _pumpWait(w, _request());

    expect(find.text('النداء:'), findsOneWidget);
    expect(find.text('+963'), findsOneWidget);
    // الرقم المعروض منزوع النداء: لا يتكرر النداء داخله
    expect(find.widgetWithText(SelectableText, '999123456'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, '+963999123456'), findsNothing);
  });

  testWidgets('بلا callingCode من خادم قديم: الرقم كاملاً بلا سطر نداء', (
    WidgetTester w,
  ) async {
    await _pumpWait(w, _request(callingCode: null));

    expect(find.text('النداء:'), findsNothing);
    expect(
      find.widgetWithText(SelectableText, '+963999123456'),
      findsOneWidget,
    );
  });

  testWidgets('نداء لا يطابق بداية الرقم يتجاهله العرض ولا يقطع الرقم', (
    WidgetTester w,
  ) async {
    await _pumpWait(w, _request(callingCode: '+1'));

    expect(find.text('النداء:'), findsNothing);
    expect(
      find.widgetWithText(SelectableText, '+963999123456'),
      findsOneWidget,
    );
  });
}
