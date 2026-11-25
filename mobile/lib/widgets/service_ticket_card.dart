import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_icon_assets.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import 'digital_pass_card.dart';
import 'smooth_network_image.dart';
import 'tactile_scale.dart';

/// كرت خدمة موحّد بأسلوب التذكرة السويسرية الفاتحة (صفحة الأرقام + صفحة الخدمات):
/// منصة عرض هادئة للشعار، بطاقة بيضاء واضحة للاسم والتفاصيل، خط تثقيب متناسق
/// مع فتحتي الجنب، وكعب سفلي دافئ للسعر أو خيارات الباقات.
class ServiceTicketCard extends StatelessWidget {
  /// الاسم العربي الذي يملأ تبويب الاسم
  final String name;

  /// السعر أو وصف ما يعرضه الكرت في تبويبه الأسفل
  final String priceText;

  /// وسم الزاوية (نوع الخدمة) ولونه
  final String tag;
  final Color tagColor;

  /// الرمز الخام كما يخزّنه الأدمن: مسار أصل أو رابط خارجي
  final String iconRaw;

  /// بذور البحث عن الأيقونة بالاسم حين لا يكون الرمز المخزّن كافياً
  final List<String> iconSeeds;

  /// بذرة الحرف الذي يملأ أرض التذكرة حين لا صورة ولا اسم
  final String letterSeed;

  /// سطر أجنبي خافت تحت الاسم (يُرسم باتجاه ltr)
  final String foreign;

  /// سطر مساعد إضافي: عدد الدول أو وصف الخدمة
  final String metaText;

  /// خدمة تطلب بيانات سرية: قفل صغير في الزاوية المقابلة
  final bool sensitive;

  final VoidCallback onTap;

  const ServiceTicketCard({
    super.key,
    required this.name,
    required this.priceText,
    required this.tag,
    required this.tagColor,
    required this.onTap,
    this.iconRaw = '',
    this.iconSeeds = const <String>[],
    this.letterSeed = '',
    this.foreign = '',
    this.metaText = '',
    this.sensitive = false,
  });

  /// رمز التطبيق الذي يملأ الكرت: الرمز المخزّن ثم الأسماء العربي والإنجليزي
  /// ورمز الخدمة
  String? _findIconAsset() {
    final cleanIcon = iconRaw.trim();
    if (cleanIcon.isNotEmpty) {
      if (cleanIcon.startsWith('assets/')) return cleanIcon;
      final direct = builtinIconAssetExact(cleanIcon);
      if (direct != null) return direct;
      final byQuery = builtinIconAssetForQuery(cleanIcon);
      if (byQuery != null) return byQuery;
    }
    for (final seed in iconSeeds) {
      if (seed.trim().isEmpty) continue;
      final found = iconAssetForApp(iconUrl: cleanIcon, name: seed.trim());
      if (found != null) return found;
    }
    return null;
  }

  /// رابط صورة خارجي اختاره الأدمن بدل رمز مخزّن
  String? get _networkCover {
    final raw = iconRaw.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return null;
  }

  // هندسة التذكرة: حافة 15 مع فتحتي تثقيب عند خط الكعب السفلي
  static const double _radius = 15;
  static const double _notch = 5.5;
  static const double _seamHeight = 1;
  static const double _stubBodyHeight = 28;
  static const double _stubHeight = _seamHeight + _stubBodyHeight;

  /// ارتفاع الكعب السفلي تحت خط التثقيب
  static const double tabsHeight = _stubHeight;

  @override
  Widget build(BuildContext context) {
    final String? iconAsset = _findIconAsset();
    final String? networkCover = iconAsset == null ? _networkCover : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double height = constraints.maxHeight;
        final double ceiling = height > 0
            ? (height - _radius - _notch) / height
            : 0.78;
        final double upper = ceiling > 0.55 ? ceiling : 0.55;
        final double notchFraction = height > 0
            ? ((height - _stubHeight) / height).clamp(0.55, upper).toDouble()
            : 0.80;

        return RepaintBoundary(
          child: TactileScale(
            onTap: onTap,
            child: CustomPaint(
              painter: TicketPassShadowPainter(
                cornerRadius: _radius,
                notchRadius: _notch,
                notchPositionFraction: notchFraction,
                shadowColor: AppColors.slate900.withValues(alpha: 0.14),
                elevation: 3.0,
              ),
              child: CustomPaint(
                foregroundPainter: TicketPassBorderPainter(
                  cornerRadius: _radius,
                  notchRadius: _notch,
                  notchPositionFraction: notchFraction,
                  borderColor: AppColors.outline,
                  borderWidth: 1.0,
                ),
                child: ClipPath(
                  clipper: TicketPassClipper(
                    cornerRadius: _radius,
                    notchRadius: _notch,
                    notchPositionFraction: notchFraction,
                  ),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. منصة عرض الشعار وشارة النوع
                        Expanded(
                          child: _visualStage(
                            iconAsset: iconAsset,
                            networkCover: networkCover,
                          ),
                        ),
                        // 2. شريط الاسم والتفاصيل على خلفية بيضاء صافية
                        _infoBand(),
                        // 3. خط التثقيب الواصل بين فتحتي التذكرة
                        _perforationSeam(),
                        // 4. كعب السعر أو خيارات الباقات أسفل التذكرة
                        _priceStub(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// خلفية ناعمة فوق الكرت تُبرز الشعار وتحمل شارة النوع وقفل الخصوصية
  Widget _visualStage({
    required String? iconAsset,
    required String? networkCover,
  }) {
    final Color topWash = Color.lerp(tagColor, Colors.white, 0.90)!;
    final Color bottomWash = Color.lerp(tagColor, Colors.white, 0.96)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topWash, bottomWash],
        ),
        border: const Border(
          bottom: BorderSide(color: AppColors.slate100, width: 0.9),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 23, 7, 5),
            child: _artworkContent(
              iconAsset: iconAsset,
              networkCover: networkCover,
            ),
          ),
          PositionedDirectional(
            top: 5,
            start: 6,
            end: 6,
            child: Row(
              children: [
                Flexible(child: _typeTag()),
                if (sensitive) ...[
                  const SizedBox(width: 4),
                  _sensitiveLock(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _artworkContent({
    required String? iconAsset,
    required String? networkCover,
  }) {
    if (iconAsset != null) {
      final bool isLandscapeCard = iconAsset.startsWith('assets/cards/');
      if (isLandscapeCard) {
        return _showcaseFrame(
          Image.asset(
            iconAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _monogramContent(),
          ),
        );
      }
      return Center(
        child: _squircleFrame(
          Image.asset(
            iconAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _monogramContent(),
          ),
        ),
      );
    }

    if (networkCover != null) {
      return _showcaseFrame(
        SmoothNetworkImage(
          url: networkCover,
          fit: BoxFit.cover,
          cacheWidth: 360,
          placeholderBuilder: (_) => _monogramContent(),
          errorBuilder: (_) => _monogramContent(),
        ),
      );
    }

    return Center(child: _squircleFrame(_monogramContent()));
  }

  /// إطار مربع ناعم للشعارات المربعة أو الحرف البديل
  Widget _squircleFrame(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double side = math
            .min(constraints.maxWidth, constraints.maxHeight)
            .clamp(32.0, 56.0);
        final double r = (side * 0.27).clamp(10.0, 15.0);

        return Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.slate900.withValues(alpha: 0.11),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular((r - 1.5).clamp(8.0, 14.0)),
            child: child,
          ),
        );
      },
    );
  }

  /// إطار عرض أفقي للبطاقات العريضة والصور الخارجية
  Widget _showcaseFrame(Widget child) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(9.5), child: child),
    );
  }

  /// منطقة الاسم العربي والأسطر المساعدة بخطوط واضحة فوق خلفية بيضاء
  Widget _infoBand() {
    final bool hasForeign = foreign.isNotEmpty;
    final bool hasMeta = metaText.isNotEmpty;

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              maxLines: (hasForeign && hasMeta) ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 10.4,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
                height: 1.15,
              ),
            ),
            if (hasForeign) ...[
              const SizedBox(height: 1),
              Text(
                foreign,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: AppTypography.cairo(
                  fontSize: 8.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate400,
                  height: 1.15,
                ),
              ),
            ],
            if (hasMeta) ...[
              const SizedBox(height: 1.5),
              Text(
                metaText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.cairo(
                  fontSize: 8.6,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate500,
                  height: 1.15,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// خط التثقيب الأفقي بين جسم التذكرة وكعب السعر
  Widget _perforationSeam() {
    return ColoredBox(
      color: AppColors.amberCream,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _notch + 2),
        child: CustomPaint(
          painter: DashedLinePainter(
            color: AppColors.slate300,
            dashWidth: 4,
            dashSpace: 3,
          ),
          size: const Size(double.infinity, _seamHeight),
        ),
      ),
    );
  }

  /// كعب السعر أسفل التذكرة: خلفية كهرمانية دافئة موحّدة مع بطاقة الباقات
  Widget _priceStub() {
    final bool isBundle = priceText == 'باقات متعددة';

    return Container(
      height: _stubBodyHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFDF5), Color(0xFFFEF3C7)],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isBundle ? Icons.layers_outlined : Icons.bolt_rounded,
            size: isBundle ? 10.5 : 11.5,
            color: AppColors.secondaryBright,
          ),
          const SizedBox(width: 2.5),
          Flexible(
            child: Text(
              priceText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: isBundle ? 9.8 : 10.8,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// قفل على زاوية كرت الخدمة التي تطلب بيانات سرية
  Widget _sensitiveLock() {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: AppColors.roseWash,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.roseBorder, width: 0.8),
      ),
      child: const Icon(
        Icons.lock_outline_rounded,
        size: 10,
        color: AppColors.roseDeep,
      ),
    );
  }

  /// وسم صغير أعلى الكرت: خلفية ناعمة وحد رقيق بلون الفئة مع خط مقروء داكن
  Widget _typeTag() {
    final Color bg = Color.lerp(tagColor, Colors.white, 0.86)!;
    final Color fg = Color.lerp(tagColor, AppColors.slate900, 0.45)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tagColor.withValues(alpha: 0.30), width: 0.7),
      ),
      child: Text(
        tag,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.cairo(
          fontSize: 7.6,
          fontWeight: FontWeight.w900,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }

  /// حرف بديل بتدرج متناسق مع هوية الفئة عند عدم توفر صورة للخدمة
  Widget _monogramContent() {
    final letter = name.isNotEmpty
        ? name.substring(0, 1)
        : (letterSeed.isEmpty ? '#' : letterSeed.substring(0, 1).toUpperCase());
    final Color start = Color.lerp(tagColor, AppColors.slate800, 0.25)!;
    final Color end = Color.lerp(tagColor, AppColors.slate900, 0.65)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: AppTypography.fintechBadge(color: Colors.white, fontSize: 22),
        ),
      ),
    );
  }
}
