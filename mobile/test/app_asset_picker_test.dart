// منتقي صور المنتجات في لوحة الأدمن: أيقونة مربعة أو صورة بطاقة
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/widgets/app_asset_picker.dart';

/// لا استثناءات متوقعة داخل المنتقي؛ أي فيض تخطيط أو خطأ تحميل صورة سيظهر هنا
void _expectClean(WidgetTester w) {
  final Object? error = w.takeException();
  expect(error, isNull, reason: '$error');
}

typedef PickCallback =
    void Function(String path, String label, String category);

Future<void> _pump(WidgetTester w, PickCallback onSelect) async {
  await w.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: AppAssetPicker(selected: '', onSelected: onSelect),
            ),
          ),
        ),
      ),
    ),
  );
  await w.pumpAndSettle();
  _expectClean(w);
}

Finder _tiles(String prefix) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName.startsWith(prefix),
);

void main() {
  testWidgets('الوضع الافتراضي أيقونة ويعرض counts المكتبتين', (
    WidgetTester w,
  ) async {
    await _pump(w, (_, _, _) {});

    expect(
      find.text('85'),
      findsOneWidget,
    ); // أيقونة: 40 من البطاقات + 45 إضافية
    expect(find.text('40'), findsOneWidget); // بطاقات
    expect(_tiles('assets/icons/'), findsWidgets);
  });

  testWidgets('البحث بالاسم العربي يضيّق النتيجة ويختار المسار الصحيح', (
    WidgetTester w,
  ) async {
    String? picked;
    await _pump(w, (path, _, _) => picked = path);

    await w.enterText(find.byType(TextField).first, 'شاهد');
    await w.pumpAndSettle();
    _expectClean(w);

    expect(_tiles('assets/icons/'), findsOneWidget);
    await w.tap(_tiles('assets/icons/'));
    expect(picked, 'assets/icons/shahid.png');
  });

  testWidgets('التبديل إلى البطاقات يعرض assets/cards', (WidgetTester w) async {
    String? picked;
    await _pump(w, (path, _, _) => picked = path);

    await w.tap(find.text('صورة بطاقة'));
    await w.pumpAndSettle();
    _expectClean(w);

    expect(_tiles('assets/cards/'), findsWidgets);
    await w.tap(_tiles('assets/cards/').first);
    expect(picked, startsWith('assets/cards/'));
    expect(picked, endsWith('.png'));
  });

  testWidgets('تبويب الألعاب يخفي منتجات التطبيقات', (WidgetTester w) async {
    await _pump(w, (_, _, _) {});

    await w.tap(find.text('🎮 ألعاب'));
    await w.pumpAndSettle();
    _expectClean(w);
    await w.enterText(find.byType(TextField).first, 'أوبر');
    await w.pumpAndSettle();
    _expectClean(w);

    // «أوبر» تصنيفها تطبيق، فلا نتيجة تحت تبويب الألعاب
    expect(
      find.text('لا نتائج مطابقة — جرّب اسمًا آخر أو بدّل التبويب'),
      findsOneWidget,
    );
    expect(_tiles('assets/icons/'), findsNothing);
  });
}
