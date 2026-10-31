import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/virtual_numbers_provider.dart';
import '../../widgets/ops_ticket_card.dart';
import '../../widgets/status_pill.dart';

/// لوحة مراقبة جودة الأرقام: صف لكل منتج (سيرفر + تطبيق + دولة) بعدّاداته
/// ونسبة وصول أكواده. التقييم لكل مزود على حدة، فلا يُدمج تقييم سيرفر مع
/// تقييم غيره مهما باعا التطبيق والدولة نفسيهما، والإيقاف يخصّ المنتج وحده.
/// البطاقة تُفتح على ورقة تفاصيل فيها سجل الأحداث بأسبابه وآخر طلبات المنتج
/// وزر إعادة التفعيل (يصفّر الفشل المتتالي ويُبقي العدّادات التاريخية).
class VirtualNumberQualityScreen extends StatefulWidget {
  const VirtualNumberQualityScreen({super.key});

  @override
  State<VirtualNumberQualityScreen> createState() =>
      _VirtualNumberQualityScreenState();
}

class _VirtualNumberQualityScreenState
    extends State<VirtualNumberQualityScreen> {
  /// سلال اللوحة: «الكل» ثم الموقوفة أولاً في الترتيب الصادر من الخادم
  static const List<(String, String)> _buckets = [
    ('all', 'الكل'),
    ('active', 'نشطة'),
    ('watching', 'تحت المراقبة'),
    ('disabled', 'موقوفة'),
  ];

  final _searchCtrl = TextEditingController();
  String _bucket = 'all';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() => context
      .read<VirtualNumbersProvider>()
      .fetchAdminQuality(bucket: _bucket, search: _searchCtrl.text);

  /// إجراء مع رسالة موحّدة وتحديث للصفوف بعده (نفس نمط شاشات الانتقاء)
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

  Future<void> _openDetail(VirtualNumberQualityRow row) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (_) => _QualityDetailSheet(product: row),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VirtualNumbersProvider>();
    final board = provider.qualityBoard;
    final rows = board.rows;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('مراقبة جودة الأرقام'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: provider.isQualityLoading || _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            _summaryTicket(board.summary),
            const SizedBox(height: 12),
            _searchField(),
            const SizedBox(height: 10),
            _bucketTabs(board.summary),
            const SizedBox(height: 12),
            if (provider.errorMessage != null) ...[
              _messageBar(provider.errorMessage!),
              const SizedBox(height: 10),
            ],
            if (provider.isQualityLoading && rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (rows.isEmpty)
              _emptyState()
            else
              ...rows.map(_productCard),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // الرأس: ملخص السلال + البحث + الشرائح
  // ---------------------------------------------------------------------------

  Widget _summaryTicket(VirtualNumberQualitySummary summary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.slate900, AppColors.slate800],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _summaryFigure('${summary.active}', 'نشطة', AppColors.emerald),
          _divider(),
          _summaryFigure(
            '${summary.watching}',
            'مراقَبة',
            AppColors.ticketAmber,
          ),
          _divider(),
          _summaryFigure('${summary.disabled}', 'موقوفة', AppColors.rose),
          _divider(),
          _summaryFigure('${summary.all}', 'إجمالي', Colors.white),
        ],
      ),
    );
  }

  Widget _summaryFigure(String value, String label, Color tone) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTypography.balance(fontSize: 18, color: tone)),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.cairo(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.slate300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 26, color: AppColors.slate700);

  Widget _searchField() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (_) => _load(),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'بحث بالسيرفر أو التطبيق أو الدولة',
        hintStyle: AppTypography.cairo(fontSize: 12, color: AppColors.slate400),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 19,
          color: AppColors.slate400,
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

  Widget _bucketTabs(VirtualNumberQualitySummary summary) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _buckets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final (key, label) = _buckets[index];
          final selected = _bucket == key;
          return ActionChip(
            // العدّاد من الملخص لا من الصفوف المعروضة: السلة المختارة تُخفي
            // بقية الصفوف فتصير أرقامها أقل من حجم السلّة الحقيقي
            label: Text('$label (${summary.of(key)})'),
            onPressed: () {
              if (_bucket == key) return;
              setState(() => _bucket = key);
              _load();
            },
            backgroundColor: selected ? AppColors.slate900 : Colors.white,
            side: BorderSide(
              color: selected ? AppColors.slate900 : AppColors.slate300,
            ),
            labelStyle: AppTypography.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.slate700,
            ),
          );
        },
      ),
    );
  }

  Widget _messageBar(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 15,
            color: AppColors.errorLight,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTypography.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.errorLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46),
      child: Column(
        children: [
          const Icon(
            Icons.monitor_heart_outlined,
            size: 40,
            color: AppColors.slate400,
          ),
          const SizedBox(height: 10),
          Text(
            _bucket == 'all'
                ? 'لا منتجات أرقام بعد — تُبنى المنتجات من انتقاء الدول في لوحة التطبيقات'
                : 'لا منتج في هذه السلّة',
            textAlign: TextAlign.center,
            style: AppTypography.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // بطاقة منتج: الاسم الوهمي + نسبة الأكواد + العدّادات + سبب الإيقاف
  // ---------------------------------------------------------------------------

  Color _accent(VirtualNumberQualityRow row) {
    if (row.autoDisabled) return AppColors.rose;
    if (row.consecutiveFailures > 0) return AppColors.ticketAmber;
    if (!row.isActive) return AppColors.slate400;
    return AppColors.emerald;
  }

  String _bucketLabel(VirtualNumberQualityRow row) {
    if (row.autoDisabled) return 'موقوف جودةً';
    if (row.consecutiveFailures > 0) return 'تحت المراقبة';
    if (!row.isActive) return 'موقوف يدوياً';
    return 'نشِط';
  }

  Widget _productCard(VirtualNumberQualityRow row) {
    final accent = _accent(row);
    final rate = row.effectiveCodeRate;

    return OpsTicketCard(
      accent: accent,
      icon: Icons.sim_card_rounded,
      tag: row.title,
      title: '${row.flag} ${row.countryName}',
      subtitle: '${row.appName} • رمز الدولة ${row.countryCode}',
      status: StatusPill(status: _statusKey(row), label: _bucketLabel(row)),
      amount: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            row.codeRateLabel,
            style: AppTypography.price(fontSize: 15, color: accent),
          ),
          Text(
            'وصول الأكواد',
            style: AppTypography.cairo(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: AppColors.slate400,
            ),
          ),
        ],
      ),
      rows: [
        OpsTicketInfoRow(
          icon: Icons.receipt_long_rounded,
          label: 'الطلبات',
          value:
              '${row.totalOrders} • محتسب ${row.success + row.failure}'
              ' • غير محتسب ${row.cancelled + row.outOfStock + row.pending}',
        ),
        OpsTicketInfoRow(
          icon: Icons.fact_check_rounded,
          label: 'نجاح / فشل',
          value: '${row.success} / ${row.failure}',
          tint: accent,
        ),
        OpsTicketInfoRow(
          icon: Icons.repeat_on_rounded,
          label: 'الفشل المتتالي',
          value: '${row.consecutiveFailures}',
          tint: row.consecutiveFailures > 0 ? AppColors.rose : null,
        ),
        OpsTicketInfoRow(
          icon: Icons.hub_rounded,
          label: 'المزود الحقيقي',
          value: row.providerMissing
              ? 'مزود محذوف'
              : '${row.providerName}${row.providerActive ? '' : ' (موقوف)'}',
          tint: row.providerActive ? null : AppColors.rose,
        ),
        if (rate == null)
          OpsTicketInfoRow(
            icon: Icons.help_outline_rounded,
            label: 'التقييم',
            value: 'لا نتيجة محتسبة بعد — النفاد والإلغاء لا يُحسبان ضد المزود',
          ),
        if (row.disabledReason.isNotEmpty)
          OpsTicketInfoRow(
            icon: Icons.block_rounded,
            label: 'سبب الإيقاف',
            value: row.disabledReason,
            tint: AppColors.rose,
          ),
      ],
      meta: row.disabledAt == null
          ? 'آخر إيقاف: —'
          : 'آخر إيقاف: ${_stamp(row.disabledAt)}'
                '${row.disabledBy.isNotEmpty ? ' (${row.disabledBy})' : ''}',
      actions: [
        TextButton(
          onPressed: _busy ? null : () => _openDetail(row),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'السجل',
            style: AppTypography.cairo(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        if (row.needsAttention)
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => context
                        .read<VirtualNumbersProvider>()
                        .reactivateProduct(
                          row.productId,
                          note: 'إعادة تفعيل من لوحة الجودة',
                        ),
                  ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'إعادة تفعيل',
              style: AppTypography.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.tertiaryLight,
              ),
            ),
          ),
      ],
    );
  }

  /// StatusPill يعرف ألوانه من المفتاح: المراقَبة تُمرَّر pending لتصبح ذهبية
  String _statusKey(VirtualNumberQualityRow row) {
    if (row.autoDisabled) return 'inactive';
    if (row.consecutiveFailures > 0) return 'pending';
    return 'active';
  }

  String _stamp(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

// ---------------------------------------------------------------------------
// ورقة تفاصيل المنتج: عدّاداته + سجل أحداثه بأسبابه + آخر طلباته
// ---------------------------------------------------------------------------

class _QualityDetailSheet extends StatefulWidget {
  final VirtualNumberQualityRow product;

  const _QualityDetailSheet({required this.product});

  @override
  State<_QualityDetailSheet> createState() => _QualityDetailSheetState();
}

class _QualityDetailSheetState extends State<_QualityDetailSheet> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() => context
      .read<VirtualNumbersProvider>()
      .fetchQualityEvents(widget.product.productId);

  Future<void> _reactivate() async {
    setState(() => _busy = true);
    final provider = context.read<VirtualNumbersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final message = await provider.reactivateProduct(
      widget.product.productId,
      note: 'إعادة تفعيل من لوحة الجودة',
    );
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: message != null ? AppColors.slate800 : AppColors.rose,
        content: Text(
          message ?? provider.errorMessage ?? 'تعذّرت إعادة التفعيل',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VirtualNumbersProvider>();
    final detail = provider.qualityDetail;
    // الصف المارّ يبقى أساس العرض حتى أثناء الجلب أو لو فشل: السجل وحده يغيب
    final product = detail?.product ?? widget.product;
    final height = MediaQuery.sizeOf(context).height * 0.82;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(product),
          const SizedBox(height: 4),
          Expanded(
            child: provider.isQualityLoading && detail == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                    children: [
                      _countersRow(product),
                      if (product.disabledReason.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _reasonBox(product),
                      ],
                      const SizedBox(height: 12),
                      _sectionLabel('سجل الأحداث'),
                      if (detail == null || detail.events.isEmpty)
                        _tinyEmpty(
                          'لا أحداث مسجّلة بعد لهذا المنتج — يُسجَّل كل إغلاق طلب',
                        )
                      else
                        ...detail.events.map(_eventRow),
                      const SizedBox(height: 14),
                      _sectionLabel('آخر الطلبات'),
                      if (detail == null || detail.requests.isEmpty)
                        _tinyEmpty('لا طلبات على هذا المنتج')
                      else
                        ...detail.requests.map(_requestRow),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(VirtualNumberQualityRow product) {
    final accent = product.autoDisabled
        ? AppColors.rose
        : (product.consecutiveFailures > 0
              ? AppColors.ticketAmber
              : AppColors.emerald);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${product.flag} ${product.countryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate900,
                  ),
                ),
                Text(
                  '${product.title} • ${product.appName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          if (product.needsAttention)
            FilledButton.icon(
              onPressed: _busy ? null : _reactivate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.tertiaryLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 15),
              label: Text(
                _busy ? 'جارٍ…' : 'إعادة تفعيل',
                style: AppTypography.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            product.codeRateLabel,
            style: AppTypography.price(fontSize: 16, color: accent),
          ),
        ],
      ),
    );
  }

  Widget _countersRow(VirtualNumberQualityRow product) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _counter('الطلبات', '${product.totalOrders}', AppColors.slate700),
        _counter('نجاح', '${product.success}', AppColors.emerald),
        _counter('فشل', '${product.failure}', AppColors.rose),
        _counter('إلغاء', '${product.cancelled}', AppColors.slate500),
        _counter('نفاد', '${product.outOfStock}', AppColors.slate500),
        _counter('غير محسوم', '${product.pending}', AppColors.slate500),
        _counter(
          'متتالٍ',
          '${product.consecutiveFailures}',
          product.consecutiveFailures > 0 ? AppColors.rose : AppColors.slate500,
        ),
      ],
    );
  }

  Widget _counter(String label, String value, Color tone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.balance(fontSize: 12.5, color: tone),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.cairo(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasonBox(VirtualNumberQualityRow product) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block_rounded, size: 15, color: AppColors.rose),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '${product.disabledReason}'
              '${product.disabledBy.isNotEmpty ? ' — ${product.disabledBy}' : ''}',
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.errorLight,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.cairo(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.slate600,
        ),
      ),
    );
  }

  Widget _tinyEmpty(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: AppTypography.cairo(fontSize: 10.5, color: AppColors.slate400),
      ),
    );
  }

  /// حدث واحد: نتيجته هل دخلت التقييم + سببها الخام كما ورد من المزود
  Widget _eventRow(VirtualNumberQualityEvent event) {
    final tone = switch (event.outcome) {
      VirtualNumberQualityEvent.success => AppColors.emerald,
      VirtualNumberQualityEvent.failed => AppColors.rose,
      VirtualNumberQualityEvent.autoDisabled => AppColors.errorLight,
      VirtualNumberQualityEvent.reactivated => AppColors.primaryBlue,
      VirtualNumberQualityEvent.cancelled => AppColors.slate500,
      VirtualNumberQualityEvent.outOfStock => AppColors.slate500,
      _ => AppColors.ticketAmber,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.label,
                  style: AppTypography.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: tone,
                  ),
                ),
              ),
              Text(
                event.counted ? 'في التقييم' : 'غير محتسب',
                style: AppTypography.cairo(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: event.counted ? tone : AppColors.slate400,
                ),
              ),
            ],
          ),
          if (event.reason.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              event.reason,
              style: AppTypography.cairo(
                fontSize: 10,
                color: AppColors.slate600,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 3),
          Text(
            '${event.sourceLabel}'
            '${event.requestNumber.isNotEmpty ? ' • ${event.requestNumber}' : ''}'
            ' • ${_stamp(event.createdAt)}',
            style: AppTypography.cairo(fontSize: 9, color: AppColors.slate400),
          ),
        ],
      ),
    );
  }

  Widget _requestRow(VirtualNumberQualityRequest request) {
    final tone = request.hasCode ? AppColors.emerald : AppColors.rose;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Icon(
            request.hasCode ? Icons.sms_rounded : Icons.sms_failed_rounded,
            size: 15,
            color: tone,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.requestNumber.isEmpty ? '—' : request.requestNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate800,
                  ),
                ),
                Text(
                  '${request.status}'
                  '${request.phoneNumber.isNotEmpty ? ' • ${request.phoneNumber}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 9,
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
          Text(
            request.hasCode ? (request.smsCode ?? '') : 'بلا رمز',
            style: AppTypography.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }

  String _stamp(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
