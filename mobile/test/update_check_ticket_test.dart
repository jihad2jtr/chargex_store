// نافذة «التحقق من التحديثات»: تصميم التذكرة الحديثة — جسم + كعب حالة مفصولان
// بخط تثقيب، مع الحفاظ على سلوك الفحص (1.2 ثانية) وأزراره.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/widgets/digital_pass_card.dart';
import 'package:layan_chargex/widgets/update_check_dialog.dart';

/// الشبكة معطّلة: النافذة لا تستدعي شبكة أصلاً، والحماية من أي استدعاء طارئ
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

/// أخطاء كل اختبار مجمّعة هنا: أخطاء تحميل الخطوط متوقّعة مع حظر الشبكة،
/// أما أخطاء RenderFlex (طفو التخطيط) فتُفشل الاختبار
final List<Object> _collected = <Object>[];

List<Object> _drain(WidgetTester w) {
  final errors = <Object>[];
  for (;;) {
    final error = w.takeException();
    if (error == null) break;
    errors.add(error);
  }
  _collected.addAll(errors);
  return errors;
}

Future<void> _settle(WidgetTester w, {int ms = 600}) async {
  await w.pump();
  await w.pump(Duration(milliseconds: ms));
  _drain(w);
}

Future<void> _openDialog(WidgetTester w, {double width = 420}) async {
  w.view.physicalSize = Size(width, 760);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => UpdateCheckDialog.show(context),
                child: const Text('افتح الفحص'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(w);

  await w.tap(find.text('افتح الفحص'));
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
  _drain(w);
}

/// ينهي مهلة الفحص (1.2 ثانية) ويصل بالحالة إلى «أحدث إصدار»
Future<void> _finishCheck(WidgetTester w) async {
  await w.pump(const Duration(milliseconds: 1400));
  await _settle(w);
}

bool _hasTicketClipped(WidgetTester w) => w
    .widgetList<ClipPath>(find.byType(ClipPath))
    .any((c) => c.clipper is TicketPassClipper);

bool _hasPainter(WidgetTester w) => w
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .any((p) => p.painter is VerticalDashedLinePainter);

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);
  setUp(() => _collected.clear());

  testWidgets('حالة الفحص: عنوان الفحص وكعب الإصدار وزر معطّل', (w) async {
    await _openDialog(w);

    expect(find.text('جاري فحص التحديثات...'), findsOneWidget);
    expect(find.text('جارٍ الفحص'), findsOneWidget);
    expect(find.text('SYSTEM // OTA CHECK'), findsOneWidget);
    expect(find.text(UpdateCheckDialog.versionLabel), findsOneWidget);
    expect(find.text(UpdateCheckDialog.buildLabel), findsOneWidget);

    // الإغلاق غير متاح أثناء الفحص، وزر إعادة الفحص لم يظهر بعد
    expect(find.text('جارٍ الفحص…'), findsOneWidget);
    expect(find.text('فحص مجدداً'), findsNothing);
    expect(find.text('أبرز التحسينات في هذا الإصدار'), findsNothing);

    // تصريف مهلة الفحص (1.2 ثانية) حتى لا يبقى مؤقّت معلّق
    await _finishCheck(w);
  });

  testWidgets('بعد الفحص: رسالة أحدث إصدار والتحسينات الثلاثة', (w) async {
    await _openDialog(w);
    await _finishCheck(w);

    expect(find.text('أنت تستخدم أحدث إصدار!'), findsOneWidget);
    expect(find.text('أحدث إصدار'), findsOneWidget);
    expect(find.text('أبرز التحسينات في هذا الإصدار'), findsOneWidget);
    expect(find.text('فحص مجدداً'), findsOneWidget);
    expect(find.text('إغلاق'), findsWidgets);

    expect(find.text('تسريع تنفيذ الطلبات والشحن الفوري'), findsOneWidget);
    expect(find.text('ميزة تحديد نسبة الربح وتسعير الزبائن'), findsOneWidget);
    expect(find.text('شريط سفلي مبسّط وقائمة علوية سريعة'), findsOneWidget);
  });

  testWidgets('لمسة التذكرة: قصّ التذكرة + ظل + خط تثقيب رأسي', (w) async {
    await _openDialog(w);
    await _finishCheck(w);

    expect(_hasTicketClipped(w), isTrue);

    final clipper = w
        .widgetList<ClipPath>(find.byType(ClipPath))
        .map((c) => c.clipper)
        .whereType<TicketPassClipper>()
        .first;
    expect(clipper.notchPositionFraction, 0.5);

    expect(_hasPainter(w), isTrue);

    // خط التثقيب يمتد مع معظم ارتفاع التذكرة (IntrinsicHeight + stretch)
    final ticketRect = w.getRect(
      find.byWidgetPredicate(
        (widget) => widget is ClipPath && widget.clipper is TicketPassClipper,
      ),
    );
    final tearRect = w.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is VerticalDashedLinePainter,
      ),
    );
    expect(tearRect.height, greaterThan(ticketRect.height * 0.7));

    final shadowed = w
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .any((p) => p.painter is TicketPassShadowPainter);
    final bordered = w
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .any((p) => p.foregroundPainter is TicketPassBorderPainter);
    expect(shadowed, isTrue);
    expect(bordered, isTrue);
  });

  testWidgets('على 320dp: لا طفو تخطيط والتحسينات تبقى مقروءة', (w) async {
    await _openDialog(w, width: 320);
    await _finishCheck(w);

    expect(find.text('أنت تستخدم أحدث إصدار!'), findsOneWidget);
    expect(find.text(UpdateCheckDialog.versionLabel), findsOneWidget);
    expect(find.text('شريط سفلي مبسّط وقائمة علوية سريعة'), findsOneWidget);
    // أخطاء RenderFlex وحدها تُفشل الاختبار، وأخطاء الخطوط مُتجاهَلة عمداً
    expect(
      _collected.where((e) => '$e'.contains('RenderFlex')),
      isEmpty,
      reason: _collected.map((e) => '$e').join('\n'),
    );
  });

  testWidgets('زر فحص مجدداً يعيد النافذة إلى حالة الفحص', (w) async {
    await _openDialog(w);
    await _finishCheck(w);

    await w.tap(find.text('فحص مجدداً'));
    await w.pump();
    await _settle(w, ms: 200);

    expect(find.text('جاري فحص التحديثات...'), findsOneWidget);
    expect(find.text('أبرز التحسينات في هذا الإصدار'), findsNothing);

    // تصريف مهلة الفحص كي لا يبقى مؤقّت معلّق عند نهاية الاختبار
    await w.pump(const Duration(milliseconds: 1400));
    await _settle(w);
  });
}
