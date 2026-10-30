import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/virtual_numbers_provider.dart';
import '../../widgets/ops_ticket_card.dart';
import '../../widgets/status_pill.dart';
import 'providers_management_screen.dart';
import 'virtual_number_apps_screen.dart';

/// لوحة إدارة الأرقام الوهمية: متابعة طلبات العملاء، حالة مزود الأرقام ورصيده،
/// مزامنة الكتالوج، وتحكم الأدمن بالإلغاء (مع إرجاع المبلغ) أو الإغلاق.
class VirtualNumbersManagementScreen extends StatefulWidget {
  const VirtualNumbersManagementScreen({super.key});

  @override
  State<VirtualNumbersManagementScreen> createState() =>
      _VirtualNumbersManagementScreenState();
}

class _VirtualNumbersManagementScreenState
    extends State<VirtualNumbersManagementScreen> {
  static const List<_StatusTab> _tabs = [
    _StatusTab('all', 'الكل', null),
    _StatusTab('pending', 'تجهيز', VirtualNumberRequestModel.pending),
    _StatusTab('waiting', 'بانتظار', VirtualNumberRequestModel.waiting),
    _StatusTab('received', 'وصل', VirtualNumberRequestModel.received),
    _StatusTab('completed', 'مغلق', VirtualNumberRequestModel.completed),
    _StatusTab('expired', 'منتهي', VirtualNumberRequestModel.expired),
    _StatusTab('cancelled', 'ملغى', VirtualNumberRequestModel.cancelled),
    _StatusTab('failed', 'فشل', VirtualNumberRequestModel.failed),
  ];

  final _searchCtrl = TextEditingController();
  String _status = 'all';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<VirtualNumbersProvider>();
      provider.fetchAdminStats();
      provider.fetchAdminRequests();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final provider = context.read<VirtualNumbersProvider>();
    await provider.fetchAdminStats();
    await provider.fetchAdminRequests(
      status: _status,
      search: _searchCtrl.text,
    );
  }

  Future<void> _run(
    Future<String?> Function() action, {
    bool reloadList = true,
  }) async {
    setState(() => _busy = true);
    final provider = context.read<VirtualNumbersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final message = await action();
    if (!context.mounted) return;
    setState(() => _busy = false);
    if (reloadList) await _reload();
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VirtualNumbersProvider>();
    final stats = provider.stats;
    final rows = provider.adminRequests;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إدارة الأرقام الوهمية'),
        actions: [
          // تطبيقات الأرقام (تليجرام/واتساب…): تُنشأ فارغة ثم تُنتقى دولها
          IconButton(
            tooltip: 'تطبيقات الأرقام',
            onPressed: _openApps,
            icon: const Icon(Icons.apps_rounded),
          ),
          // خدمات التفعيل المضمون انتقلت إلى بطاقة مستقلة في لوحة الأدمن
          // مزودو الأرقام في صفحة مستقلة عن مزودي المتاجر
          IconButton(
            tooltip: 'إدارة مزودي الأرقام',
            onPressed: _openProviders,
            icon: const Icon(Icons.settings_ethernet_rounded),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: provider.isAdminLoading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            _overviewTicket(provider, stats),
            const SizedBox(height: 14),
            _searchField(),
            const SizedBox(height: 10),
            _statusTabs(stats),
            const SizedBox(height: 12),
            if (provider.errorMessage != null) ...[
              _messageBar(provider.errorMessage!, isError: true),
              const SizedBox(height: 10),
            ],
            if (provider.infoMessage != null) ...[
              _messageBar(provider.infoMessage!),
              const SizedBox(height: 10),
            ],
            if (provider.isAdminLoading && rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (rows.isEmpty)
              _emptyState()
            else ...[
              _sectionHeader('طلبات العملاء'),
              ...rows.map((request) => _requestCard(request)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openApps() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const VirtualNumberAppsScreen()));
  }

  Future<void> _openProviders() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const ProvidersManagementScreen(virtualNumbersOnly: true),
      ),
    );
    // العودة بعد إضافة مزود أو تعديله: تُحدَّث بطاقة المزود والرصيد هنا
    if (mounted) await context.read<VirtualNumbersProvider>().fetchAdminStats();
  }

  // ---------------------------------------------------------------------------
  // بطاقة النظرة العامة (تذكرة): مؤشرات + خط تمزّق + أدوار التشغيل والمزود
  // ---------------------------------------------------------------------------

  Widget _overviewTicket(
    VirtualNumbersProvider provider,
    VirtualNumberStats stats,
  ) {
    final info = stats.provider;
    return Container(
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0891B2).withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Icon(
                    Icons.numbers_rounded,
                    size: 18,
                    color: Color(0xFF0891B2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'نظرة عامة',
                    style: AppTypography.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                StatusPill(
                  status: info == null
                      ? 'inactive'
                      : (info.isActive ? info.status : 'inactive'),
                  label: info == null ? 'بلا مزود' : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                _kpi('${stats.total}', 'إجمالي', Colors.white),
                _kpi(
                  '\$${stats.revenue.toStringAsFixed(2)}',
                  'إيراد',
                  const Color(0xFFFDE047),
                ),
                _kpi(
                  '\$${stats.cost.toStringAsFixed(2)}',
                  'تكلفة',
                  Colors.white70,
                ),
                _kpi(
                  '\$${stats.profit.toStringAsFixed(2)}',
                  'ربح',
                  const Color(0xFF6EE7B7),
                ),
              ],
            ),
          ),
          const OpsTearLine(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 12, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _controlButton(
                  label: 'مزامنة الكتالوج',
                  icon: Icons.sync_rounded,
                  enabled: !_busy,
                  onTap: () => provider.adminSyncCatalog(),
                  reloadList: false,
                ),
                _controlButton(
                  label: 'فحص المزود',
                  icon: Icons.monitor_heart_outlined,
                  enabled: !_busy,
                  onTap: () => provider.adminCheckProvider(),
                  reloadList: false,
                ),
                _controlButton(
                  label: 'المسح الدوري',
                  icon: Icons.autorenew_rounded,
                  enabled: !_busy,
                  onTap: () => provider.adminRunSweep(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String value, String label, Color tone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.slate800,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.balance(color: tone, fontSize: 13.5),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.cairo(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required Future<String?> Function() onTap,
    bool reloadList = true,
  }) {
    return TextButton.icon(
      onPressed: enabled ? () => _run(onTap, reloadList: reloadList) : null,
      icon: Icon(icon, size: 15),
      label: Text(label, style: AppTypography.cairo(fontSize: 11)),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.slate700,
        disabledForegroundColor: AppColors.slate400,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        padding: const EdgeInsets.symmetric(horizontal: 9),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchCtrl,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _reload(),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'بحث برقم الطلب أو العميل أو الرقم',
        hintStyle: AppTypography.cairo(fontSize: 12, color: AppColors.slate400),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 19,
          color: AppColors.slate400,
        ),
        suffixIcon: IconButton(
          tooltip: 'بحث',
          onPressed: _reload,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate300),
        ),
      ),
    );
  }

  Widget _statusTabs(VirtualNumberStats stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _tabs.map((tab) {
          final selected = _status == tab.key;
          final count = tab.statusCode == null
              ? stats.total
              : stats.countOf(tab.statusCode!);
          return Padding(
            padding: const EdgeInsets.only(left: 7),
            child: FilterChip(
              selected: selected,
              label: Text('${tab.label} ($count)'),
              onSelected: (_) {
                setState(() => _status = tab.key);
                _reload();
              },
              selectedColor: AppColors.slate900,
              labelStyle: AppTypography.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.slate700,
              ),
              checkmarkColor: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _messageBar(String message, {bool isError = false}) {
    final tone = isError ? AppColors.rose : AppColors.slate700;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: AppTypography.cairo(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: tone,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          const Icon(
            Icons.numbers_rounded,
            size: 42,
            color: AppColors.slate400,
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد طلبات بهذا التصنيف',
            style: AppTypography.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // بطاقة طلب في اللوحة
  // ---------------------------------------------------------------------------

  /// عنوان قسم داخل قائمة التذاكر: شريط بلون التذكرة مع خط جانبي
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF0891B2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: AppTypography.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.slate700,
            ),
          ),
          const Expanded(
            child: Divider(color: AppColors.outlineVariant, indent: 10),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(VirtualNumberRequestModel request) {
    final accent = request.hasCode
        ? AppColors.emerald
        : (request.isLive
              ? AppColors.ticketAmber
              : (request.isRefunded ? AppColors.slate500 : AppColors.rose));

    final customer = [
      if (request.userName.isNotEmpty) request.userName,
      if (request.customUserId.isNotEmpty) request.customUserId,
      if (request.userEmail.isNotEmpty) request.userEmail,
    ].join(' • ');

    return OpsTicketCard(
      accent: accent,
      icon: Icons.sim_card_rounded,
      tag: '#${request.requestNumber}',
      title: '${request.title} • ${request.countryName}',
      subtitle: customer.isNotEmpty
          ? customer
          : (request.operator.isEmpty ? 'أي مشغّل' : request.operator),
      amount: Text(
        '\$${request.amount.toStringAsFixed(2)}',
        style: AppTypography.price(fontSize: 13, color: AppColors.slate900),
      ),
      status: StatusPill(status: request.status, label: request.statusLabel),
      rows: [
        OpsTicketInfoRow(
          icon: Icons.phone_rounded,
          label: 'الرقم',
          value: request.phoneNumber ?? '— لم يُجهّز بعد',
          mono: true,
          trailing: request.phoneNumber == null
              ? null
              : IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'نسخ الرقم',
                  onPressed: () => _copy(request.phoneNumber!, 'الرقم'),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: AppColors.slate500,
                  ),
                ),
        ),
        if (request.hasCode)
          OpsTicketInfoRow(
            icon: Icons.key_rounded,
            label: 'رمز التحقق',
            value: request.smsCode!,
            mono: true,
            tint: AppColors.tertiaryLight,
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'نسخ الرمز',
              onPressed: () => _copy(request.smsCode!, 'الرمز'),
              icon: const Icon(
                Icons.copy_rounded,
                size: 15,
                color: AppColors.tertiaryLight,
              ),
            ),
          ),
        OpsTicketInfoRow(
          icon: Icons.request_quote_rounded,
          label: 'التكلفة / الربح',
          value:
              '\$${request.cost.toStringAsFixed(2)} / '
              '\$${request.profit.toStringAsFixed(2)}',
        ),
        if (request.providerRef.isNotEmpty)
          OpsTicketInfoRow(
            icon: Icons.tag_rounded,
            label: 'مرجع المزود',
            value: request.providerRef,
            mono: true,
          ),
      ],
      // اللوحة ترى السبب الداخلي (اسم المزود وملاحظة من نفّذ الإجراء)،
      // أما العميل فلا يصله سوى العبارة العامة في حقل note
      note: request.adminNote.isNotEmpty ? request.adminNote : request.note,
      meta: _metaLine(request),
      actions: request.isLive
          ? [
              if (request.hasCode)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => context
                              .read<VirtualNumbersProvider>()
                              .adminFinish(request.id),
                        ),
                  child: const Text('إغلاق'),
                ),
              FilledButton(
                onPressed: _busy ? null : () => _cancelRequest(request),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.slate700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: const Text('إلغاء وإرجاع'),
              ),
            ]
          : const [],
    );
  }

  String _metaLine(VirtualNumberRequestModel request) {
    final created = request.createdAt;
    final parts = <String>[
      if (created != null)
        '${created.day.toString().padLeft(2, '0')}/'
            '${created.month.toString().padLeft(2, '0')} '
            '${created.hour.toString().padLeft(2, '0')}:'
            '${created.minute.toString().padLeft(2, '0')}',
      if (request.isLive && request.remainingSeconds() != null)
        'متبقٍ ${request.remainingSeconds()}ث',
      if (request.isRefunded) 'أُرجع المبلغ',
    ];
    return parts.join(' • ');
  }

  Future<void> _cancelRequest(VirtualNumberRequestModel request) async {
    final reasonCtrl = TextEditingController();
    final provider = context.read<VirtualNumbersProvider>();

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إلغاء #${request.requestNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'يُلغى الرقم لدى المزود ويُرجع \$${request.amount.toStringAsFixed(2)} '
              'لرصيد العميل.',
              style: AppTypography.cairo(fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء (اختياري)',
                helperText: 'يبقى في اللوحة وحدها: العميل يقرأ عبارة عامة',
                helperMaxLines: 2,
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (go != true) return;

    await _run(
      () => provider.adminCancel(
        request.id,
        reason: reason.isEmpty ? null : reason,
      ),
    );
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.slate800,
        content: Text(
          'تم نسخ $label',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }
}

class _StatusTab {
  final String key;
  final String label;
  final String? statusCode;

  const _StatusTab(this.key, this.label, this.statusCode);
}
