import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/virtual_numbers_provider.dart';
import '../../widgets/virtual_number_app_form_dialog.dart';

/// معجم تطبيقات الأرقام: بوابة «متاح للمزودين» الوحيدة في النظام.
///
/// كل مدخل من المعجم الكامل (800+) له مفتاح تفعيل/إيقاف هنا؛ المتاح وحده
/// يظهر في انتقاء الدول لدى المزودين وفي الاستيراد الجماعي وشاشة العميل.
/// الإيقاف إخفاءٌ عرضي غير اتلافي: وثاقة التطبيق ومنتجاتها لا تُحذف أبداً.
class VirtualNumberDictionaryScreen extends StatefulWidget {
  const VirtualNumberDictionaryScreen({super.key});

  @override
  State<VirtualNumberDictionaryScreen> createState() =>
      _VirtualNumberDictionaryScreenState();
}

class _VirtualNumberDictionaryScreenState
    extends State<VirtualNumberDictionaryScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late final TabController _tabs;
  int _tab = 0;
  bool _busy = false;

  /// حُمّلت الدول/المراجعة مرة واحدة عند أول فتح لتبويبها
  bool _countriesLoaded = false;
  bool _reviewLoaded = false;

  /// المفتاح الذي يُنفَّذ عليه PATCH الآن: إشعاره وحده يتحول لمؤشر تحميل
  String? _togglingKey;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)
      ..addListener(() {
        setState(() {});
        if (!_tabs.indexIsChanging) _onTabOpened(_tabs.index);
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<VirtualNumbersProvider>().fetchAdminDictionary();
      }
    });
  }

  /// جلب كسول لتبويبي الدول والمراجعة عند أول زيارة لهما
  void _onTabOpened(int index) {
    final provider = context.read<VirtualNumbersProvider>();
    if (index == 1 && !_countriesLoaded) {
      _countriesLoaded = true;
      provider.fetchDictionaryCountries();
    } else if (index == 2 && !_reviewLoaded) {
      _reviewLoaded = true;
      provider.fetchReviewQueue();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final provider = context.read<VirtualNumbersProvider>();
    await provider.fetchAdminDictionary();
    if (_tabs.index == 1) await provider.fetchDictionaryCountries();
    if (_tabs.index == 2) await provider.fetchReviewQueue();
  }


  /// تنفيذ إجراء مع رسالة نتيجة موحّدة (نفس نمط شاشة المنتجات)
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

  /// تبديل التوفر: الإيقاف أولُاً يطلب تأكيداً — العقد أن الإخفاء غير اتلافي
  Future<void> _toggle(VirtualNumberDictionaryEntry entry, bool value) async {
    if (!value) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('إخفاء «${entry.nameAr}» من المزودين'),
          content: Text(
            'سيتوقف هذا التطبيق عن الظهور في انتقاء الدول لدى المزودين، '
            'وفي اللوحة، وفي شاشة العميل — دون حذف وثاقته أو دوله المضافة. '
            'إعادته متاحة في أي وقت.',
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
              child: const Text('إخفاء'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    if (!mounted) return;
    setState(() => _togglingKey = entry.key);
    final provider = context.read<VirtualNumbersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final message = await provider.toggleDictionaryOffered(entry.key, value);
    if (!mounted) return;
    setState(() => _togglingKey = null);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: message != null ? AppColors.slate800 : AppColors.rose,
        content: Text(
          message ?? provider.errorMessage ?? 'تعذّر تحديث التوفر',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _bulkImport() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استيراد كتالوج الخدمات'),
        content: Text(
          'يُنشئ تطبيقاً مفعّلاً لكل خدمة متاحة في المعجم ضمن كتالوج المزود '
          'لم تُضَف بعد — بلا دول. تُنتقى الدول لكل خدمة لاحقاً من كتالوج '
          'المزود، فلا يظهر شيء للعميل قبل الانتقاء.',
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

  /// استيراد ذكي من المزودين إلى المعجم المركزي، ثم عرض نافذة التقرير.
  /// لا يفعّل البيع: العنصر المستورد الجديد يبقى مسودة غير متاحة حتى تُتيحه
  /// الإدارة من بوابة «متاح»، ثم تُضيف له دولاً/منتجات.
  Future<void> _importFromProviders() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استيراد من المزودين'),
        content: Text(
          'يصل لكل مزود نشط ويجلب تطبيقاته ودوله، يربط الموجود منها بالمعجم '
          'مهما اختلفت الأسماء والرموز، ويضيف الجديد كمسودة غير متاحة، '
          'ويرسل الغامض إلى تبويب المراجعة. لا يحذف شيئاً ولا يفعّل البيع.',
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
    if (go != true || !mounted) return;
    final provider = context.read<VirtualNumbersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final report = await provider.importFromProviders();
    if (!mounted) return;
    setState(() => _busy = false);
    if (report == null) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.rose,
          content: Text(
            provider.errorMessage ?? 'تعذّر الاستيراد',
            style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
          ),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تقرير الاستيراد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reportLine('المزودون المفحوصون', report.providers),
            _reportLine('الخدمات الممسوحة', report.servicesScanned),
            _reportLine('تطبيقات مربوطة', report.appsLinked),
            _reportLine('تطبيقات جديدة (غير متاحة)', report.appsCreated),
            _reportLine('تطبيقات قيد المراجعة', report.appsPending),
            _reportLine('دول مربوطة', report.countriesLinked),
            _reportLine('دول جديدة', report.countriesCreated),
            _reportLine('دول قيد المراجعة', report.countriesPending),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  Widget _reportLine(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$label: $value',
        style: AppTypography.cairo(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// تعديل/دمج دولة من تبويب الدول
  Future<void> _editCountry(VirtualNumberDictCountry country) async {
    final nameCtrl = TextEditingController(text: country.nameAr);
    final mergeCtrl = TextEditingController();
    final countries = context.read<VirtualNumbersProvider>().dictionaryCountries;
    final provider = context.read<VirtualNumbersProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('دولة ${country.flag} ${country.nameEn} (${country.code})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'الاسم العربي'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              isExpanded: true,
              hint: const Text('دمج في دولة أخرى (اختياري)'),
              items: [
                for (final c in countries.where((c) => c.code != country.code))
                  DropdownMenuItem(
                    value: c.code,
                    child: Text('${c.nameEn} (${c.code})'),
                  ),
              ],
              onChanged: (v) => mergeCtrl.text = v ?? '',
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
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    final merge = mergeCtrl.text.trim();
    if (save != true) {
      nameCtrl.dispose();
      mergeCtrl.dispose();
      return;
    }
    await provider.patchDictionaryCountry({
      'code': country.code,
      if (merge.isNotEmpty) 'mergeInto': merge else 'nameAr': nameCtrl.text.trim(),
    });
    nameCtrl.dispose();
    mergeCtrl.dispose();
    if (!mounted) return;
    final err = provider.errorMessage;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: err == null ? AppColors.slate800 : AppColors.rose,
        content: Text(
          err ?? 'تم تحديث الدولة',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }

  /// حلّ بند مراجعة: ربط بأول مرشّح، أو إنشاء جديد، أو تجاهل
  Future<void> _resolveReview(VirtualNumberDictReview item, String action) async {
    await _run(
      () => context.read<VirtualNumbersProvider>().resolveReviewItem(
        item.id,
        action,
        targetKey: action == 'link' && item.candidateKeys.isNotEmpty
            ? item.candidateKeys.first
            : null,
      ),
    );
  }

  /// اقتراحات رموز الخدمات: من الكتالوج المخزّن ثم يُجلب إن كان فارغاً
  Future<List<({String code, String name})>> _catalogCodes() async {
    final provider = context.read<VirtualNumbersProvider>();
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
    return codes;
  }

  Future<void> _openForm() async {
    final codes = await _catalogCodes();
    if (!mounted) return;
    await VirtualNumberAppFormDialog.open(context, catalogServices: codes);
    // وثاقة جديدة قد تغيّر عدّادات المعجم
    if (mounted) await _reload();
  }

  /// تعديل سطر المعجم: وثاقة موجودة تُفتح للتعديل (الاسم/الأيقونة)، وغير
  /// الموثَّقة تُفتح إنشاءً مسبق التعبئة باسم المعجم ورمز المزود لديه
  Future<void> _openEditForm(VirtualNumberDictionaryEntry entry) async {
    final codes = await _catalogCodes();
    if (!mounted) return;
    final editing = entry.appId.isEmpty
        ? null
        : VirtualNumberAppModel(
            id: entry.appId,
            name: entry.appName,
            appKey: entry.key,
            serviceCode: entry.serviceCode,
            iconUrl: entry.iconUrl,
          );
    await VirtualNumberAppFormDialog.open(
      context,
      app: editing,
      catalogServices: codes,
      initialName: editing == null
          ? (entry.nameEn.isNotEmpty ? entry.nameEn : entry.nameAr)
          : '',
      initialServiceCode: editing == null
          ? (entry.fivesimCode.isNotEmpty
                ? entry.fivesimCode
                : entry.herosmsCode)
          : '',
    );
    // التعديل يغيّر appName/serviceCode الظاهرة في المدخل نفسه
    if (mounted) await _reload();
  }

  List<VirtualNumberDictionaryEntry> _filtered(
    List<VirtualNumberDictionaryEntry> all,
  ) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return all.where((e) {
      if (_tab == 1 && !e.offered) return false;
      if (_tab == 2 && e.appId.isEmpty) return false;
      if (query.isEmpty) return true;
      return e.nameAr.toLowerCase().contains(query) ||
          e.nameEn.toLowerCase().contains(query) ||
          e.key.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VirtualNumbersProvider>();
    final offeredCount = provider.adminDictionary
        .where((e) => e.offered)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // عنوان مرن بملالغة: ثلاثة أزرار (استيراد/تحديث/إضافة) تضيق على
        // الشاشات النحيلة فتتداخل أزرار الـ appBar مع العنوان بلا Flexible
        title: const Flexible(
          child: Text(
            'معجم التطبيقات',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 2),
        actions: [
          IconButton(
            tooltip: 'إضافة تطبيق لكل خدمة في كتالوج المزود',
            visualDensity: VisualDensity.compact,
            onPressed: _busy ? null : _bulkImport,
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          IconButton(
            tooltip: 'تحديث',
            visualDensity: VisualDensity.compact,
            onPressed: provider.isDictionaryLoading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'تطبيق جديد',
            visualDensity: VisualDensity.compact,
            onPressed: (_busy || _tabs.index != 0) ? null : _openForm,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'التطبيقات'),
            Tab(text: 'الدول'),
            Tab(text: 'المراجعة'),
          ],
        ),
      ),
      // جسدٌ واحد حسب التبويب النشط (لا TabBarView): يبقي بقية الشجرة خارج
      // الذاكرة فلا تتعارض حقول البحث/النصوص بين التبويبات في الاختبارات
      body: _tabs.index == 1
          ? _countriesBody(provider)
          : _tabs.index == 2
          ? _reviewBody(provider)
          : _appsBody(provider, offeredCount),
    );
  }

  /// تبويب التطبيقات: بوابة المتاح + زر الاستيراد من المزودين + البحث والقائمة
  Widget _appsBody(VirtualNumbersProvider provider, int offeredCount) {
    final entries = _filtered(provider.adminDictionary);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _importFromProviders,
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: Text(
                'استيراد من المزودين',
                style: AppTypography.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        _hintBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'بحث بالاسم العربي أو الإنجليزي أو المفتاح',
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
        _subTabs(offeredCount, provider.adminDictionary.length),
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
            child:
                provider.isDictionaryLoading && provider.adminDictionary.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                ? _emptyState()
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 4, bottom: 28),
                    itemExtent: 64,
                    itemCount: entries.length,
                    itemBuilder: (_, i) => _row(entries[i]),
                  ),
          ),
        ),
      ],
    );
  }

  /// تبويب الدول: كيانات المعجم الموحّدة برموز كل مزود؛ السطر يفتح تعديل/دمج
  Widget _countriesBody(VirtualNumbersProvider provider) {
    final countries = provider.dictionaryCountries;
    if (countries.isEmpty && !_countriesLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.dictionaryCountries.isEmpty) {
          provider.fetchDictionaryCountries();
        }
      });
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: countries.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 60),
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 42,
                  color: AppColors.slate400,
                ),
                const SizedBox(height: 10),
                Text(
                  'لا دول بعد — استيراد من المزودين أو بذر المعجم',
                  textAlign: TextAlign.center,
                  style: AppTypography.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 28),
              itemCount: countries.length,
              itemBuilder: (_, i) => _countryRow(countries[i]),
            ),
    );
  }

  Widget _countryRow(VirtualNumberDictCountry c) {
    final codes = c.codes.entries.map((e) => '${e.key}:${e.value}').join('، ');
    return ListTile(
      leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
      title: Text(
        c.nameAr.isNotEmpty ? c.nameAr : c.nameEn,
        style: AppTypography.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.slate900,
        ),
      ),
      subtitle: Text(
        '${c.code} · ${c.origin}${codes.isEmpty ? '' : ' · $codes'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.cairo(fontSize: 10.5, color: AppColors.slate500),
      ),
      trailing: IconButton(
        tooltip: 'تعديل أو دمج',
        icon: const Icon(Icons.edit_outlined, size: 18),
        onPressed: _busy ? null : () => _editCountry(c),
      ),
    );
  }

  /// تبويب المراجعة: بنود استيراد غامضة تُحسم بالربط/الإنشاء/التجاهل
  Widget _reviewBody(VirtualNumbersProvider provider) {
    final items = provider.reviewQueue;
    if (items.isEmpty && !_reviewLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.reviewQueue.isEmpty) {
          provider.fetchReviewQueue();
        }
      });
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 60),
              children: [
                const Icon(
                  Icons.task_alt_rounded,
                  size: 42,
                  color: AppColors.emerald,
                ),
                const SizedBox(height: 10),
                Text(
                  'لا بنود مراجعة — كل الهويات محسومة',
                  textAlign: TextAlign.center,
                  style: AppTypography.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 28),
              itemCount: items.length,
              itemBuilder: (_, i) => _reviewRow(items[i]),
            ),
    );
  }

  Widget _reviewRow(VirtualNumberDictReview item) {
    final kindLabel = item.kind == 'country' ? 'دولة' : 'تطبيق';
    final candidates = item.candidateKeys.isEmpty
        ? 'لا مرشّحات'
        : 'مرشّحات: ${item.candidateKeys.join('، ')}';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$kindLabel — «${item.rawName.isNotEmpty ? item.rawName : item.rawCode}» (${item.providerType})',
            style: AppTypography.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'رمز مزوّد: ${item.rawCode} · $candidates',
            style: AppTypography.cairo(fontSize: 10.5, color: AppColors.slate500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (item.candidateKeys.isNotEmpty)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _resolveReview(item, 'link'),
                  child: const Text('ربط'),
                ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _resolveReview(item, 'create'),
                child: const Text('إنشاء جديد'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _resolveReview(item, 'dismiss'),
                child: const Text('تجاهل'),
              ),
            ],
          ),
        ],
      ),
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
              'التطبيقات المتاحة هنا هي وحدها التي تظهر في انتقاء الدول لدى '
              'المزودين وشاشة العميل. الإيقاف يُخفي بلا حذف، وزر التعديل في '
              'كل سطر يُعدّل اسم التطبيق وأيقونته أو يوثّقه إن لم يُضَف بعد.',
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

  Widget _subTabs(int offeredCount, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _tabChip(0, 'الكل ($total)'),
          const SizedBox(width: 6),
          _tabChip(1, 'متاح ($offeredCount)'),
          const SizedBox(width: 6),
          _tabChip(2, 'مُضاف من المزود'),
        ],
      ),
    );
  }

  Widget _tabChip(int index, String label) {
    final selected = _tab == index;
    return ChoiceChip(
      label: Text(
        label,
        style: AppTypography.cairo(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : AppColors.slate700,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: AppColors.slate800,
      side: const BorderSide(color: AppColors.slate300),
      onSelected: (_) => setState(() => _tab = index),
    );
  }

  /// سطر مضغوط واحد: المعجم كبير (800+) فيُعرض بقائمة ثابتة الارتفاع
  Widget _row(VirtualNumberDictionaryEntry entry) {
    final toggling = _togglingKey == entry.key;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.offered ? AppColors.slate300 : AppColors.slate200,
        ),
      ),
      child: Row(
        children: [
          _icon(entry),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.nameAr.isNotEmpty ? entry.nameAr : entry.nameEn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                    ),
                    if (entry.appId.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _productBadge(entry.productCount),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.nameEn.isNotEmpty ? entry.nameEn : entry.key,
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
          // تعديل الوثاقة المخزّنة (اسم/أيقونة) أو توثيق المدخل إنشاءً —
          // مقصوص كي لا يتجاوز ارتفاع itemExtent فيقتطع حافة البطاقة
          IconButton(
            tooltip: entry.appId.isNotEmpty
                ? 'تعديل التطبيق'
                : 'توثيق التطبيق من المزود',
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: _togglingKey != null ? null : () => _openEditForm(entry),
            icon: Icon(
              entry.appId.isNotEmpty
                  ? Icons.edit_outlined
                  : Icons.app_registration_rounded,
              size: 18,
              color: AppColors.slate700,
            ),
          ),
          const SizedBox(width: 4),
          if (toggling)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            // مقصوص بالارتفاع: المفتاح الافتراضي أطول من السطر ويترجم التداخل
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: entry.offered,
                onChanged: _togglingKey != null
                    ? null
                    : (v) => _toggle(entry, v),
              ),
            ),
        ],
      ),
    );
  }

  /// أيقونة المعجم من حزمة الأصول، وحرف الاسم بديلاً عنها
  Widget _icon(VirtualNumberDictionaryEntry entry) {
    final asset = entry.icon.startsWith('assets/') ? entry.icon : null;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: asset != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                asset,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _letter(entry),
              ),
            )
          : _letter(entry),
    );
  }

  Widget _letter(VirtualNumberDictionaryEntry entry) {
    final name = entry.nameEn.isNotEmpty ? entry.nameEn : entry.nameAr;
    return Text(
      name.isEmpty ? '?' : name.characters.first,
      style: AppTypography.cairo(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: const Color(0xFFFDE047),
      ),
    );
  }

  /// وسم «n دولة»: التطبيق أُضيف من المزود وله هذه العدّة من الدول
  Widget _productBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.emerald.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        count == 1 ? 'دولة' : '$count دولة',
        style: AppTypography.cairo(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColors.emerald,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 60),
      children: [
        const Icon(
          Icons.search_off_rounded,
          size: 42,
          color: AppColors.slate400,
        ),
        const SizedBox(height: 10),
        Text(
          'لا نتيجة مطابقة — جرّب اسماً آخر أو تبويب «الكل»',
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
}
