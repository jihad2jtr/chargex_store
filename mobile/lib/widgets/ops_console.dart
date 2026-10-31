import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/dashboard_stats_model.dart';

const Color _navy = Color(0xFF0F172A);
const Color _rose = Color(0xFFE11D48);
const Color _amber = Color(0xFFD97706);
const Color _emerald = Color(0xFF059669);
const Color _sky = Color(0xFF0284C7);
const Color _indigo = Color(0xFF4F46E5);
const Color _teal = Color(0xFF0D9488);

/// لوحة «حالة العمل» للأدمن:
/// بطاقة قرار واحدة (ما يحتاج تدخلًا) + 6 مؤشرات مالية/تشغيلية
/// + رسم إيرادات آخر 7 أيام + شريط صحة النظام.
/// الفكرة: اللون يحمل معنى إجراء (أحمر = تدخل فوري، كهرماني = مراقبة، أخضر = سليم).
class OpsConsole extends StatefulWidget {
  final DashboardStatsModel? stats;
  final DateTime? updatedAt;
  final VoidCallback? onReviewOrders;
  final VoidCallback? onReviewTopups;
  final VoidCallback? onReviewDelayed;

  const OpsConsole({
    super.key,
    required this.stats,
    this.updatedAt,
    this.onReviewOrders,
    this.onReviewTopups,
    this.onReviewDelayed,
  });

  @override
  State<OpsConsole> createState() => _OpsConsoleState();
}

class _OpsConsoleState extends State<OpsConsole> {
  // منطوية افتراضياً إلى زر في أعلى الصفحة؛ السهم للأسفل يفتح حالة العمل
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final bool alert = s?.needsAction ?? false;
    final Color dot = alert ? AppColors.ticketAmber : AppColors.accentGreen;

    // بطاقة واحدة موحّدة اللون: رأس الشريط + لوحة الحالة داخل نفس الكرت
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkNav,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.28),
            blurRadius: 14,
            spreadRadius: 0.5,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(dot),
          // مؤثر السحب للأسفل: تكشف اللوحة بحركة ارتفاع ناعمة
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(9, 2, 9, 9),
                      child: s == null ? _buildSkeleton() : _buildConsole(s),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- HEADER

  /// رأس البطاقة — نفس لون الكرت الموحد (داكن مثل الشريط العلوي) وبدون نبض
  Widget _buildHeader(Color dot) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            children: [
              // شارة الأيقونة مع نقطة الحالة
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.38),
                    width: 1.0,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.monitor_heart_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'حالة العمل',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.schedule_rounded,
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      widget.updatedAt == null ? '…' : _time(widget.updatedAt!),
                      style: AppTypography.technicalCode(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // قرص السهم: يدور ويكشف اللوحة عند السحب للأسفل
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                ),
                child: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- CONSOLE

  Widget _buildConsole(DashboardStatsModel s) {
    // موحّد مع الرأس: المحتوى يستقر مباشرة داخل نفس الكرت الداكن بلا بطاقة بيضاء منفصلة
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDecisionBanner(s),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const double gap = 8;
            final double w = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(width: w, child: _revenueTile(s)),
                SizedBox(width: w, child: _profitTile(s)),
                SizedBox(width: w, child: _topupsTile(s)),
                SizedBox(width: w, child: _delayedTile(s)),
                SizedBox(width: w, child: _aovTile(s)),
                SizedBox(width: w, child: _completionTile(s)),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _buildWeekChart(s),
        const SizedBox(height: 10),
        _buildHealthStrip(s),
      ],
    );
  }

  // --------------------------------------------------------- DECISION CARD

  Widget _buildDecisionBanner(DashboardStatsModel s) {
    final bool critical = s.delayedOrders > 0;
    final Color base = critical ? _rose : (s.needsAction ? _amber : _emerald);

    final List<String> parts = [];
    if (s.pendingOrders > 0) parts.add('${s.pendingOrders} طلب شحن');
    if (s.pendingTopups > 0) {
      parts.add('${_money(s.pendingTopupsAmount)} إيداع');
    }
    if (s.delayedOrders > 0) parts.add('${s.delayedOrders} تجاوز الموعد');

    final String title = critical
        ? 'طلبات تجاوزت موعد التسليم'
        : (s.needsAction ? 'مهام تنتظر إجراءك' : 'لا شيء ينتظر إجراءك');
    final String subtitle = parts.isEmpty
        ? 'كل الطلبات والإيداعات معالجة — استمر على هذا الأداء'
        : parts.join('  •  ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: s.delayedOrders > 0
            ? (widget.onReviewDelayed ?? widget.onReviewOrders)
            : widget.onReviewOrders,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [base, Color.lerp(base, _navy, 0.28)!],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  critical
                      ? Icons.timer_off_rounded
                      : (s.needsAction
                            ? Icons.bolt_rounded
                            : Icons.verified_rounded),
                  color: Colors.white,
                  size: 20,
                ),
              ),
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 9.8,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  s.needsAction
                      ? Icons.arrow_back_rounded
                      : Icons.check_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- TILES

  Widget _revenueTile(DashboardStatsModel s) {
    final double delta = s.revenueDeltaPct;
    final bool up = delta >= 0;
    return _tile(
      label: 'إيرادات اليوم',
      value: _money(s.revenueToday),
      icon: Icons.trending_up_rounded,
      accent: _sky,
      sub: delta == 0 && s.revenueYesterday == 0
          ? 'لا مبيعات أمس'
          : '${up ? '▲' : '▼'} ${delta.abs().toStringAsFixed(0)}% عن أمس',
      subColor: delta == 0 ? AppColors.textMuted : (up ? _emerald : _rose),
    );
  }

  Widget _profitTile(DashboardStatsModel s) {
    return _tile(
      label: 'صافي الربح اليوم',
      value: _money(s.profitToday),
      icon: Icons.savings_rounded,
      accent: _emerald,
      sub: 'أمس ${_money(s.profitYesterday)}',
    );
  }

  Widget _topupsTile(DashboardStatsModel s) {
    final bool pending = s.pendingTopups > 0;
    return _tile(
      label: 'إيداعات معلقة',
      value: _money(s.pendingTopupsAmount),
      icon: Icons.account_balance_wallet_rounded,
      accent: pending ? _amber : _emerald,
      sub: pending
          ? '${s.pendingTopups} طلب • انتظار ${_wait(s.oldestTopupMinutes)}'
          : 'لا يوجد اعتماد معلق',
      subColor: pending ? _amber : AppColors.textMuted,
      onTap: widget.onReviewTopups,
    );
  }

  Widget _delayedTile(DashboardStatsModel s) {
    final bool late = s.delayedOrders > 0;
    return _tile(
      label: 'تجاوزوا الموعد',
      value: '${s.delayedOrders}',
      icon: Icons.timer_outlined,
      accent: late ? _rose : _emerald,
      sub: late
          ? 'أطول انتظار ${_wait(s.longestWaitMinutes)}'
          : 'كل الطلبات داخل الوقت',
      subColor: late ? _rose : AppColors.textMuted,
      onTap: widget.onReviewDelayed,
    );
  }

  Widget _aovTile(DashboardStatsModel s) {
    return _tile(
      label: 'متوسط قيمة الطلب',
      value: _money(s.aov),
      icon: Icons.receipt_long_rounded,
      accent: _indigo,
      sub: '${s.orders30d} طلب خلال 30 يوم',
    );
  }

  Widget _completionTile(DashboardStatsModel s) {
    final bool risky = s.failureRate >= 5;
    return _tile(
      label: 'نسبة الإنجاز',
      value: '${s.completionRate.toStringAsFixed(0)}%',
      icon: Icons.task_alt_rounded,
      accent: risky ? _amber : _emerald,
      sub: 'فشل ${s.failureRate.toStringAsFixed(1)}% خلال 30 يوم',
      subColor: risky ? _amber : AppColors.textMuted,
    );
  }

  Widget _tile({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color accent,
    Color? subColor,
    VoidCallback? onTap,
  }) {
    final Widget body = Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 12,
                  color: Color.lerp(accent, Colors.white, 0.45),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.plusJakartaSans(
                fontSize: 17.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.05,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 8.8,
              fontWeight: FontWeight.w600,
              color: subColor ?? Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: body,
    );
  }

  // ------------------------------------------------------------ WEEK CHART

  Widget _buildWeekChart(DashboardStatsModel s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'إيرادات آخر 7 أيام',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                  ),
                ),
              ),
              Text(
                _money(s.weekRevenue),
                style: AppTypography.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: CustomPaint(
              painter: _WeekBarsPainter(
                values: s.last7Days.map((d) => d.revenue).toList(),
                barColor: _sky,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- HEALTH STRIP

  Widget _buildHealthStrip(DashboardStatsModel s) {
    final bool providersOk = s.providersOnline > 0;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _chip(
          Icons.cloud_done_rounded,
          'مزودين ${s.providersOnline}/${s.providersTotal}',
          providersOk ? _emerald : _rose,
        ),
        _chip(
          Icons.confirmation_number_rounded,
          'أكواد متاحة ${s.codesAvailable}',
          _indigo,
        ),
        _chip(Icons.view_carousel_rounded, 'بانرات ${s.bannersActive}', _amber),
        _chip(
          Icons.account_balance_wallet_rounded,
          'حسابات دفع ${s.accountsActive}',
          _sky,
        ),
        _chip(Icons.people_alt_rounded, 'مستخدمون +${s.usersNewToday}', _teal),
        _chip(
          Icons.category_rounded,
          'باقات ${s.productsActive}',
          AppColors.slate700,
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String text, Color accent) {
    final Color tint = Color.lerp(accent, Colors.white, 0.45)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: tint),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 8.8,
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- SKELETON

  Widget _buildSkeleton() {
    Widget block(double h, double w) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: block(46, double.infinity))]),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: block(58, double.infinity)),
            const SizedBox(width: 8),
            Expanded(child: block(58, double.infinity)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: block(58, double.infinity)),
            const SizedBox(width: 8),
            Expanded(child: block(58, double.infinity)),
          ],
        ),
        const SizedBox(height: 10),
        block(52, double.infinity),
        const SizedBox(height: 8),
        Text(
          'جارٍ تحميل مؤشرات اليوم…',
          style: AppTypography.cairo(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- HELPERS

  static String _money(double value) {
    final v = value.abs();
    if (v >= 10000) return '${(value / 1000).toStringAsFixed(1)}k \$';
    if (v >= 1000) return '${value.toStringAsFixed(0)} \$';
    return '${value.toStringAsFixed(2)} \$';
  }

  static String _wait(int minutes) {
    if (minutes <= 0) return '0 د';
    if (minutes < 60) return '$minutes د';
    return '${minutes ~/ 60}س ${minutes % 60}د';
  }

  static String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// أعمدة إيرادات آخر 7 أيام (آخر عمود = اليوم)
class _WeekBarsPainter extends CustomPainter {
  final List<double> values;
  final Color barColor;

  _WeekBarsPainter({required this.values, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Paint baseline = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      baseline,
    );

    if (values.isEmpty) return;

    final int n = values.length;
    final double gap = 5;
    final double barW = ((size.width - gap * (n - 1)) / n).clamp(2.0, 22.0);
    final double totalW = barW * n + gap * (n - 1);
    final double startX = (n < 4) ? 0 : (size.width - totalW) / 2;
    final double peak = values.fold<double>(0, (m, v) => v > m ? v : m);

    for (int i = 0; i < n; i++) {
      final bool isToday = i == n - 1;
      final double ratio = peak <= 0 ? 0 : values[i] / peak;
      final double h = peak <= 0
          ? 2
          : (ratio * (size.height - 4)).clamp(2.0, size.height - 2);
      final double x = startX + i * (barW + gap);
      final Rect rect = Rect.fromLTWH(x, size.height - h, barW, h);

      final Paint p = Paint()
        ..color = barColor.withValues(alpha: isToday ? 1.0 : 0.32);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barW / 2.4)),
        p,
      );
      if (isToday) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - h, barW, 3),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.25),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeekBarsPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.barColor != barColor;
  }
}
