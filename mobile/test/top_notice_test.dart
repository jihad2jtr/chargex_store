// التنبيهات كانت شريطاً أسفل الشاشة: لا يراه من يكتب ولا يشبه وصول الإشعار.
// هذا الاختبار يثبّت أنها تنزل في رأس الشاشة، وأنها تنصرف من تلقاء نفسها،
// وأن فعلَ الخبر يُنفَّذ مرةً واحدة، وأن الأحدث يحلُّ محلَّ سابقه.
// ووجهها الثاني: ما كُتب شريطَ أسفل الشاشة يُعرض تنبيهاً أعلاها بأرضيته وفعلِه
// ومدّتِه، فلا تتفرّق مواضعُ الخبر في التطبيق.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/theme/app_colors.dart';
import 'package:layan_chargex/core/theme/app_typography.dart';
import 'package:layan_chargex/widgets/top_notice.dart';

const Duration _hold = Duration(seconds: 2);

Future<void> _showNotice(
  WidgetTester w, {
  String title = 'وصل رقمك',
  String body = '5sim · 12345',
  Duration hold = _hold,
  String? actionLabel,
  VoidCallback? onAction,
}) async {
  await w.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('صفحة الأرقام')),
          body: Center(
            child: FilledButton(
              onPressed: () => TopNotice.show(
                context,
                title: title,
                body: body,
                hold: hold,
                actionLabel: actionLabel,
                onAction: onAction,
              ),
              child: const Text('أرسل خبراً'),
            ),
          ),
        ),
      ),
    ),
  );
  await w.tap(find.text('أرسل خبراً'));
  await w.pump();
  // أنهى التنبيهَ دخولَه
  await w.pump(const Duration(milliseconds: 400));
}

/// يُنهي المهلة ويُنحِي أثرها: لا يبقى مؤقّتٌ بعد الاختبار
Future<void> _drain(WidgetTester w, Duration hold) async {
  await w.pump(hold + const Duration(milliseconds: 800));
  await w.pumpAndSettle();
}

/// شاشةٌ فيها زرٌّ يُبلغ بشريطٍ كُتب على عهدة ScaffoldMessenger
Future<void> _showBar(WidgetTester w, SnackBar bar) async {
  await w.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('إدارة')),
          body: Center(
            child: FilledButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).showTopSnackBar(bar),
              child: const Text('أبلِغ'),
            ),
          ),
        ),
      ),
    ),
  );
  await w.tap(find.text('أبلِغ'));
  await w.pump();
  // أنهى التنبيهَ دخولَه
  await w.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('التنبيه ينزل في أعلى الشاشة لا في أسفلها', (
    WidgetTester w,
  ) async {
    await _showNotice(w);

    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('وصل رقمك'), findsOneWidget);
    expect(find.text('5sim · 12345'), findsOneWidget);

    final Size screen = w.view.physicalSize / w.view.devicePixelRatio;
    final Rect banner = w.getRect(find.byType(MaterialBanner));
    // رأسُ الشاشة: لا ينتصف فضلاً عن أن يبلغ طرفها السفلي
    expect(banner.top, lessThan(screen.height * 0.25));
    expect(banner.bottom, lessThan(screen.height * 0.5));
    // وملءُ العرض، فليس شريطاً عائماً يترك جانباً فارغاً
    expect(banner.width, closeTo(screen.width, 1));

    await _drain(w, _hold);
  });

  testWidgets('التنبيه ينصرف وحده بعد مهلته', (WidgetTester w) async {
    await _showNotice(w);
    expect(find.byType(MaterialBanner), findsOneWidget);

    await w.pump(_hold);
    await w.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('فعلُ الخبر يعمل مرةً واحدة ثم ينحى التنبيه', (
    WidgetTester w,
  ) async {
    int taps = 0;
    await _showNotice(w, actionLabel: 'عرض', onAction: () => taps++);

    await w.tap(find.text('عرض'));
    await w.pumpAndSettle();
    expect(taps, 1);
    expect(find.byType(MaterialBanner), findsNothing);

    // ومهلته التي أُنهيَت معه لا تنحِي خبراً جاء بعده
    await _drain(w, _hold);
  });

  testWidgets('شريطُ الأسفل يُعرَض تنبيهاً في رأس الشاشة بأرضيته', (
    WidgetTester w,
  ) async {
    await _showBar(
      w,
      const SnackBar(
        content: Text('تم حذف القالب'),
        backgroundColor: AppColors.slate900,
        // وأشكالُ الشريط لا تُنقل: البقية بأرضه وفعلِه ومدّته
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ),
    );

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('تم حذف القالب'), findsOneWidget);
    final MaterialBanner banner = w.widget<MaterialBanner>(
      find.byType(MaterialBanner),
    );
    expect(banner.backgroundColor, AppColors.slate900);

    final Size screen = w.view.physicalSize / w.view.devicePixelRatio;
    final Rect rect = w.getRect(find.byType(MaterialBanner));
    expect(rect.top, lessThan(screen.height * 0.25));
    expect(rect.width, closeTo(screen.width, 1));

    // وأرضيةٌ داكنة تحتاج نصاً فاتحاً وإلا ضاع الخبر عن القارئ
    final RenderParagraph para = w.renderObject<RenderParagraph>(
      find.text('تم حذف القالب'),
    );
    expect(para.text.style!.color, Colors.white);

    await _drain(w, const Duration(seconds: 4));
  });

  testWidgets('الأرضيةُ الفاتحة تنقلب إلى نصٍّ داكن ومن لا فعل له تنحية', (
    WidgetTester w,
  ) async {
    await _showBar(
      w,
      const SnackBar(
        content: Text('فرغ الحقل'),
        backgroundColor: AppColors.surfaceCard,
      ),
    );

    final RenderParagraph para = w.renderObject<RenderParagraph>(
      find.text('فرغ الحقل'),
    );
    expect(para.text.style!.color, AppColors.slate900);
    // وMaterialBanner لا يقبل أفعالاً فارغة، فلإغلاق نصيبٌ دائماً
    expect(find.byTooltip('إغلاق'), findsOneWidget);

    await _drain(w, const Duration(seconds: 4));
  });

  testWidgets('فعلُ الشريط يبقى فعلاً في التنبيه ثم ينحى', (
    WidgetTester w,
  ) async {
    int taps = 0;
    await _showBar(
      w,
      SnackBar(
        // وأغلبُ رسائل الشاشات مكتوبةٌ بهذا الخطّ، فلونَها ينزل مع التنبيه
        content: Text('حُفظ التعديل', style: AppTypography.cairo()),
        action: SnackBarAction(label: 'تراجع', onPressed: () => taps++),
        duration: const Duration(seconds: 3),
      ),
    );

    expect(find.text('تراجع'), findsOneWidget);
    final RenderParagraph para = w.renderObject<RenderParagraph>(
      find.text('حُفظ التعديل'),
    );
    expect(para.text.style!.color, Colors.white);

    await w.tap(find.text('تراجع'));
    await w.pumpAndSettle();
    expect(taps, 1);
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('مهلةُ الشريط تُنحّي التنبيه في أوانها', (WidgetTester w) async {
    await _showBar(
      w,
      const SnackBar(
        content: Text('خبرٌ قصير'),
        duration: Duration(seconds: 3),
      ),
    );

    await w.pump(const Duration(seconds: 1));
    expect(find.byType(MaterialBanner), findsOneWidget);

    await w.pump(const Duration(seconds: 2, milliseconds: 800));
    await w.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
  });

  test('لا رسالةَ في الشاشات تنزل أسفل الشاشة', () {
    // حارسٌ من أن يُكتَب خبرٌ جديدٌ في موضعٍ قد اعتاد صاحبه أن يرفع إليه البصر
    final RegExp bottomBar = RegExp(
      r'\.showSnackBar\(|\.hideCurrentSnackBar\(|\.clearSnackBars\(',
    );
    final List<String> culprits = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        // وملفُ التنبيه يُستثنى: ذُكر فيه الاسم القديم في شرحه
        .where((File f) => !f.path.endsWith('top_notice.dart'))
        .where((File f) => bottomBar.hasMatch(f.readAsStringSync()))
        .map((File f) => f.path)
        .toList();

    expect(culprits, isEmpty);
  });

  testWidgets('الخبر الأحدث يحلُّ محلَّ سابقه ولا يصطفّ خلفه', (
    WidgetTester w,
  ) async {
    int n = 0;
    await w.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    TopNotice.show(context, title: 'خبر ${++n}', hold: _hold),
                child: const Text('أرسل'),
              ),
            ),
          ),
        ),
      ),
    );

    for (int i = 0; i < 2; i++) {
      await w.tap(find.text('أرسل'));
      await w.pump();
      await w.pump(const Duration(milliseconds: 400));
    }

    // واحدٌ على الشاشة لا اثنان، وهو الأخير لا الأول
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text('خبر 2'), findsOneWidget);
    expect(find.text('خبر 1'), findsNothing);

    await _drain(w, _hold);
  });
}
