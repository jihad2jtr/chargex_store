// حماية تفاعل شحن المحفظة: نموذج طريقة الدفع يُعرض في نافذة منبثقة
// (وليس داخل الصفحة) — يفتح عند الضغط على الطريقة ويُغلق بزر الإغلاق.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/exchange_rate_provider.dart';
import 'package:layan_chargex/providers/wallet_provider.dart';
import 'package:layan_chargex/screens/user/topup_screen.dart';
import 'package:layan_chargex/widgets/brand_logo.dart';

/// الشبكة معطّلة: أي طلب يفشل فوراً بدل أن يعلّق الاختبار
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

Future<void> _pumpTopup(WidgetTester w, {double width = 360}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  w.view.physicalSize = Size(width, 900);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider()),
        ChangeNotifierProvider<ExchangeRateProvider>(
          create: (_) => ExchangeRateProvider(),
        ),
      ],
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: TopupScreen(showAppBar: false),
        ),
      ),
    ),
  );

  await w.pump(const Duration(milliseconds: 300));
}

Future<void> _openMethod(WidgetTester w, String title) async {
  await w.tap(find.text(title).first);
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('الصفحة لا تعرض نموذج طريقة الدفع قبل الاختيار', (
    WidgetTester w,
  ) async {
    await _pumpTopup(w);

    expect(
      find.text('اضغط على طريقة الدفع لفتح نافذة الطلب وإتمام الشحن'),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('شريط الطرق يعرض شعارَي شام كاش و Binance', (
    WidgetTester w,
  ) async {
    await _pumpTopup(w);

    // شعار الوسيلتين في شريط الاختيار بدل الأيقونات العامة
    expect(find.byType(BrandLogo), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is BrandLogo && widget.asset == BrandLogo.binance,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is BrandLogo && widget.asset == BrandLogo.shamCash,
      ),
      findsOneWidget,
    );
  });

  testWidgets('الضغط على طريقة الدفع يفتح نموذجها في نافذة منبثقة', (
    WidgetTester w,
  ) async {
    await _pumpTopup(w);
    await _openMethod(w, 'شام كاش');

    expect(find.byType(BottomSheet), findsOneWidget);
    // العنوان داخل النافذة + عنصر الشريط في الصفحة
    expect(find.text('شام كاش'), findsNWidgets(2));
    // زر إغلاق النافذة موجود
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('زر الإغلاق يعيد الصفحة بلا نافذة', (WidgetTester w) async {
    await _pumpTopup(w);
    await _openMethod(w, 'أكواد');
    expect(find.byType(BottomSheet), findsOneWidget);

    await w.tap(find.byIcon(Icons.close_rounded));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.text('اضغط على طريقة الدفع لفتح نافذة الطلب وإتمام الشحن'),
      findsOneWidget,
    );
  });

  // تبويب الآيدي: نص المعرّف وزر نسخه مضغوطان (بلا أحجام افتراضية كبيرة)
  testWidgets('تبويب الآيدي: المعرّف وزر النسخ بحجم مضغوط', (
    WidgetTester w,
  ) async {
    await _pumpTopup(w, width: 340);
    await _openMethod(w, 'الآيدي');

    expect(find.byType(BottomSheet), findsOneWidget);

    // find.text يلتقي النص الداخلي، فلا بد من SelectableText نفسه
    final SelectableText idField = w
        .widgetList<SelectableText>(find.byType(SelectableText))
        .single;
    expect(idField.data, '8940-CX');
    expect(idField.style?.fontSize, lessThanOrEqualTo(14));

    // الزر: ElevatedButton.icon يبني نوعاً خاصاً فرعياً، فلا بد من bySubtype
    final ElevatedButton button = w.widget<ElevatedButton>(
      find.bySubtype<ElevatedButton>(),
    );
    // بلا الحد الافتراضي (64×40) وبلا وسادة لمس: الارتفاع الفعلي بقي مضغوطاً
    expect(
      button.style?.minimumSize?.resolve(const <WidgetState>{})?.height,
      28,
    );
    expect(button.style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    expect(w.getRect(find.bySubtype<ElevatedButton>()).height, lessThan(34));

    expect(testerLayoutException(w), isNull);
  });

  testWidgets('النافذة تعمل على شاشة ضيقة 320px', (WidgetTester w) async {
    await _pumpTopup(w, width: 320);
    await _openMethod(w, 'Binance');

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(testerLayoutException(w), isNull);
  });
}

/// أي استثناء فيض/طباعة (overflow) يُعد عيباً حقيقياً
Object? testerLayoutException(WidgetTester w) {
  Object? found;
  final Object? error = w.takeException();
  if (error != null && !error.toString().contains('google_fonts')) {
    found = error;
  }
  return found;
}
