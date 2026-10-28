import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/admin_provider.dart';

/// نافذة توليد دفعة قسائم شحن رقمية.
///
/// controllers تعيش ضمن حالة النافذة وتُصرَّف في dispose الخاص بها: تصريفها في
/// `showDialog(...).whenComplete` يحدث وطريق النافذة ما زال ينهي حركة الإغلاق
/// والـ TextField لا يزال حيّاً، فيرمي «A TextEditingController was used after
/// being disposed» وتظهر الشاشة الحمراء.
class GenerateVoucherBatchDialog extends StatefulWidget {
  const GenerateVoucherBatchDialog({super.key, required this.onCreated});

  /// تستدعيها النافذة بعد نجاح التوليد ومعها معرّف الدفعة الجديد
  final void Function(String batchId) onCreated;

  @override
  State<GenerateVoucherBatchDialog> createState() =>
      _GenerateVoucherBatchDialogState();
}

class _GenerateVoucherBatchDialogState
    extends State<GenerateVoucherBatchDialog> {
  final TextEditingController _amountCtrl = TextEditingController(text: '10');
  final TextEditingController _countCtrl = TextEditingController(text: '5');
  final TextEditingController _noteCtrl = TextEditingController();

  /// يمنع ضغطتي توليد متزامنتين (كانت تُنشئ دفعتين بدل واحدة)
  bool _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _countCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.cairo()),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _submit() async {
    final double amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final int count = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (amount <= 0 || count <= 0) {
      _snack('يرجى إدخال قيم صحيحة', AppColors.rose);
      return;
    }

    setState(() => _busy = true);
    final AdminProvider admin = Provider.of<AdminProvider>(
      context,
      listen: false,
    );
    // await هنا بعد pop ممنوع أن يلمس controllers، لذلك نقرأ الحقول قبله
    final String? batchId = await admin.generateShippingCodes(
      amount,
      count,
      note: _noteCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (batchId == null) {
      _snack('حدث خطأ أثناء الإنشاء', AppColors.rose);
      return;
    }

    // الرسالة تُعرض قبل الإغلاق: بعدها تفقد النافذة سياقها
    _snack('تم إنشاء $count قسيمة ضمن دفعة واحدة', AppColors.emerald);
    Navigator.of(context).pop();
    widget.onCreated(batchId);
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) {
    OutlineInputBorder border([Color color = AppColors.outline, double w = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: w),
      );
    }

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppTypography.cairo(fontSize: 13, color: AppColors.slate600),
      prefixIcon: Icon(icon, color: AppColors.slate600),
      filled: true,
      fillColor: AppColors.paper,
      border: border(),
      enabledBorder: border(),
      focusedBorder: border(AppColors.primaryBlue, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              color: AppColors.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          // العنوان العربي طويل: موسَّع كي لا يتجاوز حافة النافذة
          Expanded(
            child: Text(
              'توليد قسائم شحن رقمية',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountCtrl,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppTypography.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: _decoration(
                'قيمة كل كود بالدولار (USD \$)',
                Icons.attach_money,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _countCtrl,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              style: AppTypography.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: _decoration(
                'عدد الأكواد المراد إنشاؤها (1 - 50)',
                Icons.pin_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteCtrl,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              style: AppTypography.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: _decoration(
                'اسم الدفعة (اختياري) — يظهر في التصدير',
                Icons.label_outline,
                hint: 'مثال: قسائم منصة الأسبوع 44',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(
            'إلغاء',
            style: AppTypography.cairo(
              fontSize: 13,
              color: AppColors.slate600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            elevation: 0,
          ),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'توليد القسائم',
                  style: AppTypography.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}
