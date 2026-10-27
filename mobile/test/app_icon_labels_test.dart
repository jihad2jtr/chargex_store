// سطر الاسم الأجنبي تحت الأيقونة في الشبكة: عربي + إنكليزي
// ملاحظة: google_fonts يحاول تنزيل الخطوط في الاختبارات فتُستهلك استثناءاتها هنا.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/constants/app_icon_assets.dart';
import 'package:layan_chargex/models/app_model.dart';
import 'package:layan_chargex/widgets/app_icon_tile.dart';

/// يصيّر الخلية بخلية بعرض [cellWidth] ويعيد أخطاء الفيض الطبغي فقط
/// (استثناءات google_fonts مستثناة لأنها تحاول تنزيل الخطوط بلا شبكة).
/// Center ضروري: home يعطي قيوداً مشدودة (800x600) فيتجاهل SizedBox عرضه.
Future<List<String>> _renderTile(
  WidgetTester w,
  String name,
  String iconUrl, {
  double cellWidth = 84,
}) async {
  await w.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: cellWidth,
            height: AppIconTile.tileHeightFor(cellWidth),
            child: AppIconTile(
              app: AppItemModel(
                id: 'x',
                name: name,
                iconUrl: iconUrl,
                appType: 'game',
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await w.pumpAndSettle();
  final List<String> overflow = <String>[];
  Object? error;
  while ((error = w.takeException()) != null) {
    final String text = error.toString();
    if (text.contains('OVERFLOW') || text.contains('overflow')) {
      overflow.add(text);
    }
  }
  return overflow;
}

void main() {
  group('englishNameForApp', () {
    test('مسار البطاقة وحده يكفي لمعرفة الاسم الأجنبي', () {
      expect(
        englishNameForApp(iconUrl: 'assets/cards/pubg-mobile.png', name: ''),
        'PUBG Mobile',
      );
      expect(
        englishNameForApp(iconUrl: '', name: 'ببجي موبايل'),
        'PUBG Mobile',
      );
    });

    test('اسم عربي من سجل الأيقونات الإضافية -> اسم السجل', () {
      expect(englishNameForApp(iconUrl: '', name: 'شاهد'), 'Shahid');
      expect(
        englishNameForApp(iconUrl: 'assets/icons/uber.png', name: ''),
        'Uber',
      );
    });

    test('بلا اسم وبلا مسار -> null', () {
      expect(englishNameForApp(iconUrl: '', name: ''), isNull);
    });

    test('منتج مجهول في المكتبة -> null', () {
      expect(englishNameForApp(iconUrl: '', name: 'شاحن جداري سريع'), isNull);
    });
  });

  testWidgets('الخلية تعرض العربي فوق الإنكليزي', (w) async {
    expect(
      await _renderTile(w, 'ببجي موبايل', 'assets/cards/pubg-mobile.png'),
      isEmpty,
    );
    expect(find.text('ببجي موبايل'), findsOneWidget);
    expect(find.text('PUBG Mobile'), findsOneWidget);

    // العربي أعلى الإنكليزي عمودياً
    final double yArabic = w.getTopLeft(find.text('ببجي موبايل')).dy;
    final double yEnglish = w.getTopLeft(find.text('PUBG Mobile')).dy;
    expect(yArabic, lessThan(yEnglish));
  });

  testWidgets('اسم طويل لا يفيض عن الخلية رغم السطرين', (w) async {
    expect(
      await _renderTile(
        w,
        'بطاقة هدايا بلايستيشن إضافية للطبعة الدولية',
        'assets/cards/playstation.png',
        cellWidth: 74,
      ),
      isEmpty,
    );
    expect(find.text('PlayStation Network (PSN)'), findsOneWidget);
  });

  testWidgets('الاسم الأجنبي لا يتكرر في سطرين', (w) async {
    expect(await _renderTile(w, 'Free Fire', ''), isEmpty);
    expect(find.text('Free Fire'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('منتج مجهول يكتفي بسطر الاسم المخزّن', (w) async {
    expect(await _renderTile(w, 'شاحن جداري سريع', ''), isEmpty);
    expect(find.text('شاحن جداري سريع'), findsOneWidget);
    // لا سطر ثانٍ على أي حال: الخلية فيها نص واحد فقط
    expect(find.byType(Text), findsOneWidget);
  });
}
