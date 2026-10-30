import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_icon_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/app_catalog_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/virtual_numbers_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/status_pill.dart';
import 'topup_screen.dart';

/// صفحة الأرقام الوهمية: بدل صفحة «شحن الاشتراكات».
/// الاختلاف الجوهري عن بقية المشتريات أن الرمز يصل بعد ثوانٍ أو دقائق، فالصفحة
/// تُبقي الرقم الحيّ في الأعلى وتفحصه دورياً، وتُرجع المبلغ تلقائياً عند انتهاء
/// المهلة بلا رسالة — لذلك تُظهر العدّاد وحالة الإرجاع بوضوح.
class VirtualNumbersScreen extends StatefulWidget {
  final bool showAppBar;
  const VirtualNumbersScreen({super.key, this.showAppBar = true});

  @override
  State<VirtualNumbersScreen> createState() => _VirtualNumbersScreenState();
}

class _VirtualNumbersScreenState extends State<VirtualNumbersScreen> {
  final Set<String> _codeAnnounced = {};
  final Set<String> _refundAnnounced = {};

  /// بحث الخدمات: الكتالوج يضم مئات التطبيقات فالبحث يختصر الطريق
  final TextEditingController _serviceSearch = TextEditingController();
  String _serviceQuery = '';

  VirtualNumbersProvider? _provider;
  Timer? _ticker;
  bool _tickerRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<VirtualNumbersProvider>();
      // ما هو مُستلَم أو مُرجَع بالفعل في المخزن لا يُعاد التنبيه عنه عند كل فتح
      for (final request in provider.myRequests) {
        if (request.hasCode) _codeAnnounced.add(request.id);
        if (request.isRefunded) _refundAnnounced.add(request.id);
      }
      _provider = provider..addListener(_onProviderChanged);
      provider.fetchOptions();
      provider.fetchMyRequests().then((_) {
        if (mounted) provider.startAutoPolling();
      });
      context.read<WalletProvider>().fetchBalance();
      _syncTicker();
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    _provider?.stopPolling();
    _ticker?.cancel();
    _serviceSearch.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    final provider = _provider;
    if (provider == null) return;

    final active = provider.activeRequest;
    if (active != null &&
        active.hasCode &&
        !_codeAnnounced.contains(active.id)) {
      _codeAnnounced.add(active.id);
      _notify(
        'وصل رمز التحقق',
        'افتح الرقم وانسخ الرمز قبل انتهاء نافذة العرض',
        AppColors.emerald,
      );
    }

    for (final request in provider.myRequests) {
      if (request.isRefunded && !_refundAnnounced.contains(request.id)) {
        _refundAnnounced.add(request.id);
        _notify(
          'أُرجع المبلغ إلى محفظتك',
          '${request.title}: ${request.note}',
          AppColors.ticketAmber,
        );
        if (mounted) {
          context.read<WalletProvider>().fetchBalance();
        }
      }
    }

    _syncTicker();
  }

  /// الرسائل تأجل إلى ما بعد الإطارية: notifyListeners قد يحدث أثناء البناء
  void _notify(String title, String body, Color tone) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: tone,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title — $body',
                  style: AppTypography.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// عدّاد الثواني يعمل فقط أثناء وجود مهلة جارية (لا مؤقّت بلا حاجة)
  void _syncTicker() {
    final needsTicker = _provider?.activeRequest != null;
    if (needsTicker && !_tickerRunning) {
      _tickerRunning = true;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needsTicker && _tickerRunning) {
      _tickerRunning = false;
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _refreshAll() async {
    final provider = context.read<VirtualNumbersProvider>();
    await provider.fetchMyRequests();
    await provider.fetchOptions(forceRefresh: true);
    provider.startAutoPolling();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VirtualNumbersProvider>();
    final active = provider.activeRequest;

    final body = RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: widget.showAppBar ? 12 : 4,
          left: widget.showAppBar ? 14 : 0,
          right: widget.showAppBar ? 14 : 0,
          bottom: widget.showAppBar ? 28 : 104,
        ),
        children: [
          if (provider.errorMessage != null &&
              provider.options.services.isEmpty &&
              active == null) ...[
            _buildAlert(provider.errorMessage!),
            const SizedBox(height: 14),
          ],
          if (active != null) ...[
            _buildSectionHeader('رقمك النشط', 'LIVE NUMBER', _headerAccent),
            const SizedBox(height: 10),
            _LiveNumberPass(
              request: active,
              waitMinutes: provider.options.waitMinutes,
              onCopy: _copy,
              onClose: () => _closeActive(active),
            ),
            const SizedBox(height: 18),
          ] else ...[
            _buildStatStrip(provider),
            const SizedBox(height: 16),
            // القسم الأول: خدمة يدوية يُنفّذها مشرف مقابل تفعيل مضمون
            ..._buildGuaranteedSection(provider),
            _buildSectionHeader(
              'اختر الخدمة',
              'ACTIVATE',
              AppColors.ticketAmber,
            ),
            const SizedBox(height: 10),
            _buildServicesArea(provider),
            const SizedBox(height: 18),
          ],
          // سجل الأرقام الوهمية لم يعد منعزلاً هنا: هو مدمج في «طلباتي»
        ],
      ),
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('الأرقام الوهمية'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              provider.stopPolling();
              _refreshAll().then((_) => provider.startAutoPolling());
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: body,
    );
  }

  // ---------------------------------------------------------------------------
  // بطاقات الصفحة
  // ---------------------------------------------------------------------------

  /// لون شريط عنوان «رقمك النشط»: أخضر عند وصول الرمز وإلا ذهبي
  Color get _headerAccent {
    final active = _provider?.activeRequest;
    return active != null && active.hasCode
        ? AppColors.emerald
        : AppColors.ticketAmber;
  }

  Widget _buildSectionHeader(String title, String badge, Color accent) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.55)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.slate900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: AppTypography.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }

  /// شريط إحصائي خفيف فوق الكتالوج: حجم الخدمات والدول والمهلة المعتمدة
  Widget _buildStatStrip(VirtualNumbersProvider provider) {
    final services = provider.options.services;
    final countries = services.fold<int>(
      0,
      (sum, service) => sum + service.countries.length,
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          _statCell(Icons.apps_rounded, '${services.length}', 'خدمة متاحة'),
          _statDivider(),
          _statCell(Icons.public_rounded, '$countries', 'دولة'),
          _statDivider(),
          _statCell(
            Icons.timer_outlined,
            '${provider.options.waitMinutes}',
            'دقيقة مهلة',
          ),
        ],
      ),
    );
  }

  Widget _statCell(IconData icon, String value, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          children: [
            Icon(icon, size: 17, color: AppColors.primaryBlue),
            const SizedBox(height: 5),
            Text(
              value,
              style: AppTypography.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
              ),
            ),
            Text(
              label,
              style: AppTypography.cairo(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 36, color: AppColors.slate100);

  // ---------------------------------------------------------------------------
  // القسم الأول: «تفعيل مضمون» — خدمات يدوية على شكل كروت
  // ---------------------------------------------------------------------------

  /// تُعرض فقط حين توجد خدمة يدوية فعّالة، فلا تتغير الصفحة بدونها
  List<Widget> _buildGuaranteedSection(VirtualNumbersProvider provider) {
    final services = provider.options.manualServices;
    if (services.isEmpty) return const [];
    return [
      _buildSectionHeader('تفعيل مضمون', 'GUARANTEED', AppColors.emerald),
      const SizedBox(height: 10),
      ...services.map(
        (service) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _ManualServiceCard(
            service: service,
            onTap: () => _openManualSheet(service),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  // ---------------------------------------------------------------------------
  // القسم الثاني: تطبيقات مزوّدي الأرقام — أيقونات كبيرة كنمط صفحة التطبيقات
  // ---------------------------------------------------------------------------

  Widget _buildServicesArea(VirtualNumbersProvider provider) {
    if (provider.isLoadingOptions && provider.options.services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final all = provider.options.services;
    if (all.isEmpty) {
      return _buildEmptyCatalog(provider);
    }

    final services = _filteredServices(all);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (all.length > 8) ...[
          _serviceSearchField(),
          const SizedBox(height: 10),
        ],
        if (services.isEmpty) _buildNoMatch() else _buildAppIconsGrid(services),
      ],
    );
  }

  /// شبكة أيقونات بنفس قياسات «صفحة التطبيقات»: مربّع بحواف دائرية وتحتَه
  /// سطر اسمه + سطر الدول والسعر ابتداءً من أرخص دولة.
  Widget _buildAppIconsGrid(List<VirtualNumberServiceOption> services) {
    const double spacing = 10;
    const double targetCell = 84;
    const double infoHeight = 30;

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
            mainAxisExtent: cellWidth + 6 + infoHeight,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return _ServiceIconTile(
              service: service,
              onTap: () => _openCountrySheet(service),
            );
          },
        );
      },
    );
  }

  /// ترشيح الخدمات بالاسم العربي أو الإنجليزي أو الرمز
  List<VirtualNumberServiceOption> _filteredServices(
    List<VirtualNumberServiceOption> all,
  ) {
    final q = _serviceQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (s) => '${s.nameAr} ${s.nameEn} ${s.name} ${s.code}'
              .toLowerCase()
              .contains(q),
        )
        .toList();
  }

  Widget _serviceSearchField() {
    return TextField(
      controller: _serviceSearch,
      onChanged: (v) => setState(() => _serviceQuery = v),
      textInputAction: TextInputAction.search,
      style: AppTypography.cairo(fontSize: 12.5, color: AppColors.slate900),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'ابحث عن تطبيق أو خدمة',
        hintStyle: AppTypography.cairo(
          fontSize: 11.5,
          color: AppColors.slate400,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: AppColors.slate400,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        suffixIcon: _serviceQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'مسح',
                onPressed: () {
                  _serviceSearch.clear();
                  setState(() => _serviceQuery = '');
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.slate400,
                ),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildNoMatch() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 34,
            color: AppColors.slate400,
          ),
          const SizedBox(height: 8),
          Text(
            'لا تطبيق يطابق «$_serviceQuery»',
            textAlign: TextAlign.center,
            style: AppTypography.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCatalog(VirtualNumbersProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.numbers_rounded,
            size: 40,
            color: AppColors.slate400,
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد أرقام متاحة',
            style: AppTypography.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.slate900,
            ),
          ),

          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => provider.fetchOptions(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('إعادة جلب القائمة'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlert(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorLight,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.cairo(
                fontSize: 11.5,
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
  // الإجراءات
  // ---------------------------------------------------------------------------

  void _copy(String value, String label) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.slate800,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'تم نسخ $label',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _openCountrySheet(VirtualNumberServiceOption service) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _CountrySheet(
        service: service,
        balance: context.read<WalletProvider>().balance,
        waitMinutes: context.read<VirtualNumbersProvider>().options.waitMinutes,
        onSubmit: (country, operator) => _submit(service, country, operator),
      ),
    );
    if (mounted) context.read<VirtualNumbersProvider>().startAutoPolling();
  }

  /// نافذة طلب خدمة يدوية (تفعيل مضمون): تُجمع الحقول المطلوبة ثم يُرسل
  /// الطلب عبر `/orders` نفسه فيظهر في «طلباتي» وفي مساحة المشرف المختص.
  Future<void> _openManualSheet(VirtualNumberManualServiceModel service) async {
    final wallet = context.read<WalletProvider>();
    // يُلتقط قبل فتح النافذة: داخل النافذة يصبح أقرب Scaffold هو نافذتها
    final messenger = ScaffoldMessenger.of(context);
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _ManualServiceSheet(
        service: service,
        balance: wallet.balance,
        onSubmit: (accountInput) =>
            _submitManual(messenger, service, accountInput),
      ),
    );
    if (submitted != true || !mounted) return;
    // الخادم يخصم الرصيد في المعاملة نفسها: مزامنة ثم تحديث سجل الطلبات
    await wallet.fetchBalance();
    if (!mounted) return;
    context.read<AppCatalogProvider>().fetchMyOrders();
    await context.read<VirtualNumbersProvider>().fetchMyRequests();
  }

  /// يُعيد true عند نجاح الطلب كي تُغلق النافذة نفسها
  Future<bool> _submitManual(
    ScaffoldMessengerState messenger,
    VirtualNumberManualServiceModel service,
    Map<String, String> accountInput,
  ) async {
    final wallet = context.read<WalletProvider>();

    if (service.price > wallet.balance) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('رصيد غير كافٍ'),
          content: Text(
            'السعر \$${service.price.toStringAsFixed(2)} ورصيدك '
            '\$${wallet.balance.toStringAsFixed(2)}. اشحن رصيدك ثم أعد المحاولة.',
            style: AppTypography.cairo(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('الذهاب للشحن'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const TopupScreen()));
      }
      return false;
    }

    final catalog = context.read<AppCatalogProvider>();
    final result = await catalog.purchaseProduct(
      productId: service.id,
      accountInput: accountInput,
    );

    if (!mounted) return result != null;

    if (result == null) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            catalog.errorMessage ?? 'تعذّر إرسال الطلب',
            style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
          ),
        ),
      );
      return false;
    }

    final newBalance = result['newBalance'];
    if (newBalance is num) {
      context.read<AuthProvider>().updateBalanceLocally(newBalance.toDouble());
    }
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          result['message']?.toString() ??
              'تم استلام طلبك وسيُنفّذه المشرف المختص',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
    return true;
  }

  /// يُعيد true عند نجاح الطلب كي تُغلق النافذة نفسها
  Future<bool> _submit(
    VirtualNumberServiceOption service,
    VirtualNumberCountryOption country,
    VirtualNumberOperator? operator,
  ) async {
    final provider = context.read<VirtualNumbersProvider>();
    final wallet = context.read<WalletProvider>();

    if (country.salePrice > wallet.balance) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('رصيد غير كافٍ'),
          content: Text(
            'السعر \$${country.salePrice.toStringAsFixed(2)} ورصيدك '
            '\$${wallet.balance.toStringAsFixed(2)}. اشحن رصيدك ثم أعد المحاولة.',
            style: AppTypography.cairo(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('الذهاب للشحن'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const TopupScreen()));
      }
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'تفعيل رقم '
          '${service.nameAr.isNotEmpty ? service.nameAr : service.name}',
        ),
        content: Text(
          'الدولة: ${country.nameAr.isNotEmpty ? country.nameAr : country.name}\n'
          'المشغّل: ${operator?.name ?? 'أي مشغّل متاح'}\n'
          'السعر: \$${country.salePrice.toStringAsFixed(2)} يُخصم من رصيدك\n\n'
          'يصل الرمز تلقائياً خلال الانتظار، وإن لم تصل رسالة تُرجع المبلغ كاملاً.',
          style: AppTypography.cairo(fontSize: 12.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تفعيل الرقم'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    final message = await provider.requestNumber(
      service: service.code,
      country: country.code,
      operator: operator?.code,
    );

    if (!mounted) return message != null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: message != null ? AppColors.slate800 : AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message ?? provider.errorMessage ?? 'تعذّر تفعيل الرقم',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
    return message != null;
  }

  Future<void> _closeActive(VirtualNumberRequestModel request) async {
    final provider = context.read<VirtualNumbersProvider>();
    final gotCode = request.hasCode;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gotCode ? 'إغلاق الرقم' : 'إلغاء الرقم'),
        content: Text(
          gotCode
              ? 'سيُغلق الرقم بعد استلام الرمز. لا يُرجع المبلغ لأن الخدمة سُلّمت.'
              : 'لم يصل رمز بعد — يُلغى الرقم حالياً ويُرجع المبلغ \$${request.amount.toStringAsFixed(2)} إلى رصيدك.',
          style: AppTypography.cairo(fontSize: 12.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(gotCode ? 'إغلاق' : 'إلغاء واسترجاع'),
          ),
        ],
      ),
    );
    if (go != true) return;

    final message = await provider.closeRequest(request.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: message != null ? AppColors.slate800 : AppColors.rose,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message ?? provider.errorMessage ?? 'تعذّر إغلاق الرقم',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
    await context.read<WalletProvider>().fetchBalance();
  }
}

// =============================================================================
// بطاقة الرقم الحيّ: الرقم للنسخ، العدّاد، ثم الرمز عندما يصل
// =============================================================================

class _LiveNumberPass extends StatelessWidget {
  final VirtualNumberRequestModel request;
  final int waitMinutes;
  final void Function(String value, String label) onCopy;
  final VoidCallback onClose;

  const _LiveNumberPass({
    required this.request,
    required this.waitMinutes,
    required this.onCopy,
    required this.onClose,
  });

  String _countdown() {
    final left = request.remainingSeconds();
    if (left == null) return '—';
    final minutes = (left / 60).floor();
    final seconds = left % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = request.hasCode;
    final accent = hasCode ? AppColors.emerald : AppColors.ticketAmber;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شريط الحالة العلوي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.slate900, AppColors.slate800],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                if (request.flag.isNotEmpty) ...[
                  Text(request.flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Text(
                    '${request.title} • ${request.countryName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                StatusPill(status: request.status, label: request.statusLabel),
              ],
            ),
          ),

          _perforation(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _numberRow(),
                const SizedBox(height: 10),
                if (hasCode) ...[
                  _codePanel(request.smsCode!, request.smsText),
                ] else
                  _waitingPanel(),
                if (request.note.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    request.note,
                    style: AppTypography.cairo(
                      fontSize: 10.5,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            onCopy(request.phoneNumber ?? '', 'الرقم'),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('نسخ الرقم'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.slate900,
                          side: const BorderSide(color: AppColors.slate300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onClose,
                        style: FilledButton.styleFrom(
                          backgroundColor: hasCode
                              ? AppColors.emerald
                              : AppColors.slate700,
                        ),
                        icon: Icon(
                          hasCode
                              ? Icons.check_circle_rounded
                              : Icons.close_rounded,
                          size: 16,
                        ),
                        label: Text(hasCode ? 'تم — إغلاق' : 'إلغاء واسترجاع'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.phoneNumber == null
                      ? 'جارٍ تجهيز الرقم…'
                      : 'أدخل هذا الرقم في التطبيق',
                  style: AppTypography.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  request.phoneNumber ?? '— — —',
                  style: AppTypography.technicalCode(
                    color: AppColors.slate900,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          _countdownGauge(),
        ],
      ),
    );
  }

  /// مدّة النافذة الكاملة بالثواني لحساب نسبة المقياس الدائري
  int _totalSeconds() {
    final end = request.expiresAt;
    if (end == null) return waitMinutes * 60;
    final start = request.hasCode ? request.codeReceivedAt : request.createdAt;
    final span = start == null ? 0 : end.difference(start).inSeconds;
    return span > 0 ? span : waitMinutes * 60;
  }

  /// مقياس دائري للمهلة: الطوق يتقلّص مع الوقت والرقم في المركز
  Widget _countdownGauge() {
    final left = request.remainingSeconds() ?? 0;
    final total = _totalSeconds();
    final progress = total > 0 ? (left / total).clamp(0.0, 1.0) : 0.0;
    final urgent = left <= 120 && !request.hasCode;
    final tone = request.hasCode
        ? AppColors.emerald
        : (urgent ? AppColors.rose : AppColors.ticketAmber);

    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: tone.withValues(alpha: 0.16),
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _countdown(),
                style: AppTypography.technicalCode(
                  color: AppColors.slate900,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                request.hasCode ? 'نافذة العرض' : 'متبقٍ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waitingPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ticketAmberLight),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.ticketAmber,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بانتظار وصول رسالة التحقق…',
                  style: AppTypography.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'يظهر الرمز هنا تلقائياً خلال دقائق، وإن مرّت $waitMinutes دقيقة بلا رمز يُرجع المبلغ لرصيدك.',
                  style: AppTypography.cairo(
                    fontSize: 10.5,
                    height: 1.5,
                    color: AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _codePanel(String code, String? smsText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.mark_email_read_rounded,
                size: 17,
                color: AppColors.tertiaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                'رمز التحقق وصل',
                style: AppTypography.cairo(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onTertiaryContainer,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'نسخ الرمز',
                onPressed: () => onCopy(code, 'الرمز'),
                icon: const Icon(
                  Icons.copy_all_rounded,
                  size: 18,
                  color: AppColors.tertiaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SelectableText(
            code,
            textAlign: TextAlign.center,
            style: AppTypography.technicalCode(
              color: AppColors.slate900,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 7,
            ),
          ),
          const SizedBox(height: 2),
          // رمز يبقى معروضاً ما بقيت نافذة الرقم الحيّ: التنبيه في المقياس الدائري
          Text(
            'انسخ الرمز قبل انتهاء المهلة',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.slate500,
            ),
          ),
          if (smsText != null && smsText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              smsText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 10,
                height: 1.45,
                color: AppColors.slate600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// خط تمزّق التذكرة: حزّتان على الجانبين يصل بينهما خط متقطّع
  Widget _perforation() {
    const hole = 12.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: hole,
        child: Row(
          children: [
            _hole(hole),
            Expanded(
              child: CustomPaint(
                painter: _DashedLinePainter(),
                child: const SizedBox(height: hole),
              ),
            ),
            _hole(hole),
          ],
        ),
      ),
    );
  }

  Widget _hole(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// خط أفقي متقطّع رفيع يفصل رأس التذكرة عن متنها
class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.slate200
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + dash, size.height / 2),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// أيقونة خدمة كبيرة في الشبكة (نمط صفحة التطبيقات)
// =============================================================================

class _ServiceIconTile extends StatelessWidget {
  final VirtualNumberServiceOption service;
  final VoidCallback onTap;

  const _ServiceIconTile({required this.service, required this.onTap});

  /// الأيقونة المربعة: رمز التطبيق المخزّن ثم اسم الخدمة ثم الأسماء الأجنبية
  String? _findIconAsset() {
    final cleanIcon = service.icon.trim();
    if (cleanIcon.isNotEmpty) {
      if (cleanIcon.startsWith('assets/')) return cleanIcon;
      final direct = builtinIconAssetExact(cleanIcon);
      if (direct != null) return direct;
      final byQuery = builtinIconAssetForQuery(cleanIcon);
      if (byQuery != null) return byQuery;
    }
    for (final q in [service.nameAr, service.nameEn, service.name]) {
      if (q.trim().isEmpty) continue;
      final found = iconAssetForApp(iconUrl: service.icon, name: q.trim());
      if (found != null) return found;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String? iconAsset = _findIconAsset();
    final displayName = service.nameAr.isNotEmpty
        ? service.nameAr
        : service.name;
    // الاسم الأجنبي لا يظهر إذا كان المخزّن أجنبياً أصلاً أو مطابقاً له
    final showEn =
        service.nameEn.isNotEmpty &&
        service.nameEn != service.nameAr &&
        !_hasArabic(displayName);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _iconSquare(iconAsset, displayName)),
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
          if (showEn)
            Text(
              service.nameEn,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: AppTypography.cairo(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: AppColors.slate400,
                height: 1.15,
              ),
            ),
          Text(
            '${service.countries.length} دولة • من \$${service.bestPrice.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.cairo(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ticketAmber,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  static bool _hasArabic(String value) =>
      RegExp(r'[\u0600-\u06FF]').hasMatch(value);

  /// مربّع بحواف دائرية (squircle) بلمعة زجاجية مثل أيقونات شاشة الهاتف
  Widget _iconSquare(String? iconAsset, String displayName) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final radius = (size * 0.27).clamp(14.0, 30.0);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              colors: [Color(0xFFF8FAFC), Color(0xFFE9EFF7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (iconAsset != null)
                  Image.asset(
                    iconAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _letterFallback(displayName),
                  )
                else
                  _letterFallback(displayName),
                // لمعة علوية خفيفة
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: size * 0.4,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.28),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _letterFallback(String displayName) {
    final letter = displayName.isNotEmpty
        ? displayName.substring(0, 1)
        : (service.code.isEmpty
              ? '#'
              : service.code.substring(0, 1).toUpperCase());
    return Center(
      child: Text(
        letter,
        style: AppTypography.fintechBadge(
          color: AppColors.slate800,
          fontSize: 20,
        ),
      ),
    );
  }
}

// =============================================================================
// بطاقة خدمة يدوية — القسم الأول «تفعيل مضمون»
// =============================================================================

class _ManualServiceCard extends StatelessWidget {
  final VirtualNumberManualServiceModel service;
  final VoidCallback onTap;

  const _ManualServiceCard({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _appBadge(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate900,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          service.description.isNotEmpty
                              ? service.description
                              : 'تفعيل على يد مختص برسم مُخصم من رصيدك',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.slate900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '\$${service.price.toStringAsFixed(2)}',
                      style: AppTypography.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFDE047),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(Icons.verified_user_rounded, 'تنفيذ بشري مضمون'),
                  if (service.etaLabel.isNotEmpty)
                    _chip(Icons.schedule_rounded, service.etaLabel),
                  if (service.appName.isNotEmpty)
                    _chip(Icons.apps_rounded, service.appName),
                  if (service.isSensitive)
                    _chip(Icons.lock_outline_rounded, 'بيانات سرية'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// أيقونة التطبيق المرتبط بالخدمة، وحرف اسم الخدمة بديلاً عنها
  Widget _appBadge() {
    final asset = _resolveAppIcon();
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFEDF2F7)],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: asset != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                asset,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _letter(),
              ),
            )
          : _letter(),
    );
  }

  String? _resolveAppIcon() {
    final raw = service.appIcon.trim();
    if (raw.isNotEmpty) {
      if (raw.startsWith('assets/')) return raw;
      final direct = builtinIconAssetExact(raw);
      if (direct != null) return direct;
      final byQuery = builtinIconAssetForQuery(raw);
      if (byQuery != null) return byQuery;
    }
    for (final name in [service.appName, service.name]) {
      if (name.trim().isEmpty) continue;
      final found = iconAssetForApp(iconUrl: raw, name: name.trim());
      if (found != null) return found;
    }
    return null;
  }

  Widget _letter() {
    final source = service.appName.isNotEmpty ? service.appName : service.name;
    return Text(
      source.isEmpty ? '#' : source.substring(0, 1),
      style: AppTypography.fintechBadge(
        color: AppColors.slate800,
        fontSize: 15,
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.slate600),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.cairo(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.slate600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// نافذة طلب خدمة يدوية (تفعيل مضمون)
// =============================================================================

class _ManualServiceSheet extends StatefulWidget {
  final VirtualNumberManualServiceModel service;
  final double balance;

  /// يُعيد true عند نجاح الطلب كي تُغلق النافذة نفسها
  final Future<bool> Function(Map<String, String> accountInput) onSubmit;

  const _ManualServiceSheet({
    required this.service,
    required this.balance,
    required this.onSubmit,
  });

  @override
  State<_ManualServiceSheet> createState() => _ManualServiceSheetState();
}

class _ManualServiceSheetState extends State<_ManualServiceSheet> {
  late final List<String> _fieldLabels;
  late final Map<String, TextEditingController> _controllers;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _fieldLabels = widget.service.requiredFields.isEmpty
        ? const ['المعرف']
        : widget.service.requiredFields;
    _controllers = {
      for (final label in _fieldLabels) label: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final input = <String, String>{};
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('يرجى إدخال ${entry.key}')));
        return;
      }
      input[entry.key] = value;
    }

    setState(() => _sending = true);
    final ok = await widget.onSubmit(input);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final enough = service.price <= widget.balance;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.slate200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                service.name,
                style: AppTypography.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                service.description.isNotEmpty
                    ? service.description
                    : 'خدمة يدوية يُنفّذها مشرف مختص بدل المزود الآلي.',
                style: AppTypography.cairo(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 17,
                      color: AppColors.emerald,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تفعيل مضمون${service.etaLabel.isNotEmpty ? ' • التنفيذ خلال ${service.etaLabel}' : ''}'
                        '\nإن تعذّر التفعيل يُعاد المبلغ إلى رصيدك.',
                        style: AppTypography.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (service.instructions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.amberContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 17,
                        color: AppColors.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          service.instructions,
                          style: AppTypography.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amber,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              for (final label in _fieldLabels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _controllers[label],
                    obscureText: service.sensitiveFields.contains(label),
                    style: AppTypography.cairo(
                      fontSize: 12.5,
                      color: AppColors.slate900,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: service.sensitiveFields.contains(label)
                          ? '$label (سري)'
                          : label,
                      labelStyle: AppTypography.cairo(
                        fontSize: 11.5,
                        color: AppColors.slate500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: _sending || !enough ? null : _send,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: enough
                      ? AppColors.primaryBlue
                      : AppColors.slate200,
                ),
                child: Text(
                  _sending
                      ? 'جارٍ الإرسال…'
                      : enough
                      ? 'تأكيد الطلب (\$${service.price.toStringAsFixed(2)})'
                      : 'رصيد غير كافٍ (\$${service.price.toStringAsFixed(2)})',
                  style: AppTypography.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// نافذة اختيار الدولة والمشغّل
// =============================================================================

class _CountrySheet extends StatefulWidget {
  final VirtualNumberServiceOption service;
  final double balance;
  final int waitMinutes;
  final Future<bool> Function(
    VirtualNumberCountryOption country,
    VirtualNumberOperator? operator,
  )
  onSubmit;

  const _CountrySheet({
    required this.service,
    required this.balance,
    required this.waitMinutes,
    required this.onSubmit,
  });

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  VirtualNumberCountryOption? _country;
  String? _operatorCode;
  bool _submitting = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.service.countries.isNotEmpty) {
      _country = widget.service.countries.first;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// قائمة الدول قد تحمل المئات: الفلترة تُقلّصها فوراً بالعربي أو الإنجليزي
  List<VirtualNumberCountryOption> _visibleCountries() {
    final all = widget.service.countries;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (c) => '${c.nameAr} ${c.nameEn} ${c.name} ${c.code}'
              .toLowerCase()
              .contains(q),
        )
        .toList();
  }

  Future<void> _submit() async {
    final country = _country;
    if (country == null || _submitting) return;
    setState(() => _submitting = true);
    final ok = await widget.onSubmit(country, _operatorFor(country));
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Navigator.of(context).pop();
  }

  VirtualNumberOperator? _operatorFor(VirtualNumberCountryOption country) {
    if (_operatorCode == null || country.operators.isEmpty) return null;
    for (final operator in country.operators) {
      if (operator.code == _operatorCode) return operator;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final countries = _visibleCountries();
    final total = widget.service.countries.length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 42,
            height: 4,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _buildSheetAppIcon(widget.service),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أرقام ${widget.service.nameAr.isNotEmpty ? widget.service.nameAr : widget.service.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                      if (widget.service.nameEn.isNotEmpty &&
                          widget.service.nameEn != widget.service.nameAr)
                        Text(
                          widget.service.nameEn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate400,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  'رصيدك \$${widget.balance.toStringAsFixed(2)}',
                  style: AppTypography.balance(
                    fontSize: 11.5,
                    color: AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'اختر الدولة — وإن كانت متاحة اختر المشغّل. '
              'تُرجَع المبلغ تلقائياً إن مرّت ${widget.waitMinutes} دقيقة بلا رمز.',
              style: AppTypography.cairo(
                fontSize: 10.5,
                height: 1.5,
                color: AppColors.slate500,
              ),
            ),
          ),
          if (total > 8) ...[const SizedBox(height: 10), _searchField()],
          const SizedBox(height: 8),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('لا دول متاحة لهذه الخدمة'),
            )
          else if (countries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('لا دولة تطابق بحثك'),
            )
          else
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.46,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: countries.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.slate100,
                      ),
                      itemBuilder: (context, index) {
                        final country = countries[index];
                        final selected = _country?.code == country.code;
                        final affordable = country.salePrice <= widget.balance;
                        return _countryRow(country, selected, affordable);
                      },
                    ),
                  ),
                ),
              ),
            ),
          if (_country != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Text(
                'المشغّل',
                style: AppTypography.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate600,
                ),
              ),
            ),
            _operatorRow(),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: FilledButton(
              onPressed: _country == null || _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.slate900,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'تفعيل الرقم \$${(_country?.salePrice ?? 0).toStringAsFixed(2)}',
                      style: AppTypography.arabicButton(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        style: AppTypography.cairo(fontSize: 12.5, color: AppColors.slate900),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'ابحث عن دولة بالعربي أو الإنجليزي',
          hintStyle: AppTypography.cairo(
            fontSize: 11.5,
            color: AppColors.slate400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.slate400,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'مسح',
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.slate400,
                  ),
                ),
          filled: true,
          fillColor: AppColors.slate50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primaryBlue,
              width: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  /// صف دولة داخل حاوية موحّدة: صفوف متلاصقة يفصلها خط رفيع، وشريط لوني
  /// جانبي للدولة المختارة بدل الإطار السميك
  Widget _countryRow(
    VirtualNumberCountryOption country,
    bool selected,
    bool affordable,
  ) {
    final flag = country.flag.isNotEmpty ? country.flag : '🌐';
    final nameAr = country.nameAr.isNotEmpty ? country.nameAr : country.name;
    final showEn = country.nameEn.isNotEmpty && country.nameEn != nameAr;

    return Material(
      color: selected ? const Color(0xFFFFF7E6) : Colors.white,
      child: InkWell(
        onTap: () => setState(() {
          _country = country;
          _operatorCode = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(
                color: selected
                    ? AppColors.secondaryBright
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Text(flag, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            nameAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate900,
                            ),
                          ),
                        ),
                        if (showEn) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '(${country.nameEn})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (country.count > 0)
                      Text(
                        'متاح ${country.count} رقم',
                        style: AppTypography.cairo(
                          fontSize: 9.5,
                          color: AppColors.slate500,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${country.salePrice.toStringAsFixed(2)}',
                    style: AppTypography.price(
                      color: affordable ? AppColors.slate900 : AppColors.rose,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_off_rounded,
                    size: 15,
                    color: selected
                        ? AppColors.secondaryBright
                        : AppColors.slate300,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetAppIcon(VirtualNumberServiceOption svc) {
    String? asset;
    final clean = svc.icon.trim();
    if (clean.isNotEmpty) {
      if (clean.startsWith('assets/')) {
        asset = clean;
      } else {
        asset = builtinIconAssetExact(clean) ?? builtinIconAssetForQuery(clean);
      }
    }
    asset ??= iconAssetForApp(
      iconUrl: svc.icon,
      name: svc.nameAr.isNotEmpty ? svc.nameAr : svc.name,
    );

    if (asset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          asset,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _sheetFallback(svc),
        ),
      );
    }
    return _sheetFallback(svc);
  }

  Widget _sheetFallback(VirtualNumberServiceOption svc) {
    final letter = svc.nameAr.isNotEmpty
        ? svc.nameAr.substring(0, 1)
        : (svc.code.isEmpty ? '#' : svc.code.substring(0, 1).toUpperCase());
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        letter,
        style: AppTypography.fintechBadge(
          color: const Color(0xFFFDE047),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _operatorRow() {
    final country = _country;
    final operators = country?.operators ?? const <VirtualNumberOperator>[];
    if (operators.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'يُختار المشغّل تلقائياً',
          style: AppTypography.cairo(fontSize: 10.5, color: AppColors.slate500),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          _operatorChip(null, 'أي مشغّل'),
          ...operators.map((o) => _operatorChip(o.code, o.name)),
        ],
      ),
    );
  }

  Widget _operatorChip(String? code, String label) {
    final selected = _operatorCode == code;
    return Padding(
      padding: const EdgeInsets.only(left: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _operatorCode = code),
        labelStyle: AppTypography.cairo(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.slate700,
        ),
        selectedColor: AppColors.slate900,
        backgroundColor: AppColors.slate100,
      ),
    );
  }
}
