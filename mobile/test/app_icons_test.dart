// كل منتج له أيقونة مربعة في assets/icons/: 40 بطاقة كتالوج + 45 أيقونة إضافية
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/constants/app_icon_assets.dart';
import 'package:layan_chargex/core/constants/card_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('40 بطاقة كتالوج لها أيقونة في assets/icons', () async {
    expect(kBuiltinCardAssets.length, 40);
    for (final asset in kBuiltinCardAssets) {
      final String? icon = builtinIconAssetForCard(asset.assetPath);
      expect(icon, isNotNull, reason: 'بدون أيقونة: ${asset.assetPath}');
      final ByteData data = await rootBundle.load(icon!);
      expect(data.lengthInBytes, greaterThan(300), reason: icon);
    }
  });

  test('45 أيقونة إضافية معلنة وقابلة للتحميل', () async {
    expect(kBuiltinIconAssets.length, 45);
    final slugs = kBuiltinIconAssets.map((a) => a.slug).toSet();
    expect(slugs.length, kBuiltinIconAssets.length, reason: 'slug مكرر');

    // لا تعارض مع بطاقات الكتالوج (نفس الاسم = نفس الملف)
    final cardSlugs = kBuiltinCardAssets
        .map((c) => c.assetPath.split('/').last.replaceAll('.png', ''))
        .toSet();
    expect(slugs.intersection(cardSlugs), isEmpty);

    for (final asset in kBuiltinIconAssets) {
      final ByteData data = await rootBundle.load(asset.assetPath);
      expect(data.lengthInBytes, greaterThan(300), reason: asset.assetPath);
    }
  });

  test('ملفات الأيقونات على القرص مطابقة للسجل', () {
    final onDisk = Directory('assets/icons')
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split(Platform.pathSeparator).last)
        .toSet();
    final declared = <String>{
      for (final c in kBuiltinCardAssets) c.assetPath.split('/').last,
      for (final a in kBuiltinIconAssets) a.assetPath.split('/').last,
    };
    expect(onDisk.difference(declared), isEmpty, reason: 'ملفات غير معلنة');
    expect(declared.difference(onDisk), isEmpty, reason: 'ملفات ناقصة');
  });

  test('حلّ الأيقونة من الاسم (عربي وإنكليزي وslug ومسار)', () {
    expect(builtinIconAssetForQuery('شاهد'), 'assets/icons/shahid.png');
    expect(builtinIconAssetForQuery('Shahid VIP'), 'assets/icons/shahid.png');
    expect(
      builtinIconAssetForQuery('Counter-Strike 2'),
      'assets/icons/counter-strike-2.png',
    );
    expect(
      builtinIconAssetForQuery('CS2'),
      'assets/icons/counter-strike-2.png',
    );
    expect(
      builtinIconAssetForQuery('builtin:talabat'),
      'assets/icons/talabat.png',
    );
    expect(
      builtinIconAssetForQuery('assets/icons/tod.png'),
      'assets/icons/tod.png',
    );
    expect(builtinIconAssetForQuery('أنغامي'), 'assets/icons/anghami.png');

    // الاسم الطويل لا يخلط بين نسختين من نفس اللعبة
    expect(
      builtinIconAssetExact('فري فاير ماكس'),
      'assets/icons/free-fire-max.png',
    );
    expect(builtinIconAssetExact('فري فاير'), isNull);
    expect(builtinIconAssetForQuery('منتج غير معروف إطلاقًا'), isNull);
  });

  test('تصنيفات السجل صالحة وتُستعمل في منتقي لوحة الأدمن', () {
    for (final asset in kBuiltinIconAssets) {
      expect(
        asset.category,
        anyOf('game', 'app', 'service'),
        reason: 'تصنيف خاطئ: ${asset.slug}',
      );
    }
    expect(
      kBuiltinIconAssets.where((a) => a.category == 'game').length,
      16,
      reason: 'ألعاب جديدة',
    );
    expect(
      kBuiltinIconAssets.where((a) => a.category == 'service').length,
      24,
      reason: 'فيديو/موسيقى + أدوات',
    );
    expect(
      kBuiltinIconAssets.where((a) => a.category == 'app').length,
      5,
      reason: 'تطبيقات خدمة',
    );
  });

  test('الأيقونة والبطاقة مقرونتان ذهاباً وإياباً', () {
    expect(
      builtinCardAssetForIcon('assets/icons/pubg-mobile.png'),
      'assets/cards/pubg-mobile.png',
    );
    // أيقونة بلا بطاقة مقابلة تبقى كما هي
    expect(builtinCardAssetForIcon('assets/icons/shahid.png'), isNull);
    expect(builtinCardAssetForIcon('assets/cards/spotify.png'), isNull);

    // حلّ الاسم المركّب (استعمال البطاقة أولاً ثم السجل)
    expect(
      builtinIconAssetForName('ببجي موبايل'),
      'assets/icons/pubg-mobile.png',
    );
    expect(
      builtinIconAssetForName('كاونتر سترايك 2'),
      'assets/icons/counter-strike-2.png',
    );
    expect(builtinIconAssetForName('لا شيء بهذا الاسم'), isNull);
  });
}
