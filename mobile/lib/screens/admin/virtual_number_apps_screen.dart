import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/virtual_numbers_provider.dart';
import '../../widgets/ops_ticket_card.dart';
import '../../widgets/collapsible_ticket.dart';
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
  // فلتر حالة المنتجات: 0 الكل، 1 جاهزة، 2 بلا دول مفعّلة، 3 متوقفة
  int _filter = 0;

  // شجرة التصفح: مفاتيح الدول الفردة داخل تذكرة التطبيق
  // (تطبيق|دولة)؛ الدولة ذات المشغّل الواحد لا تحتاج فرداً
  final Set<String> _expandedCountryKeys = <String>{};

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
    final products = provider.adminApps.where((app) => app.productCount > 0);
    final apps = products
        .where(
          (app) =>
              query.isEmpty ||
              app.name.toLowerCase().contains(query) ||
              app.serviceCode.toLowerCase().contains(query),
        )
        .where(_matchesFilter)
        .toList();
    // عدّات الحالة تُحسب على كل المنتجات قبل فلتر البحث والفلتر نفسه
    final nVisible = products.where((a) => a.visibleToClients).length;
    final totalCountries = products.fold(0, (sum, a) => sum + a.productCount);
    final activeCountries = products.fold(
      0,
      (sum, a) => sum + a.activeProductCount,
    );

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
          _heroCard(products.length, totalCountries, activeCountries, nVisible),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.4,
                  ),
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

  /// هل يطابق المنتج فلتر الحالة الحالي؟ (0 الكل، 1 جاهزة، 2 بلا دول
  /// مفعّلة، 3 متوقفة) — مسمّيات الفلاتر تُعمد مختلفة عن أوسمة التذاكر
  /// كي لا تتداخل قراءات الاختبارات النصية بين الرأس والبطاقات
  bool _matchesFilter(VirtualNumberAppModel app) {
    return switch (_filter) {
      1 => app.visibleToClients,
      2 => app.isActive && !app.visibleToClients,
      3 => !app.isActive,
      _ => true,
    };
  }

  // ---------------------------------------------------------------------------
  // بطاقة الهوية: تدرّج العلامة (سيان→سماوي) فوق Bento أرقامًا حيّة للوحة —
  // عدّاد المنتجات والدول المفعّلة والجاهزة للبيع بنظرة واحدة قبل قائمة
  // التذاكر، فتعرف الإدارة فورًا حجم الكتالوج المبني ومدى ظهوره للعميل
  // ---------------------------------------------------------------------------

  Widget _heroCard(
    int total,
    int countries,
    int activeCountries,
    int nVisible,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_rounded,
                size: 17,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'كتالوج الأرقام الجاهز للبيع',
                  style: AppTypography.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                'مُنتقًى من مزودين متعددين',
                style: AppTypography.cairo(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _heroStat('$total', 'منتج تطبيق'),
              _heroStat('$activeCountries/$countries', 'دولة مفعّلة'),
              _heroStat('$nVisible', 'جاهزة للبيع', highlight: true),
            ].withSeparator(),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.ticketAmber.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Colors.white.withValues(alpha: highlight ? 0.45 : 0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.balance(
                fontSize: 15,
                color: highlight ? AppColors.ticketAmberLight : Colors.white,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
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
          switch ((query.isNotEmpty, _filter != 0)) {
            (true, _) => 'لا نتيجة مطابقة للبحث',
            (false, true) => 'لا منتج بهذه الحالة الآن',
            (false, false) =>
              'لم تُضف أي دولة من المزود بعد — افتح المعجم وأتق التطبيقات '
                  'ثم انتقِ دولها من صفحة المزود',
          },
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
  // تذكرة تطبيق مطوية: الرأس (أيقونة+اسم+رمز+وسم+عدّاد الدول) يظهر دائماً،
  // والنقر يفرد أسطر الإدارة ورقائق الدول وأزرار التذييل. تحفظ اللغة البصرية
  // المشتركة مع سجل التفعيلات (CollapsibleTicket فوق OpsTicketCard).
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

    return CollapsibleTicket(
      builder: (context, open) {
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
          // العدّاد في الرأس: يلمّح للأدمن بحالة الدول دون فرد البطاقة
          amount: _countBadge(
            '${app.activeProductCount}/${app.productCount}',
            'دولة مفعّلة',
            tone: _countriesTone(app),
          ),
          status: _visibilityChip(app),
          // الانتقاء والإدارة يفتحان كتالوج المزود — لا يظهر إلا عند الفرد
          rows: open
              ? [
                  InkWell(
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
                ]
              : const [],
          // الدول داخل جسم التذكرة: مجموعة لكل دولة، وفرد الدولة يُظهر
          // مشغّليها سطراً سطراً مع التبديل والحذف والشراء التجريبي
          media: (open && countries.isNotEmpty)
              ? _countryTree(app, countries, accent)
              : null,
          // التذييل بعد خط التمزّق: إجراءات التطبيق (كما في بقية تذاكر الإدارة).
          // مطوياً: مؤشر Chevron يلمّح بالنقر للفرد
          actions: open
              ? [
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
                      color: app.isActive
                          ? AppColors.emerald
                          : AppColors.slate400,
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
                ]
              : const [
                  Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.slate400,
                  ),
                ],
        );
      },
    );
  }

  /// شجرة داخل تذكرة التطبيق: دولة ← مشغّلون. الدولة ذات مشغّل
  /// واحد تُعرض سطراً واحداً بلا رأس منفصل، ومتى تعدّد المشغّلون
  /// ظهر رأس قابل للفرد يفتح أسطر المشغّلين اسفله
  Widget _countryTree(
    VirtualNumberAppModel app,
    List<VirtualNumberAppCountry> countries,
    Color accent,
  ) {
    final groups = <String, List<VirtualNumberAppCountry>>{};
    for (final c in countries) {
      (groups[c.code] ??= <VirtualNumberAppCountry>[]).add(c);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries)
          _countryGroup(app.id, entry.key, entry.value, accent),
      ],
    );
  }

  /// رأس الدولة + أسطر مشغّليها: التطبيق ⊃ دولة ⊃ مشغّل. الدولة ذات
  /// مشغّل واحد تُعرض برأسها وسطر مشغّلها مباشرة، ومتى تعدّد المشغّلون
  /// صار الرأس قابلاً للنقر ليفرد أسطرهم أو يطويها
  Widget _countryGroup(
    String appId,
    String countryCode,
    List<VirtualNumberAppCountry> operators,
    Color accent,
  ) {
    final first = operators.first;
    final activeCount = operators.where((o) => o.active).length;
    final multi = operators.length > 1;
    final key = '$appId|$countryCode';
    // دولة بمشغّل واحد: لا حاجة لفرد، تُعرض مفتوحة دائماً
    final expanded = !multi || _expandedCountryKeys.contains(key);
    final headerLabel = first.name.trim().isEmpty
        ? countryCode
        : first.name.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // رأس الدولة: النقر يفرد/يطوي أسطر مشغّليها عند التعدد
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: multi
              ? () => setState(() {
                  if (_expandedCountryKeys.contains(key)) {
                    _expandedCountryKeys.remove(key);
                  } else {
                    _expandedCountryKeys.add(key);
                  }
                })
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                Icon(
                  multi
                      ? (expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded)
                      : Icons.location_city_rounded,
                  size: 15,
                  color: accent,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    multi
                        ? '$headerLabel · ${operators.length} مشغّل'
                        : headerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
                if (multi)
                  Text(
                    '$activeCount/${operators.length} مفعّل',
                    style: AppTypography.cairo(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate500,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final op in operators)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _operatorRow(op, accent),
            ),
      ],
    );
  }

  /// سطر مشغّل واحد تحت رأس دولته: اسم المشغّل + نقطة الجودة + شراء
  /// تجريبي + تبديل الظهور + (إعادة تفعيل عند الإيقاف الجودة) + حذف
  Widget _operatorRow(VirtualNumberAppCountry country, Color accent) {
    final tone = _qualityColor(country);
    final opName = country.operatorName.trim().isNotEmpty
        ? country.operatorName.trim()
        : (country.serverLabel.trim().isNotEmpty
              ? country.serverLabel.trim()
              : 'مشغّل');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              opName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
          ),
          // الشراء التجريبي: يسبق ظهور المنتج للعميل للتأكد من وصول الرقم
          if (country.id.isNotEmpty)
            IconButton(
              tooltip: 'شراء تجريبي من هذا السيرفر',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: _busy ? null : () => _testBuy(country, opName),
              icon: const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primary,
              ),
            ),
          // إعادة التفعيل بعد إيقاف الجودة: تصفّر الفشل المتتالي
          if (country.autoDisabled)
            IconButton(
              tooltip: 'إعادة التفعيل (يصفّر الفشل المتتالي)',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: _busy || country.id.isEmpty
                  ? null
                  : () => _run(
                      () => context
                          .read<VirtualNumbersProvider>()
                          .reactivateProduct(
                            country.id,
                            note: 'إعادة تفعيل سريعة من اللوحة',
                          ),
                    ),
              icon: const Icon(
                Icons.restart_alt_rounded,
                color: AppColors.emerald,
              ),
            )
          else
            IconButton(
              tooltip: country.active
                  ? 'إخفاء هذا المشغّل عن العميل'
                  : 'إظهار هذا المشغّل للعميل',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: _busy || country.id.isEmpty
                  ? null
                  : () => _run(
                      () => context
                          .read<VirtualNumbersProvider>()
                          .toggleAdminProduct(country.id),
                    ),
              icon: Icon(
                country.active
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                color: country.active ? AppColors.emerald : AppColors.slate400,
              ),
            ),
          IconButton(
            tooltip: 'حذف هذا المشغّل من التطبيق',
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: _busy || country.id.isEmpty
                ? null
                : () => _run(
                    () => context
                        .read<VirtualNumbersProvider>()
                        .removeAdminProduct(country.id),
                  ),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.rose,
            ),
          ),
        ],
      ),
    );
  }

  /// شراء تجريبي: يستدعي مسار العميل نفسه (requestNumber) باسم الأدمن،
  /// فيُخصم من رصيده ويظهر الرقم في صفحة أرقامه للتحقق
  Future<void> _testBuy(VirtualNumberAppCountry country, String opName) async {
    final vn = context.read<VirtualNumbersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('شراء تجريبي'),
        content: Text(
          'سيُطلب رقم من «${country.name} — $opName» على حسابك الإداري؛ '
          'يُخصم سعره من رصيدك ويصلك الرقم في صفحة أرقام العميل كأي طلب عادي.',
          style: AppTypography.cairo(fontSize: 12.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('طلب الرقم'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final message = await vn.requestNumber(productId: country.id);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: message != null ? AppColors.slate800 : AppColors.rose,
        content: Text(
          message ?? vn.errorMessage ?? 'تعذّر الشراء التجريبي',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
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

  /// احتياط عند خلو `app.countries` (كتالوج مخزّن): تُقرأ الدول المضافة من
  /// كتالوج مزوده المعروض، فيبقى وسم السيرفر مطابقاً لذلك المزود.
  /// كل مشغّل مضاف يصبح سطراً مستقللاً: الدمج بينها يُلغي تمييز التبديل
  List<VirtualNumberAppCountry> _countriesFromCatalog(
    VirtualNumberAppModel app,
  ) {
    final catalog = context.read<VirtualNumbersProvider>().adminCatalog;
    final service = catalog.services
        .cast<VirtualNumberCatalogService?>()
        .firstWhere((s) => s!.code == app.serviceCode, orElse: () => null);
    if (service == null) return const [];
    return [
      for (final c in service.countries)
        for (final op in c.addedOperators)
          VirtualNumberAppCountry(
            id: op.productId,
            code: c.code,
            name: c.name,
            active: op.productActive,
            providerId: catalog.providerId,
            serverLabel: catalog.providerServerLabel,
            // «أي مشغّل» قيمة العرض الافتراضية عند غياب الاسم: اللوحة
            // تُفضّل فراغ الحقل على ظهور كلمة احتياطية لمنتج لا مشغّل له
            operatorName: op.added && op.displayName != 'أي مشغّل'
                ? op.displayName
                : '',
            operator: op.code,
            autoDisabled: op.productAutoDisabled,
            consecutiveFailures: op.productConsecutiveFailures,
            totalOrders: 0,
          ),
    ];
  }

  Widget _visibilityChip(VirtualNumberAppModel app) {
    final tone = visibleColor(app);
    final IconData glyph;
    if (!app.isActive) {
      glyph = Icons.power_off_rounded;
    } else if (app.visibleToClients) {
      glyph = Icons.check_circle_rounded;
    } else {
      glyph = Icons.visibility_off_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(glyph, size: 11, color: tone),
          const SizedBox(width: 4),
          Text(
            app.visibleToClients
                ? 'ظاهرة للعميل'
                : (app.isActive ? 'بلا دول مفعّلة' : 'موقوفة'),
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

  Color visibleColor(VirtualNumberAppModel app) {
    if (!app.isActive) return AppColors.slate400;
    return app.visibleToClients ? AppColors.emerald : AppColors.ticketAmber;
  }

  /// لون عدّاد الدول: زمرد إذا كلها مفعّلة، كهرماني إذا بعضُها مخفي،
  /// رمادي إذا لم تُفعّل منها دولة — درج لوني يكمّل وسم الحالة الجانبي
  Color _countriesTone(VirtualNumberAppModel app) {
    if (app.activeProductCount == 0) return AppColors.slate400;
    if (app.activeProductCount < app.productCount) return AppColors.ticketAmber;
    return AppColors.emerald;
  }

  Widget _countBadge(String value, String label, {required Color tone}) {
    return Row(
      children: [
        Text(value, style: AppTypography.balance(fontSize: 13, color: tone)),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.cairo(fontSize: 10.5, color: AppColors.slate500),
        ),
      ],
    );
  }
}

/// فاصل رفيع شفاف بين مربّعات إحصاء بطاقة الهوية (تنسيق Bento)
extension on List<Widget> {
  List<Widget> withSeparator() {
    final out = <Widget>[];
    for (var i = 0; i < length; i++) {
      if (i > 0) out.add(const SizedBox(width: 8));
      out.add(this[i]);
    }
    return out;
  }
}
