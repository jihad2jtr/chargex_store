import 'package:flutter/material.dart';

import '../core/constants/app_icon_assets.dart';
import '../core/constants/card_assets.dart';
import '../core/theme/app_typography.dart';
import '../models/app_model.dart';

/// أيقونة تطبيق/لعبة بنمط أيقونات شاشة الهاتف:
/// مربّع بحواف دائرية (squircle) يحمل شعار التطبيق + الاسم أسفله.
class AppIconTile extends StatefulWidget {
  final AppItemModel app;
  final VoidCallback onTap;

  const AppIconTile({super.key, required this.app, required this.onTap});

  /// في تصاميم بطاقات الكتالوج يشغل الشعار نصف البطاقة الأيسر تقريباً،
  /// لذا نعرض هذه النسبة فقط داخل الأيقونة المربّعة.
  static const double artworkVisibleFraction = 0.46;

  /// ارتفاع سطر الاسم العربي (سطران كحد أقصى)
  static const double nameHeight = 26.0;

  /// ارتفاع سطر الاسم الأجنبي تحت العربي
  static const double foreignHeight = 12.0;

  /// الفراغ اليسير بين السطر العربي والسطر الأجنبي
  static const double nameForeignGap = 3.0;

  /// إجمالي ارتفاع سطري الاسم تحت الأيقونة (مع الفراغ بينهما)
  static const double labelHeight = nameHeight + nameForeignGap + foreignHeight;
  static const double labelGap = 6.0;

  /// الارتفاع الكلي المطلوب لخلية الشبكة عند عرض بعرض [cellWidth]
  static double tileHeightFor(double cellWidth) =>
      cellWidth + labelGap + labelHeight;

  @override
  State<AppIconTile> createState() => _AppIconTileState();
}

class _AppIconTileState extends State<AppIconTile> {
  bool _pressed = false;

  /// نمط أي حرف عربي في النص — يُفرَّق به الاسم العربي عن الاسم الأجنبي
  static final RegExp _arabicLetter = RegExp('[\u0600-\u06FF]');

  /// مطابقة اسم التطبيق/اللعبة مع بطاقات الشعارات المرفقة داخل التطبيق
  static String? _matchBuiltinAsset(String query) =>
      builtinCardAssetForQuery(query);

  /// يدعم: assets/... و https://... و `builtin:<key>` وأسماء الملفات المجرّدة
  static ImageProvider? _directProvider(String raw) {
    String value = raw.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('builtin:')) {
      value = value.substring('builtin:'.length).trim();
      if (value.isEmpty) return null;
      if (value.endsWith('.png') ||
          value.endsWith('.jpg') ||
          value.endsWith('.webp') ||
          value.contains('/')) {
        return AssetImage(
          value.startsWith('assets/') ? value : 'assets/cards/$value',
        );
      }
      final String? asset = _matchBuiltinAsset(value);
      return asset == null ? null : AssetImage(asset);
    }

    if (value.startsWith('assets/')) return AssetImage(value);
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return NetworkImage(value);
    }
    // مسار نسبي من الخادم لا يمكن تحميله مباشرة
    if (value.startsWith('/')) return null;

    if (!value.contains('/') &&
        RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false).hasMatch(value)) {
      return AssetImage('assets/cards/$value');
    }

    final String? asset = _matchBuiltinAsset(value);
    return asset == null ? null : AssetImage(asset);
  }

  static ImageProvider? _resolveProvider(AppItemModel app) {
    final ImageProvider? direct = _directProvider(app.iconUrl);
    if (direct != null) return direct;
    final String? asset = _matchBuiltinAsset(app.name);
    return asset == null ? null : AssetImage(asset);
  }

  /// الأيقونة المربعة المرفقة في assets/icons/ لهذا المنتج، أو null.
  /// المنطق مشترك مع قوائم لوحة الأدمن عبر iconAssetForApp.
  static String? _squareIconFor(AppItemModel app) =>
      iconAssetForApp(iconUrl: app.iconUrl, name: app.name);

  /// سطر الاسم الأجنبي تحت الأيقونة (من بطاقات الكتالوج أو سجل الأيقونات).
  /// يُحجب إذا كان الاسم المخزّن أجنبياً أصلاً أو مطابقاً للاسم الأجنبي.
  String? get _foreignName {
    final String stored = widget.app.name.trim();
    if (stored.isEmpty) return null;
    // اسم لاتيني: سطر واحد يكفي، وإلا يتكرر الاسم مرتين
    if (!_arabicLetter.hasMatch(stored)) return null;
    final String? en = englishNameForApp(
      iconUrl: widget.app.iconUrl,
      name: stored,
    );
    if (en == null || en.isEmpty) return null;
    return en.toLowerCase() == stored.toLowerCase() ? null : en;
  }

  static ({IconData icon, List<Color> gradient}) _fallbackStyle(
    String appType,
  ) {
    switch (appType.toLowerCase()) {
      case 'subscription':
        return (
          icon: Icons.card_membership_rounded,
          gradient: const [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
        );
      case 'service':
        return (
          icon: Icons.miscellaneous_services_rounded,
          gradient: const [Color(0xFFF59E0B), Color(0xFFB45309)],
        );
      case 'app':
        return (
          icon: Icons.apps_rounded,
          gradient: const [Color(0xFF0284C7), Color(0xFF0C4A6E)],
        );
      default:
        return (
          icon: Icons.sports_esports_rounded,
          gradient: const [Color(0xFF7C3AED), Color(0xFF4C1D95)],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = constraints.maxWidth;
        final double radius = (size * 0.27).clamp(14.0, 30.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.93 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconSquare(size, radius),
                const SizedBox(height: AppIconTile.labelGap),
                SizedBox(
                  height: AppIconTile.labelHeight,
                  width: size,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // الاسم المخزّن (عربي في الغالب) — يأخذ ارتفاعه الطبيعي
                      // (سطر أو سطران) مع فراغ يسير يفصله عن الاسم الأجنبي.
                      Text(
                        widget.app.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.cairo(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppIconTile.nameForeignGap),
                      // الاسم الأجنبي من مكتبة المشروع، إن عُرف
                      if (_foreignName case final String en)
                        Text(
                          en,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: AppTypography.cairo(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                            height: 1.15,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconSquare(double size, double radius) {
    final String? iconAsset = _squareIconFor(widget.app);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. الأيقونة المربعة تملأ المربّع كاملاً، أو الشعار مقتطعاً من البطاقة
            if (iconAsset != null)
              Image.asset(
                iconAsset,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => _buildCardArt(size),
              )
            else
              _buildCardArt(size),

            // 2. لمعة زجاجية علوية مثل أيقونات الهاتف
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size * 0.45,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. حد داخلي رقيق
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// الشعار مقتطعاً من فنّ البطاقة الأفقي (يقع الشعار في النصف الأيسر منها)،
  /// يُستخدم عندما لا توجد أيقونة مربعة مرفقة لهذا المنتج.
  Widget _buildCardArt(double size) {
    final ImageProvider? provider = _resolveProvider(widget.app);
    if (provider == null) return _buildFallback(size);

    final double artWidth = size / AppIconTile.artworkVisibleFraction;
    final double artHeight = artWidth / 1.5;

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: artWidth,
        maxWidth: artWidth,
        minHeight: artHeight,
        maxHeight: artHeight,
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          alignment: Alignment.centerLeft,
          errorBuilder: (ctx, err, stack) => _buildFallback(
            size,
            width: artWidth,
            height: artHeight,
            inOverflow: true,
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(
    double size, {
    double? width,
    double? height,
    bool inOverflow = false,
  }) {
    final style = _fallbackStyle(widget.app.appType);
    final Widget glyph = Icon(
      style.icon,
      size: size * 0.42,
      color: Colors.white.withValues(alpha: 0.92),
    );

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: style.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: inOverflow
            // مركز النافذة المرئية داخل الصندوق المقتطع
            ? Align(alignment: const Alignment(-0.54, 0), child: glyph)
            : Center(child: glyph),
      ),
    );
  }
}
