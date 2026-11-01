import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/virtual_number_model.dart';
import '../providers/virtual_numbers_provider.dart';
import 'app_asset_picker.dart';

/// حوار إنشاء/تعديل تطبيق أرقام (الاسم + رمز الخدمة + أيقونة اختيارية).
///
/// كان خاصاً بشاشة التطبيقات، وأصبح مشتركاً بينها وبين «معجم التطبيقات»:
/// المعجم يُنشئ منه وثاقة تطبيق جديد، وشاشة المنتجات تُعدّل بها وثاقة قائمة.
class VirtualNumberAppFormDialog extends StatefulWidget {
  final VirtualNumberAppModel? app;
  final List<({String code, String name})> catalogServices;

  /// تعبئة مسبقة لوضع الإنشاء (شاشة المعجم): اسم ورمز مقترح من مدخل المعجم
  final String initialName;
  final String initialServiceCode;

  const VirtualNumberAppFormDialog({
    super.key,
    this.app,
    this.catalogServices = const [],
    this.initialName = '',
    this.initialServiceCode = '',
  });

  @override
  State<VirtualNumberAppFormDialog> createState() =>
      _VirtualNumberAppFormDialogState();
}

class _VirtualNumberAppFormDialogState
    extends State<VirtualNumberAppFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _iconCtrl;
  bool _saving = false;

  bool get _isEdit => widget.app != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.app?.name ?? widget.initialName,
    );
    _codeCtrl = TextEditingController(
      text: widget.app?.serviceCode ?? widget.initialServiceCode,
    );
    _iconCtrl = TextEditingController(text: widget.app?.iconUrl ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim().toLowerCase();
    if (name.isEmpty || (!_isEdit && code.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاسم ورمز الخدمة مطلوبان')),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<VirtualNumbersProvider>();
    final message = _isEdit
        ? await provider.updateAdminApp(
            widget.app!.id,
            name: name,
            iconUrl: _iconCtrl.text.trim(),
          )
        : await provider.createAdminApp(
            name: name,
            serviceCode: code,
            iconUrl: _iconCtrl.text.trim(),
          );
    if (!mounted) return;
    if (message != null) Navigator.pop(context, true);
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final usedCodes = context
        .read<VirtualNumbersProvider>()
        .adminApps
        .map((a) => a.serviceCode)
        .toSet();
    // اقتراح الخدمات المتبقية من الكتالوج الحيّ (تُملأ بالنقر)
    final suggestions = widget.catalogServices
        .where((s) => !_isEdit && !usedCodes.contains(s.code))
        .take(12)
        .toList();

    // عرض مضبوط للحوار: AlertDialog يقيس أبعاد المحتوى الجوهرية، ومقيّط
    // الأيقونات الداخلي (LayoutBuilder) لا يدعم القياس الجوهري فيقع في
    // وضع التصحيح — العرض الضيّق هنا يُبطل القياس ويثبّت التخطيط الشريطيّ
    final contentWidth = (MediaQuery.sizeOf(context).width - 120).clamp(
      260.0,
      340.0,
    );

    return AlertDialog(
      title: Text(_isEdit ? 'تعديل التطبيق' : 'تطبيق أرقام جديد'),
      content: SizedBox(
        width: contentWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'الاسم المعروض للعميل',
                  hintText: 'Telegram',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _codeCtrl,
                enabled: !_isEdit, // الرمز ثابت: المطابقة مع كتالوج المزود
                decoration: InputDecoration(
                  labelText: _isEdit
                      ? 'رمز الخدمة (ثابت)'
                      : 'رمز الخدمة لدى المزود',
                  hintText: _isEdit ? null : 'telegram',
                  helperText: _isEdit
                      ? null
                      : 'طابِقه من كتالوج المزود — به تُطابَق الأسعار والدول',
                  helperMaxLines: 2,
                  isDense: true,
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'خدمات من كتالوج المزود:',
                  style: AppTypography.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate500,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: suggestions
                      .map(
                        (s) => ActionChip(
                          label: Text(
                            '${s.name} · ${s.code}',
                            style: AppTypography.cairo(fontSize: 10),
                          ),
                          onPressed: () {
                            setState(() {
                              _codeCtrl.text = s.code;
                              if (_nameCtrl.text.trim().isEmpty) {
                                _nameCtrl.text = s.name;
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _iconCtrl,
                decoration: const InputDecoration(
                  labelText: 'أيقونة (اختياري)',
                  hintText: 'رابط أو مسار من المعرض أدناه',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 210,
                child: AppAssetPicker(
                  selected: _iconCtrl.text,
                  onSelected: (path, label, category) {
                    setState(() {
                      _iconCtrl.text = path;
                      if (_nameCtrl.text.trim().isEmpty) _nameCtrl.text = label;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('تراجع'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'حفظ' : 'إنشاء'),
        ),
      ],
    );
  }
}
