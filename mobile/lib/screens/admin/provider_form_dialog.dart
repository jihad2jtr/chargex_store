import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/provider_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/digital_pass_card.dart';

/// نافذة إضافة/تعديل مزود الخدمة بهوية التذكرة الفاتحة.
/// النافذة تملك controllers خاصتها وتصرّفها في `dispose`: تصريفها في
/// `showDialog(...).whenComplete` يحدث وطريق النافذة ما زال ينهي حركة الإغلاق
/// والـ TextField لا يزال حيّاً، فيرمي «A TextEditingController was used after
/// being disposed» وتظهر الشاشة الحمراء.
class ProviderFormDialog extends StatefulWidget {
  const ProviderFormDialog({super.key, required this.admin, this.provider});

  final AdminProvider admin;
  final ProviderModel? provider;

  @override
  State<ProviderFormDialog> createState() => _ProviderFormDialogState();
}

class _ProviderFormDialogState extends State<ProviderFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _secretCtrl;
  late final TextEditingController _marginCtrl;

  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.provider != null;

  @override
  void initState() {
    super.initState();
    final ProviderModel? p = widget.provider;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _urlCtrl = TextEditingController(text: p?.baseUrl ?? '');
    _keyCtrl = TextEditingController(text: p?.apiKey ?? '');
    _secretCtrl = TextEditingController(text: p?.apiSecret ?? '');
    _marginCtrl = TextEditingController(
      text: (p?.profitMarginValue ?? 10.0).toString(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _secretCtrl.dispose();
    _marginCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _nameCtrl.text.trim();
    final String url = _urlCtrl.text.trim();
    final String key = _keyCtrl.text.trim();
    final double? margin = double.tryParse(_marginCtrl.text.trim());

    if (name.isEmpty || url.isEmpty || key.isEmpty) {
      setState(() => _error = 'يرجى ملء جميع الحقول الأساسية');
      return;
    }
    if (margin == null || margin < 0) {
      setState(() => _error = 'نسبة الربح يجب أن تكون رقماً موجباً');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final Map<String, dynamic> data = <String, dynamic>{
      'name': name,
      'baseUrl': url,
      'apiKey': key,
      'apiSecret': _secretCtrl.text.trim().isEmpty
          ? null
          : _secretCtrl.text.trim(),
      'profitMarginType': 'percentage',
      'profitMarginValue': margin,
    };

    final bool ok = _isEdit
        ? await widget.admin.updateProvider(widget.provider!.id, data)
        : await widget.admin.createProvider(data);

    if (!mounted) return;
    setState(() => _busy = false);

    // الرسالة قبل الإغلاق: بعدها تفقد النافذة سياقها
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'تم حفظ بيانات المزود بنجاح ✅'
              : (widget.admin.errorMessage ?? 'حدث خطأ أثناء الحفظ'),
          style: AppTypography.cairo(),
        ),
        backgroundColor: ok ? AppColors.tertiaryLight : AppColors.errorLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) Navigator.of(context).pop();
  }

  void _fillQuick({required String name, required String url}) {
    setState(() {
      _nameCtrl.text = name;
      _urlCtrl.text = url;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
      titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      actionsPadding: const EdgeInsets.fromLTRB(14, 8, 16, 16),
      title: Row(
        children: [
          _iconChip(AppColors.primaryBlue, Icons.hub_rounded),
          const SizedBox(width: 9),
          // Expanded: العنوان العربي الطويل لا يفيض على حافة النافذة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'تعديل بيانات المزود' : 'إضافة مزود جديد',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    color: AppColors.slate900,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                Text(
                  _isEdit ? 'PROVIDER · UPDATE' : 'PROVIDER · CREATE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.technicalCode(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'بيانات الربط عبر API المباشر لجلب المنتجات والأسعار',
              style: AppTypography.cairo(
                color: AppColors.slate500,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _quickChip(
                  label: 'Fox Reload',
                  icon: Icons.flash_on_rounded,
                  color: AppColors.ticketAmber,
                  onTap: () => _fillQuick(
                    name: 'Fox Reload',
                    url: 'https://public-api.foxreload.com',
                  ),
                ),
                _quickChip(
                  label: 'Bay2Game',
                  icon: Icons.games_rounded,
                  color: AppColors.primaryBlue,
                  onTap: () => _fillQuick(
                    name: 'Bay2Game',
                    url: 'https://bay2game.com/api',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _dashedRule(),
            const SizedBox(height: 12),
            _field(
              controller: _nameCtrl,
              label: 'اسم المزود (مثال: Smile One, SEAGM)',
              icon: Icons.business_rounded,
            ),
            const SizedBox(height: 11),
            _field(
              controller: _urlCtrl,
              label: 'Base URL رابط الـ API الرئيسي',
              icon: Icons.link_rounded,
              isUrl: true,
            ),
            const SizedBox(height: 11),
            _field(
              controller: _keyCtrl,
              label: 'API Key المفتاح البرمجي',
              icon: Icons.key_rounded,
            ),
            const SizedBox(height: 11),
            _field(
              controller: _secretCtrl,
              label: 'API Secret (اختياري)',
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 11),
            _field(
              controller: _marginCtrl,
              label: 'نسبة الربح % المطبّقة على كل منتجات المزود',
              icon: Icons.trending_up_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'تُحدَّد نسبة الربح هنا لكل منتجات هذا المزود، وليست لكل منتج على حدة.\n'
              'أي تعديل هنا يعيد حساب أسعار بيع منتجاته تلقائياً.',
              style: AppTypography.cairo(
                color: AppColors.slate500,
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: AppColors.rose.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 14,
                      color: AppColors.errorLight,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTypography.cairo(
                          fontSize: 11,
                          color: AppColors.errorLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(
            'إلغاء',
            style: AppTypography.cairo(color: AppColors.slate500),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  'حفظ البيانات',
                  style: AppTypography.cairo(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Widget _dashedRule() {
    return SizedBox(
      height: 1,
      child: CustomPaint(
        painter: DashedLinePainter(
          color: AppColors.outline,
          dashWidth: 4,
          dashSpace: 4,
        ),
      ),
    );
  }

  Widget _iconChip(Color color, IconData icon, {double size = 30}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.lerp(color, Colors.white, 0.28)!, color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }

  Widget _quickChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.cairo(
          color: AppColors.slate900,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.32)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: onTap,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isUrl = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: !_busy,
      keyboardType: keyboardType,
      style: isUrl
          ? AppTypography.technicalCode(
              color: AppColors.slate900,
              fontSize: 12.5,
            )
          : AppTypography.cairo(color: AppColors.slate900, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.cairo(
          color: AppColors.slate500,
          fontSize: 11.5,
        ),
        prefixIcon: Icon(icon, color: AppColors.primaryBlue, size: 18),
        filled: true,
        fillColor: AppColors.surfaceDim,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
