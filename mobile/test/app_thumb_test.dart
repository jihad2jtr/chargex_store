import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/models/app_model.dart';
import 'package:layan_chargex/widgets/app_thumb.dart';

/// مصغّرات التطبيقات في قوائم لوحة الأدمن يجب أن تعرض الأيقونة المربعة
/// (assets/icons) كما يراها العميل، لا فنّ البطاقة الأفقي المقتطع.
///
/// لا google_fonts هنا: AppThumb لا يرسم نصاً، فلا استثناءات مطلوبة.
void main() {
  AppItemModel buildApp(String iconUrl, String name) => AppItemModel(
    id: 'app-1',
    name: name,
    iconUrl: iconUrl,
    appType: 'game',
    isActive: true,
    sortOrder: 0,
  );

  Future<String?> renderedAsset(WidgetTester tester, AppItemModel app) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppThumb(app: app, size: 44)),
      ),
    );
    await tester.pump();
    if (find.byType(Image).evaluate().isEmpty) return null;
    final Image image = tester.widget(find.byType(Image));
    final Object provider = image.image;
    return provider is AssetImage ? provider.assetName : null;
  }

  testWidgets('AppThumb: مسار بطاقة -> أيقونة مربعة بالعنوان نفسه', (
    tester,
  ) async {
    expect(
      await renderedAsset(
        tester,
        buildApp('assets/cards/pubg-mobile.png', 'ببجي موبايل'),
      ),
      'assets/icons/pubg-mobile.png',
    );
  });

  testWidgets('AppThumb: بلا صورة مخزّنة -> الأيقونة تُستنتج من الاسم', (
    tester,
  ) async {
    expect(
      await renderedAsset(tester, buildApp('', 'Roblox')),
      'assets/icons/roblox.png',
    );
    expect(
      await renderedAsset(tester, buildApp('', 'شاهد')),
      'assets/icons/shahid.png',
    );
  });

  testWidgets('AppThumb: أيقونة مختارة صراحةً تمر كما هي', (tester) async {
    expect(
      await renderedAsset(tester, buildApp('assets/icons/tod.png', 'تود')),
      'assets/icons/tod.png',
    );
  });

  testWidgets('AppThumb: صور الأدمن الخاصة لا تُبدل بأيقونة المشروع', (
    tester,
  ) async {
    // رابط خارجي -> NetworkImage لا AssetImage
    expect(
      await renderedAsset(tester, buildApp('https://cdn/x.png', 'تطبيق غريب')),
      isNull,
    );
    // مسار مرفوع على السيرفر -> بديل رمادي، ولا تُفرض أيقونة المشروع
    final String? uploaded = await renderedAsset(
      tester,
      buildApp('/uploads/custom.png', 'تطبيق غريب'),
    );
    expect(uploaded, isNot(startsWith('assets/icons/')));
    expect(uploaded, isNot(startsWith('assets/cards/')));
  });
}
