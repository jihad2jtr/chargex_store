// ترتيب أولوية الأيقونة داخل AppIconTile:
// صورة الأدمن (رابط/ملف مرفوع) > اسم مطابق للسجل > بطاقة الكتالوج > اسم قريب من السجل
// ملاحظة: google_fonts يحاول تنزيل الخطوط في الاختبارات فتُستهلك استثناءاته هنا.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/models/app_model.dart';
import 'package:layan_chargex/widgets/app_icon_tile.dart';

Future<List<String>> _renderedAssets(
  WidgetTester w,
  String name,
  String iconUrl,
) async {
  final AppItemModel app = AppItemModel(
    id: 'x',
    name: name,
    iconUrl: iconUrl,
    appType: 'game',
  );
  await w.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        // Center: home يعطي قيوداً مشدودة 800x600 فتُتجاهل أبعاد SizedBox
        child: Center(
          child: SizedBox(
            width: 80,
            height: AppIconTile.tileHeightFor(80),
            child: AppIconTile(app: app, onTap: () {}),
          ),
        ),
      ),
    ),
  );
  await w.pumpAndSettle();
  // استثناءات الخط (google_fonts) متوقعة بلا شبكة، أما فيض الطباعة فعيب
  final List<String> layoutErrors = <String>[];
  Object? error;
  while ((error = w.takeException()) != null) {
    final String text = error.toString();
    if (text.contains('overflow') || text.contains('OVERFLOW')) {
      layoutErrors.add(text);
    }
  }
  expect(layoutErrors, isEmpty);
  return w
      .widgetList<Image>(find.byType(Image))
      .map((i) => i.image)
      .whereType<AssetImage>()
      .map((p) => p.assetName)
      .toList();
}

void main() {
  testWidgets('AppIconTile يختار الأيقونة الصحيحة', (WidgetTester w) async {
    // بلا بطاقة -> من السجل الجديد
    expect(await _renderedAssets(w, 'شاهد', ''), ['assets/icons/shahid.png']);
    expect(await _renderedAssets(w, 'Counter-Strike 2', ''), [
      'assets/icons/counter-strike-2.png',
    ]);
    expect(await _renderedAssets(w, 'فري فاير ماكس', ''), [
      'assets/icons/free-fire-max.png',
    ]);

    // بطاقة كتالوج -> أيقونتها بنفس الاسم
    expect(
      await _renderedAssets(w, 'ببجي موبايل', 'assets/cards/pubg-mobile.png'),
      ['assets/icons/pubg-mobile.png'],
    );
    expect(await _renderedAssets(w, 'فري فاير', 'builtin:free-fire.png'), [
      'assets/icons/free-fire.png',
    ]);

    // صورة الأدمن لا تُستبدل بأيقونة مدمجة
    expect(
      await _renderedAssets(w, 'تطبيقي', 'assets/uploads/custom-logo.png'),
      isNot(contains(startsWith('assets/icons/'))),
    );

    // أيقونة مربعة مختارة صراحةً
    expect(await _renderedAssets(w, 'تطبيقي', 'assets/icons/tod.png'), [
      'assets/icons/tod.png',
    ]);

    // مجهول تماماً -> أيقونة رمزية بلا صورة
    expect(await _renderedAssets(w, 'منتج مجهول تمامًا', ''), isEmpty);
  });
}
