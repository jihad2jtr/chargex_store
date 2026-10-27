import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import 'providers_management_screen.dart';
import 'apps_products_management_screen.dart';
import 'payment_accounts_screen.dart';
import 'shipping_codes_screen.dart';
import 'orders_management_screen.dart';
import 'banners_management_screen.dart';
import 'manual_services_management_screen.dart';
import 'users_management_screen.dart';
import 'service_templates_screen.dart';
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
  final String _selectedCategory = 'all'; // 'all' | 'catalog' | 'finance'
  Timer? _autoRefreshTimer;
  int _statsTick = 0;

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
    ]);
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AuthProvider>(context);
    final admin = Provider.of<AdminProvider>(context);

    final pendingOrdersCount = admin.pendingOrdersCount;
    final pendingTopupsCount = admin.pendingTopupsCount;
    final totalPending = pendingOrdersCount + pendingTopupsCount;

    final sections = _getSections(
      admin,
      pendingOrdersCount,
      pendingTopupsCount,
    );
    final filteredSections = _selectedCategory == 'all'
        ? sections
        : sections.where((s) => s.category == _selectedCategory).toList();

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
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const UnifiedTactileHeader(isDashboard: true),
                    const SizedBox(height: 12),

                    // KPI Stats Grid
                    _buildOpsConsole(admin),
                    const SizedBox(height: 28),

                    // Management Sections Header with Interactive Category Tabs
                    _buildManagementHeader(sections.length, totalPending),
                    const SizedBox(height: 14),

                    // Category Filter Tabs
                    const SizedBox(height: 16),

                    // Management Sections Grid (نمط أيقونات الهاتف)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredSections.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.of(context).size.width >= 1200
                            ? 6
                            : MediaQuery.of(context).size.width >= 700
                            ? 5
                            : 4,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 126,
                      ),
                      itemBuilder: (context, index) {
                        final item = filteredSections[index];
                        return _buildSectionTile(item);
                      },
                    ),
                    const SizedBox(height: 24),
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
              width: 3.5,
              height: 18,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'أقسام الإدارة والتحكم',
              style: AppTypography.cairo(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outline),
          ),
          child: Text(
            '$totalSections أقسام رئيسية',
            style: AppTypography.cairo(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
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
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
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
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.34),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: Colors.white, size: 28),
              ),
              if (badgeCount != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badgeCount,
                      textAlign: TextAlign.center,
                      style: AppTypography.cairo(
                        fontSize: 9.5,
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
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.statusText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 9.5,
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
  ) {
    final totalPending = pendingOrdersCount + pendingTopupsCount;
    final stats = admin.dashboardStats;
    final onlineProviders = stats?.providersOnline ?? 0;
    final activeBanners = stats?.bannersActive ?? 0;
    final activeAccounts = stats?.accountsActive ?? 0;
    final unusedCodes = stats?.codesAvailable ?? 0;
    final supervisorsCount = stats?.usersSupervisors ?? 0;

    return [
      // 1. Providers Management
      _AdminSectionItem(
        title: 'إدارة المزودين',
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

      // 2. Apps & Products (Merged)
      _AdminSectionItem(
        title: 'التطبيقات والمنتجات',
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF0EA5E9), // Cyan / Sky Blue
        category: 'catalog',
        statusText:
            '${stats?.appsActive ?? 0} تطبيق • ${stats?.productsActive ?? 0} باقة',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AppsAndProductsManagementScreen(),
            ),
          );
        },
      ),

      // 3. Service Templates (أنواع قوالب الخدمة)
      _AdminSectionItem(
        title: 'أنواع قوالب الخدمة',
        icon: Icons.description_outlined,
        color: const Color(0xFF7C3AED), // Violet
        category: 'catalog',
        statusText: '${stats?.serviceTemplates ?? 0} قالب',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ServiceTemplatesScreen()),
          );
        },
      ),

      // 4. Manual Services & Supervisors
      _AdminSectionItem(
        title: 'الخدمات اليدوية والمشرفين',
        icon: Icons.assignment_ind_rounded,
        color: const Color(0xFF0D9488), // Teal
        category: 'catalog',
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

      // 5. Users Management
      _AdminSectionItem(
        title: 'إدارة المستخدمين',
        icon: Icons.manage_accounts_rounded,
        color: const Color(0xFF0EA5E9), // Sky Blue
        category: 'finance',
        statusText: '${stats?.usersTotal ?? 0} مستخدم',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UsersManagementScreen()),
          );
        },
      ),

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

      // 7. Shipping & Voucher Codes
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

      // 8. Orders & Requests Review
      _AdminSectionItem(
        title: 'الطلبات والمراجعة',
        icon: Icons.fact_check_rounded,
        color: const Color(0xFFF43F5E), // Rose / Red
        category: 'finance',
        isAlert: totalPending > 0,
        statusText: totalPending > 0 ? '$totalPending معلق' : 'مكتمل ✅',
        statusColor: totalPending > 0 ? AppColors.error : AppColors.tertiary,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OrdersManagementScreen()),
          );
        },
      ),

      // 9. Billboard & Ads
      _AdminSectionItem(
        title: 'لوحة الإعلانات',
        icon: Icons.view_carousel_rounded,
        color: const Color(0xFFF59E0B), // Amber Gold
        category: 'catalog',
        statusText: '$activeBanners نشط',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BannersManagementScreen()),
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
