import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_icon_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/order_model.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/app_catalog_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/virtual_numbers_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/digital_pass_card.dart';
import '../../widgets/top_notice.dart';
import 'manual_order_details_screen.dart';
import 'topup_screen.dart';
import 'virtual_number_wait_screen.dart';

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

enum VirtualNumberCategory {
  auto,
  manual,
}

class _VirtualNumbersScreenState extends State<VirtualNumbersScreen> {
  final Set<String> _codeAnnounced = {};
  final Set<String> _refundAnnounced = {};

  /// التبديل بين الخدمات التلقائية واليدوية
  VirtualNumberCategory _selectedCategory = VirtualNumberCategory.auto;
  bool _categoryManuallySelected = false;

  /// الطلب اليدوي الناتج عن آخر إرسال: تُلتقط نسخته داخل النافذة التي تُغلق
  /// نفسها، ثم يُفتح صفحته (الشات) بعد إغلاقها من سياق هذه الصفحة
  OrderModel? _pendingManualOrder;

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

  /// الرسائل تأجل إلى ما بعد الإطارية: notifyListeners قد يحدث أثناء البناء،
  /// وهي تنبيهٌ في أعلى الشاشة لا شريطٌ أسفلها يغطيه الإصبع أثناء الكتابة
  void _notify(String title, String body, Color tone) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // خبرُ الصفحة سطرٌ واحد: عنوانٌ ومضمونُه في نصٍّ كما كان في الشريط
      TopNotice.show(context, title: '$title — $body', tone: tone);
    });
  }

  /// عدّاد الثواني يعمل فقط أثناء وجود مهلة جارية (لا مؤقّت بلا حاجة)
  void _syncTicker() {
    final needsTicker = _provider?.activeRequests.isNotEmpty == true;
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
    final actives = provider.activeRequests;

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
              actives.isEmpty) ...[
            _buildAlert(provider.errorMessage!),
            const SizedBox(height: 14),
          ],
          // شريط الأرقام الجارية — صغير ولا يحجب الكتالوج: العميل يتابع
          // شراءه وهو ينتظر رمزه، ولكل رقم صفحة انتظاره الخاصة
          if (actives.isNotEmpty) ...[
            _buildSectionHeader(
              'أرقامك الجارية',
              '${actives.length} LIVE',
              _headerAccent,
            ),
            const SizedBox(height: 10),
            ...actives.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _ActiveNumberStrip(
                  request: request,
                  onTap: () => _openWaitScreen(request),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // بلا شريط علوي: الصفحة تبدأ مباشرة بشبكة الخدمات — عدّات الخدمات
          // والدول والمهلة ليست قراراً يتخذه العميل. الشبكة واحدة تجمع اليدوي
          // المضمون والتلقائي بشارة نوع على زاوية كل كرت
          _buildSectionHeader('اختر الخدمة', 'ACTIVATE', AppColors.ticketAmber),
          const SizedBox(height: 10),
          _buildServicesArea(provider),
          const SizedBox(height: 18),
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

  /// لون شريط عنوان «أرقامك الجارية»: أخضر عند وصول الرمز وإلا ذهبي
  Color get _headerAccent {
    final actives = _provider?.activeRequests ?? const [];
    return actives.any((a) => a.hasCode)
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

  // ---------------------------------------------------------------------------
  // شبكة واحدة: التفعيل المضمون (يدوي) وشراء الأرقام (تلقائي) معاً — لا
  // قسمين منعزلين، والفرق يُقرأ من شارة زاوية كل كرت
  // ---------------------------------------------------------------------------

  Widget _buildServicesArea(VirtualNumbersProvider provider) {
    if (provider.isLoadingOptions &&
        provider.options.services.isEmpty &&
        provider.options.manualServices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final options = provider.options.services;
    final manuals = provider.options.manualServices;
    if (options.isEmpty && manuals.isEmpty) {
      return _buildEmptyCatalog(provider);
    }

    // توجيه تلقائي للقسم المتاح إذا لم يحدد العميل تبويباً معيناً
    if (!_categoryManuallySelected) {
      if (options.isEmpty && manuals.isNotEmpty) {
        _selectedCategory = VirtualNumberCategory.manual;
      } else if (manuals.isEmpty && options.isNotEmpty) {
        _selectedCategory = VirtualNumberCategory.auto;
      }
    }

    final isAuto = _selectedCategory == VirtualNumberCategory.auto;
    final cards = isAuto
        ? options.map((s) => _NumberCardItem.auto(s)).toList()
        : manuals.map((s) => _NumberCardItem.manual(s)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCategoryToggle(options.length, manuals.length),
        const SizedBox(height: 10),
        _buildTypeExplanation(),
        const SizedBox(height: 12),
        if (cards.isEmpty)
          _buildEmptySection(isAuto)
        else
          _buildCardsGrid(cards),
      ],
    );
  }

  Widget _buildCategoryToggle(int autoCount, int manualCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              category: VirtualNumberCategory.auto,
              title: 'الخدمات التلقائية',
              badge: autoCount > 0 ? '$autoCount' : null,
              icon: Icons.bolt_rounded,
              activeColor: AppColors.ticketAmber,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildToggleButton(
              category: VirtualNumberCategory.manual,
              title: 'الخدمات اليدوية',
              badge: manualCount > 0 ? '$manualCount' : null,
              icon: Icons.verified_user_rounded,
              activeColor: AppColors.emerald,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required VirtualNumberCategory category,
    required String title,
    required String? badge,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedCategory == category;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectedCategory != category) {
            setState(() {
              _selectedCategory = category;
              _categoryManuallySelected = true;
            });
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: activeColor.withValues(alpha: 0.4),
                    width: 1.2,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? activeColor : AppColors.slate500,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected ? AppColors.slate900 : AppColors.slate600,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.15)
                        : AppColors.slate200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: AppTypography.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? activeColor : AppColors.slate600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeExplanation() {
    final isAuto = _selectedCategory == VirtualNumberCategory.auto;
    final tone = isAuto ? AppColors.ticketAmber : AppColors.emerald;
    final title = isAuto
        ? 'الخدمات التلقائية (أرقام فورية)'
        : 'الخدمات اليدوية (تفعيل مضمون)';
    final badgeText = isAuto ? 'فوري وتلقائي' : 'إشراف ومتابعة';
    final description = isAuto
        ? 'أرقام سحابية مؤتمتة من عدة دول ومزودين، يصلك رمز التفعيل تلقائياً في ثوانٍ. وفي حال عدم وصول الرسالة خلال المهلة، يُعاد المبلغ تلقائياً وفورياً إلى محفظتك.'
        : 'تفعيل يدوي ومضمون بواسطة فريق الدعم المختص لضمان استقرار حسابك وتجنب الحظر، مع متابعة مباشرة لطلبك حتى وصول الرمز وإتمام التفعيل بنجاح.';
    final icon = isAuto ? Icons.bolt_rounded : Icons.verified_user_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: AppTypography.cairo(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: tone,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: AppTypography.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(bool isAuto) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            isAuto ? Icons.numbers_rounded : Icons.handshake_outlined,
            size: 34,
            color: AppColors.slate400,
          ),
          const SizedBox(height: 8),
          Text(
            isAuto
                ? 'لا توجد أرقام تلقائية متاحة حالياً'
                : 'لا توجد خدمات يدوية متاحة حالياً',
            style: AppTypography.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.slate600,
            ),
          ),
        ],
      ),
    );
  }

  /// ثلاثة كروت في الصف ثابتة: على الشاشة العريضة يكبر الكرت ولا يقلّ عدد
  /// الكروت، والفراغ بين الكروت متساوٍ في الاتجاهين لأنها كروت لا أيقونات
  Widget _buildCardsGrid(List<_NumberCardItem> cards) {
    const double spacing = 8;
    const int columns = 3;
    const double infoHeight = 52;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: cellWidth + infoHeight,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return _NumberServiceCard(
              item: card,
              onTap: () => card.isManual
                  ? _openManualSheet(card.manual!)
                  : _openCountrySheet(card.option!),
            );
          },
        );
      },
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

  Future<void> _openCountrySheet(VirtualNumberServiceOption service) async {
    // معرّفات الأرقام الجارية قبل الشراء: الجديد وحده يملك صفحة الانتظار
    final beforeIds = context
        .read<VirtualNumbersProvider>()
        .myRequests
        .map((r) => r.id)
        .toSet();
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
        onSubmit: (country, offer) => _submit(service, country, offer),
      ),
    );
    if (!mounted) return;
    final provider = context.read<VirtualNumbersProvider>();
    provider.startAutoPolling();
    // الشراء ينجح من داخل النافذة التي تُغلق نفسها: التنقل هنا يكون
    // والصفحة هي أقرب Scaffold، وإلا قفزت الصفحة القديمة أمام الانتظار
    VirtualNumberRequestModel? created;
    for (final r in provider.myRequests) {
      if (r.isLive && !beforeIds.contains(r.id)) {
        created = r;
        break;
      }
    }
    if (created != null) _openWaitScreen(created);
  }

  /// صفحة انتظار الرمز: مستقلة، والعودة منها لا تلغي الرقم ولا توقف رصد الرموز
  void _openWaitScreen(VirtualNumberRequestModel request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VirtualNumberWaitScreen(
          requestId: request.id,
          initialRequest: request,
        ),
      ),
    );
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
    // الشراء اليدوي لا يكتمل في هذه الصفحة: العميل يحتاج الدردشة ليُتابع
    // الطلب ويكمل ما يطلبه مقدّم الخدمة (كود/مرفق/بيانات إضافية)
    final created = _pendingManualOrder;
    _pendingManualOrder = null;
    if (created != null && mounted) _openManualOrderChat(created);
  }

  /// صفحة الطلب/الدردشة: مستقلة كالانتظار، والعودة منها تُبقي القائمة محدَّثة
  void _openManualOrderChat(OrderModel order) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ManualOrderDetailsScreen(order: order)),
    );
  }

  /// نسخة الطلب الملتقطة من استجابة الشراء: الخادم يعيد الطلب كاملاً بعد
  /// populate، وهي ما تحتاجه تذكرة المحادثة (اسم الخدمة والمسند والمهلة).
  /// يستُدعى سجل «طلباتي» احتياطاً إن لم تُعد الاستجابة كائناً صالحاً.
  OrderModel? _manualOrderFrom(Map<String, dynamic> result) =>
      context.read<AppCatalogProvider>().lastPurchasedOrder(result);

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
      messenger.showTopSnackBar(
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
    // تُلتقط هنا والنافذة ما زالت مفتوحة: التنقل بعدها من هذه الصفحة لا من
    // النافذة التي تُغلق نفسها، فيبقى الظاهر هو الطلب لا القائمة القديمة
    _pendingManualOrder = _manualOrderFrom(result);
    messenger.showTopSnackBar(
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
    VirtualNumberOffer offer,
  ) async {
    final provider = context.read<VirtualNumbersProvider>();
    final wallet = context.read<WalletProvider>();
    // السعر من العرض المختار: سيرفران يبيعان الدولة نفسها بسعرين مختلفين
    final price = offer.salePrice;

    if (price > wallet.balance) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('رصيد غير كافٍ'),
          content: Text(
            'السعر \$${price.toStringAsFixed(2)} ورصيدك '
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
          // اسم السيرفر للعميل مبهم: لا يسرّب اسم المشغّل الحقيقي ولا
          // وسم المزود، بل «سيرفر N» بحسب ترتيبه في قائمة عروض الدولة
          'السيرفر: ${_serverTitleFor(country, offer)}\n'
          'السعر: \$${price.toStringAsFixed(2)} يُخصم من رصيدك\n\n'
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
      // المنتج هو المقصود بالشراء: به يُحدَّد السيرفر وهامشه وعدّاد جودته
      productId: offer.isPurchasable ? offer.productId : null,
      // بلا معرّف منتج (كتالوج قديم مخزَّن) يعود المسار القديم برموز التطبيق
      service: offer.isPurchasable ? '' : service.code,
      country: offer.isPurchasable ? '' : country.code,
      // المشغّل صار صفة المنتج نفسه: يُرسل في المسار القديم فقط حين لا منتج
      operator: offer.isPurchasable ? null : offer.operator,
    );

    if (!mounted) return message != null;

    ScaffoldMessenger.of(context).showTopSnackBar(
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
}

/// شريط رقم جارٍ مختصر: يُلمح بحالة الرقم ووقته، والضغط يفتح صفحة الانتظار
class _ActiveNumberStrip extends StatelessWidget {
  final VirtualNumberRequestModel request;
  final VoidCallback onTap;

  const _ActiveNumberStrip({required this.request, required this.onTap});

  String _clock() {
    final left = request.remainingSeconds();
    if (left == null) return '—';
    final m = (left / 60).floor();
    final s = left % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = request.hasCode;
    final tone = hasCode ? AppColors.emerald : AppColors.ticketAmber;
    final detail = hasCode
        ? (request.smsCode ?? '')
        : (request.phoneNumber ?? 'جارٍ تجهيز الرقم…');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tone.withValues(alpha: 0.45), width: 1.3),
          ),
          child: Row(
            children: [
              Text(request.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.title} • ${request.countryName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasCode ? 'الرمز: $detail' : detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.technicalCode(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: hasCode ? AppColors.emerald : AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _clock(),
                    style: AppTypography.technicalCode(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: tone,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasCode ? 'اضغط للرمز' : 'بانتظار الرمز',
                    style: AppTypography.cairo(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: AppColors.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// كرت خدمة في شبكة الأرقام: تذكرة صورتها تملؤها، ووسم النوع في زاويتها
// =============================================================================

class _NumberServiceCard extends StatelessWidget {
  final _NumberCardItem item;
  final VoidCallback onTap;

  const _NumberServiceCard({required this.item, required this.onTap});

  /// رمز التطبيق الذي يملأ الكرت: الرمز المخزّن ثم الأسماء العربي والأجنبي ورمز الخدمة
  String? _findIconAsset() {
    final cleanIcon = item.iconRaw.trim();
    if (cleanIcon.isNotEmpty) {
      if (cleanIcon.startsWith('assets/')) return cleanIcon;
      final direct = builtinIconAssetExact(cleanIcon);
      if (direct != null) return direct;
      final byQuery = builtinIconAssetForQuery(cleanIcon);
      if (byQuery != null) return byQuery;
    }
    for (final seed in item.iconSeeds) {
      if (seed.trim().isEmpty) continue;
      final found = iconAssetForApp(iconUrl: cleanIcon, name: seed.trim());
      if (found != null) return found;
    }
    return null;
  }

  // غلاف التذكرة: فتحتان على الحافتين وحوافة 14، والصورة تملأ الكرت إلى خطّ
  // تبويبي الاسم والسعر لا إلى آخره
  static const double _radius = 14;
  static const double _notch = 6;

  // تبويبا الكرت: شريط الاسم وشريط السعر أسفل التذكرة، والفتحتان على خطّهما
  static const double _stubHeight = 22;
  static const double _nameHeight = 20;
  static const double _tabsHeight = _stubHeight + _nameHeight;

  @override
  Widget build(BuildContext context) {
    final String? iconAsset = _findIconAsset();

    return LayoutBuilder(
      builder: (context, constraints) {
        // الفتحتان تنزلان إلى خطّ القصّ فوق تبويبي الاسم والسعر، فتنقسم
        // التذكرة إلى صورةٍ أعلى وجنبٍ مقصوصٍ أسفل لا إلى كرتٍ بفتحةٍ في وسطه
        final double height = constraints.maxHeight;
        final double ceiling = (height - _radius - _notch) / height;
        final double upper = ceiling > 0.55 ? ceiling : 0.55;
        final double notchFraction = ((height - _tabsHeight) / height)
            .clamp(0.55, upper)
            .toDouble();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: CustomPaint(
            painter: TicketPassShadowPainter(
              cornerRadius: _radius,
              notchRadius: _notch,
              notchPositionFraction: notchFraction,
              // ظلّ بلون النوع: أخضر خلف المضمون وكهرماني خلف الآلي
              shadowColor: item.tagColor,
              elevation: 5,
            ),
            foregroundPainter: TicketPassBorderPainter(
              cornerRadius: _radius,
              notchRadius: _notch,
              notchPositionFraction: notchFraction,
              borderColor: Colors.white.withValues(alpha: 0.75),
              borderWidth: 1,
            ),
            child: ClipPath(
              clipper: TicketPassClipper(
                cornerRadius: _radius,
                notchRadius: _notch,
                notchPositionFraction: notchFraction,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // أرض التذكرة: تدرّج وحرف، كي لا تترك البطاقةُ بلا رمز
                  // بياضاً على حوافها، ولكي يبقى تحت تبويبي الاسم والسعر ما يسده
                  _letterBackdrop(),
                  // الصورة وقدرُها ما فوق التبويبين: حدُّها السفلي خطُّ الاسم
                  // نفسه، فلا اسمَ ولا سعرَ يُقرأ فوق جزء منها
                  PositionedDirectional(
                    top: 0,
                    start: 0,
                    end: 0,
                    bottom: _tabsHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (iconAsset != null)
                          Positioned.fill(
                            child: Image.asset(
                              iconAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        // تعتيم أسفل الصورة: الأسطر الصغيرة تُقرأ فوق أي رمز
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0.0, 0.4, 0.7, 0.86],
                                  colors: [
                                    Color(0x00000000),
                                    Color(0x0D000000),
                                    Color(0x66000000),
                                    Color(0xB3000000),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // أعلى الصورة للقفل والشارة، وأسفلها الأسطر الصغيرة
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(7, 20, 7, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // الاسم الأجنبي وعدد الدول يبقيان على الصورة،
                                // أما الاسم والسعر فلكلٍّ تبويبه تحتها
                                if (item.foreign.isNotEmpty)
                                  _subLine(item.foreign, ltr: true),
                                if (item.metaText.isNotEmpty)
                                  _subLine(item.metaText),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // تبويب الاسم فوق تبويب السعر: شريطاهما الآن على أرض التذكرة
                  // لا على الصورة
                  PositionedDirectional(
                    bottom: _stubHeight,
                    start: 0,
                    end: 0,
                    child: _nameTab(),
                  ),
                  // تبويب السعر أسفل الكرت: السعر وحده، أكبر وأبين من قبل
                  PositionedDirectional(
                    bottom: 0,
                    start: 0,
                    end: 0,
                    child: _priceStub(),
                  ),
                  // شارة النوع في زاوية الكرت: هي وحدها ما يفرّق خدمةَ مشرف
                  // مضمونة عن رقم مزود آلي، بعد أن ادمجت الشبكة الواحدة القسمين
                  PositionedDirectional(top: 4, start: 4, child: _typeTag()),
                  if (item.sensitive)
                    // قفل صغير في الزاوية المقابلة: الخدمة تطلب بيانات سرية
                    PositionedDirectional(
                      top: 4,
                      end: 4,
                      child: _sensitiveLock(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// سطر مساعد فوق الاسم: الاسم الأجنبي أو عدد الدول، بخطّ خافت صغير
  Widget _subLine(String text, {bool ltr = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        textDirection: ltr ? TextDirection.ltr : null,
        style: AppTypography.cairo(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
          height: 1.15,
        ),
      ),
    );
  }

  /// تبويب الاسم: شريط متدرّج رأسي من أسفل الكرت إلى أعلاه، الاسمُ فيه وحده
  /// بخطّ أبيض بائن، فلا يقرأه أحد فوق صورة داكنة
  Widget _nameTab() {
    return Container(
      height: _nameHeight,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        // التدرّج من أسفل الكرت إلى أعلاه: سواد عند تبويب السعر يفتح شيئاً
        // فشيئاً نحو الصورة، فالتبويبان طبقة واحدة لا شريطان بنفس اللون
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, AppColors.slate700],
        ),
        border: Border(top: BorderSide(color: Colors.white38, width: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.cairo(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.15,
          ),
        ),
      ),
    );
  }

  /// شريط السعر أسفل التذكرة: أرضية داكنة مصمتة وخطّ كبير بلون التطبيق المميز،
  /// فالسعر أول ما تقرأه العين ولا ينافسه سطرُ الدول ولا الاسم
  Widget _priceStub() {
    return Container(
      height: _stubHeight,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.slate900,
        // نفس الخيط الأبيض الرفيع الذي فوق تبويب الاسم: خطّان متماثلان
        // يفصلان الصورة عن الاسم عن السعر
        border: Border(top: BorderSide(color: Colors.white38, width: 0.8)),
      ),
      child: Text(
        item.priceText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppTypography.cairo(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: AppColors.ticketAmber,
          height: 1.15,
        ),
      ),
    );
  }

  /// قفل على زاوية كرت الخدمة التي تطلب بيانات سرية
  Widget _sensitiveLock() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Icon(
        Icons.lock_outline_rounded,
        size: 9,
        color: AppColors.rose,
      ),
    );
  }

  /// وسم صغير أعلى الكرت: أخضر للتفعيل المضمون، كهرماني للرقم الآلي
  Widget _typeTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: item.tagColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.tag,
        maxLines: 1,
        style: AppTypography.cairo(
          fontSize: 7,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    );
  }

  /// خلفية التذكرة: تدرّج بحرف كبير من اسم الخدمة، تُمدّ فوقها الصورة عند وجودها
  Widget _letterBackdrop() {
    final letter = item.name.isNotEmpty
        ? item.name.substring(0, 1)
        : (item.letterSeed.isEmpty
              ? '#'
              : item.letterSeed.substring(0, 1).toUpperCase());
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF475569)],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: AppTypography.fintechBadge(color: Colors.white, fontSize: 30),
        ),
      ),
    );
  }
}

// =============================================================================
// عنصر شبكة الأرقام: خدمة يدوية مضمونة أو رقم مزود تلقائي في قالب واحد
// =============================================================================

/// بيانات جاهزة للرسم تجمع النوعين، فتُرسم الشبكة الواحدة بكروت متطابقة لا
/// تتفرّع إلا في النص وشارة الزاوية ونافذة الطلب التي يفتحها النقر
class _NumberCardItem {
  const _NumberCardItem({
    required this.isManual,
    required this.name,
    required this.iconRaw,
    required this.iconSeeds,
    required this.letterSeed,
    required this.priceText,
    required this.tag,
    required this.tagColor,
    this.foreign = '',
    this.metaText = '',
    this.sensitive = false,
    this.manual,
    this.option,
  });

  /// خدمة يدوية: اسمها العربي وحده في السطر الأول، وتبويب السعر أسفل الكرت
  factory _NumberCardItem.manual(VirtualNumberManualServiceModel s) {
    return _NumberCardItem(
      isManual: true,
      name: s.name,
      iconRaw: s.appIcon,
      // أيقونة التطبيق المرتبط ثم اسم الخدمة: «تفعيل تيليجرام يدوي» يدلّ على
      // تيليجرام، فتبقى الأيقونة مطابقة لبقية الكروت حتى بلا رمز مخزّن
      iconSeeds: <String>[s.appName, s.name, s.appServiceCode],
      letterSeed: s.appName.isNotEmpty ? s.appName : s.name,
      priceText: '\$${s.price.toStringAsFixed(2)}',
      tag: 'يدوي مضمون',
      tagColor: AppColors.emerald,
      // الخدمة التي تطلب بيانات سرية تُنبَّه بقفل على الكرت، لا بنص يقرأه المار
      sensitive: s.isSensitive,
      manual: s,
    );
  }

  /// رقم مزود: الاسم العربي وتحته الأجنبي، والدول سطرٌ والسعر في تبويبه
  factory _NumberCardItem.auto(VirtualNumberServiceOption s) {
    final displayName = s.nameAr.isNotEmpty ? s.nameAr : s.name;
    final foreign = s.nameEn.trim();
    // السطر الأجنبي لا يظهر إلا تحت اسم عربي: إن كان الظاهر لاتينياً أصلاً
    // فلا يُكرر، وإن طابق الأجنبي العربي يُحجب
    final showForeign =
        _hasArabicText(displayName) &&
        foreign.isNotEmpty &&
        foreign != displayName;
    return _NumberCardItem(
      isManual: false,
      name: displayName,
      iconRaw: s.icon,
      iconSeeds: <String>[s.nameAr, s.nameEn, s.name],
      letterSeed: s.code,
      priceText: 'من \$${s.bestPrice.toStringAsFixed(2)}',
      metaText: '${s.countries.length} دولة',
      tag: 'تلقائي',
      tagColor: AppColors.ticketAmber,
      foreign: showForeign ? foreign : '',
      option: s,
    );
  }

  final bool isManual;
  final String name;
  final String foreign;
  final String iconRaw;
  final List<String> iconSeeds;
  final String letterSeed;

  /// السعر وحده: يُرسم في تبويب أسفل الكرت لا مختلطاً بغيره
  final String priceText;
  final String metaText;
  final String tag;
  final Color tagColor;
  final bool sensitive;
  final VirtualNumberManualServiceModel? manual;
  final VirtualNumberServiceOption? option;
}

bool _hasArabicText(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);

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
    // الحقول كما عرّفتها الإدارة حرفياً: خدمة يدوية بلا حقول تُنفَّذ بمجرّد
    // تأكيد الطلب، فإجبار حقل «المعرف» كان يُلزم العميل ببيانات لا تحتاجها
    // الخدمة ويُرفض طلبه إن تركه فارغاً
    _fieldLabels = widget.service.requiredFields;
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
        ).showTopSnackBar(SnackBar(content: Text('يرجى إدخال ${entry.key}')));
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

  /// خدمة بلا حقول إدخال: يُطمأن العميل أن لا بيانات مطلوبة منه، فيُصبح
  /// زر التأكيد هو الخطوة الوحيدة قبل دخول الطلب مساحة المشرف
  Widget _noFieldsNote() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.fact_check_outlined,
            size: 17,
            color: AppColors.slate600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'لا تحتاج هذه الخدمة أي بيانات منك — أكّد الطلب فقط وسيبدأ '
              'المشرف المختص في التنفيذ.',
              style: AppTypography.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.slate600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
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
              if (_fieldLabels.isEmpty) ...[
                _noFieldsNote(),
                const SizedBox(height: 14),
              ],
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
    VirtualNumberOffer offer,
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

  /// العرض المختار: الدولة الواحدة قد تُباع عبر عدة عروض (كل مشغّل/سيرفر عرض
  /// مستقل بسعره ومخزونه)، فالسعر والمخزون صفة هذا العرض لا صفة الدولة
  VirtualNumberOffer? _offer;
  bool _submitting = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.service.countries.isNotEmpty) {
      _selectCountry(widget.service.countries.first);
    }
  }

  void _selectCountry(VirtualNumberCountryOption country) {
    _country = country;
    // أول سيرفرات الدولة هو المختار: لا تُوجَّه يد العميل إلى أرخص سعر
    _offer = country.effectiveOffers.first;
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
    final offer = _offer;
    if (country == null || offer == null || _submitting) return;
    setState(() => _submitting = true);
    final ok = await widget.onSubmit(country, offer);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Navigator.of(context).pop();
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
                        final affordable =
                            country.lowestPrice <= widget.balance;
                        return _countryRow(country, selected, affordable);
                      },
                    ),
                  ),
                ),
              ),
            ),
          if (_country != null && _country!.effectiveOffers.length > 1) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                'السيرفر',
                style: AppTypography.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate600,
                ),
              ),
            ),
            _serverCards(_country!),
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
                      // السعر من العرض المختار: كل سيرفر بسعره، ولا يُدمج سعران
                      'تفعيل الرقم \$${(_offer?.salePrice ?? 0).toStringAsFixed(2)}',
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
    // الدول تُعرض بأرخص سيرفر يبيعها، لكن الشراء يكون على السيرفر المختار نفسه
    final servers = country.effectiveOffers.length;

    return Material(
      color: selected ? const Color(0xFFFFF7E6) : Colors.white,
      child: InkWell(
        onTap: () => setState(() => _selectCountry(country)),
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
                    if (servers > 1)
                      Text(
                        'متاحة من $servers سيرفر',
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
                    // «من $X» حين يبيعها أكثر من سيرفر، وسعر السيرفر الواحد غيره
                    '${servers > 1 ? 'من ' : ''}\$${country.lowestPrice.toStringAsFixed(2)}',
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

  /// بطاقات السيرفرات: عرض مستقل لكل سيرفر ب اسمه المبهم «سيرفر N» وسعره
  /// ومخزونه. الاسم الحقيقي للمشغّل لا يظهر للعميل حتى لا يعرف من أي
  /// مزود يأتيه الرقم، وحين يكون للدولة سيرفر واحد تُستعمل تسمية المزود
  /// الافتراضية كما كان قبل تعدد السيرفرات
  Widget _serverCards(VirtualNumberCountryOption country) {
    final offers = country.effectiveOffers;
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: offers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final offer = offers[index];
          final selected = _offer?.selectionKey == offer.selectionKey;
          final affordable = offer.salePrice <= widget.balance;
          return _serverCard(offer, selected, affordable, index, offers.length);
        },
      ),
    );
  }

  Widget _serverCard(
    VirtualNumberOffer offer,
    bool selected,
    bool affordable,
    int index,
    int total,
  ) {
    return Material(
      color: selected ? const Color(0xFFFFF7E6) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _offer = offer;
        }),
        child: Container(
          width: 132,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.secondaryBright
                  : AppColors.outlineVariant,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.cloud_outlined,
                    size: 14,
                    color: selected
                        ? AppColors.secondaryBright
                        : AppColors.slate400,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      // الاسم المعروض: مبهم «سيرفر N» حين تعدّدت بطاقات
                      // الدولة، وإلا اسم السيرفر الوهمي للمزود
                      total > 1 ? 'سيرفر ${index + 1}' : offer.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '\$${offer.salePrice.toStringAsFixed(2)}',
                style: AppTypography.price(
                  color: affordable ? AppColors.slate900 : AppColors.rose,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// عنوان السيرفر للعميل: «سيرفر N» بحسب ترتيبه في بطاقات الدولة حين
/// تعدّدت، وإلا الاسم الوهمي للمزود. لا يسرّب اسم المشغّل الحقيقي
/// كي لا يعرف العميل من أي مصدر يأتيه الرقم
String _serverTitleFor(
  VirtualNumberCountryOption country,
  VirtualNumberOffer offer,
) {
  final list = country.effectiveOffers;
  if (list.length <= 1) return offer.label;
  final pos = list.indexWhere((o) => o.selectionKey == offer.selectionKey);
  return pos >= 0 ? 'سيرفر ${pos + 1}' : offer.label;
}
