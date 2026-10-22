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
import '../../widgets/unified_tactile_header.dart';
import '../../widgets/digital_pass_card.dart';
import '../../widgets/floating_role_dashboard_shield.dart';
import '../../widgets/live_status_console.dart';
import '../user/user_main_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedCategory = 'all'; // 'all' | 'catalog' | 'finance'
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });

    // Auto-refresh pending counts and critical lists silently every 15 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        final admin = Provider.of<AdminProvider>(context, listen: false);
        admin.fetchAdminOrders(silent: true);
        admin.fetchManualTopupRequests();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    await Future.wait([
      admin.fetchProviders(),
      admin.fetchAdminApps(),
      admin.fetchAdminProducts(),
      admin.fetchAdminOrders(),
      admin.fetchManualTopupRequests(),
      admin.fetchAdminBanners(),
      admin.fetchPaymentAccounts(),
      admin.fetchShippingCodes(),
      admin.fetchSupervisors(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final admin = Provider.of<AdminProvider>(context);

    final pendingOrdersCount = admin.adminOrders
        .where((o) => o.status == 'pending')
        .length;
    final pendingTopupsCount = admin.manualTopupRequests
        .where((r) => r.status == 'pending')
        .length;
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
                    // Welcome Banner
                    _buildExecutiveHeader(auth.currentUser?.name, totalPending),
                    const SizedBox(height: 20),

                    // KPI Stats Grid
                    _buildKpiSection(
                      pendingOrdersCount,
                      pendingTopupsCount,
                      admin,
                    ),
                    const SizedBox(height: 28),

                    // Management Sections Header with Interactive Category Tabs
                    _buildManagementHeader(sections.length, totalPending),
                    const SizedBox(height: 14),

                    // Category Filter Tabs
                    _buildCategoryTabs(sections),
                    const SizedBox(height: 16),

                    // Management Sections Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredSections.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.of(context).size.width >= 1200
                            ? 4
                            : MediaQuery.of(context).size.width >= 700
                            ? 3
                            : 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.2,
                      ),
                      itemBuilder: (context, index) {
                        final item = filteredSections[index];
                        return _buildManagementCard(item);
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

  // --- Executive Welcome Banner ---
  Widget _buildExecutiveHeader(String? adminName, int totalPending) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkNav,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.ticketAmber.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppColors.ticketAmber,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'مرحباً، ${adminName ?? 'المدير العام'}',
                            style: AppTypography.cairo(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF065F46),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.accentGreen.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ONLINE ROOT',
                                style: AppTypography.technicalCode(
                                  color: const Color(0xFF6EE7B7),
                                  fontSize: 8.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalPending > 0
                          ? 'يوجد $totalPending طلب بحاجة لمراجعتك وتأكيد الشحن'
                          : 'النظام يعمل بكفاءة تامة وجميع خوادم الـ API متصلة',
                      style: AppTypography.cairo(
                        fontSize: 11.5,
                        color: totalPending > 0
                            ? AppColors.ticketAmber
                            : const Color(0xFF94A3B8),
                        fontWeight: totalPending > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Live Operation Status Console (KPIs) ---
  Widget _buildKpiSection(
    int pendingOrders,
    int pendingTopups,
    AdminProvider admin,
  ) {
    final onlineProviders = admin.providers
        .where((p) => p.status == 'online')
        .length;
    final providersTotal = admin.providers.length;

    final metrics = [
      LiveStatusMetric(
        label: 'الطلبات المعلقة',
        sub: 'شحن بالآيدي بانتظار التأكيد',
        value: pendingOrders.toString(),
        icon: Icons.hourglass_top_rounded,
        accent: AppColors.ticketAmber,
        statusText: pendingOrders > 0 ? 'بانتظار المراجعة' : 'مستقر',
        isAlert: pendingOrders > 0,
        rawValue: pendingOrders,
      ),
      LiveStatusMetric(
        label: 'الرصيد المعلق',
        sub: 'إيداعات يدوية غير معتمدة',
        value: pendingTopups.toString(),
        icon: Icons.account_balance_wallet_rounded,
        accent: AppColors.primaryBlue,
        statusText: pendingTopups > 0 ? 'يتطلب اعتماد' : 'معتمد',
        isAlert: pendingTopups > 0,
        rawValue: pendingTopups,
      ),
      LiveStatusMetric(
        label: 'المزودين النشطين',
        sub: '$onlineProviders من $providersTotal متصل بالـ API',
        value: providersTotal.toString(),
        icon: Icons.cloud_done_rounded,
        accent: AppColors.accentGreen,
        statusText: onlineProviders > 0 ? '$onlineProviders متصل' : 'غير متصل',
        rawValue: onlineProviders,
      ),
      LiveStatusMetric(
        label: 'المنتجات المنشورة',
        sub: 'موزعة على ${admin.adminApps.length} تطبيق وخدمة',
        value: admin.adminProducts.length.toString(),
        icon: Icons.category_rounded,
        accent: const Color(0xFF6366F1),
        statusText: admin.adminProducts.isNotEmpty ? 'منشور' : 'فارغ',
        rawValue: admin.adminProducts.length,
      ),
    ];

    return LiveStatusConsole(metrics: metrics);
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

  // --- Category Filter Tabs ---
  Widget _buildCategoryTabs(List<_AdminSectionItem> sections) {
    final catalogCount = sections.where((s) => s.category == 'catalog').length;
    final financeCount = sections.where((s) => s.category == 'finance').length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            'all',
            'جميع الأقسام (${sections.length})',
            Icons.dashboard_rounded,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'catalog',
            'الخدمات والكتالوج ($catalogCount)',
            Icons.auto_awesome_motion_rounded,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'finance',
            'المالية والعمليات ($financeCount)',
            Icons.account_balance_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedCategory == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = key;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkNav : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.darkNav : AppColors.outline,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.ticketAmber
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.cairo(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Premium Management Card ---
  Widget _buildManagementCard(_AdminSectionItem item) {
    return TicketDashboardCard(
      title: item.title,
      badgeText: item.statusText,
      subtitle: item.subtitle,
      icon: item.icon,
      accentColor: item.color,
      isAlert: item.isAlert,
      actionLabel: 'دخول للقسم',
      imageUrl: item.imageUrl,
      onTap: item.onTap,
    );
  }

  // --- Sections Data Builder ---
  List<_AdminSectionItem> _getSections(
    AdminProvider admin,
    int pendingOrdersCount,
    int pendingTopupsCount,
  ) {
    final totalPending = pendingOrdersCount + pendingTopupsCount;
    final onlineProviders = admin.providers
        .where((p) => p.status == 'online')
        .length;
    final activeBanners = admin.adminBanners.where((b) => b.isActive).length;
    final activeAccounts = admin.paymentAccounts
        .where((a) => a.isActive)
        .length;
    final unusedCodes = admin.shippingCodes.where((c) => !c.isUsed).length;

    return [
      // 1. Apps & Products (Merged)
      _AdminSectionItem(
        title: 'التطبيقات والمنتجات',
        subtitle: 'إدارة الخدمات، الباقات والأسعار وتحديد هوامش الربح',
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF0EA5E9), // Cyan / Sky Blue
        category: 'catalog',
        statusText:
            '${admin.adminApps.length} تطبيق • ${admin.adminProducts.length} باقة',
        imageUrl: 'assets/sections/apps_products.jpg',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AppsAndProductsManagementScreen(),
            ),
          );
        },
      ),

      // 2. Providers Management
      _AdminSectionItem(
        title: 'إدارة المزودين',
        subtitle: 'فحص الاتصال والربط المباشر وجلب المنتجات التلقائي',
        icon: Icons.hub_rounded,
        color: const Color(0xFF6366F1), // Electric Indigo
        category: 'catalog',
        statusText: '${admin.providers.length} مزود ($onlineProviders متصل)',
        statusColor: onlineProviders > 0 ? AppColors.tertiary : null,
        imageUrl: 'assets/sections/providers.jpg',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ProvidersManagementScreen(),
            ),
          );
        },
      ),

      // 3. Billboard & Ads
      _AdminSectionItem(
        title: 'لوحة الإعلانات',
        subtitle: 'إدارة البانرات والعروض الترويجية المتحركة للعملاء',
        icon: Icons.view_carousel_rounded,
        color: const Color(0xFFF59E0B), // Amber Gold
        category: 'catalog',
        statusText: '$activeBanners نشط / ${admin.adminBanners.length}',
        imageUrl: 'assets/sections/banners.jpg',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BannersManagementScreen()),
          );
        },
      ),

      // 4. Orders & Requests Review
      _AdminSectionItem(
        title: 'الطلبات والمراجعة',
        subtitle: 'مراجعة طلبات الشحن بالآيدي وتأكيد الإيداعات اليدوية',
        icon: Icons.fact_check_rounded,
        color: const Color(0xFFF43F5E), // Rose / Red
        category: 'finance',
        isAlert: totalPending > 0,
        statusText: totalPending > 0 ? '$totalPending معلق' : 'مكتمل ✅',
        statusColor: totalPending > 0 ? AppColors.error : AppColors.tertiary,
        imageUrl: 'assets/sections/orders.jpg',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OrdersManagementScreen()),
          );
        },
      ),

      // 5. Payment Accounts & Barcode
      _AdminSectionItem(
        title: 'حسابات الدفع',
        subtitle: 'شام كاش، بايننس Pay، باركودات الدفع والتحويل',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981), // Emerald
        category: 'finance',
        statusText: '$activeAccounts مفعل',
        statusColor: AppColors.tertiary,
        imageUrl: 'assets/sections/payments.jpg',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaymentAccountsScreen()),
          );
        },
      ),

      // 6. Shipping & Voucher Codes
      _AdminSectionItem(
        title: 'أكواد الشحن',
        subtitle: 'توليد وإدارة كروت الشحن الرقمية ومتابعة الاستهلاك',
        icon: Icons.confirmation_number_rounded,
        color: const Color(0xFF8B5CF6), // Purple
        category: 'finance',
        statusText: '$unusedCodes كود متاح',
        imageUrl: 'assets/sections/shipping_codes.jpg',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ShippingCodesScreen()),
          );
        },
      ),

      // 7. Manual Services & Supervisors
      _AdminSectionItem(
        title: 'الخدمات اليدوية والمشرفين',
        subtitle: 'متابعة الطلبات البشرية، المشرفين، مراقبة التأخير والاسترجاع',
        icon: Icons.assignment_ind_rounded,
        color: const Color(0xFF0D9488), // Teal
        category: 'catalog',
        statusText: '${admin.supervisors.length} مشرف • متابعة SLA',
        statusColor: AppColors.secondary,
        imageUrl: 'assets/sections/manual_services.jpg',
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
  final String subtitle;
  final IconData icon;
  final Color color;
  final String category;
  final String statusText;
  final Color? statusColor;
  final bool isAlert;
  final String imageUrl;
  final VoidCallback onTap;

  const _AdminSectionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.category,
    required this.statusText,
    this.statusColor,
    this.isAlert = false,
    required this.imageUrl,
    required this.onTap,
  });
}
