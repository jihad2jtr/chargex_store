import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/virtual_numbers_provider.dart';
import '../../widgets/ops_ticket_card.dart';
import '../../widgets/virtual_app_ticket_leading.dart';
import '../../widgets/virtual_number_app_form_dialog.dart';
import 'virtual_number_catalog_screen.dart';
import 'virtual_number_dictionary_screen.dart';

/// منتجات الأرقام المضافة: وثاقات التطبيقات التي أُضيفت من المزود ولها دولة
/// واحدة على الأقل. إتاحة تطبيق جديد للمزودين وإضافته والاستيراد الجماعي
/// تتم من «معجم التطبيقات»؛ هنا تُدار الدول والجودة والتفعيل فقط.
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
    final saved = await VirtualNumberAppFormDialog.open(
      context,
      app: app,
      catalogServices: codes,
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
    // شاشة المنتجات: الوثاقات المضافة من المزود التي لها دولة واحدة على الأقل؛
    // الفارغة تُدار من «معجم التطبيقات» وشبكة الانتقاء
    final apps = provider.adminApps
        .where((app) => app.productCount > 0)
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
        title: const Text('منتجات الأرقام المضافة'),
        actions: [
          IconButton(
            tooltip: 'معجم التطبيقات',
            onPressed: _openDictionary,
            icon: const Icon(Icons.menu_book_rounded),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: provider.isAppsLoading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
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
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (_, i) => _appCard(apps[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDictionary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VirtualNumberDictionaryScreen()),
    );
    // العودة من المعجم: تطبيق أُتيح أو وُثِّق قد يغيّر قائمة المنتجات
    if (mounted) await _reload();
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
              'هذه منتجات التطبيقات المُضافة من المزود؛ لإتاحة تطبيق جديد '
              'للمزودين أو إضافته ادخل إلى «معجم التطبيقات»، ثم انتقِ دوله من '
              'صفحة مزودي الأرقام. الخدمة لا تظهر للعميل إلا بدولة مفعّلة.',
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
              ? 'لم تُضف أي دولة من المزود بعد — افتح المعجم وأتق التطبيقات '
                    'ثم انتقِ دولها من صفحة المزود'
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
              onPressed: _openDictionary,
              icon: const Icon(Icons.menu_book_rounded, size: 17),
              label: const Text('فتح معجم التطبيقات'),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // تذكرة تطبيق: ثيم ولون لكل تطبيق + أيقونته + خط تمزّق + تذييل إجراءات
  // (نفس لغة OpsTicketCard المستخدمة في بقية لوحات الإدارة)
  // ---------------------------------------------------------------------------

  Widget _appCard(VirtualNumberAppModel app) {
    // الدول تُقرأ مباشرة من `app.countries` (ناتج listAdminApps الذي يقرأ
    // قاعدة البيانات)، حتى تظهر التطبيقات ودولها في اللوحة ولو كان المزود
    // معطلاً (يحاول جلب الكتالوج فيفشل). الكتالوج يُستعمل احتياطاً فقط.
    final countries = app.countries.isNotEmpty
        ? app.countries
        : _countriesFromCatalog(app);
    final accent = virtualAppAccent(
      '${app.appKey}|${app.serviceCode}|${app.name}',
    );
    final iconRaw = app.icon.isNotEmpty ? app.icon : app.iconUrl;

    return OpsTicketCard(
      accent: accent,
      leading: VirtualAppLeading(
        iconRaw: iconRaw,
        appKey: app.appKey,
        name: app.name,
        accent: accent,
      ),
      // رمز الخدمة تحت الاسم مباشرة (مربّع الأيقونة الأوضح في الرأس)
      title: app.name,
      subtitle: 'رمز الخدمة: ${app.serviceCode}',
      status: _visibilityChip(app),
      rows: [
        // الانتقاء والإدارة يفتحان كتالوج المزود — نفس مسار تطبيقات المتجر
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _busy ? null : () => _openCatalog(app),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.public_rounded,
                        size: 15,
                        color: accent.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          app.productCount == 0
                              ? 'انتقِ دول هذه الخدمة من كتالوج المزود'
                              : 'إدارة الدول والأسعار من كتالوج المزود',
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
                ),
              ),
            ),
            const SizedBox(width: 6),
            _countBadge(
              '${app.activeProductCount}/${app.productCount}',
              'دولة مفعّلة',
            ),
          ],
        ),
      ],
      // الدول المفعّلة داخل جسم التذكرة: نقطة الجودة + وسم السيرفر لكل دولة
      media: countries.isEmpty
          ? null
          : Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                for (final country in countries) _countryChip(country),
              ],
            ),
      // التذييل بعد خط التمزّق: إجراءات التطبيق (كما في بقية تذاكر الإدارة)
      actions: [
        IconButton(
          tooltip: app.isActive ? 'إيقاف التطبيق' : 'تفعيل التطبيق',
          visualDensity: VisualDensity.compact,
          onPressed: _busy
              ? null
              : () => _run(
                  () => context.read<VirtualNumbersProvider>().toggleAdminApp(
                    app.id,
                  ),
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
