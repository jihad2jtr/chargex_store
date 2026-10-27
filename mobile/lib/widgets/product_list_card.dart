import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/product_model.dart';
import 'digital_pass_card.dart';

/// بطاقة باقة (منتج) في شاشة التطبيق: تصميم تذكرة فاتحة
/// — نص داكن على أبيض (وضوح عالٍ)، شارة نوع التسليم، ملخص المحتوى،
///   وكعب سعر بلون كهرماني هادئ يحمل السعر وزر الشحن.
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
  /// مثال: "139 ل.س" — للعرض فقط ولا يدخل في حساب الدفع إطلاقاً
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
  static const double _height = 102;
  static const double _stubWidth = 94;

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
          bg: const Color(0xFFF5F3FF),
          fg: const Color(0xFF6D28D9),
        );
      case 'manual':
        return (
          icon: Icons.support_agent_rounded,
          label: 'تنفيذ يدوي',
          hint: 'ينفّذه المشرف • خلال ${product.estimatedMinutes} دقيقة',
          bg: const Color(0xFFFFF7ED),
          fg: const Color(0xFFB45309),
        );
      default:
        return (
          icon: Icons.bolt_rounded,
          label: 'فوري آلي',
          hint: 'شحن تلقائي مباشر خلال ثوانٍ',
          bg: const Color(0xFFECFDF5),
          fg: const Color(0xFF047857),
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
      child: CustomPaint(
        painter: TicketPassShadowPainter(
          cornerRadius: _radius,
          notchPositionFraction: 0.5,
          notchRadius: _notchRadius,
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
                child: SizedBox(
                  height: _height,
                  child: Row(
                    children: [
                      // ---------------- جسم البطاقة (الاسم + النوع + الوصف)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 10, 14, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  _pill(
                                    icon: meta.icon,
                                    label: meta.label,
                                    bg: meta.bg,
                                    fg: meta.fg,
                                  ),
                                  if (discounted) ...[
                                    const SizedBox(width: 5),
                                    _pill(
                                      icon: Icons.trending_down_rounded,
                                      label: 'سعر مخفّض',
                                      bg: const Color(0xFFECFDF5),
                                      fg: const Color(0xFF047857),
                                    ),
                                  ],
                                  const Spacer(),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cairo(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.slate900,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    product.description != null &&
                                            product.description!
                                                .trim()
                                                .isNotEmpty
                                        ? Icons.info_outline_rounded
                                        : meta.icon,
                                    size: 11,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      (product.description != null &&
                                              product.description!
                                                  .trim()
                                                  .isNotEmpty)
                                          ? product.description!
                                          : meta.hint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.cairo(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (marginText != null) ...[
                                    const SizedBox(width: 5),
                                    _pill(
                                      icon: Icons.percent_rounded,
                                      label: marginText!,
                                      bg: const Color(0xFFF1F5F9),
                                      fg: AppColors.slate600,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ---------------- خط التثقيب الفاصل
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: CustomPaint(
                          painter: VerticalDashedLinePainter(
                            color: AppColors.outlineVariant,
                          ),
                          size: const Size(1, 60),
                        ),
                      ),

                      // ---------------- كعب السعر + زر الشحن
                      SizedBox(
                        width: _stubWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: insufficient
                                  ? [
                                      const Color(0xFFFFF1F2),
                                      const Color(0xFFFECDD3),
                                    ]
                                  : [
                                      const Color(0xFFFFFDF5),
                                      const Color(0xFFFEF3C7),
                                    ],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (discounted)
                                  Text(
                                    '\$${product.previousPrice!.toStringAsFixed(2)}',
                                    style:
                                        AppTypography.price(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: insufficient
                                              ? const Color(0xFF9F1239)
                                              : const Color(0xFF92400E),
                                        ).copyWith(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          height: 1.0,
                                        ),
                                  ),
                                if (showCost)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 1),
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
                                        ? const Color(0xFFBE123C)
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                // المقابل بالليرة السورية — خافت تحت السعر بالدولار
                                if (sypPriceText != null &&
                                    sypPriceText!.isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      sypPriceText!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.cairo(
                                        fontSize: 8.6,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF94A3B8),
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: insufficient
                                        ? const Color(0xFF9F1239)
                                        : const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        insufficient
                                            ? Icons.lock_outline_rounded
                                            : Icons.bolt_rounded,
                                        size: 10,
                                        color: const Color(0xFFFBBF24),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        insufficient ? 'رصيد ناقص' : 'شحن',
                                        style: AppTypography.cairo(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
          Text(
            label,
            style: AppTypography.cairo(
              fontSize: 8.8,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
