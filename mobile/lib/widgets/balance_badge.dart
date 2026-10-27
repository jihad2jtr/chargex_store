import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class BalanceBadge extends StatelessWidget {
  final double balance;
  final VoidCallback? onTap;

  const BalanceBadge({super.key, required this.balance, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bolt_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '\$${balance.toStringAsFixed(2)}',
              style: AppTypography.balance(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.add_circle,
              size: 15,
              color: AppColors.ticketAmber,
            ),
          ],
        ),
      ),
    );
  }
}
