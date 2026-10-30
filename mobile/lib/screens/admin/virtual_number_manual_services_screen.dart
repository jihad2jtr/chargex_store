import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/virtual_numbers_provider.dart';

/// شاشة إدارة «خدمات الأرقام اليدوية» (تفعيل مضمون).
///
/// الخدمة منتج (type=manual) بلا تطبيق متجر: تُربط بتطبيق أرقام (تليجرام/واتساب…)
/// وتُسند لمشرف. تظهر في القسم الأول من صفحة أرقام العميل، وطلبها يمر عبر
/// /orders نفسه فيسلك مسار الخدمات اليدوية (محفظة ذرّية + عمل في مساحة المشرف).
class VirtualNumberManualServicesScreen extends StatefulWidget {
  const VirtualNumberManualServicesScreen({super.key});

  @override
  State<VirtualNumberManualServicesScreen> createState() =>
      _VirtualNumberManualServicesScreenState();
}

class _VirtualNumberManualServicesScreenState
    extends State<VirtualNumberManualServicesScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<VirtualNumbersProvider>();
    final admin = context.read<AdminProvider>();
    await Future.wait([
      provider.fetchAdminManualServices(),
      provider.fetchAdminApps(quiet: true),
      admin.fetchAllUsers(silent: true),
    ]);
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final provider = context.read<VirtualNumbersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final message = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: message != null ? AppColors.slate800 : AppColors.rose,
        content: Text(
          message ?? provider.errorMessage ?? 'تعذّرت العملية',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _openForm({VirtualNumberManualServiceModel? service}) async {
    // تطبيقات الأرقام مطلوبة للاسناد: تُجلب إن لم تكن محمّلة بعد
    final provider = context.read<VirtualNumbersProvider>();
    if (provider.adminApps.isEmpty) {
      await provider.fetchAdminApps();
      if (!mounted) return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _ManualServiceFormSheet(service: service),
    );
    if (saved == true) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VirtualNumbersProvider>();
    final services = provider.adminManualServices;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('خدمات الأرقام اليدوية'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: provider.isManualLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'خدمة جديدة',
            onPressed: _busy ? null : () => _openForm(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: provider.isManualLoading && services.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : services.isEmpty
            ? _buildEmpty()
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                itemCount: services.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final service = services[index];
                  return _ManualServiceCard(
                    service: service,
                    busy: _busy,
                    onEdit: () => _openForm(service: service),
                    onToggle: () => _run(
                      () => provider.toggleAdminManualService(service.id),
                    ),
                    onDelete: () => _confirmDelete(service),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.verified_rounded, size: 46, color: AppColors.slate400),
        const SizedBox(height: 12),
        Text(
          'لا خدمات تفعيل مضمون بعد',
          textAlign: TextAlign.center,
          style: AppTypography.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'أضف خدمة يدوية لتطبيق أرقام واسندها لمشرف؛ ستظهر في أعلى صفحة العميل.',
          textAlign: TextAlign.center,
          style: AppTypography.cairo(fontSize: 11.5, color: AppColors.slate500),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _openForm(),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('خدمة جديدة'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(VirtualNumberManualServiceModel service) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الخدمة'),
        content: Text(
          'سيُحذف "${service.name}"${service.openOrders > 0 ? ' — وستُوقَف فقط لوجود ${service.openOrders} طلباً قيد التنفيذ' : ''}.',
          style: AppTypography.cairo(fontSize: 12.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (go != true) return;
    await _run(
      () => context.read<VirtualNumbersProvider>().deleteAdminManualService(
        service.id,
      ),
    );
  }
}

// ورقة إنشاء/تعديل خدمة يدوية للأرقام: اسم + تطبيق أرقام + مشرف + سعر + حقول.
class _ManualServiceFormSheet extends StatefulWidget {
  final VirtualNumberManualServiceModel? service;

  const _ManualServiceFormSheet({this.service});

  @override
  State<_ManualServiceFormSheet> createState() =>
      _ManualServiceFormSheetState();
}

class _ManualServiceFormSheetState extends State<_ManualServiceFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _fieldsCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _instructionsCtrl;

  String? _appId;
  String? _supervisorId;
  bool _isSensitive = false;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.service != null;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _priceCtrl = TextEditingController(
      text: s == null ? '' : s.price.toStringAsFixed(2),
    );
    _minutesCtrl = TextEditingController(
      text: (s?.estimatedMinutes ?? 120).toString(),
    );
    _fieldsCtrl = TextEditingController(
      text: s?.requiredFields.join('، ') ?? '',
    );
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _instructionsCtrl = TextEditingController(text: s?.instructions ?? '');
    _appId = s?.appId.isNotEmpty == true ? s!.appId : null;
    _supervisorId = s?.supervisorId.isNotEmpty == true ? s!.supervisorId : null;
    _isSensitive = s?.isSensitive ?? false;
    _isActive = s?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _minutesCtrl.dispose();
    _fieldsCtrl.dispose();
    _descCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  List<String> _parseFields(String raw) => raw
      .split(RegExp(r'[،,;\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    if (name.isEmpty) {
      _toast('اسم الخدمة مطلوب');
      return;
    }
    if (_appId == null) {
      _toast('اختر تطبيق الأرقام');
      return;
    }
    if (price == null || price <= 0) {
      _toast('حدد سعر الخدمة بالدولار');
      return;
    }
    final fields = _parseFields(_fieldsCtrl.text);

    setState(() => _saving = true);
    final provider = context.read<VirtualNumbersProvider>();
    final body = <String, dynamic>{
      'name': name,
      'vnAppId': _appId,
      'supervisorId': _supervisorId,
      'price': price,
      'description': _descCtrl.text.trim(),
      'instructions': _instructionsCtrl.text.trim(),
      'requiredFields': fields,
      'estimatedMinutes': int.tryParse(_minutesCtrl.text.trim()) ?? 120,
      'isSensitive': _isSensitive,
      'isActive': _isActive,
    };
    final message = _isEdit
        ? await provider.updateAdminManualService(widget.service!.id, body)
        : await provider.createAdminManualService(body);
    if (!mounted) return;
    if (message != null) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      _toast(provider.errorMessage ?? 'تعذّرت الحفظ');
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.slate800,
        content: Text(
          text,
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<VirtualNumbersProvider>().adminApps;
    final users = context.watch<AdminProvider>().allUsers;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _isEdit ? 'تعديل الخدمة' : 'خدمة تفعيل مضمون جديدة',
              style: AppTypography.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'تظهر الخدمة في أعلى صفحة أرقام العميل، ويُسنَد طلبها للمشرف المختار.',
              style: AppTypography.cairo(
                fontSize: 11,
                color: AppColors.slate500,
              ),
            ),
            const SizedBox(height: 14),
            _field(
              controller: _nameCtrl,
              label: 'اسم الخدمة *',
              icon: Icons.title_rounded,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _appId,
              isExpanded: true,
              decoration: _decor('تطبيق الأرقام *', Icons.apps_rounded),
              items: [
                ...apps.map(
                  (a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _appId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _supervisorId,
              isExpanded: true,
              decoration: _decor('المشرف المسؤول', Icons.person_pin_rounded),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('بدون مشرف محدد (يعينه الأدمن لاحقاً)'),
                ),
                ...users.map(
                  (u) => DropdownMenuItem(
                    value: u['_id']?.toString(),
                    child: Text(
                      '${u['name']} (${u['email']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _supervisorId = v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _priceCtrl,
                    label: 'السعر \$ *',
                    icon: Icons.attach_money_rounded,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    controller: _minutesCtrl,
                    label: 'المهلة (دقيقة)',
                    icon: Icons.timer_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _field(
              controller: _fieldsCtrl,
              label: 'الحقول المطلوبة (افصل بينها بفاصلة)',
              icon: Icons.input_rounded,
              hint: 'مثال: رقم الهاتف، اسم الحساب',
            ),
            const SizedBox(height: 10),
            _field(
              controller: _descCtrl,
              label: 'الوصف (اختياري)',
              icon: Icons.description_rounded,
            ),
            const SizedBox(height: 10),
            _field(
              controller: _instructionsCtrl,
              label: 'تعليمات التنفيذ للمشرف (اختياري)',
              icon: Icons.assignment_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isSensitive,
              onChanged: (v) => setState(() => _isSensitive = v),
              title: Text(
                'بيانات حساسة (تشفير المؤقت)',
                style: AppTypography.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: Text(
                'مفعّلة (تظهر للعميل)',
                style: AppTypography.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isEdit ? 'حفظ التعديلات' : 'إضافة الخدمة'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decor(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: AppTypography.cairo(fontSize: 12, color: AppColors.slate500),
    prefixIcon: Icon(icon, size: 18, color: AppColors.slate400),
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTypography.cairo(fontSize: 12.5, color: AppColors.slate900),
      decoration: _decor(label, icon).copyWith(
        hintText: hint,
        hintStyle: AppTypography.cairo(fontSize: 11, color: AppColors.slate400),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة خدمة واحدة
// ---------------------------------------------------------------------------

class _ManualServiceCard extends StatelessWidget {
  final VirtualNumberManualServiceModel service;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ManualServiceCard({
    required this.service,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: AppTypography.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                      ),
                    ),
                    if (service.appName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'تطبيق: ${service.appName}',
                        style: AppTypography.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _priceTag(service.price),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _chip(
                Icons.person_pin_rounded,
                service.supervisorName.isNotEmpty
                    ? service.supervisorName
                    : 'غير مسند',
              ),
              if (service.etaLabel.isNotEmpty)
                _chip(Icons.timer_outlined, service.etaLabel),
              if (service.isSensitive)
                _chip(Icons.lock_rounded, 'بيانات حساسة'),
              if (service.openOrders > 0)
                _chip(
                  Icons.pending_actions_rounded,
                  '${service.openOrders} جاري',
                ),
              _chip(
                Icons.toggle_on_rounded,
                service.isActive ? 'مفعّلة' : 'موقوفة',
                tone: service.isActive ? AppColors.emerald : AppColors.slate400,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: service.isActive ? 'إيقاف' : 'تفعيل',
                visualDensity: VisualDensity.compact,
                onPressed: busy ? null : onToggle,
                icon: Icon(
                  service.isActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  color: service.isActive
                      ? AppColors.emerald
                      : AppColors.slate400,
                ),
              ),
              IconButton(
                tooltip: 'تعديل',
                visualDensity: VisualDensity.compact,
                onPressed: busy ? null : onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.slate700,
                ),
              ),
              IconButton(
                tooltip: 'حذف',
                visualDensity: VisualDensity.compact,
                onPressed: busy ? null : onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.rose,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceTag(double price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '\$${price.toStringAsFixed(2)}',
        style: AppTypography.cairo(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFDE047),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color? tone}) {
    final color = tone ?? AppColors.slate600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
