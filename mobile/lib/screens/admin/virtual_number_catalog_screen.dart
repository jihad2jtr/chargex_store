import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_icon_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/virtual_numbers_provider.dart';

/// كتالوج مزود الأرقام في اللوحة: تابين بلا قائمة accordion طويلة:
/// 1) شبكة التطبيقات المُنتقاة المخزّنة لدى الخادم — تُرسم فوراً من قاعدة
///    بياناتنا وحدها (بأسماء المعجم عربي وتحتيه الأجنبي) بلا انتظار المزود؛
/// 2) اختيار تطبيق يحمّل دوله من لقطة كتالوج المزود المخزّنة لديه — ردّ فوري
///    لأن اللقطة جاهزة، و«مزامنة من المزود» تجدّدها من المصدر عند الحاجة.
/// ثم ينتقي الأدمن الدول ويضيفها إلى التطبيق، ويفعّل أو يعطّل كل دولة؛
/// والدولة المفعّلة وحدها تظهر للعميل في صفحة الأرقام.
/// تُفتح هذه الشاشة من بطاقة المزود في «مزودو الأرقام الوهمية» أو من بطاقة
/// تطبيق في «تطبيقات الأرقام» (فتبدأ على تفصيله مباشرة).
class VirtualNumberCatalogScreen extends StatefulWidget {
  /// عند المرور من بطاقة تطبيق: يُفتح تفصيله مباشرة
  final VirtualNumberAppModel? focusApp;

  /// مزود الأرقام المحدد من بطاقته في صفحة المزودين (غيابه يعني الافتراضي الحيّ)
  final String? providerId;

  const VirtualNumberCatalogScreen({super.key, this.focusApp, this.providerId});

  @override
  State<VirtualNumberCatalogScreen> createState() =>
      _VirtualNumberCatalogScreenState();
}

class _VirtualNumberCatalogScreenState
    extends State<VirtualNumberCatalogScreen> {
  final _searchCtrl = TextEditingController();

  // التطبيق المخزَّن المختار في عرض التفصيل: المرور من بطاقة تطبيق يفتحه
  // مباشرة (لا في postFrame: أول بناء يجب أن يكون على التفصيل)
  late String? _selectedAppId = widget.focusApp?.id;
  bool _busy = false;

  // شجرة الانتقاء: مفتاح لكل دولة داخل قسم (مضاف/متاح) —
  // «a|cu» للمضاف و«f|cu» للمتاح؛ النقر على رأس الدولة يفرد مشغّليها
  final Set<String> _expandedCountryKeys = <String>{};

  VirtualNumbersProvider get _vn => context.read<VirtualNumbersProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // التطبيقات من قاعدة بياناتنا: شبكة فورية بلا كتالوج المزود
      _vn.fetchAdminApps().then((_) {
        if (mounted && _selectedAppId != null) _fetchCountries();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// إعادة التحديث: التفصيل يقرأ اللقطة، والشبكة تقرأ التطبيقات
  Future<void> _reload() {
    final appId = _selectedAppId;
    return appId == null
        ? _vn.fetchAdminApps()
        : _vn.fetchAppCountries(appId: appId, providerId: widget.providerId);
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final provider = _vn;
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
    if (message != null) {
      await provider.fetchAdminApps(quiet: true);
      final appId = _selectedAppId;
      if (appId != null) {
        await provider.fetchAppCountries(
          appId: appId,
          providerId: widget.providerId,
        );
      }
    }
  }

  /// التطبيق المخزَّن المختار إن كان لا يزال في القائمة (قد يُحذف من مكان آخر)
  VirtualNumberAppModel? _findSelected(List<VirtualNumberAppModel> apps) {
    final id = _selectedAppId;
    if (id == null) return null;
    for (final a in apps) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VirtualNumbersProvider>();
    final app = _findSelected(provider.adminApps);
    // تابين: شبكة تطبيقات مُنتقاة أولاً، واختيارها يفتح دولها من اللقطة
    return app == null
        ? _gridView(provider, provider.adminApps)
        : _detailView(provider, app);
  }

  List<Widget> _appActions(VirtualNumbersProvider provider) => [
    IconButton(
      tooltip: 'مزامنة هذا المزود من المصدر',
      onPressed: provider.isCatalogLoading || _busy ? null : _syncThenReload,
      icon: const Icon(Icons.sync_rounded),
    ),
    IconButton(
      tooltip: 'تحديث',
      onPressed: provider.isAppsLoading || _busy ? null : _reload,
      icon: const Icon(Icons.refresh_rounded),
    ),
  ];

  Widget _errorRow(VirtualNumbersProvider provider) {
    return Padding(
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
    );
  }

  // ---------------------------------------------------------------------------
  // التاب الأول: شبكة التطبيقات المُنتقاة — تُرسم فوراً من قاعدة بياناتنا
  // ---------------------------------------------------------------------------

  Widget _gridView(
    VirtualNumbersProvider provider,
    List<VirtualNumberAppModel> apps,
  ) {
    final query = _searchCtrl.text.trim().toLowerCase();
    var shown = apps;
    if (query.isNotEmpty) {
      shown = shown
          .where(
            (a) =>
                '${a.name} ${a.nameAr} ${a.nameEn} ${a.serviceCode} '
                        '${a.appKey}'
                    .toLowerCase()
                    .contains(query),
          )
          .toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('انتقاء دول التطبيقات'),
        actions: _appActions(provider),
      ),
      body: Column(
        children: [
          if (provider.adminCatalog.providerName.isNotEmpty)
            _marginBar(provider.adminCatalog),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'بحث في ${apps.length} تطبيقاً',
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
              ],
            ),
          ),
          if (provider.errorMessage != null) _errorRow(provider),
          Expanded(
            child: provider.isAppsLoading && apps.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : shown.isEmpty
                ? _emptyState(apps)
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                      children: [
                        Text(
                          'اختر تطبيقاً لعرض دوله وجلبها — ${shown.length} تطبيقاً',
                          style: AppTypography.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _appsGrid(shown),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// شبكة بنفس نمط أيقونات العميل: مربّع أيقونة وتحته الاسم العربي وتحتيه
  /// الأجنبي وسطر الرمز والدول وشارة الحالة — infoH يستوعب السطور بلا طفو
  Widget _appsGrid(List<VirtualNumberAppModel> apps) {
    const double spacing = 10;
    const double targetCell = 84;
    const double infoH = 62;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final crossAxisCount =
            ((availableWidth + spacing) / (targetCell + spacing))
                .round()
                .clamp(3, 8)
                .toInt();
        final cellWidth =
            (availableWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing + 4,
            mainAxisExtent: cellWidth + 6 + infoH,
          ),
          itemCount: apps.length,
          itemBuilder: (_, i) => _appTile(apps[i]),
        );
      },
    );
  }

  Widget _appTile(VirtualNumberAppModel app) {
    final displayName = app.nameAr.isNotEmpty ? app.nameAr : app.name;
    final foreign = app.nameEn.trim();
    final showForeign =
        foreign.isNotEmpty && foreign != displayName && _hasArabic(displayName);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selectedAppId = app.id);
        // الدول تُحمَّل عند الاختيار من لقطة الخادم: ردّ فوري بلا مزامنة
        _fetchCountries();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _iconSquare(_iconAssetFor(app), displayName)),
          const SizedBox(height: 6),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.slate900,
              height: 1.2,
            ),
          ),
          if (showForeign)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                foreign,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: AppTypography.cairo(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate400,
                  height: 1.1,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 2),
            Text(
              app.serviceCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: AppTypography.cairo(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: AppColors.slate500,
                height: 1.15,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            '${app.productCount} دولة مُنتقاة',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.cairo(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          // FittedBox: شارة «ظاهرة للعميل» أوسع من الخانة عند 3 أعمدة
          FittedBox(fit: BoxFit.scaleDown, child: _appStateChip(app)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // التاب الثاني: تفصيل تطبيق مخزَّن — دوله من اللقطة ثم الانتقاء والتفعيل
  // ---------------------------------------------------------------------------

  Widget _detailView(
    VirtualNumbersProvider provider,
    VirtualNumberAppModel app,
  ) {
    final catalog = provider.adminCatalog;
    final displayName = app.nameAr.isNotEmpty ? app.nameAr : app.name;
    return PopScope(
      // رجوع الجهاز يخرج من تفصيل التطبيق إلى الشبكة، لا من الشاشة كلها
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selectedAppId = null);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'انتقاء دول $displayName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            tooltip: 'رجوع',
            onPressed: () => setState(() => _selectedAppId = null),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          actions: _appActions(provider),
        ),
        body: Column(
          children: [
            _marginBar(catalog),
            if (provider.errorMessage != null) _errorRow(provider),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                  children: [
                    _appHeaderCard(app, catalog),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: _countriesSection(app, provider, catalog),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// جسم التفصيل: صفوف هذا التطبيق من لقطة المزود (يُطابقها الخادم بمفتاح
  /// المعجم حتى لو اختلف رمز الخدمة لديه)، أو إرشاد للمزامنة إن لا لقطة
  Widget _countriesSection(
    VirtualNumberAppModel app,
    VirtualNumbersProvider provider,
    VirtualNumberAdminCatalog catalog,
  ) {
    final rows = catalog.services;
    if (rows.isEmpty) {
      if (provider.isCatalogLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          catalog.providerName.isEmpty || catalog.fetchedAt.isEmpty
              ? 'لم تُجلب دول هذا المزود بعد — اضغط «مزامنة من المزود» أولاً'
              : 'لا خدمة مطابقة لهذا التطبيق في كتالوج المزود — زامن ثم أعد الجلب',
          textAlign: TextAlign.center,
          style: AppTypography.cairo(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.slate500,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final row in rows) ...[
          _countriesBody(row, catalog, true),
          if (row != rows.last) const Divider(height: 16),
        ],
      ],
    );
  }

  /// رأس التطبيق: أيقونة واسم عربي والاسم الأجنبي تحته، وزر «جلب الدول» —
  /// يقرأ الخادمُ دولَ هذا التطبيق من لقطة الكتالوج المخزّنة لديه فوراً، أما
  /// «مزامنة من المزود» فتجدّد اللقطة كاملة من المصدر وهو المسار الأبطأ،
  /// ولا مزود يقدّم دول تطبيق واحد وحده في API عنده.
  Widget _appHeaderCard(
    VirtualNumberAppModel app,
    VirtualNumberAdminCatalog catalog,
  ) {
    final displayName = app.nameAr.isNotEmpty ? app.nameAr : app.name;
    final foreign = app.nameEn.trim();
    final showForeign =
        foreign.isNotEmpty && foreign != displayName && _hasArabic(displayName);
    final iconAsset = _iconAssetFor(app);
    final catalogCountries = catalog.services.fold<int>(
      0,
      (sum, s) => sum + s.countries.length,
    );
    final providerCode = catalog.services.isNotEmpty
        ? catalog.services.first.code
        : app.serviceCode;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: _iconSquare(iconAsset, displayName),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                      ),
                    ),
                    if (showForeign) ...[
                      const SizedBox(height: 3),
                      Text(
                        foreign,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: AppTypography.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate400,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'رمز المزود $providerCode • '
                      '${app.productCount} دولة مُنتقاة'
                      '${catalogCountries > 0 ? ' • $catalogCountries في كتالوج السيرفر' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 10,
                        color: AppColors.slate500,
                      ),
                    ),
                    if (catalog.fetchedAt.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'لقطة الكتالوج ${_shortDateTime(catalog.fetchedAt)}'
                        '${catalog.stale ? ' — قديمة، زامِنها' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: catalog.stale
                              ? AppColors.ticketAmber
                              : AppColors.slate400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _appStateChip(app),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _fetchCountries,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.slate900,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.get_app_rounded, size: 16),
                  label: Text(
                    'جلب الدول',
                    style: AppTypography.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _syncThenReload,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text(
                    'مزامنة من المزود',
                    style: AppTypography.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _fetchCountries() async {
    final appId = _selectedAppId;
    if (appId == null) return;
    final provider = _vn;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    await provider.fetchAppCountries(
      appId: appId,
      providerId: widget.providerId,
    );
    final error = provider.errorMessage;
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error == null ? AppColors.slate800 : AppColors.rose,
        content: Text(
          error ?? 'تم جلب الدول من لقطة كتالوج المزود',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }

  /// تاريخ اللقطة مختصراً بلا اعتماد حزمة intl: «يوم/شهر ساعة:دقيقة»
  String _shortDateTime(String iso) {
    final parsed = DateTime.tryParse(iso)?.toLocal();
    if (parsed == null) return iso;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  // ---------------------------------------------------------------------------
  // أيقونات التطبيقات: نفس مسارات الحل في صفحة الأرقام (مخزّن ثم مبنيّان)
  // ---------------------------------------------------------------------------

  String? _iconAssetFor(VirtualNumberAppModel app) {
    final cleanIcon = app.icon.trim();
    if (cleanIcon.isNotEmpty) {
      if (cleanIcon.startsWith('assets/')) return cleanIcon;
      final direct = builtinIconAssetExact(cleanIcon);
      if (direct != null) return direct;
      final byQuery = builtinIconAssetForQuery(cleanIcon);
      if (byQuery != null) return byQuery;
    }
    for (final q in [
      app.nameAr,
      app.nameEn,
      app.name,
      app.serviceCode,
      app.appKey,
    ]) {
      if (q.trim().isEmpty) continue;
      final found = iconAssetForApp(iconUrl: cleanIcon, name: q.trim());
      if (found != null) return found;
    }
    return null;
  }

  static bool _hasArabic(String value) => RegExp(r'[؀-ۿ]').hasMatch(value);

  /// مربّع بحواف دائرية كأيقونة هاتف، وحرف الاسم بديلاً عند غياب الأيقونة
  Widget _iconSquare(String? iconAsset, String name) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final radius = (size * 0.27).clamp(12.0, 26.0);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              colors: [Color(0xFFF8FAFC), Color(0xFFE9EFF7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: iconAsset != null
              ? Image.asset(
                  iconAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _letter(name),
                )
              : _letter(name),
        );
      },
    );
  }

  Widget _letter(String name) {
    final trimmed = name.trim();
    return Center(
      child: Text(
        trimmed.isEmpty ? '#' : trimmed.substring(0, 1).toUpperCase(),
        style: AppTypography.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.slate700,
        ),
      ),
    );
  }

  /// مزامنة هذا المزود وحده من المصدر (المسار البطيء على طلب صريح)، ثم
  /// إعادة قراءة اللقطة والتطبيقات: عدّادات الدول تتحدث
  Future<void> _syncThenReload() async {
    final provider = _vn;
    final syncProviderId =
        widget.providerId ?? provider.adminCatalog.providerId;
    setState(() => _busy = true);
    final message = await provider.adminSyncCatalog(providerId: syncProviderId);
    if (!mounted) return;
    setState(() => _busy = false);
    await _reload();
    // يُعاد قراءة Messenger بعد التمر (تحديث context عبر await)
    await provider.fetchAdminApps(quiet: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: message != null ? AppColors.slate800 : AppColors.rose,
        content: Text(
          message ?? provider.errorMessage ?? 'تعذّرت المزامنة',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }

  Widget _marginBar(VirtualNumberAdminCatalog catalog) {
    final margin = catalog.marginType == 'fixed'
        ? '\$${catalog.marginValue.toStringAsFixed(2)} ثابتة'
        : '${catalog.marginValue.toStringAsFixed(0)}%';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.slate300),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.percent_rounded,
            size: 16,
            color: AppColors.slate700,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'السعر للعميل = تكلفة المزود + هامش ${catalog.providerName}'
              '${_serverSuffix(catalog)} ($margin) — '
              'يتحدّث تلقائياً مع كل مزامنة للكتالوج',
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

  /// وسم السيرفر الوهمي: الانتقاء هنا يخصّ منتجات هذا المزود وحده، فبدل
  /// وسمه يخلط الأدمن دولتين متشابهتين من سيرفرين مختلفين
  String _serverSuffix(VirtualNumberAdminCatalog catalog) {
    final label = catalog.providerServerLabel.trim();
    return label.isEmpty ? '' : ' — $label';
  }

  Widget _emptyState(List<VirtualNumberAppModel> apps) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 60),
      children: [
        const Icon(Icons.public_rounded, size: 42, color: AppColors.slate400),
        const SizedBox(height: 10),
        Text(
          apps.isEmpty
              ? 'لا تطبيقات مُنتقاة بعد — أضِفها من «تطبيقات الأرقام»'
              : 'لا تطبيق مطابق للفلتر الحالي',
          textAlign: TextAlign.center,
          style: AppTypography.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.slate500,
          ),
        ),
      ],
    );
  }

  Widget _appStateChip(VirtualNumberAppModel app) {
    final String label;
    final Color tone;
    if (!app.isActive) {
      label = 'تطبيق موقوف';
      tone = AppColors.rose;
    } else if (app.activeProductCount == 0) {
      label = 'تطبيق بلا دول';
      tone = AppColors.ticketAmber;
    } else {
      label = 'ظاهرة للعميل';
      tone = AppColors.emerald;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.cairo(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }

  Widget _countriesBody(
    VirtualNumberCatalogService service,
    VirtualNumberAdminCatalog catalog,
    bool hasApp,
  ) {
    // كل صف = عرض مستقل (دولة + مشغّل): المضاف يُعرض بحالته، والمتاح يُنتقى
    // بسعره. فلا يُدمج مشغّلان في صف واحد ولا يُخفى فارق السعر بينهما.
    final addedRows = <_CatalogOfferRow>[];
    final freshRows = <_CatalogOfferRow>[];
    for (final country in service.countries) {
      for (final op in country.addedOperators) {
        addedRows.add(_CatalogOfferRow(country, op));
      }
      final addable = country.addableOperators;
      if (addable.isNotEmpty) {
        for (final op in addable) {
          freshRows.add(_CatalogOfferRow(country, op));
        }
      } else if (country.operators.isEmpty) {
        // مزود بلا مشغّلين: عرض عام واحد يختار له المزود أي مشغّل
        freshRows.add(
          _CatalogOfferRow(
            country,
            VirtualNumberCatalogOperator(
              code: '',
              price: country.cost,
              count: country.count,
            ),
          ),
        );
      }
    }
    final selected = <String>{};
    String keyOf(_CatalogOfferRow row) => row.operator.keyOf(row.country.code);

    return StatefulBuilder(
      builder: (context, setBodyState) {
        Widget freshRow(_CatalogOfferRow row) {
          final key = keyOf(row);
          return CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            checkboxShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            value: selected.contains(key),
            onChanged: (v) => setBodyState(() {
              if (v == true) {
                selected.add(key);
              } else {
                selected.remove(key);
              }
            }),
            title: Text(
              row.operator.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.slate900,
              ),
            ),
            subtitle: Text(
              'تكلفة \$${row.operator.price.toStringAsFixed(2)} • '
              'سعر العميل \$${row.operator.salePrice.toStringAsFixed(2)} • '
              'متاح ${row.operator.count}',
              style: AppTypography.cairo(
                fontSize: 10,
                color: AppColors.slate500,
              ),
            ),
          );
        }

        // تجميع الصفوف بحسب الدولة لرسم شجرة «دولة ⊃ مشغّلون»
        final addedGroups = <String, List<_CatalogOfferRow>>{};
        for (final r in addedRows) {
          (addedGroups[r.country.code] ??= <_CatalogOfferRow>[]).add(r);
        }
        final freshGroups = <String, List<_CatalogOfferRow>>{};
        for (final r in freshRows) {
          (freshGroups[r.country.code] ??= <_CatalogOfferRow>[]).add(r);
        }

        return Column(
          children: [
            if (addedRows.isNotEmpty) ...[
              _sectionLabel(
                'عروض هذا السيرفر المضافة — فَعّل أو عطّل ظهورها للعميل (لا تخصّ غيرها)',
              ),
              for (final entry in addedGroups.entries) ...[
                _countryHeader(
                  section: 'a',
                  country: entry.value.first.country,
                  operatorCount: entry.value.length,
                  onToggle: () {
                    final k = 'a|${entry.key}';
                    setBodyState(() {
                      if (_expandedCountryKeys.contains(k)) {
                        _expandedCountryKeys.remove(k);
                      } else {
                        _expandedCountryKeys.add(k);
                      }
                    });
                  },
                ),
                if (entry.value.length == 1 ||
                    _expandedCountryKeys.contains('a|${entry.key}'))
                  for (final r in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _addedRow(r.country, r.operator, catalog),
                    ),
              ],
              const Divider(height: 16),
            ],
            if (freshRows.isNotEmpty) ...[
              _sectionLabel(
                hasApp
                    // المشغّل بعينه هو الوحدة المباعة: لكل عرض سعره ومنتجه
                    // وعدّاد جودته، فلا يُدمج سعران في صف واحد
                    ? 'عروض كتالوج هذا السيرفر — كل عرض منتج مستقل بمشغّله وسعره'
                    : 'لا تطبيق لهذه الخدمة بعد — أضف عروضاً فيُنشأ تطبيقها',
              ),
              SizedBox(
                // الكتالوج قد يحمل مئات الدول والمشغّلين: قائمة داخلية قابلة للتمرير
                height: 380,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final entry in freshGroups.entries) ...[
                      _countryHeader(
                        section: 'f',
                        country: entry.value.first.country,
                        operatorCount: entry.value.length,
                        onToggle: () {
                          final k = 'f|${entry.key}';
                          setBodyState(() {
                            if (_expandedCountryKeys.contains(k)) {
                              _expandedCountryKeys.remove(k);
                            } else {
                              _expandedCountryKeys.add(k);
                            }
                          });
                        },
                      ),
                      if (entry.value.length == 1 ||
                          _expandedCountryKeys.contains('f|${entry.key}'))
                        for (final r in entry.value)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: freshRow(r),
                          ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Text(
                      selected.isEmpty
                          ? 'لم يُحدَّد عرض بعد'
                          : '${selected.length} عرض مختار',
                      style: AppTypography.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate600,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: selected.isEmpty || _busy
                          ? null
                          : () => _addSelected(
                              service,
                              freshRows
                                  .where((r) => selected.contains(keyOf(r)))
                                  .toList(),
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.slate900,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        hasApp ? 'إضافة للتطبيق' : 'إنشاء تطبيق وإضافة',
                        style: AppTypography.cairo(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (addedRows.isEmpty && freshRows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'لا دول متاحة لهذه الخدمة لدى المزود',
                  style: AppTypography.cairo(
                    fontSize: 11.5,
                    color: AppColors.slate500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// رأس دولة داخل شجرة الانتقاء: النقر يفرد/يطوي أسطر مشغّليها؛
  /// الدولة بمشغّل واحد تفتح تلقائياً فلا يحتاج الأدمن نقرة إضافية
  Widget _countryHeader({
    required String section,
    required VirtualNumberCatalogCountry country,
    required int operatorCount,
    required VoidCallback onToggle,
  }) {
    final key = '$section|${country.code}';
    final expanded = operatorCount == 1 || _expandedCountryKeys.contains(key);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: operatorCount == 1 ? null : onToggle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.slate900.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              operatorCount == 1
                  ? Icons.location_city_rounded
                  : (expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded),
              size: 15,
              color: AppColors.slate700,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                operatorCount == 1
                    ? _countryLabel(country)
                    : '${_countryLabel(country)} · $operatorCount مشغّل',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// اسم الدولة من المعجم: عربي أولاً مع الإنجليزي والعلم، وإن غاب الاسم
  /// المترجم يبقى الاسم كما وصل من المزود
  String _countryLabel(VirtualNumberCatalogCountry country) {
    final ar = country.nameAr.isNotEmpty ? country.nameAr : country.name;
    final flag = country.flag.isNotEmpty ? '${country.flag} ' : '';
    final en = country.nameEn.isNotEmpty && country.nameEn != ar
        ? ' (${country.nameEn})'
        : '';
    return '$flag$ar$en';
  }

  /// سطر عرض مُضاف (دولة + مشغّل): تبديل التفعيل + إعادة التفعيل بعد إيقاف
  /// الجودة + حذف من التطبيق. المشغّل هو الوحدة المباعة، فلكل مشغّل سطره
  /// وحالته: إيقاف مشغّل لا يمسّ مشغّلاً آخر في الدولة نفسها.
  Widget _addedRow(
    VirtualNumberCatalogCountry country,
    VirtualNumberCatalogOperator operator,
    VirtualNumberAdminCatalog catalog,
  ) {
    final stoppedByQuality = operator.productAutoDisabled;
    final watching =
        !stoppedByQuality && operator.productConsecutiveFailures >= 1;
    final tone = stoppedByQuality
        ? AppColors.rose
        : (watching
              ? AppColors.ticketAmber
              : (operator.productActive
                    ? AppColors.emerald
                    : AppColors.slate400));
    final productId = operator.productId;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      leading: Icon(
        stoppedByQuality
            ? Icons.block_rounded
            : (operator.productActive
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_off_rounded),
        size: 19,
        color: tone,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              // رأس الدولة يرسم اسمها فوق، فسطر المشغّل يخصّ اسم المشغّل وحده
              operator.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.slate900,
              ),
            ),
          ),
          // وسم السيرفر: المنتج هنا يخصّ مزود هذه الشاشة وحده
          _serverChip(catalog),
        ],
      ),
      subtitle: Text(
        'سعر العميل \$${operator.salePrice.toStringAsFixed(2)}'
        '${stoppedByQuality ? ' • موقوف جودةً (${operator.productConsecutiveFailures} فشل متتالٍ)' : ''}'
        '${watching ? ' • تحت المراقبة (${operator.productConsecutiveFailures} فشل متتالٍ)' : ''}'
        '${stoppedByQuality || watching ? '' : (operator.productActive ? ' • ظاهر للعميل' : ' • مخفي عن العميل')}',
        style: AppTypography.cairo(fontSize: 10, color: tone),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stoppedByQuality)
            IconButton(
              tooltip: 'إعادة التفعيل (يصفّر الفشل المتتالي ويُبقي التاريخ)',
              visualDensity: VisualDensity.compact,
              onPressed: _busy || productId.isEmpty
                  ? null
                  : () => _run(
                      () => _vn.reactivateProduct(
                        productId,
                        note: 'إعادة تفعيل من كتالوج المزود',
                      ),
                    ),
              icon: const Icon(
                Icons.restart_alt_rounded,
                size: 18,
                color: AppColors.emerald,
              ),
            ),
          Switch(
            value: operator.productActive,
            onChanged: _busy || productId.isEmpty
                ? null
                : (_) => _run(() => _vn.toggleAdminProduct(productId)),
          ),
          IconButton(
            tooltip: 'حذف العرض من التطبيق',
            visualDensity: VisualDensity.compact,
            onPressed: _busy || productId.isEmpty
                ? null
                : () => _run(() => _vn.removeAdminProduct(productId)),
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.rose,
            ),
          ),
        ],
      ),
    );
  }

  Widget _serverChip(VirtualNumberAdminCatalog catalog) {
    final label = catalog.providerServerLabel.trim();
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.cairo(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColors.slate600,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: Text(
          text,
          style: AppTypography.cairo(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.slate500,
          ),
        ),
      ),
    );
  }

  /// إضافة العروض المختارة إلى التطبيق المختار (شبكة التطبيقات: له appId دائماً).
  /// كل عرض = دولة + مشغّل: تُجمع عروض الدولة الواحدة في حمولة واحدة وتُنشئ
  /// منتجاً مستقلاً لكل مشغّل بسعره.
  Future<void> _addSelected(
    VirtualNumberCatalogService service,
    List<_CatalogOfferRow> rows,
  ) async {
    final provider = context.read<VirtualNumbersProvider>();
    final catalog = provider.adminCatalog;
    final appId = _selectedAppId ?? service.appId;
    if (appId.isEmpty || rows.isEmpty) return;

    final byCountry = <String, List<_CatalogOfferRow>>{};
    for (final row in rows) {
      (byCountry[row.country.code] ??= []).add(row);
    }
    final payload = byCountry.values.map((list) {
      final country = list.first.country;
      return <String, dynamic>{
        'code': country.code,
        'name': country.name,
        'cost': country.cost,
        'count': country.count,
        'operators': list
            .map(
              (r) => {
                'code': r.operator.code,
                'name': r.operator.name,
                'price': r.operator.price,
                'type': r.operator.type,
                'count': r.operator.count,
              },
            )
            .toList(),
      };
    }).toList();

    await _run(
      () => provider.addCountriesToApp(
        appId: appId,
        countries: payload,
        providerId: catalog.providerId,
        serviceCode: service.code,
      ),
    );
  }
}

/// صف انتقاء في كتالوج الإدارة: دولة + مشغّل (السيرفر) الذي يُباع منتجاً مستقلاً
class _CatalogOfferRow {
  final VirtualNumberCatalogCountry country;
  final VirtualNumberCatalogOperator operator;

  const _CatalogOfferRow(this.country, this.operator);
}
