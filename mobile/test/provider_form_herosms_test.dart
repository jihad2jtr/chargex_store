// نافذة بيانات الربط لدى المزودين: رقاقة Hero-SMS تملأ الاسم والرابط الصحيحين،
// فالخادم يشتق نوع المزود (herosms) من اسمه/رابطه ولا يوجد حقل نوع في النموذج.
// الرقاقتان تظهران في نافذة صفحة مزودي الأرقام وحدها (بعد فصلها عن المتاجر)،
// وكذلك رقافتا DogeSMS وSMSPool الجديدتان بنفس القاعدة.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/screens/admin/provider_form_dialog.dart';

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

Future<void> _pumpForm(WidgetTester w, AdminProvider admin) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  w.view.physicalSize = const Size(520, 1400);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    ChangeNotifierProvider<AdminProvider>(
      create: (_) => admin,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ProviderFormDialog(admin: admin, virtualNumbersOnly: true),
            ),
          ),
        ),
      ),
    ),
  );
  await w.pump();
  await w.pump(const Duration(milliseconds: 300));
}

/// خطُّ google_fonts غير متاح في الاختبار فتُرسم الحروف بمربعات عريضة قد تفيض؛
/// تُستهلك ضجيجاً، وأي استثناء آخر يبقى عيباً حقيقياً في النافذة.
void _drainExpectedNoise(WidgetTester w) {
  final List<String> unexpected = <String>[];
  Object? error;
  while ((error = w.takeException()) != null) {
    final String text = error.toString();
    final bool noise =
        text.contains('google_fonts') ||
        text.contains('RenderFlex') ||
        text.contains('overflow') ||
        text.contains('OVERFLOW');
    if (!noise) unexpected.add(text);
  }
  expect(unexpected, isEmpty);
}

/// قيمة حقل بصفحته لا بترتيبه: مزودو الأرقام لهم حقل اسم السيرفر بين الاسم
/// والرابط، فالفهرس يتغيّر بين النماذج بينما يبقى الوصف وحده ثابتاً
String _fieldText(WidgetTester w, String label) =>
    w.widget<TextField>(find.widgetWithText(TextField, label)).controller!.text;

const _nameLabel = 'اسم المزود (5sim أو Hero-SMS أو DogeSMS أو SMSPool)';
const _urlLabel = 'Base URL رابط الـ API الرئيسي';
const _serverLabel = 'اسم السيرفر الظاهر للعميل';

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('رقاقة Hero-SMS تملأ الاسم ورابط handler_api', (
    WidgetTester w,
  ) async {
    await _pumpForm(w, AdminProvider());

    expect(find.text('5sim للأرقام الوهمية'), findsOneWidget);
    expect(find.text('Hero-SMS للأرقام الوهمية'), findsOneWidget);

    await w.tap(find.text('Hero-SMS للأرقام الوهمية'));
    await w.pump();

    expect(_fieldText(w, _nameLabel), 'Hero-SMS');
    // اسم Hero-SMS ورابطه معاً يشتق منهما الخادم نوع herosms
    expect(
      _fieldText(w, _urlLabel),
      'https://hero-sms.com/stubs/handler_api.php',
    );
    // الرقاقة تملأ هوية المزود وحدها: الاسم الوهمي المعروض للعميل لا يُمسّ
    expect(_fieldText(w, _serverLabel), 'Server 1');

    _drainExpectedNoise(w);
  });

  testWidgets('رقاقة 5sim تبقى على رابطها بعد إضافة البديل', (
    WidgetTester w,
  ) async {
    await _pumpForm(w, AdminProvider());

    await w.tap(find.text('5sim للأرقام الوهمية'));
    await w.pump();

    expect(_fieldText(w, _nameLabel), '5sim');
    // الجذر الحيّ للمزوّد: api.5sim.net أُزيل فكانت الطلبات تفشل عليه
    expect(_fieldText(w, _urlLabel), 'https://5sim.net/v1');

    _drainExpectedNoise(w);
  });

  testWidgets('رقاقتا DogeSMS وSMSPool تملأان الاسم وجذر الـ API', (
    WidgetTester w,
  ) async {
    await _pumpForm(w, AdminProvider());

    expect(find.text('DogeSMS للأرقام الوهمية'), findsOneWidget);
    expect(find.text('SMSPool للأرقام الوهمية'), findsOneWidget);

    await w.tap(find.text('DogeSMS للأرقام الوهمية'));
    await w.pump();

    expect(_fieldText(w, _nameLabel), 'DogeSMS');
    expect(_fieldText(w, _urlLabel), 'https://api.dogesms.com');

    await w.tap(find.text('SMSPool للأرقام الوهمية'));
    await w.pump();

    expect(_fieldText(w, _nameLabel), 'SMSPool');
    expect(_fieldText(w, _urlLabel), 'https://api.smspool.net');

    _drainExpectedNoise(w);
  });
}
