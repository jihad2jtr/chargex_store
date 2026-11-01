import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/virtual_number_model.dart';
import '../providers/virtual_numbers_provider.dart';
import 'app_asset_picker.dart';

/// محرّر إنشاء/تعديل تطبيق أرقام (الاسم + رمز الخدمة + معرض الأيقونات).
///
/// كان حوار AlertDialog ضيّقاً لا يتسع لمقيّط الصور (تبويبات + بحث + تصفية
/// + شبكة 236px فيتداخل)، وأصبح ورقة سفلية بارتفاع 90% من الشاشة: حقول
/// مريحة قابلة للتمرير، قسم أيقونة مستقل بكامل عرضه، وشريط حفظ ثابت أسفل.
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

  /// فتح المحرّر في ورقة سفلية كاملة العرض — العقد نفسه كحوار سابق:
  /// يُرجَع true بعد حفظ ناجح، وfalse أو null عند الإغلاق بلا حفظ
  static Future<bool?> open(
    BuildContext context, {
    VirtualNumberAppModel? app,
    List<({String code, String name})> catalogServices = const [],
    String initialName = '',
    String initialServiceCode = '',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => Padding(
        // اللوحة المفاتيح لا تحجب شريط الحفظ ولا آخر الحقول
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: VirtualNumberAppFormDialog(
          app: app,
          catalogServices: catalogServices,
          initialName: initialName,
          initialServiceCode: initialServiceCode,
        ),
      ),
    );
  }

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

    // الورقة تعطي قيوداً محددة للمحتوى: لا قياس جوهري ولا تداخل — بعكس AlertDialog
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      width: double.infinity,
      child: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _fieldLabel('الاسم المعروض للعميل'),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Telegram',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(
                    _isEdit ? 'رمز الخدمة لدى المزود (ثابت)' : 'رمز الخدمة',
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _codeCtrl,
                    enabled: !_isEdit, // الرمز ثابت: المطابقة مع كتالوج المزود
                    decoration: InputDecoration(
                      hintText: _isEdit ? null : 'telegram',
                      helperText: _isEdit
                          ? null
                          : 'طابِقه من كتالوج المزود — به تُطابَق الأسعار والدول',
                      helperMaxLines: 2,
                      isDense: true,
                    ),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _fieldLabel('خدمات من كتالوج المزود (انقر للإدراج):'),
                    const SizedBox(height: 6),
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
                  const SizedBox(height: 16),
                  _iconSection(),
                ],
              ),
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.slate900,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isEdit ? Icons.edit_outlined : Icons.add_rounded,
              size: 17,
              color: AppColors.ticketAmber,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'تعديل التطبيق' : 'تطبيق أرقام جديد',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                  ),
                ),
                Text(
                  'الدول والأسعار تُطابَق برمز الخدمة لا بالاسم',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 10,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إغلاق',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(
              Icons.close_rounded,
              size: 20,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: AppTypography.cairo(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.slate700,
      ),
    );
  }

  /// قسم الأيقونة بكامل عرض الورقة: حقل المسار ثم المنتقي بلا قصّ ارتفاع —
  /// المنتقي جلب شبكته الثابتة (236px) داخل التمرير، فلم يعد يتداخل
  Widget _iconSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.image_outlined,
                size: 16,
                color: AppColors.slate700,
              ),
              const SizedBox(width: 6),
              Expanded(child: _fieldLabel('أيقونة التطبيق (اختياري)')),
              if (_iconCtrl.text.trim().isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _iconCtrl.text = ''),
                  child: const Text('مسح'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _iconCtrl,
            decoration: const InputDecoration(
              hintText: 'رابط أو مسار — أو اختر من المعرض أدناه',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          AppAssetPicker(
            selected: _iconCtrl.text,
            onSelected: (path, label, category) {
              setState(() {
                _iconCtrl.text = path;
                if (_nameCtrl.text.trim().isEmpty) _nameCtrl.text = label;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 14, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate200)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size(112, 40)),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEdit ? 'حفظ' : 'إنشاء'),
          ),
        ],
      ),
    );
  }
}
