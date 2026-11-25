import 'package:flutter/material.dart';

import '../core/constants/app_icon_assets.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/product_model.dart';
import 'digital_pass_card.dart';
import 'smooth_network_image.dart';
import 'tactile_scale.dart';

/// بطاقة باقة (منتج) داخل شاشة التطبيق/اللعبة: تصميم تذكرة مستطيلة حديثة
/// تجمع شعار التطبيق أو نوع التسليم مع شريط لوني جانبي، وعنواناً بارزاً
/// يسهل مسحه سريعاً، مع خط تثقيب وكعب سعر واضح وزر شحن بارز.
class ProductListCard extends StatelessWidget {
  final ProductModel product;

  /// السعر المعروض للعميل (بعد هامش الوكيل إن وُجد)
  final double displayPrice;

  /// سعر التكلفة (قبل هامش الوكيل) — يُعرض فقط حين يفعّل الوكيل نسبته
  final double? costPrice;

  /// نص هامش الوكيل (اختياري): "+10% للزبون"
  final String? marginText;

  /// رصيد المستخدم لعرض تنبيه «رصيد ناقص» (اختياري)
  final double? balance;

  /// المقابل بالليرة السورية: سطر خافت تحت السعر بالدولار (اختياري)
  final String? sypPriceText;

  /// اسم التطبيق/اللعبة ورابط أو مسار أيقونتها لإظهار الهوية البصرية على الباقة
  final String? appName;
  final String? appIconUrl;

  final VoidCallback onTap;

  const ProductListCard({
    super.key,
    required this.product,
    required this.displayPrice,
    required this.onTap,
    this.costPrice,
    this.marginText,
    this.balance,
    this.sypPriceText,
    this.appName,
    this.appIconUrl,
  });

  static const double _radius = 18;
  static const double _notchRadius = 6.5;
  static const double _minHeight = 104;
  static const double _stubWidth = 110;

  // ------------------------------------------------------------ TYPE META

  ({IconData icon, String label, String hint, Color bg, Color fg}) _meta() {
    switch (product.type) {
      case 'codes':
        return (
          icon: Icons.confirmation_number_rounded,
          label: 'كود رقمي',
          hint: product.availableCodesCount > 0
              ? '${product.availableCodesCount} كود متوفر — تسليم فوري'
              : 'يُسلَّم الكود فور إتمام الدفع',
          bg: AppColors.violetWash,
          fg: AppColors.violetMid,
        );
      case 'manual':
        return (
          icon: Icons.support_agent_rounded,
          label: 'تنفيذ يدوي',
          hint: 'ينفّذه المشرف • خلال ${product.estimatedMinutes} دقيقة',
          bg: AppColors.amberCream,
          fg: AppColors.amberDeep,
        );
      default:
        return (
          icon: Icons.bolt_rounded,
          label: 'فوري آلي',
          hint: 'شحن تلقائي مباشر خلال ثوانٍ',
          bg: AppColors.successWash,
          fg: AppColors.successDeep,
        );
    }
  }

  String? _resolveAppAsset() {
    final cleanIcon = (appIconUrl ?? '').trim();
    final cleanName = (appName ?? '').trim();
    if (cleanIcon.isEmpty && cleanName.isEmpty) return null;

    final matched = iconAssetForApp(
      iconUrl: cleanIcon,
      name: cleanName.isNotEmpty ? cleanName : product.name,
    );
    if (matched != null) return matched;
    if (cleanIcon.startsWith('assets/')) return cleanIcon;
    return null;
  }

  String? get _networkIcon {
    final raw = (appIconUrl ?? '').trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta();
    final bool insufficient = balance != null && balance! < displayPrice;
    final bool discounted =
        product.hasPriceChanged && product.previousPrice != null;
    // التكلفة لا تُعرض إلا عندما تختلف عن سعر البيع (هامش الوكيل مفعّل)
    final bool showCost =
        costPrice != null && (costPrice! - displayPrice).abs() > 0.001;

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: RepaintBoundary(
        child: TactileScale(
          onTap: onTap,
          child: CustomPaint(
            painter: TicketPassShadowPainter(
              cornerRadius: _radius,
              notchPositionFraction: 0.5,
              notchRadius: _notchRadius,
              shadowColor: AppColors.slate900.withValues(alpha: 0.14),
              elevation: 3.5,
            ),
            child: CustomPaint(
              foregroundPainter: TicketPassBorderPainter(
                cornerRadius: _radius,
                notchPositionFraction: 0.5,
                notchRadius: _notchRadius,
                borderColor: AppColors.outline,
                borderWidth: 1.0,
              ),
              child: ClipPath(
                clipper: TicketPassClipper(
                  cornerRadius: _radius,
                  notchPositionFraction: 0.5,
                  notchRadius: _notchRadius,
                ),
                child: Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: onTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: _minHeight),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // شريط لوني جانبي يربط الكرت بهوية نوع التنفيذ
                            Container(width: 4, color: meta.fg),

                            // ---------------- جسم البطاقة
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  12,
                                  11,
                                  12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _leadingVisual(meta),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // اسم الباقة أولاً وبخط واضح بارز
                                          Text(
                                            product.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.cairo(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.slate900,
                                              height: 1.18,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Wrap(
                                            spacing: 5,
                                            runSpacing: 4,
                                            children: [
                                              _pill(
                                                icon: meta.icon,
                                                label: meta.label,
                                                bg: meta.bg,
                                                fg: meta.fg,
                                              ),
                                              if (discounted)
                                                _pill(
                                                  icon: Icons
                                                      .trending_down_rounded,
                                                  label: 'سعر مخفّض',
                                                  bg: AppColors.successWash,
                                                  fg: AppColors.successDeep,
                                                ),
                                              if (marginText != null)
                                                _pill(
                                                  icon: Icons.percent_rounded,
                                                  label: marginText!,
                                                  bg: AppColors.slate100,
                                                  fg: AppColors.slate600,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            (product.description != null &&
                                                    product.description!
                                                        .trim()
                                                        .isNotEmpty)
                                                ? product.description!.trim()
                                                : meta.hint,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.cairo(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // ---------------- خط التثقيب الفاصل
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: CustomPaint(
                                painter: VerticalDashedLinePainter(
                                  color: AppColors.slate300,
                                ),
                                size: const Size(1, double.infinity),
                              ),
                            ),

                            // ---------------- كعب السعر وزر الشحن
                            SizedBox(
                              width: _stubWidth,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: insufficient
                                        ? const [
                                            AppColors.roseMist,
                                            Color(0xFFFFE4E6),
                                          ]
                                        : const [
                                            Color(0xFFFFFBEB),
                                            Color(0xFFFEF3C7),
                                          ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (discounted)
                                      Text(
                                        '\$${product.previousPrice!.toStringAsFixed(2)}',
                                        style: AppTypography.price(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: insufficient
                                              ? AppColors.roseDark
                                              : AppColors.amberInk,
                                        ).copyWith(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          height: 1.0,
                                        ),
                                      ),
                                    if (showCost)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 1,
                                        ),
                                        child: Text(
                                          'التكلفة \$${costPrice!.toStringAsFixed(2)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.cairo(
                                            fontSize: 8.6,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textMuted,
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '\$${displayPrice.toStringAsFixed(2)}',
                                      style: AppTypography.price(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: insufficient
                                            ? AppColors.roseInk
                                            : AppColors.slate900,
                                      ),
                                    ),
                                    if (sypPriceText != null &&
                                        sypPriceText!.isNotEmpty) ...[
                                      const SizedBox(height: 1.5),
                                      Text(
                                        sypPriceText!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.cairo(
                                          fontSize: 8.6,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.slate500,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4.5,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: insufficient
                                            ? null
                                            : const LinearGradient(
                                                colors: [
                                                  AppColors.darkNav,
                                                  AppColors.slate800,
                                                ],
                                              ),
                                        color: insufficient
                                            ? AppColors.roseDeep
                                            : null,
                                        borderRadius: BorderRadius.circular(9),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (insufficient
                                                    ? AppColors.roseDeep
                                                    : AppColors.darkNav)
                                                .withValues(alpha: 0.22),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            insufficient
                                                ? Icons.lock_outline_rounded
                                                : Icons.bolt_rounded,
                                            size: 11,
                                            color: insufficient
                                                ? Colors.white
                                                : AppColors.amberBright,
                                          ),
                                          const SizedBox(width: 2.5),
                                          Flexible(
                                            child: Text(
                                              insufficient ? 'رصيد ناقص' : 'شحن',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.cairo(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// أيقونة التطبيق/اللعبة إن وُجدت مع نقطة نوع التنفيذ، وإلا أيقونة نوع الباقة
  Widget _leadingVisual(
    ({IconData icon, String label, String hint, Color bg, Color fg}) meta,
  ) {
    final asset = _resolveAppAsset();
    final net = asset == null ? _networkIcon : null;

    if (asset != null || net != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.slate900.withValues(alpha: 0.10),
                  blurRadius: 7,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11.5),
              child: asset != null
                  ? Image.asset(
                      asset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _fallbackTile(meta, size: 46),
                    )
                  : SmoothNetworkImage(
                      url: net!,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      placeholderBuilder: (_) => _fallbackTile(meta, size: 46),
                      errorBuilder: (_) => _fallbackTile(meta, size: 46),
                    ),
            ),
          ),
          PositionedDirectional(
            bottom: -3,
            end: -3,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: meta.fg,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(meta.icon, size: 9, color: Colors.white),
            ),
          ),
        ],
      );
    }

    return _fallbackTile(meta, size: 44);
  }

  Widget _fallbackTile(
    ({IconData icon, String label, String hint, Color bg, Color fg}) meta, {
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: meta.bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: meta.fg.withValues(alpha: 0.24),
          width: 1,
        ),
      ),
      child: Icon(meta.icon, size: 21, color: meta.fg),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 8.8,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
