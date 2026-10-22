import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// مؤشر واحد داخل لوحة الحالة الموحّدة
class LiveStatusMetric {
  final String label;
  final String sub;
  final String value;
  final IconData icon;
  final Color accent;
  final String statusText;
  final bool isAlert;
  final int rawValue;
  final VoidCallback? onTap;

  const LiveStatusMetric({
    required this.label,
    required this.sub,
    required this.value,
    required this.icon,
    required this.accent,
    required this.statusText,
    this.isAlert = false,
    required this.rawValue,
    this.onTap,
  });
}

/// عرض مؤشرات حالة العمل على شكل دوائر (Gauges) مباشرة على الخلفية
/// بدون حاوية/كارت خارجي
class LiveStatusConsole extends StatelessWidget {
  final String title;
  final List<LiveStatusMetric> metrics;
  final String alertBadgeText;
  final String stableBadgeText;

  const LiveStatusConsole({
    super.key,
    this.title = 'حالة العمل المباشرة',
    required this.metrics,
    this.alertBadgeText = 'NEEDS ACTION',
    this.stableBadgeText = 'REAL-TIME',
  });

  @override
  Widget build(BuildContext context) {
    final maxRaw = metrics
        .map((m) => m.rawValue)
        .fold<int>(1, (prev, e) => e > prev ? e : prev);
    final bool hasPending = metrics.any((m) => m.isAlert);
    final Color headerDot = hasPending
        ? AppColors.ticketAmber
        : AppColors.accentGreen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // رأس بسيط بدون كارت
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: headerDot,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: headerDot.withValues(alpha: 0.6),
                    blurRadius: 7,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.outline),
              ),
              child: Text(
                hasPending ? alertBadgeText : stableBadgeText,
                style: AppTypography.technicalCode(
                  color: hasPending
                      ? const Color(0xFFB45309)
                      : AppColors.textMuted,
                  fontSize: 8.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // شبكة الدوائر
        LayoutBuilder(
          builder: (context, constraints) {
            const double gap = 12;
            final double cellWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: 20,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: cellWidth,
                    child: _buildCircleMetric(metric, maxRaw),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCircleMetric(LiveStatusMetric m, int maxRaw) {
    final accent = m.isAlert ? const Color(0xFFEF4444) : m.accent;
    final fraction = (m.rawValue / maxRaw).clamp(0.08, 1.0).toDouble();
    final bool longValue = m.value.length > 5;

    final Widget circle = Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: -3,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: FittedBox(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(m.icon, size: 14, color: accent),
                  const SizedBox(height: 3),
                  Text(
                    m.value,
                    style: AppTypography.plusJakartaSans(
                      fontSize: longValue ? 15 : 21,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkNav,
                      height: 1.0,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 10),
        Text(
          m.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.cairo(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          m.sub,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.cairo(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: accent.withValues(alpha: 0.38)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.isAlert) ...[
                Icon(Icons.warning_amber_rounded, size: 11, color: accent),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  m.statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (m.onTap == null) return content;
    return InkWell(
      onTap: m.onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}
