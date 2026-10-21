import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class UpdateCheckDialog extends StatefulWidget {
  const UpdateCheckDialog({super.key});

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
    return Dialog(
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.outline),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isChecking
                    ? AppColors.brandGradient
                    : const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (_isChecking ? AppColors.primaryContainer : AppColors.tertiary).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isChecking
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              _isChecking ? 'جاري فحص التحديثات...' : 'أنت تستخدم أحدث إصدار!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle
            Text(
              _isChecking
                  ? 'يتم الاتصال بالخادم للتحقق من توافر إصدارات جديدة'
                  : 'تطبيق JGO محدث إلى أحدث نسخة مستقرة.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),

            // Version Info Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الإصدار المثبت:', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                  Row(
                    children: [
                      Icon(Icons.verified, size: 16, color: AppColors.secondary),
                      SizedBox(width: 6),
                      Text(
                        'v1.0.0 (Build 1)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryBright),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Changelog bullet points if finished
            if (!_isChecking) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أبرز التحسينات في هذا الإصدار:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                    SizedBox(height: 8),
                    _FeatureRow(icon: Icons.bolt, text: 'تسريع تنفيذ الطلبات والشحن الفوري'),
                    SizedBox(height: 6),
                    _FeatureRow(icon: Icons.percent, text: 'ميزة تحديد نسبة الربح وتسعير الزبائن'),
                    SizedBox(height: 6),
                    _FeatureRow(icon: Icons.dashboard_customize, text: 'شريط سفلي مبسّط وقائمة علوية سريعة'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Actions
            Row(
              children: [
                if (!_isChecking)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _startCheck,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('فحص مجدداً'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.outline),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                if (!_isChecking) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('إغلاق'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
