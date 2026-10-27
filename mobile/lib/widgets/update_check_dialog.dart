import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import 'digital_pass_card.dart';

/// نافذة «التحقق من التحديثات» بتذكرة JGO: جسم على اليمين وكعب حالة على
/// اليسار، بينهما خط تثقيب رأسي، وفتحتا تثقيب في منتصف الحافتين.
class UpdateCheckDialog extends StatefulWidget {
  const UpdateCheckDialog({super.key});

  /// الإصدار المثبت — مطابق لسطر `version: 1.0.0+1` في pubspec.yaml
  static const String versionLabel = 'v1.0.0';
  static const String buildLabel = 'BUILD 1';

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const UpdateCheckDialog(),
    );
  }

  @override
  State<UpdateCheckDialog> createState() => _UpdateCheckDialogState();
}

class _UpdateCheckDialogState extends State<UpdateCheckDialog> {
  // مقاسات التذكرة: نفس أرقام بطاقات التطبيق (radius كبير + فتحة 9)
  static const double _radius = 20;
  static const double _notch = 9;
  static const double _stubWidth = 92;

  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _startCheck();
  }

  void _startCheck() {
    setState(() {
      _isChecking = true;
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _isChecking
        ? AppColors.primaryBlue
        : AppColors.tertiaryLight;

    return Dialog(
      // السطح ترسمه التذكرة نفسها، فلا حاجة لتزيين Dialog
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: CustomPaint(
        painter: TicketPassShadowPainter(
          cornerRadius: _radius,
          notchRadius: _notch,
          notchPositionFraction: 0.5,
          shadowColor: AppColors.slate900,
          elevation: 10,
        ),
        child: CustomPaint(
          foregroundPainter: TicketPassBorderPainter(
            cornerRadius: _radius,
            notchRadius: _notch,
            notchPositionFraction: 0.5,
            borderColor: AppColors.outline,
            borderWidth: 1,
          ),
          child: ClipPath(
            clipper: TicketPassClipper(
              cornerRadius: _radius,
              notchRadius: _notch,
              notchPositionFraction: 0.5,
            ),
            child: Container(
              color: AppColors.surfaceCard,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height - 48,
              ),
              child: SingleChildScrollView(
                // IntrinsicHeight + stretch كي يمتد الكعب وخط التثقيب بكامل ارتفاع التذكرة
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---------------- جسم التذكرة (الحالة + التحسينات + الأزرار)
                      Expanded(child: _body(context, accent)),

                      // ---------------- خط التثقيب الفاصل
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: CustomPaint(
                          painter: VerticalDashedLinePainter(
                            color: AppColors.outlineVariant,
                            dashHeight: 5,
                            dashSpace: 4,
                          ),
                          // حد أدنى للطول، والـ stretch يمدّه لباقي التذكرة
                          size: const Size(1, 120),
                        ),
                      ),

                      // ---------------- كعب الحالة (الإصدار والبناء)
                      _stub(accent),
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

  // ---------------------------------------------------------------------------
  // جسم التذكرة
  // ---------------------------------------------------------------------------
  Widget _body(BuildContext context, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Flexible حتى لا يتجاوز شارة الحالة العرض المتاح على الشاشات الضيقة
              Flexible(child: _statusPill(accent)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SYSTEM // OTA CHECK',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.technicalCode(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'إغلاق',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: AppColors.slate400,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            _isChecking ? 'جاري فحص التحديثات...' : 'أنت تستخدم أحدث إصدار!',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.slate900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _isChecking
                ? 'يتم الاتصال بالخادم للتحقق من توافر إصدارات جديدة'
                : 'تطبيق JGO محدث إلى أحدث نسخة مستقرة.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.slate600,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 13),

          if (!_isChecking) _changelog(),
          if (!_isChecking) const SizedBox(height: 13),

          _actions(context, accent),
        ],
      ),
    );
  }

  Widget _statusPill(Color accent) {
    final IconData icon = _isChecking
        ? Icons.sync_rounded
        : Icons.verified_rounded;
    final String label = _isChecking ? 'جارٍ الفحص' : 'أحدث إصدار';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _changelog() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: AppColors.secondaryBright,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'أبرز التحسينات في هذا الإصدار',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const _FeatureRow(text: 'تسريع تنفيذ الطلبات والشحن الفوري'),
          const SizedBox(height: 7),
          const _FeatureRow(text: 'ميزة تحديد نسبة الربح وتسعير الزبائن'),
          const SizedBox(height: 7),
          const _FeatureRow(text: 'شريط سفلي مبسّط وقائمة علوية سريعة'),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, Color accent) {
    // زر فوق زر: صفّ الأزرار الأفقي يتجاوز عرض الجسم على شاشات 320dp
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _isChecking ? null : () => Navigator.of(context).pop(),
          icon: _isChecking
              ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.slate400,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 15),
          label: Text(_isChecking ? 'جارٍ الفحص…' : 'إغلاق'),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.surfaceContainerHigh,
            disabledForegroundColor: AppColors.slate500,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
        ),
        if (!_isChecking) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _startCheck,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text('فحص مجدداً'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.slate700,
              side: const BorderSide(color: AppColors.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // كعب التذكرة: ختم الحالة + رقم الإصدار والبناء
  // ---------------------------------------------------------------------------
  Widget _stub(Color accent) {
    return SizedBox(
      width: _stubWidth,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isChecking
                ? const [Color(0xFFF0F9FF), Color(0xFFBAE6FD)]
                : const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 16, 8, 16),
          child: Column(
            // متمركز رأسياً: ختم الإصدار يقع عند خط التثقيب تماماً
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: _isChecking
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.primaryBlue,
                        ),
                      )
                    : const Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: AppColors.onTertiaryContainer,
                      ),
              ),
              const SizedBox(height: 11),
              Text(
                UpdateCheckDialog.versionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.technicalCode(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate800,
                ),
              ),
              const SizedBox(height: 5),
              // تثقيب مصغّر داخل الكعب يفصل الإصدار عن رقم البناء
              SizedBox(
                width: 34,
                height: 1,
                child: CustomPaint(
                  painter: DashedLinePainter(
                    color: accent.withValues(alpha: 0.5),
                    dashWidth: 3,
                    dashSpace: 3,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                UpdateCheckDialog.buildLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.technicalCode(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate500,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.tertiaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 10,
            color: AppColors.onTertiaryContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.slate600,
            ),
          ),
        ),
      ],
    );
  }
}
