import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/virtual_numbers_provider.dart';
import '../../widgets/app_asset_picker.dart';
import 'virtual_number_catalog_screen.dart';

/// تطبيقات الأرقام الوهمية: نفس فكرة «تطبيقات المتجر» —
/// تُنشئ هنا تطبيقاً فارغاً لكل خدمة (تليجرام/واتساب…)، ثم تنتقي دولها
/// (منتجاتها) من كتالوج المزود عبر صفحة مزودي الأرقام. لا تظهر أي خدمة
/// للعميل قبل إضافة دولة مفعّلة إلى تطبيقها.
class VirtualNumberAppsScreen extends StatefulWidget {
  const VirtualNumberAppsScreen({super.key});

  @override
  State<VirtualNumberAppsScreen> createState() =>
      _VirtualNumberAppsScreenState();
}

class _VirtualNumberAppsScreenState extends State<VirtualNumberAppsScreen> {
  final _searchCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // listAdminApps يقرأ الدول من قاعدة البيانات مباشرة، فتظهر التطبيقات
      // ودولها في اللوحة حتى لو كان المزود معطلاً (لا جلب كتالوج هنا).
      if (mounted) context.read<VirtualNumbersProvider>().fetchAdminApps();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await context.read<VirtualNumbersProvider>().fetchAdminApps();
  }

  /// تنفيذ إجراء تنسيق مع رسالة نتيجة موحّدة (نفس نمط شاشة الإدارة الأم)
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
    if (message != null) await _reload();
  }

  Future<void> _openForm({VirtualNumberAppModel? app}) async {
    final provider = context.read<VirtualNumbersProvider>();
    // اقتراح رموز الخدمات يبدأ من الكتالوج المخزّن ثم يُجلب إن كان فارغاً
    var codes = provider.adminCatalog.services
        .map((s) => (code: s.code, name: s.name))
        .toList();
    if (codes.isEmpty) {
      await provider.fetchAdminCatalog();
      if (mounted) {
        codes = context
            .read<VirtualNumbersProvider>()
            .adminCatalog
            .services
            .map((s) => (code: s.code, name: s.name))
            .toList();
      }
    }
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AppFormDialog(app: app, catalogServices: codes),
    );
    if (saved == true) await _reload();
  }

  Future<void> _openCatalog(VirtualNumberAppModel? app) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VirtualNumberCatalogScreen(focusApp: app),
      ),
    );
    // العودة من انتقاء الدول أو تبديل تفعيلها: العدّادات تتغير
    if (mounted) await _reload();
  }

  Future<void> _confirmDelete(VirtualNumberAppModel app) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التطبيق'),
        content: Text(
          'سيُحذف "${app.name}" مع ${app.productCount} دولة مرتبطة به. '
          'لن تظهر هذه الخدمة للعميل في صفحة الأرقام.',
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
      () => context.read<VirtualNumbersProvider>().deleteAdminApp(app.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VirtualNumbersProvider>();
    final query = _searchCtrl.text.trim().toLowerCase();
    final apps = provider.adminApps
        .where(
          (app) =>
              query.isEmpty ||
              app.name.toLowerCase().contains(query) ||
              app.serviceCode.toLowerCase().contains(query),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تطبيقات الأرقام'),
        actions: [
          IconButton(
            tooltip: 'إضافة تطبيق لكل خدمة في كتالوج المزود',
            onPressed: _busy ? null : _bulkImport,
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: provider.isAppsLoading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'تطبيق جديد',
            onPressed: _busy ? null : () => _openForm(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _hintBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'بحث بالاسم أو رمز الخدمة',
                hintStyle: AppTypography.cairo(
                  fontSize: 12,
                  color: AppColors.slate400,
                ),
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
            ),
          ),
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: AppColors.errorLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: AppTypography.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.errorLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: provider.isAppsLoading && provider.adminApps.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : apps.isEmpty
                  ? _emptyState(query)
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                      itemCount: apps.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _appCard(apps[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkImport() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استيراد كتالوج الخدمات'),
        content: Text(
          'يُنشئ تطبيقاً مفعّلاً لكل خدمة في كتالوج المزود لم تُضَف بعد — '
          'بلا دول. تُنتقى الدول لكل خدمة لاحقاً من كتالوج المزود، '
          'فلا يظهر شيء للعميل قبل الانتقاء.',
          style: AppTypography.cairo(fontSize: 12.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استيراد'),
          ),
        ],
      ),
    );
    if (go != true) return;
    await _run(
      () => context.read<VirtualNumbersProvider>().bulkCreateAdminApps(),
    );
  }

  Widget _hintBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.slate300),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 16,
            color: AppColors.slate700,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'أنشئ التطبيق فارغاً هنا، ثم انتقِ دوله من «مزودو الأرقام الوهمية». '
              'الخدمة لا تظهر للعميل إلا بتطبيق مفعّل ودولة مفعّلة واحدة على الأقل.',
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.slate700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String query) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 60),
      children: [
        Icon(
          query.isEmpty
              ? Icons.app_registration_rounded
              : Icons.search_off_rounded,
          size: 42,
          color: AppColors.slate400,
        ),
        const SizedBox(height: 10),
        Text(
          query.isEmpty
              ? 'لا توجد تطبيقات بعد — أنشئ تطبيقاً لكل خدمة تريد بيع أرقامها'
              : 'لا نتيجة مطابقة للبحث',
          textAlign: TextAlign.center,
          style: AppTypography.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.slate500,
          ),
        ),
        if (query.isEmpty) ...[
          const SizedBox(height: 14),
          Center(
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _openForm(),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('تطبيق جديد'),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // بطاقة تطبيق: عدّاد الدول + إجراءات (تفعيل/تعديل/انتقاء/حذف)
  // ---------------------------------------------------------------------------

  Widget _appCard(VirtualNumberAppModel app) {
    // الدول تُقرأ مباشرة من `app.countries` (ناتج listAdminApps الذي يقرأ
    // قاعدة البيانات)، حتى تظهر التطبيقات ودولها في اللوحة ولو كان المزود
    // معطلاً (يحاول جلب الكتالوج فيفشل). الكتالوج يُستعمل احتياطاً فقط.
    final countries = app.countries.isNotEmpty
        ? app.countries
        : _countriesFromCatalog(app);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: app.isActive ? AppColors.outlineVariant : AppColors.slate300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    app.name.isEmpty ? '?' : app.name.characters.first,
                    style: AppTypography.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFDE047),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                      ),
                    ),
                    Text(
                      'رمز الخدمة: ${app.serviceCode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 10.5,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              // مؤشر ما يراه العميل: يظهر فقط عند وجود دولة مفعّلة
              _visibilityChip(app),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _countBadge(
                '${app.activeProductCount}/${app.productCount}',
                'دولة مفعّلة',
              ),
              const Spacer(),
              IconButton(
                tooltip: app.isActive ? 'إيقاف التطبيق' : 'تفعيل التطبيق',
                visualDensity: VisualDensity.compact,
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => context
                            .read<VirtualNumbersProvider>()
                            .toggleAdminApp(app.id),
                      ),
                icon: Icon(
                  app.isActive
                      ? Icons.power_settings_new_rounded
                      : Icons.power_off_rounded,
                  size: 19,
                  color: app.isActive ? AppColors.emerald : AppColors.slate400,
                ),
              ),
              IconButton(
                tooltip: 'تعديل الاسم أو الأيقونة',
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : () => _openForm(app: app),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.slate700,
                ),
              ),
              IconButton(
                tooltip: 'حذف التطبيق ودوله',
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : () => _confirmDelete(app),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.rose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // الانتقاء يتم من كتالوج المزود — نفس مسار تطبيقات المتجر
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _openCatalog(app),
            icon: const Icon(Icons.public_rounded, size: 16),
            label: Text(
              app.productCount == 0
                  ? 'انتقِ دول هذه الخدمة من كتالوج المزود'
                  : 'إدارة الدول والأسعار من كتالوج المزود',
              style: AppTypography.cairo(fontSize: 11.5),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.08),
              foregroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          // عرض أسماء الدول المفعّلة مباشرة داخل البطاقة
          if (countries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: countries.map(_countryChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// بطاقة دولة واحدة: اسمها + وسم السيرفر + نقطة حالتها. الدولة نفسها قد
  /// تُباع من أكثر من سيرفر، فلكل سيرفر عدّاد جودته وإيقافه المستقل.
  Widget _countryChip(VirtualNumberAppCountry country) {
    final tone = _qualityColor(country);
    final label = country.serverLabel.trim();
    return Material(
      color: tone.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        // النقر يفتح إيقافاً/إعادة تفعيل سريعين دون دخول شاشة الجودة
        onTap: _busy || country.id.isEmpty
            ? null
            : () => _openCountryActions(country),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: tone.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                country.name,
                style: AppTypography.cairo(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTypography.cairo(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// أخضر = سليم، كهرماني = فشل متتالٍ تحت المراقبة، أحمر = موقوف جودةً،
  /// رمادي = مخفي يدوياً عن العميل
  Color _qualityColor(VirtualNumberAppCountry country) {
    if (country.autoDisabled) return AppColors.rose;
    if (country.consecutiveFailures >= 1) return AppColors.ticketAmber;
    if (!country.active) return AppColors.slate400;
    return AppColors.emerald;
  }

  String _qualityLabel(VirtualNumberAppCountry country) {
    if (country.autoDisabled) return 'موقوف تلقائياً لتكرار فشل الأرقام';
    if (country.consecutiveFailures >= 1) {
      return 'تحت المراقبة: ${country.consecutiveFailures} فشل متتالٍ';
    }
    return country.active ? 'ظاهرة للعميل' : 'مخفية عن العميل';
  }

  /// احتياط عند خلو `app.countries` (كتالوج مخزّن): تُقرأ الدول المضافة من
  /// كتالوج مزوده المعروض، فيبقى وسم السيرفر مطابقاً لذلك المزود
  List<VirtualNumberAppCountry> _countriesFromCatalog(
    VirtualNumberAppModel app,
  ) {
    final catalog = context.read<VirtualNumbersProvider>().adminCatalog;
    final service = catalog.services
        .cast<VirtualNumberCatalogService?>()
        .firstWhere((s) => s!.code == app.serviceCode, orElse: () => null);
    if (service == null) return const [];
    return service.countries
        .where((c) => c.added)
        .map(
          (c) => VirtualNumberAppCountry(
            id: c.productId,
            code: c.code,
            name: c.name,
            active: c.productActive,
            providerId: catalog.providerId,
            serverLabel: catalog.providerServerLabel,
            autoDisabled: c.productAutoDisabled,
            consecutiveFailures: c.productConsecutiveFailures,
            totalOrders: 0,
          ),
        )
        .toList();
  }

  /// إجراء سريع على منتج واحد: إيقاف/تفعيل يدوي، أو إعادة تفعيل بعد إيقاف
  /// الجودة (تصفّر الفشل المتتالي وتُبقي العدّادات التاريخية)
  Future<void> _openCountryActions(VirtualNumberAppCountry country) async {
    final provider = context.read<VirtualNumbersProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                country.name,
                style: AppTypography.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${country.serverLabel.trim().isEmpty ? 'بلا وسم سيرفر' : country.serverLabel.trim()}'
                ' — ${_qualityLabel(country)}',
                style: AppTypography.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _qualityColor(country),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'طلبات ${country.totalOrders} • نجاح ${country.success} • '
                'فشل ${country.failure}',
                style: AppTypography.cairo(
                  fontSize: 11,
                  color: AppColors.slate500,
                ),
              ),
              const SizedBox(height: 12),
              if (country.autoDisabled)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _run(
                      () => provider.reactivateProduct(
                        country.id,
                        note: 'إعادة تفعيل سريعة من اللوحة',
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 17),
                  label: const Text('إعادة التفعيل'),
                )
              else
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _run(() => provider.toggleAdminProduct(country.id));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: country.active
                        ? AppColors.slate800
                        : AppColors.emerald,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(
                    country.active
                        ? Icons.power_settings_new_rounded
                        : Icons.check_circle_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                  label: Text(
                    country.active
                        ? 'إيقاف ظهورها للعميل'
                        : 'تفعيل ظهورها للعميل',
                    style: AppTypography.arabicButton(
                      color: Colors.white,
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _visibilityChip(VirtualNumberAppModel app) {
    final tone = visibleColor(app);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        app.visibleToClients
            ? 'ظاهرة للعميل'
            : (app.isActive ? 'بلا دول مفعّلة' : 'موقوفة'),
        style: AppTypography.cairo(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }

  Color visibleColor(VirtualNumberAppModel app) {
    if (!app.isActive) return AppColors.slate400;
    return app.visibleToClients ? AppColors.emerald : AppColors.ticketAmber;
  }

  Widget _countBadge(String value, String label) {
    return Row(
      children: [
        Text(
          value,
          style: AppTypography.balance(fontSize: 13, color: AppColors.slate900),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.cairo(fontSize: 10.5, color: AppColors.slate500),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// حوار إنشاء/تعديل تطبيق أرقام (الاسم + رمز الخدمة + أيقونة اختيارية)
// ---------------------------------------------------------------------------

class _AppFormDialog extends StatefulWidget {
  final VirtualNumberAppModel? app;
  final List<({String code, String name})> catalogServices;

  const _AppFormDialog({this.app, this.catalogServices = const []});

  @override
  State<_AppFormDialog> createState() => _AppFormDialogState();
}

class _AppFormDialogState extends State<_AppFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _iconCtrl;
  bool _saving = false;

  bool get _isEdit => widget.app != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.app?.name ?? '');
    _codeCtrl = TextEditingController(text: widget.app?.serviceCode ?? '');
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

    return AlertDialog(
      title: Text(_isEdit ? 'تعديل التطبيق' : 'تطبيق أرقام جديد'),
      content: SingleChildScrollView(
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
