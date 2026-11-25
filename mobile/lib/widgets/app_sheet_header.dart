import 'package:flutter/material.dart';

import '../core/constants/app_icon_assets.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import 'smooth_network_image.dart';

/// ترويسة موحّدة للنوافذ السفلية عند اختيار تطبيق أو خدمة (صفحة الأرقام + صفحة الخدمات):
/// مقبض سحب متمركز، أيقونة التطبيق بحجم واضح، العنوان والعنوان الفرعي الأجنبي،
/// وشارة الرصيد الحالي.
class AppSheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconRaw;
  final List<String> iconSeeds;
  final String letterSeed;
  final double balance;
  final double? requiredAmount;

  const AppSheetHeader({
    super.key,
    required this.title,
    required this.balance,
    this.subtitle = '',
    this.iconRaw = '',
    this.iconSeeds = const <String>[],
    this.letterSeed = '',
    this.requiredAmount,
  });

  String? _resolveAsset() {
    final clean = iconRaw.trim();
    if (clean.isNotEmpty) {
      if (clean.startsWith('assets/')) return clean;
      final exact = builtinIconAssetExact(clean);
      if (exact != null) return exact;
      final byQuery = builtinIconAssetForQuery(clean);
      if (byQuery != null) return byQuery;
    }
    for (final seed in iconSeeds) {
      final s = seed.trim();
      if (s.isEmpty) continue;
      final found = iconAssetForApp(iconUrl: clean, name: s);
      if (found != null) return found;
    }
    return null;
  }

  String? get _networkUrl {
    final clean = iconRaw.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSubtitle =
        subtitle.trim().isNotEmpty &&
        subtitle.trim().toLowerCase() != title.trim().toLowerCase();
    final bool enough = requiredAmount == null || balance >= requiredAmount!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate900,
                      height: 1.2,
                    ),
                  ),
                  if (hasSubtitle) ...[
                    const SizedBox(height: 1.5),
                    Text(
                      subtitle.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: enough
                    ? AppColors.emerald.withValues(alpha: 0.08)
                    : AppColors.roseWash,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: enough
                      ? AppColors.emerald.withValues(alpha: 0.28)
                      : AppColors.roseBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 13,
                    color: enough ? AppColors.emerald : AppColors.roseDeep,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'رصيدك \$${balance.toStringAsFixed(2)}',
                    style: AppTypography.balance(
                      fontSize: 11,
                      color: enough ? AppColors.slate800 : AppColors.roseDeep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIcon() {
    final asset = _resolveAsset();
    final netUrl = asset == null ? _networkUrl : null;

    Widget content;
    if (asset != null) {
      content = Image.asset(
        asset,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    } else if (netUrl != null) {
      content = SizedBox(
        width: 38,
        height: 38,
        child: SmoothNetworkImage(
          url: netUrl,
          fit: BoxFit.cover,
          cacheWidth: 120,
          placeholderBuilder: (_) => _fallback(),
          errorBuilder: (_) => _fallback(),
        ),
      );
    } else {
      content = _fallback();
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: content,
      ),
    );
  }

  Widget _fallback() {
    final seed = letterSeed.trim().isNotEmpty ? letterSeed.trim() : title.trim();
    final letter = seed.isNotEmpty ? seed.substring(0, 1).toUpperCase() : '#';
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      color: AppColors.slate900,
      child: Text(
        letter,
        style: AppTypography.fintechBadge(
          color: const Color(0xFFFDE047),
          fontSize: 13,
        ),
      ),
    );
  }
}
