import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// بطاقة عملية بأسلوب التذكرة: جسم + خط تمزّق بفجوتين جانبيتين + تذييل أفعال.
/// تُستخدم في لوحات الإدارة (إدارة الطلبات والشحن) لتوحيد لغة «التذكرة».
class OpsTicketCard extends StatelessWidget {
  final Color accent;
  final IconData? icon;

  /// ودجت يظهر داخل المربّع الملوّن مكان الأيقونة (مثل شعار شام كاش / Binance)
  final Widget? leading;
  final String? tag;
  final String title;
  final String? subtitle;
  final Widget? amount;
  final Widget? status;
  final List<Widget> rows;
  final Widget? media;
  final String? note;
  final String? meta;
  final List<Widget> actions;

  const OpsTicketCard({
    super.key,
    required this.accent,
    this.icon,
    this.leading,
    this.tag,
    required this.title,
    this.subtitle,
    this.amount,
    this.status,
    this.rows = const [],
    this.media,
    this.note,
    this.meta,
    this.actions = const [],
  }) : assert(
         icon != null || leading != null,
         'OpsTicketCard يحتاج أيقونة أو ودجت leading',
       );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  child: leading ?? Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tag != null)
                        Text(
                          tag!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.spaceMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.35,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (amount != null || status != null) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (amount != null) ...[
                        ?amount,
                        const SizedBox(height: 5),
                      ],
                      ?status,
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows,
              ),
            ),
          if (media != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 0),
              child: media!,
            ),
          if (note != null && note!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.ticketAmber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 12,
                      color: AppColors.secondaryBright,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        note!.trim(),
                        style: AppTypography.cairo(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondaryBright,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          const OpsTearLine(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: meta == null
                      ? const SizedBox.shrink()
                      : Text(
                          meta!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.plusJakartaSans(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Row(children: actions),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// سطر بيانات داخل التذكرة: أيقونة + عنوان صغير + قيمة بارزة (اختياريًا زر نسخ).
class OpsTicketInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? tint;
  final bool mono;
  final Widget? trailing;

  const OpsTicketInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tint,
    this.mono = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = tint ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            '$label:',
            style: AppTypography.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: mono
                  ? AppTypography.technicalCode(
                      fontSize: 10.5,
                      color: tint ?? AppColors.primaryBlue,
                    )
                  : AppTypography.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: tint ?? AppColors.textPrimary,
                    ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

/// خط تمزّق أفقي بفجوتين دائريتين على حافتي البطاقة (شكل كعب التذكرة).
class OpsTearLine extends StatelessWidget {
  const OpsTearLine({super.key, this.height = 16});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const CustomPaint(
        painter: _TearLinePainter(
          lineColor: AppColors.outlineVariant,
          holeColor: AppColors.background,
        ),
      ),
    );
  }
}

class _TearLinePainter extends CustomPainter {
  const _TearLinePainter({required this.lineColor, required this.holeColor});

  final Color lineColor;
  final Color holeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double y = size.height / 2;
    const double radius = 7;

    final Paint dash = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    double x = radius * 2.2;
    final double end = size.width - radius * 2.2;
    while (x < end) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
      x += 4 + 3.5;
    }

    final Paint hole = Paint()..color = holeColor;
    canvas.drawCircle(Offset(0, y), radius, hole);
    canvas.drawCircle(Offset(size.width, y), radius, hole);
  }

  @override
  bool shouldRepaint(covariant _TearLinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.holeColor != holeColor;
  }
}
