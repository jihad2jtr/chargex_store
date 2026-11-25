import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/virtual_numbers_provider.dart';
import 'providers_management_screen.dart';
import 'apps_products_management_screen.dart';
import 'payment_accounts_screen.dart';
import 'shipping_codes_screen.dart';
import 'orders_management_screen.dart';
import 'banners_management_screen.dart';
import 'manual_services_management_screen.dart';
import 'users_management_screen.dart';
import 'service_templates_screen.dart';
import 'virtual_numbers_management_screen.dart';
import 'virtual_number_apps_screen.dart';
import 'virtual_number_dictionary_screen.dart';
import 'virtual_number_manual_services_screen.dart';
import 'virtual_number_quality_screen.dart';
import '../../widgets/unified_tactile_header.dart';
import '../../widgets/floating_role_dashboard_shield.dart';
import '../../widgets/ops_console.dart';
import '../../widgets/tactile_scale.dart';
import '../../widgets/admin_section_illustration.dart';
import '../user/user_main_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Timer? _autoRefreshTimer;
  int _statsTick = 0;

  // عناوين المجموعات الظاهرة فوق كل قسم
  static const Map<String, (String, IconData)> _groupTitles = {
    'numbers': ('إدارة الأرقام', Icons.sim_card_rounded),
    'catalog': ('المتجر والمنتجات', Icons.grid_view_rounded),
    'finance': ('المالية والطلبات', Icons.account_balance_wallet_rounded),
    'people': ('المستخدمون والإشراف', Icons.manage_accounts_rounded),
    'general': ('عام', Icons.category_rounded),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });

    // تحديث تلقائي خفيف: العدّادات كل 20 ثانية، والإحصاءات الأثقل كل دقيقة
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        final admin = Provider.of<AdminProvider>(context, listen: false);
        admin.fetchPendingCounts(silent: true);
        _statsTick++;
        if (_statsTick % 3 == 0) admin.fetchDashboardStats(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// تحميل خفيف: إحصاءات مجمّعة من الخادم + عدّادات معلّقة (بدون تحميل القوائم الكاملة)
  Future<void> _loadData() async {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    await Future.wait([
      admin.fetchDashboardStats(silent: true),
      admin.fetchPendingCounts(silent: true),
      // إحصاءات الأرقام الوهمية خفيفة (تجميع بالحالة) وتُظهر النشِط في البلاطة
      Provider.of<VirtualNumbersProvider>(
        context,
        listen: false,
      ).fetchAdminStats(),
      // ملخص الجودة للبلاطة: يُطلب سلّة الموقوف وحدها لأن الملخص يُحسب على
      // كامل المنتجات في الخادم مهما كان المرشّح، فترد صفوف أقل
      Provider.of<VirtualNumbersProvider>(
        context,
        listen: false,
      ).fetchAdminQuality(bucket: 'disabled', quiet: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AuthProvider>(context);
    final admin = Provider.of<AdminProvider>(context);
    final numbers = Provider.of<VirtualNumbersProvider>(context);

    final pendingOrdersCount = admin.pendingOrdersCount;
    final pendingTopupsCount = admin.pendingTopupsCount;
    final totalPending = pendingOrdersCount + pendingTopupsCount;

    final sections = _getSections(
      admin,
      pendingOrdersCount,
      pendingTopupsCount,
      numbers,
    );
    // المجموعات مرتّبة تحت عناوينها
    final visibleKeys = _groupTitles.keys.toList();
    final visibleCount = sections.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primaryBlue,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const UnifiedTactileHeader(isDashboard: true),
                    const SizedBox(height: 6),

                    // KPI Stats Grid
                    _buildOpsConsole(admin),
                    const SizedBox(height: 6),

                    // Management Sections Header
                    _buildManagementHeader(visibleCount, totalPending),
                    const SizedBox(height: 6),

                    // Management Sections Grid (نمط أيقونات الهاتف)
                    ...visibleKeys.map((key) {
                      final groupSections = sections
                          .where((s) => s.category == key)
                          .toList();
                      if (groupSections.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGroupHeader(key, groupSections.length),
                          const SizedBox(height: 2),
                          GridView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: groupSections.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _gridColumns(),
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
                                  mainAxisExtent: 100,
                                ),
                            itemBuilder: (context, index) =>
                                _buildSectionTile(groupSections[index]),
                          ),
                          const SizedBox(height: 3),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // Floating Role Shield: يعيد إلى واجهة العميل
          FloatingRoleDashboardShield(
            onCustomTap: () => _returnToClientView(context),
          ),
        ],
      ),
    );
  }

  /// زر الدرع: العودة إلى واجهة العميل
  void _returnToClientView(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const UserMainScreen()),
      );
    }
  }

  // --- Ops Console: مؤشرات اليوم + ما يحتاج تدخلًا + صحة النظام ---
  Widget _buildOpsConsole(AdminProvider admin) {
    void openOrders() {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const OrdersManagementScreen()));
    }

    void openManualServices() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ManualServicesManagementScreen(),
        ),
      );
    }

    return OpsConsole(
      stats: admin.dashboardStats,
      updatedAt: admin.statsFetchedAt,
      onReviewOrders: openOrders,
      onReviewTopups: openOrders,
      onReviewDelayed: openManualServices,
    );
  }

  // --- Management Sections Header ---
  Widget _buildManagementHeader(int totalSections, int totalPending) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'أقسام الإدارة والتحكم',
              style: AppTypography.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.outline),
          ),
          child: Text(
            '$totalSections أقسام رئيسية',
            style: AppTypography.cairo(
              fontSize: 9.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // --- عدد أعمدة الشبكة حسب عرض الشاشة ---
  int _gridColumns() {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1000) return 5;
    return 4;
  }

  // --- عنوان مجموعة الأقسام ---
  Widget _buildGroupHeader(String key, int count) {
    final (title, icon) = _groupTitles[key]!;
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primaryBlue),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTypography.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '$count',
            style: AppTypography.cairo(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1.2,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.outline,
                  AppColors.outline.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Section Tile: صور رسومية تعبيرية مع شارة رقمية/حالة على زاوية الأيقونة ---
  Widget _buildSectionTile(_AdminSectionItem item) {
    final Color accent = item.isAlert ? const Color(0xFFEF4444) : item.color;

    // استخراج الإشارة/العدّاد من statusText لعرضه كشارة على زاوية الأيقونة بدل النص تحتها
    final RegExpMatch? countMatch = RegExp(r'(\d+)').firstMatch(item.statusText);
    final int? parsedCount = countMatch != null
        ? int.tryParse(countMatch.group(1)!)
        : null;
    final bool showCheckBadge =
        item.statusText.contains('✅') && parsedCount == null;
    final String? badgeText = parsedCount != null
        ? (parsedCount > 99 ? '99+' : '$parsedCount')
        : null;
    final Color badgeColor = item.isAlert
        ? const Color(0xFFEF4444)
        : (item.statusColor ?? accent);

    return RepaintBoundary(
      child: TactileScale(
        onTap: item.onTap,
        pressedScale: 0.93,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AdminSectionIllustration(
                  kind: item.illustration,
                  accent: accent,
                  size: 62,
                ),
                if (badgeText != null || showCheckBadge)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: showCheckBadge ? 3.5 : 5.5,
                        vertical: showCheckBadge ? 3.5 : 1.5,
                      ),
                      constraints: const BoxConstraints(minWidth: 19),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: showCheckBadge
                          ? const Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: Colors.white,
                            )
                          : Text(
                              badgeText!,
                              textAlign: TextAlign.center,
                              style: AppTypography.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sections Data Builder ---
  List<_AdminSectionItem> _getSections(
    AdminProvider admin,
    int pendingOrdersCount,
    int pendingTopupsCount,
    VirtualNumbersProvider numbers,
  ) {
    final totalPending = pendingOrdersCount + pendingTopupsCount;
    final stats = admin.dashboardStats;
    final onlineProviders = stats?.providersOnline ?? 0;

    final activeAccounts = stats?.accountsActive ?? 0;
    final unusedCodes = stats?.codesAvailable ?? 0;
    final supervisorsCount = stats?.usersSupervisors ?? 0;
    // الأرقام التي لم تُغلق بعد (تجهيز/انتظار/وصل الرمز)
    final liveNumbers =
        numbers.stats.countOf('pending') +
        numbers.stats.countOf('waiting') +
        numbers.stats.countOf('received');
    // ملخص الجودة: عدد الموقوف والمراقَب من عدّادات كل سيرفر، يُجلب بهدوء
    // كي لا تُبطِئ اللوحةُ شاشةَ الإدارة عند فتحها
    final quality = numbers.qualityBoard.summary;

    return [
      // 3. Virtual Numbers Providers (منفصلة عن مزودي المتاجر)
      _AdminSectionItem(
        title: 'مزودو الأرقام الوهمية',
        icon: Icons.perm_phone_msg_rounded,
        illustration: AdminIllustrationKind.numProviders,
        color: AppColors.primaryBlue,
        category: 'numbers',
        statusText: '',
        statusColor: numbers.stats.provider != null ? AppColors.tertiary : null,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const ProvidersManagementScreen(virtualNumbersOnly: true),
            ),
          );
        },
      ),

      // 2. معجم التطبيقات: بوابة «متاح للمزودين» — يتحكم بما يظهر في الانتقاء
      _AdminSectionItem(
        title: 'معجم تطبيقات الأرقام',
        icon: Icons.menu_book_rounded,
        illustration: AdminIllustrationKind.numDictionary,
        color: AppColors.darkNav,
        category: 'numbers',
        statusText: '',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VirtualNumberDictionaryScreen(),
            ),
          );
        },
      ),

      // 2a. منتجات الأرقام: الوثاقات المضافة من المزود التي لها دولة واحدة
      //     على الأقل (الإضافة والاستيراد الجماعي صارا داخل المعجم)
      _AdminSectionItem(
        title: 'منتجات الأرقام',
        icon: Icons.apps_rounded,
        illustration: AdminIllustrationKind.numApps,
        color: AppColors.accentGreen,
        category: 'numbers',
        statusText: '',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VirtualNumberAppsScreen()),
          );
        },
      ),

      // 2b. مراقبة جودة الأرقام: عدّادات كل سيرفر وإيقافه التلقائي وإعادة تفعيله
      _AdminSectionItem(
        title: 'مراقبة جودة الأرقام',
        icon: Icons.monitor_heart_rounded,
        illustration: AdminIllustrationKind.numQuality,
        color: AppColors.primaryBlue,
        category: 'numbers',
        statusText: quality.disabled > 0
            ? '${quality.disabled} موقوف • ${quality.watching} مراقَب'
            : (quality.watching > 0
                  ? '${quality.watching} دولة تحت المراقبة'
                  : '${quality.active} دولة بحالة جيدة'),
        statusColor: quality.disabled > 0
            ? AppColors.error
            : (quality.watching > 0 ? AppColors.ticketAmber : AppColors.tertiary),
        isAlert: quality.disabled > 0,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VirtualNumberQualityScreen(),
            ),
          );
        },
      ),

      //1b. خدمات الأرقام اليدوية «تفعيل مضمون»: صفحة مستقلة إلى جانب أخواتها
      //     (كانت خلف زر درعي داخل «الأرقام الوهمية» فقط)
      _AdminSectionItem(
        title: 'خدمات التفعيل المضمون',
        icon: Icons.verified_user_rounded,
        illustration: AdminIllustrationKind.numManual,
        color: AppColors.accentGreen,
        category: 'numbers',
        statusText: '',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VirtualNumberManualServicesScreen(),
            ),
          );
        },
      ),
      // ───── إدارة الأرقام  ─────
      //2. Virtual Numbers (أرقام التحقق الوهمية)
      _AdminSectionItem(
        title: 'سجل التفعيلات التلقائية',
        icon: Icons.sim_card_rounded,
        illustration: AdminIllustrationKind.numLogs,
        color: AppColors.primaryBlue,
        category: 'numbers',
        statusText: numbers.stats.total > 0
            ? '${numbers.stats.total} طلب • $liveNumbers نشط'
            : (numbers.stats.provider?.name.isNotEmpty == true
                  ? 'مزود: ${numbers.stats.provider!.name}'
                  : 'لم يُضبط المزود'),
        statusColor: liveNumbers > 0 ? AppColors.secondary : null,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VirtualNumbersManagementScreen(),
            ),
          );
        },
      ),
      // ───── المتجر والمنتجات ─────
      // 3. Providers Management (مزودو المتاجر)
      _AdminSectionItem(
        title: 'مزودو خدمات الشحن',
        icon: Icons.hub_rounded,
        illustration: AdminIllustrationKind.storeProviders,
        color: AppColors.primaryBlue,
        category: 'catalog',
        statusText:
            '${stats?.providersTotal ?? 0} مزود ($onlineProviders متصل)',
        statusColor: onlineProviders > 0 ? AppColors.tertiary : null,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ProvidersManagementScreen(),
            ),
          );
        },
      ),

      // 4. Apps & Products (Merged)
      _AdminSectionItem(
        title: 'التطبيقات والمنتجات',
        icon: Icons.grid_view_rounded,
        illustration: AdminIllustrationKind.storeApps,
        color: AppColors.ticketAmber,
        category: 'catalog',
        statusText: '',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AppsAndProductsManagementScreen(),
            ),
          );
        },
      ),

      // 5. Orders & Requests Review (ضمن متجر ومنتجات)
      _AdminSectionItem(
        title: 'الطلبات والمراجعة',
        icon: Icons.fact_check_rounded,
        illustration: AdminIllustrationKind.orders,
        color: AppColors.ticketAmber,
        category: 'catalog',
        isAlert: totalPending > 0,
        statusText: totalPending > 0 ? '$totalPending معلق' : 'مكتمل ✅',
        statusColor: totalPending > 0 ? AppColors.error : AppColors.tertiary,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OrdersManagementScreen()),
          );
        },
      ),

      // ───── المالية والطلبات ─────

      // 6. Payment Accounts & Barcode
      _AdminSectionItem(
        title: 'حسابات الدفع',
        icon: Icons.account_balance_wallet_rounded,
        illustration: AdminIllustrationKind.paymentAccounts,
        color: AppColors.accentGreen,
        category: 'finance',
        statusText: '$activeAccounts مفعل',
        statusColor: AppColors.tertiary,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaymentAccountsScreen()),
          );
        },
      ),

      // 5. Service Templates (أنواع قوالب الخدمة) — قسم عام
      _AdminSectionItem(
        title: 'أنواع قوالب الخدمة',
        icon: Icons.description_outlined,
        illustration: AdminIllustrationKind.templates,
        color: AppColors.darkNav,
        category: 'general',
        statusText: '',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ServiceTemplatesScreen()),
          );
        },
      ),

      // 7. Billboard & Ads — قسم عام
      _AdminSectionItem(
        title: 'لوحة إدارة الأعلانات',
        icon: Icons.view_carousel_rounded,
        illustration: AdminIllustrationKind.banners,
        color: AppColors.ticketAmber,
        category: 'general',
        statusText: '',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BannersManagementScreen()),
          );
        },
      ),
      // 8. Shipping & Voucher Codes
      _AdminSectionItem(
        title: 'أكواد الشحن',
        icon: Icons.confirmation_number_rounded,
        illustration: AdminIllustrationKind.shippingCodes,
        color: AppColors.primaryBlue,
        category: 'finance',
        statusText: '$unusedCodes كود متاح',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ShippingCodesScreen()),
          );
        },
      ),

      // ───── المستخدمون والإشراف ─────
      // 9. Users Management
      _AdminSectionItem(
        title: 'إدارة المستخدمين',
        icon: Icons.manage_accounts_rounded,
        illustration: AdminIllustrationKind.users,
        color: AppColors.primaryBlue,
        category: 'people',
        statusText: '${stats?.usersTotal ?? 0} مستخدم',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UsersManagementScreen()),
          );
        },
      ),

      // 10. Manual Services & Supervisors
      _AdminSectionItem(
        title: 'الخدمات اليدوية والمشرفين',
        icon: Icons.assignment_ind_rounded,
        illustration: AdminIllustrationKind.manualServices,
        color: AppColors.accentGreen,
        category: 'people',
        statusText: '$supervisorsCount مشرف • متابعة SLA',
        statusColor: AppColors.secondary,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ManualServicesManagementScreen(),
            ),
          );
        },
      ),
    ];
  }
}

class _AdminSectionItem {
  final String title;
  final IconData icon;
  final AdminIllustrationKind illustration;
  final Color color;
  final String category;
  final String statusText;
  final Color? statusColor;
  final bool isAlert;
  final VoidCallback onTap;

  const _AdminSectionItem({
    required this.title,
    required this.icon,
    required this.illustration,
    required this.color,
    required this.category,
    required this.statusText,
    this.statusColor,
    this.isAlert = false,
    required this.onTap,
  });
}
