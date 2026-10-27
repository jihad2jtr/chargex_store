import 'package:flutter/material.dart';

import '../core/constants/app_icon_assets.dart';
import '../core/constants/card_assets.dart';
import '../models/app_model.dart';

/// صورة مصغّرة للتطبيق في قوائم لوحة الأدمن وقوائم الاختيار.
/// تعرض الأيقونة المربعة (assets/icons) كما يراها العميل في شبكة التطبيقات،
/// بدل فنّ البطاقة الأفقي المقتطع في مربّع صغير، وتقع إلى الصورة المخزّنة
/// (بطاقة أو رابط خارجي أو ملف مرفوع) إن لم تُعرف أيقونة للمنتج.
class AppThumb extends StatelessWidget {
  final AppItemModel app;
  final double size;
  final double radius;

  const AppThumb({
    super.key,
    required this.app,
    this.size = 44,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final String? icon = iconAssetForApp(iconUrl: app.iconUrl, name: app.name);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: icon == null
          ? buildSmartAppImage(app.iconUrl, width: size, height: size)
          : Image.asset(
              icon,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) =>
                  buildSmartAppImage(app.iconUrl, width: size, height: size),
            ),
    );
  }
}
