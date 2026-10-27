import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// شعارات وسائل الدفع (شام كاش / Binance) كصور رسمية بدل الأيقونات العامة.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    required this.asset,
    this.size = 20,
    this.radius = 6,
    this.fallbackIcon = Icons.account_balance_wallet_rounded,
    this.fallbackColor,
  });

  final String asset;
  final double size;
  final double radius;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  /// شعار شام كاش (مربّع أبيض بشعار أزرق/أخضر)
  static const String shamCash = 'assets/brands/sham_cash.jpg';

  /// شعار Binance (مربّع أصفر بشعار أسود)
  static const String binance = 'assets/brands/binance.png';

  /// شعار وسيلة الشحن حسب نوع العملية، أو null للأنواع بلا شعار.
  static String? forTopupType(String type) {
    switch (type) {
      case 'sham_cash':
        return shamCash;
      case 'binance':
        return binance;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Icon(
          fallbackIcon,
          size: size,
          color: fallbackColor ?? AppColors.slate500,
        ),
      ),
    );
  }
}
