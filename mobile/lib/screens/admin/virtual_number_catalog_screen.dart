import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/virtual_numbers_provider.dart';

/// كتالوج مزود الأرقام في اللوحة: نفس فكرة «منتجات المزود» في المتجر —
/// تتصفح خدمات المزود الحيّة بدولها وأسعارها، فتُنشئ تطبيقاً للخدمة إن لم
/// يكن موجوداً، وتنتقي الدول وتضيفها إلى تطبيقها، ثم تُفعّل أو تُعطّل كل
/// دولة؛ والدولة المفعّلة وحدها تظهر للعميل في صفحة الأرقام.
/// تُفتح هذه الشاشة من بطاقة المزود في صفحة «مزودو الأرقام الوهمية».
class VirtualNumberCatalogScreen extends StatefulWidget {
  /// عند المرور من بطاقة تطبيق: تُعرض خدمته وحدها مباشرة
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

  // التركيز يُضبط هنا مباشرة لا في postFrame: أول بناء يجب أن يكون موسّعاً
  late String? _expandedCode = widget.focusApp?.serviceCode;
  bool _onlyCurated = false;
  bool _busy = false;

  VirtualNumbersProvider get _vn => context.read<VirtualNumbersProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _vn.fetchAdminCatalog(providerId: widget.providerId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() =>
      _vn.fetchAdminCatalog(providerId: widget.providerId);

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
      await provider.fetchAdminCatalog(providerId: widget.providerId);
      await provider.fetchAdminApps(quiet: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VirtualNumbersProvider>();
    final catalog = provider.adminCatalog;
    final query = _searchCtrl.text.trim().toLowerCase();
    final focus = widget.focusApp?.serviceCode;

    var services = catalog.services;
    if (focus != null && focus.isNotEmpty) {
      services = services.where((s) => s.code == focus).toList();
    }
    if (query.isNotEmpty) {
      services = services
          .where(
            (s) =>
                s.name.toLowerCase().contains(query) ||
                s.code.toLowerCase().contains(query),
          )
          .toList();
    }
    if (_onlyCurated) {
      services = services.where((s) => s.appId.isNotEmpty).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          focus == null
              ? 'كتالوج مزود الأرقام'
              : 'انتقاء دول ${widget.focusApp!.name}',
        ),
        actions: [
          IconButton(
            tooltip: 'إعادة جلب الكتالوج من المزود',
            onPressed: provider.isCatalogLoading || _busy
                ? null
                : _syncThenReload,
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: provider.isCatalogLoading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _marginBar(catalog),
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
                      hintText: 'بحث في ${catalog.services.length} خدمة',
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
                const SizedBox(width: 8),
                FilterChip(
                  selected: _onlyCurated,
                  label: const Text('المُنتقاة'),
                  onSelected: (v) => setState(() => _onlyCurated = v),
                  selectedColor: AppColors.slate900,
                  labelStyle: AppTypography.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _onlyCurated ? Colors.white : AppColors.slate700,
                  ),
                  checkmarkColor: Colors.white,
                ),
              ],
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
            child: provider.isCatalogLoading && catalog.services.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : services.isEmpty
                ? _emptyState(catalog)
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                      itemCount: services.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _serviceCard(services[i], catalog),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// إعادة الجلب تعيد الكتالوج والتطبيقات معاً (عدّادات الدول تتحدث)
  Future<void> _syncThenReload() async {
    final provider = _vn;
    setState(() => _busy = true);
    final message = await provider.adminSyncCatalog();
    if (!mounted) return;
    setState(() => _busy = false);
    await provider.fetchAdminCatalog(providerId: widget.providerId);
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

  Widget _emptyState(VirtualNumberAdminCatalog catalog) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 60),
      children: [
        const Icon(Icons.public_rounded, size: 42, color: AppColors.slate400),
        const SizedBox(height: 10),
        Text(
          catalog.services.isEmpty
              ? 'الكتالوج فارغ — مزامنة الكتالوج من شاشة إدارة الأرقام أولاً'
              : 'لا خدمة مطابقة للفلتر الحالي',
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

  // ---------------------------------------------------------------------------
  // بطاقة خدمة: accordion — الدول تُفتح عند النقر فقط (كتالوج الضخمة)
  // ---------------------------------------------------------------------------

  Widget _serviceCard(
    VirtualNumberCatalogService service,
    VirtualNumberAdminCatalog catalog,
  ) {
    final expanded = _expandedCode == service.code;
    final hasApp = service.appId.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: expanded ? AppColors.primaryBlue : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () =>
                setState(() => _expandedCode = expanded ? null : service.code),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.nameAr.isNotEmpty
                              ? service.nameAr
                              : service.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${service.nameEn.isNotEmpty ? '${service.nameEn} • ' : ''}'
                          '${service.code} • ${service.countries.length} دولة'
                          '${service.addedCount > 0 ? ' • مُنتقى ${service.addedCount}' : ''}',
                          style: AppTypography.cairo(
                            fontSize: 10.5,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // حالة التطبيق المرافق: يظهر للعميل / بلا دول / لا تطبيق
                  _appStateChip(service),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.slate400,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            _countriesBody(service, catalog, hasApp),
          ],
        ],
      ),
    );
  }

  Widget _appStateChip(VirtualNumberCatalogService service) {
    final String label;
    final Color tone;
    if (service.appId.isEmpty) {
      label = 'بلا تطبيق';
      tone = AppColors.slate400;
    } else if (!service.appActive) {
      label = 'تطبيق موقوف';
      tone = AppColors.rose;
    } else if (service.addedCount == 0) {
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
    final added = service.countries.where((c) => c.added).toList();
    final fresh = service.countries.where((c) => !c.added).toList();
    final selected = <String>{};

    return StatefulBuilder(
      builder: (context, setBodyState) {
        Widget row(VirtualNumberCatalogCountry country) {
          if (country.added) {
            return _addedRow(country, catalog);
          }
          return CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            checkboxShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            value: selected.contains(country.code),
            onChanged: (v) => setBodyState(() {
              if (v == true) {
                selected.add(country.code);
              } else {
                selected.remove(country.code);
              }
            }),
            title: Text(
              _countryLabel(country),
              style: AppTypography.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.slate900,
              ),
            ),
            subtitle: Text(
              'رمز المزود ${country.code} • '
              'تكلفة \$${country.cost.toStringAsFixed(2)} • '
              'سعر العميل \$${country.salePrice.toStringAsFixed(2)} • '
              'متاح ${country.count}',
              style: AppTypography.cairo(
                fontSize: 10,
                color: AppColors.slate500,
              ),
            ),
          );
        }

        return Column(
          children: [
            if (added.isNotEmpty) ...[
              _sectionLabel(
                'دول هذا السيرفر — فَعّل أو عطّل ظهورها للعميل (لا يخصّ غيرها)',
              ),
              ...added.map(row),
              const Divider(height: 16),
            ],
            if (fresh.isNotEmpty) ...[
              _sectionLabel(
                hasApp
                    // نفس الدولة لدى سيرفر آخر = منتج مستقل: عدّاداته وهامشه
                    // وإيقافه خاصتان به وحده، فلا يُدمج سعران لصف واحد
                    ? 'دول كتالوج هذا السيرفر — إضافتها تُنشئ منتجاً باسم السيرفر '
                          'تحت التطبيق نفسه، ولو كانت الدولة معروضة عند غيره'
                    : 'لا تطبيق لهذه الخدمة بعد — أضف دولاً فيُنشأ تطبيقها',
              ),
              SizedBox(
                // الكتالوج قد يحمل مئات الدول: قائمة داخلية قابلة للتمرير
                height: 320,
                child: ListView.separated(
                  itemCount: fresh.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 1),
                  itemBuilder: (_, i) => row(fresh[i]),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Text(
                      selected.isEmpty
                          ? 'لم تُحدَّد دول بعد'
                          : '${selected.length} دولة مختارة',
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
                          : () => _addSelected(service, selected.toList()),
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
            if (added.isEmpty && fresh.isEmpty)
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

  /// سطر دولة مُنتقاة: تبديل التفعيل + إعادة التفعيل بعد إيقاف الجودة + حذف
  /// من التطبيق. الدولة ذاتها قد تظهر مرتين في سيرفرين، فلكل منهما هذا السطر
  /// بحالته الخاصة: إيقاف سيرفر لا يمسّ مطابِقه عند مزود آخر.
  Widget _addedRow(
    VirtualNumberCatalogCountry country,
    VirtualNumberAdminCatalog catalog,
  ) {
    final stoppedByQuality = country.productAutoDisabled;
    final watching =
        !stoppedByQuality && country.productConsecutiveFailures >= 1;
    final tone = stoppedByQuality
        ? AppColors.rose
        : (watching
              ? AppColors.ticketAmber
              : (country.productActive
                    ? AppColors.emerald
                    : AppColors.slate400));

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      leading: Icon(
        stoppedByQuality
            ? Icons.block_rounded
            : (country.productActive
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_off_rounded),
        size: 19,
        color: tone,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _countryLabel(country),
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
        'سعر العميل \$${country.salePrice.toStringAsFixed(2)}'
        '${stoppedByQuality ? ' • موقوف جودةً (${country.productConsecutiveFailures} فشل متتالٍ)' : ''}'
        '${watching ? ' • تحت المراقبة (${country.productConsecutiveFailures} فشل متتالٍ)' : ''}'
        '${stoppedByQuality || watching ? '' : (country.productActive ? ' • ظاهرة للعميل' : ' • مخفية عن العميل')}',
        style: AppTypography.cairo(fontSize: 10, color: tone),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stoppedByQuality)
            IconButton(
              tooltip: 'إعادة التفعيل (يصفّر الفشل المتتالي ويُبقي التاريخ)',
              visualDensity: VisualDensity.compact,
              onPressed: _busy || country.productId.isEmpty
                  ? null
                  : () => _run(
                      () => _vn.reactivateProduct(
                        country.productId,
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
            value: country.productActive,
            onChanged: _busy || country.productId.isEmpty
                ? null
                : (_) => _run(() => _vn.toggleAdminProduct(country.productId)),
          ),
          IconButton(
            tooltip: 'حذف الدولة من التطبيق',
            visualDensity: VisualDensity.compact,
            onPressed: _busy || country.productId.isEmpty
                ? null
                : () => _run(() => _vn.removeAdminProduct(country.productId)),
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

  /// إضافة الدول المختارة: تُضاف لتطبيق الخدمة، أو يُنشأ التطبيق أولاً
  Future<void> _addSelected(
    VirtualNumberCatalogService service,
    List<String> codes,
  ) async {
    final provider = context.read<VirtualNumbersProvider>();
    final catalog = provider.adminCatalog;
    final chosen = service.countries
        .where((c) => codes.contains(c.code))
        .toList();

    var appId = service.appId; // '' عند عدم وجود تطبيق مُنتقَى له
    if (appId.isEmpty) {
      // نفس فكرة المتجر: التطبيق يُنشأ أولاً باسم الخدمة من الكتالوج إن لم
      // يكن الأدمن أنشأه مسبقاً من شاشة تطبيقات الأرقام
      final message = await provider.createAdminApp(
        name: service.name,
        serviceCode: service.code,
        providerId: catalog.providerId,
      );
      if (message == null) return;
      await provider.fetchAdminApps(quiet: true);
      if (!mounted) return;
      appId =
          context
              .read<VirtualNumbersProvider>()
              .adminApps
              .where((a) => a.serviceCode == service.code)
              .map((a) => a.id)
              .firstOrNull ??
          '';
      if (appId.isEmpty) return;
    }

    await _run(
      () => provider.addCountriesToApp(
        appId: appId,
        countries: chosen,
        providerId: catalog.providerId,
      ),
    );
    if (mounted) setState(() => _expandedCode = service.code);
  }
}
