// الشريط العلوي يجب أن يلبس نفس لوحة ألوان الشريط السفلي العائم
// (خلفية darkNav + حدّ slate800 + عناصر slate800/700 ونصوص فاتحة).
// ملاحظة: الخط من google_fonts والصورة الشخصية من الشبكة تفشل في الاختبارات
// فتُستهلك استثناءاتها بعد التصيير.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/theme/app_colors.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/widgets/unified_tactile_header.dart';
import 'package:provider/provider.dart';

Future<void> _renderHeader(WidgetTester w) async {
  await w.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(width: 420, child: UnifiedTactileHeader()),
          ),
        ),
      ),
    ),
  );
  await w.pump();
  while (w.takeException() != null) {}
}

void main() {
  testWidgets('الشريط العلوي يستخدم لون الشريط السفلي الداكن', (w) async {
    await _renderHeader(w);

    final Container header = w.widget(
      find
          .descendant(
            of: find.byType(UnifiedTactileHeader),
            matching: find.byType(Container),
          )
          .first,
    );
    final BoxDecoration deco = header.decoration! as BoxDecoration;
    expect(deco.color, AppColors.darkNav);
    expect(deco.border!.top.color, AppColors.slate800);
  });

  testWidgets('لا تبقى أسطح فاتحة داخل الشريط: الاسم أبيض والأدوات داكنة', (
    w,
  ) async {
    await _renderHeader(w);

    // بلا مستخدم -> الاسم الافتراضي، ويجب أن يكون فاتحاً ليُقرأ على الداكن
    expect(w.widget<Text>(find.text('عميل JGO')).style!.color, Colors.white);

    final List<Color> surfaces = w
        .widgetList<Container>(
          find.descendant(
            of: find.byType(UnifiedTactileHeader),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .whereType<Color>()
        .toList();

    // لا يوجد أي لون أبيض أو رمادي فاتح بين أسطح الشريط
    expect(
      surfaces.where((c) => c == Colors.white || c == AppColors.slate50),
      isEmpty,
    );
  });

  // الشريط العلوي صار هوية مختصرة: الاسم + شارة الدور فقط، ومعرّف الآيدي
  // لم يعد معروضاً فيه (يبقى متاحاً من زر الباركود).
  testWidgets('الشريط العلوي لا يعرض معرّف الآيدي', (w) async {
    await _renderHeader(w);

    expect(find.text('عميل JGO'), findsOneWidget);
    expect(find.text('عميل'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(UnifiedTactileHeader),
        matching: find.textContaining('#'),
      ),
      findsNothing,
    );
  });
}
