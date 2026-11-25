import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/product_model.dart';
import 'digital_pass_card.dart';
import 'tactile_scale.dart';

/// بطاقة باقة (منتج) في شاشة التطبيق: تذكرة سويسرية فاتحة بأيقونة نوع التسليم،
/// عنوان ووصف واضحين، خط تثقيب رأسي بين الجسم وكعب السعر، وزر شحن بارز.
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
  });

  static const double _radius = 16;
  static const double _notchRadius = 7;
  static const double _minHeight = 98;
  static const double _stubWidth = 104;

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
      padding: const EdgeInsets.only(bottom: 10),
      child: RepaintBoundary(
        child: TactileScale(
          onTap: onTap,
          child: CustomPaint(
            painter: TicketPassShadowPainter(
              cornerRadius: _radius,
              notchPositionFraction: 0.5,
              notchRadius: _notchRadius,
              shadowColor: AppColors.slate900.withValues(alpha: 0.14),
              elevation: 3.0,
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
                            // ---------------- جسم البطاقة (الأيقونة + الاسم + النوع + الوصف)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  12,
                                  12,
                                  12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _leadingBadge(meta),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
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
                                          const SizedBox(height: 6),
                                          Text(
                                            product.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.cairo(
                                              fontSize: 14.2,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.slate900,
                                              height: 1.18,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
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

                            // ---------------- كعب السعر + زر الشحن
                            SizedBox(
                              width: _stubWidth,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: insufficient
                                        ? const [
                                            AppColors.roseMist,
                                            AppColors.roseBorder,
                                          ]
                                        : const [
                                            Color(0xFFFFFDF5),
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
                                        fontSize: 17.5,
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
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: insufficient
                                            ? AppColors.roseDeep
                                            : AppColors.darkNav,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (insufficient
                                                    ? AppColors.roseDeep
                                                    : AppColors.darkNav)
                                                .withValues(alpha: 0.18),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1.5),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            insufficient
                                                ? Icons.lock_outline_rounded
                                                : Icons.bolt_rounded,
                                            size: 10.5,
                                            color: insufficient
                                                ? Colors.white
                                                : AppColors.amberBright,
                                          ),
                                          const SizedBox(width: 2),
                                          Flexible(
                                            child: Text(
                                              insufficient ? 'رصيد ناقص' : 'شحن',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.cairo(
                                                fontSize: 9.2,
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

  /// شارة مربعة ناعمة تميّز نوع الباقة بصرياً على يسار/يمين النص
  Widget _leadingBadge(
    ({IconData icon, String label, String hint, Color bg, Color fg}) meta,
  ) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: meta.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: meta.fg.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Icon(meta.icon, size: 20, color: meta.fg),
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
