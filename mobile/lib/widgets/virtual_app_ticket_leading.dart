import 'package:flutter/material.dart';

import '../core/constants/app_icon_assets.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// لغة موحّدة لتذاكر الأرقام في لوحات الأدمن: لون هوية ثابت لكل تطبيق
/// وأيقونته الحقيقية من حزمة الأصول (أو الشبكة أو حرف الاسم). تُستعمل في:
/// منتجات الأرقام المضافة، مراقبة الجودة، الخدمات اليدوية، وسجل التفعيلات،
/// فتملك كل تذكرة هوية بصرية لتطبيقها بدل الأيقونات الثابتة.

/// لوحة الهوية: سيان/كهرماني/زمرد/بنفسجي/نحاسي/قرمزي — ألوان النظام نفسها
const List<Color> _kPalette = [
  AppColors.primaryBlue,
  AppColors.ticketAmber,
  AppColors.emerald,
  AppColors.violet,
  AppColors.slate700,
  AppColors.rose,
];

/// لون ثابت لكل تطبيق مهما تبدّل ترتيب القائمة: هاش FNV-1a على المعرّف،
/// لأنه مستقر عبر التشغيلات على خلاف Object.hash
Color virtualAppAccent(String seed) {
  final s = seed.toLowerCase();
  if (s.isEmpty) return AppColors.slate700;
  var h = 0x811c9dc5;
  for (final u in s.runes) {
    h = ((h ^ u) * 0x01000193) & 0x7fffffff;
  }
  return _kPalette[h % _kPalette.length];
}

/// الأيقونة من سجل الأصول: مسار حزمة صريح، ثم السجل بالاسم والمفتاح.
/// يعيد null إن لم تُعرف — فيُلجأ للشبكة أو للحرف.
String? virtualAppIconAsset({
  required String iconRaw,
  String appKey = '',
  required String name,
}) {
  final v = iconRaw.trim();
  if (v.isNotEmpty && !v.startsWith('http')) {
    if (v.startsWith('assets/')) return v;
    final direct = builtinIconAssetExact(v) ?? builtinIconAssetForQuery(v);
    if (direct != null) return direct;
  }
  final seed = appKey.isNotEmpty ? appKey : v;
  return iconAssetForApp(iconUrl: seed, name: name);
}

/// مربّع أيقونة التذكرة: صورة من الأصول أو شبكة، وحرف الاسم بلون هوية
/// التطبيق بديلاً أخيراً. يزن [size] بكسل بمربّع بحواف دائرية خفيفة.
class VirtualAppLeading extends StatelessWidget {
  final String iconRaw;
  final String appKey;
  final String name;
  final Color accent;
  final double size;

  const VirtualAppLeading({
    super.key,
    required this.iconRaw,
    this.appKey = '',
    required this.name,
    required this.accent,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final asset = virtualAppIconAsset(
      iconRaw: iconRaw,
      appKey: appKey,
      name: name,
    );
    final raw = iconRaw.trim();
    final networkUrl =
        (raw.startsWith('http') ? raw : '') +
        (raw.startsWith('http') ? '' : _httpFromAppKey());
    final radius = (size * 0.28).clamp(9.0, 14.0);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: asset != null
          ? Image.asset(
              asset,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _letter(networkUrl),
            )
          : networkUrl.isNotEmpty
          ? Image.network(
              networkUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _letter(''),
            )
          : _letter(''),
    );
  }

  String _httpFromAppKey() {
    // appKey قد يحمل رابطاً مخزّنه في بعض المزودات: يُقبل كصورة شبكية
    final k = appKey.trim();
    return k.startsWith('http') ? k : '';
  }

  Widget _letter(String networkUrl) {
    if (networkUrl.isNotEmpty) {
      // الأصول المحلية فشلت والشبكة ممكنة: تُجرَّب مرة قبل الرجوع للحرف
      return Image.network(
        networkUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _letterGlyph(),
      );
    }
    return _letterGlyph();
  }

  Widget _letterGlyph() {
    return Text(
      name.isEmpty ? '?' : name.characters.first,
      style: AppTypography.cairo(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w900,
        color: accent,
      ),
    );
  }
}
