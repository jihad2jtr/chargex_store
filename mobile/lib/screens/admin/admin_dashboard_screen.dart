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
import 'virtual_number_manual_services_screen.dart';
import 'virtual_number_quality_screen.dart';
import '../../widgets/unified_tactile_header.dart';
import '../../widgets/floating_role_dashboard_shield.dart';
import '../../widgets/ops_console.dart';
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
                    const SizedBox(height: 10),

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
                          const SizedBox(height: 3),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: groupSections.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _gridColumns(),
                                  crossAxisSpacing: 5,
                                  mainAxisSpacing: 8,
                                  mainAxisExtent: 94,
                                ),
                            itemBuilder: (context, index) =>
                                _buildSectionTile(groupSections[index]),
                          ),
                          const SizedBox(height: 5),
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
    if (width >= 1200) return 6;
    if (width >= 700) return 5;
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

  // --- Section Tile: نمط أيقونات الهاتف (App Icon) ---
  Widget _buildSectionTile(_AdminSectionItem item) {
    final Color accent = item.isAlert ? const Color(0xFFEF4444) : item.color;

    // شارة رقمية على غرار إشعارات التطبيقات: تُعرض فقط للأقسام التي تحتاج تدخلاً
    final RegExpMatch? countMatch = RegExp(
      r'^\s*(\d+)',
    ).firstMatch(item.statusText);
    final String? badgeCount = (item.isAlert && countMatch != null)
        ? countMatch.group(1)
        : null;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(accent, Colors.white, 0.30)!,
                      accent,
                      Color.lerp(accent, Colors.black, 0.20)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.34),
                      blurRadius: 9,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: Colors.white, size: 22),
              ),
              if (badgeCount != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.3),
                    ),
                    child: Text(
                      badgeCount,
                      textAlign: TextAlign.center,
                      style: AppTypography.cairo(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 1.5),
          Text(
            item.statusText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 8.6,
              fontWeight: FontWeight.bold,
              color: item.statusColor ?? AppColors.textSecondary,
            ),
          ),
        ],
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
        color: const Color(0xFF155E75), // Cyan 800
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

      // 2. تطبيقات الأرقام الوهمية: صفحة الانتقاء معزولة كقسم مستقل
      //    (كانت خلف زر أيقوني داخل «الأرقام الوهمية» فقط)
      _AdminSectionItem(
        title: 'إدارة تطبيقات الارقام',
        icon: Icons.apps_rounded,
        color: const Color(0xFF0D9488), // Teal — هوية صفحة الانتقاء نفسها
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
        color: const Color(0xFFBE123C), // Rose 700 — هوية المراقبة والتنبيه
        category: 'numbers',
        statusText: quality.disabled > 0
            ? '${quality.disabled} موقوف • ${quality.watching} مراقَب'
            : (quality.watching > 0
                  ? '${quality.watching} دولة تحت المراقبة'
                  : '${quality.active} دولة بحالة جيدة'),
        statusColor: quality.disabled > 0 || quality.watching > 0
            ? AppColors.rose
            : null,
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
        color: const Color(0xFF059669), // Emerald — هوية قسم العميل
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
        color: const Color(0xFF0891B2), // Deep Cyan
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
        color: const Color(0xFF6366F1), // Electric Indigo
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
        color: const Color(0xFF0EA5E9), // Cyan / Sky Blue
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
        color: const Color(0xFFF43F5E), // Rose / Red
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
        color: const Color(0xFF10B981), // Emerald
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
        color: const Color(0xFF7C3AED), // Violet
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
        color: const Color(0xFFF59E0B), // Amber Gold
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
        color: const Color(0xFF8B5CF6), // Purple
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
        color: const Color(0xFF0EA5E9), // Sky Blue
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
        color: const Color(0xFF0D9488), // Teal
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
  final Color color;
  final String category;
  final String statusText;
  final Color? statusColor;
  final bool isAlert;
  final VoidCallback onTap;

  const _AdminSectionItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.category,
    required this.statusText,
    this.statusColor,
    this.isAlert = false,
    required this.onTap,
  });
}
