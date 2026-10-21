import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/agent_user_model.dart';
import '../../providers/agent_provider.dart';
import '../../providers/auth_provider.dart';
import '../user/user_main_screen.dart';
import '../auth/login_screen.dart';
import '../../widgets/unified_tactile_header.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });

    // Auto-refresh silently every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        Provider.of<AgentProvider>(context, listen: false).refreshAll(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    final provider = Provider.of<AgentProvider>(context, listen: false);
    provider.refreshAll();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            const SizedBox(width: 10),
            Text('تسجيل الخروج', style: AppTypography.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من لوحة الوكيل المعتمد؟',
          style: AppTypography.cairo(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('إلغاء', style: AppTypography.cairo(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await auth.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text('خروج', style: AppTypography.cairo(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agentProvider = Provider.of<AgentProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final stats = agentProvider.stats;
    final agentUser = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryBlue,
          onRefresh: () => agentProvider.refreshAll(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // 0. Unified Top Bar
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: UnifiedTactileHeader(isDashboard: true),
                ),
              ),

              // 1. Vault Header
              SliverToBoxAdapter(
                child: _buildVaultHeader(agentUser, stats),
              ),

              // 2. Metrics Bento Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildMetricsGrid(stats),
                ),
              ),

              // 3. Quick Action Bar (Add Client / Link Client)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _buildQuickActionBar(),
                ),
              ),

              // 4. Tab Bar (Sub-Users vs Transfers Log)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDim,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: AppColors.darkNav,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: AppTypography.cairo(fontWeight: FontWeight.w900, fontSize: 13),
                      unselectedLabelStyle: AppTypography.cairo(fontWeight: FontWeight.w700, fontSize: 13),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_alt_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text('العملاء التابعون (${stats.totalSubUsers})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.history_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text('سجل التحويلات (${stats.transferCount})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Dynamic Content (Tab 0: Sub-users with filters / Tab 1: Transfers log)
              SliverFillRemaining(
                hasScrollBody: true,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSubUsersTab(agentProvider),
                    _buildTransfersTab(agentProvider),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Top Vault Header ---
  Widget _buildVaultHeader(dynamic agentUser, AgentDashboardStats stats) {
    final balance = stats.agentBalance > 0 ? stats.agentBalance : (agentUser?.balance ?? 0.0);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkNav,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkNav.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Agent Profile & Controls
          Row(
            children: [
              // Avatar with Agent Storefront Emblem
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            agentUser?.name ?? 'الوكيل المعتمد',
                            style: AppTypography.cairo(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            'وكيل معتمد',
                            style: AppTypography.cairo(
                              color: AppColors.accentGreen,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'TKT #${agentUser?.displayId ?? "AGENT"}',
                          style: AppTypography.technicalCode(
                            color: AppColors.ticketAmber,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          agentUser?.email ?? '',
                          style: AppTypography.cairo(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Switch to Client View button
              InkWell(
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const UserMainScreen()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 14, color: AppColors.ticketAmber),
                      const SizedBox(width: 4),
                      Text(
                        'واجهة العميل',
                        style: AppTypography.cairo(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 2),
              // Refresh Icon Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                tooltip: 'تحديث البيانات',
                onPressed: _loadData,
              ),
              // Logout Icon Button
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171), size: 20),
                tooltip: 'تسجيل الخروج',
                onPressed: _showLogoutDialog,
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Bottom Row: Balance Display & Quick Fund
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.accentGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'رصيد محفظة الوكيل المتاح للتحويل',
                        style: AppTypography.cairo(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${balance.toStringAsFixed(2)}',
                        style: AppTypography.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'USDT',
                        style: AppTypography.technicalCode(
                          color: AppColors.ticketAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Quick Info Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.ticketAmber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'تحويل فوري 0.0s',
                      style: AppTypography.cairo(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
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

  // --- Metrics Bento Grid (4 Cards) ---
  Widget _buildMetricsGrid(AgentDashboardStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                title: 'إجمالي العملاء',
                value: '${stats.totalSubUsers}',
                subtitle: 'عميل تابع لك',
                icon: Icons.groups_rounded,
                accentColor: AppColors.primaryBlue,
                bgColor: const Color(0xFFF0F9FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBentoCard(
                title: 'عملاء نشطين',
                value: '${stats.activeSubUsers}',
                subtitle: 'حسابات مصرحة',
                icon: Icons.check_circle_rounded,
                accentColor: AppColors.accentGreen,
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                title: 'موقوف (احتيال / نصب)',
                value: '${stats.suspendedSubUsers}',
                subtitle: 'تجميد لمنع النصب',
                icon: Icons.gpp_bad_rounded,
                accentColor: AppColors.error,
                bgColor: const Color(0xFFFEF2F2),
                isAlert: stats.suspendedSubUsers > 0,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBentoCard(
                title: 'إجمالي المحول',
                value: '\$${stats.totalTransferred.toStringAsFixed(1)}',
                subtitle: '${stats.transferCount} عملية تحويل',
                icon: Icons.payments_rounded,
                accentColor: AppColors.ticketAmber,
                bgColor: const Color(0xFFFFFBEB),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert ? AppColors.error.withValues(alpha: 0.5) : AppColors.outline,
          width: isAlert ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isAlert ? AppColors.error : AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: isAlert ? AppColors.error : AppColors.darkNav,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.cairo(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Quick Action Bar ---
  Widget _buildQuickActionBar() {
    return Row(
      children: [
        // Button 1: Create New Sub-User
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: Text(
              'إنشاء عميل جديد',
              style: AppTypography.cairo(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
            onPressed: _showCreateUserModal,
          ),
        ),
        const SizedBox(width: 10),

        // Button 2: Link Existing User
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.darkNav,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.outline),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.link_rounded, size: 18, color: AppColors.primaryBlue),
            label: Text(
              'ربط عميل قائم',
              style: AppTypography.cairo(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
            onPressed: _showLinkUserModal,
          ),
        ),
      ],
    );
  }

  // --- Sub-Users Tab ---
  Widget _buildSubUsersTab(AgentProvider provider) {
    final subUsers = provider.filteredSubUsers;

    return Column(
      children: [
        // Search & Filters Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              // Search Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                child: TextField(
                  controller: _searchController,
                  style: AppTypography.cairo(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم، الآيدي (chx...)، الهاتف، أو البريد...',
                    hintStyle: AppTypography.cairo(fontSize: 12, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (val) {
                    provider.setSearchQuery(val);
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips
              Row(
                children: [
                  _buildFilterChip('all', 'الكل (${provider.subUsers.length})', provider),
                  const SizedBox(width: 8),
                  _buildFilterChip('active', 'نشط (${provider.stats.activeSubUsers})', provider, activeColor: AppColors.accentGreen),
                  const SizedBox(width: 8),
                  _buildFilterChip('suspended', 'موقوف (احتيال) (${provider.stats.suspendedSubUsers})', provider, activeColor: AppColors.error),
                ],
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: provider.isLoading && provider.subUsers.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
              : subUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search_rounded, size: 52, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'لا يوجد عملاء مطابقين',
                            style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'استخدم زر "إنشاء عميل جديد" أو "ربط عميل قائم" لإضافة عملاء تابعين لك',
                            style: AppTypography.cairo(fontSize: 11, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      physics: const BouncingScrollPhysics(),
                      itemCount: subUsers.length,
                      itemBuilder: (context, index) {
                        return _buildUserTicketCard(subUsers[index], provider);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, AgentProvider provider, {Color? activeColor}) {
    final isSelected = provider.activeFilter == key;
    final color = activeColor ?? AppColors.primaryBlue;

    return InkWell(
      onTap: () => provider.setFilter(key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.cairo(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // --- Sub-User Ticket Card ---
  Widget _buildUserTicketCard(AgentUserModel client, AgentProvider provider) {
    final isSuspended = client.isSuspendedByAgent;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSuspended ? AppColors.error.withValues(alpha: 0.6) : AppColors.outline,
          width: isSuspended ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSuspended ? AppColors.error.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Upper Ticket Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar, Name, Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSuspended ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          isSuspended ? Icons.person_off_rounded : Icons.person_rounded,
                          color: isSuspended ? AppColors.error : AppColors.primaryBlue,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Name & Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  client.name,
                                  style: AppTypography.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: client.displayId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تم نسخ الآيدي: ${client.displayId}', style: AppTypography.cairo(color: Colors.white)),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceDim,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: AppColors.outline),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        client.displayId,
                                        style: AppTypography.technicalCode(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.darkNav,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.copy_rounded, size: 10, color: AppColors.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                              if (client.phone != null && client.phone!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  client.phone!,
                                  style: AppTypography.cairo(
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Balance Capsule
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'رصيد العميل',
                          style: AppTypography.cairo(fontSize: 10, color: AppColors.textSecondary),
                        ),
                        Text(
                          '\$${client.balance.toStringAsFixed(2)}',
                          style: AppTypography.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isSuspended ? AppColors.error : AppColors.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Scam Alert Banner if Suspended
                if (isSuspended) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حساب مجمد بقرار الوكيل (احتيال / عدم سداد)',
                                style: AppTypography.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.error,
                                ),
                              ),
                              if (client.agentDeactivationReason != null && client.agentDeactivationReason!.isNotEmpty)
                                Text(
                                  'السبب: ${client.agentDeactivationReason}',
                                  style: AppTypography.cairo(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF991B1B),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Perforated Dashed Divider
          _buildPerforatedDivider(),

          // Bottom Action Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Transfer Balance Button (⚡ تحويل رصيد)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSuspended ? AppColors.surfaceDim : AppColors.accentGreen,
                      foregroundColor: isSuspended ? AppColors.textSecondary : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(
                      'تحويل رصيد',
                      style: AppTypography.cairo(fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    onPressed: () => _showTransferModal(client),
                  ),
                ),
                const SizedBox(width: 8),

                // Scam Freeze / Reactivate Button
                if (!isSuspended)
                  // Suspend Button (🛑 إيقاف الحساب - حماية من النصب)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE2E2),
                      foregroundColor: AppColors.error,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                    ),
                    icon: const Icon(Icons.block_rounded, size: 16, color: AppColors.error),
                    label: Text(
                      'إيقاف (نصب)',
                      style: AppTypography.cairo(fontSize: 11.5, fontWeight: FontWeight.w900),
                    ),
                    onPressed: () => _showScamFreezeModal(client),
                  )
                else
                  // Reactivate Button (🔄 تفعيل الحساب)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD1FAE5),
                      foregroundColor: AppColors.accentGreen,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppColors.accentGreen.withValues(alpha: 0.3)),
                      ),
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 16, color: AppColors.accentGreen),
                    label: Text(
                      'إلغاء التجميد والتفعيل',
                      style: AppTypography.cairo(fontSize: 11.5, fontWeight: FontWeight.w900),
                    ),
                    onPressed: () => _showReactivateModal(client),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerforatedDivider() {
    return SizedBox(
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dashed Line
          LayoutBuilder(
            builder: (context, constraints) {
              final boxWidth = constraints.constrainWidth();
              const dashWidth = 5.0;
              const dashSpace = 4.0;
              final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
              return Flex(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                direction: Axis.horizontal,
                children: List.generate(dashCount, (_) {
                  return const SizedBox(
                    width: dashWidth,
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.outline),
                    ),
                  );
                }),
              );
            },
          ),
          // Left Notch
          Positioned(
            left: -9,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Right Notch
          Positioned(
            right: -9,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Transfers History Tab ---
  Widget _buildTransfersTab(AgentProvider provider) {
    final transfers = provider.transfers;

    if (transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'لا يوجد سجل تحويلات حتى الآن',
              style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'جميع عمليات تحويل الرصيد لعملائك ستظهر هنا بتفاصيلها',
              style: AppTypography.cairo(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final t = transfers[index];
        final formattedDate = t.createdAt != null
            ? DateFormat('yyyy-MM-dd • hh:mm a').format(t.createdAt!)
            : 'الآن';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_outward_rounded, color: AppColors.ticketAmber, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.recipientName.isNotEmpty ? t.recipientName : 'عميل تابع',
                      style: AppTypography.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (t.recipientUserId.isNotEmpty) ...[
                          Text(
                            t.recipientUserId,
                            style: AppTypography.technicalCode(fontSize: 9.5, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          formattedDate,
                          style: AppTypography.cairo(fontSize: 9.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    if (t.note != null && t.note!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'ملاحظة: ${t.note}',
                        style: AppTypography.cairo(fontSize: 10, color: AppColors.primaryBlue),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '-\$${t.amount.toStringAsFixed(2)}',
                    style: AppTypography.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkNav,
                    ),
                  ),
                  Text(
                    'تم التحويل بنجاح',
                    style: AppTypography.cairo(fontSize: 9, color: AppColors.accentGreen, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // MODALS & DIALOGS
  // ===========================================================================

  // 1. Transfer Balance Modal
  void _showTransferModal(AgentUserModel client) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final agentProvider = Provider.of<AgentProvider>(context, listen: false);
    final agentBalance = agentProvider.stats.agentBalance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        double currentInput = 0.0;
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: AppColors.accentGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تحويل رصيد فوري للعميل',
                              style: AppTypography.cairo(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'المستلم: ${client.name} (${client.displayId})',
                              style: AppTypography.cairo(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Balances Preview Bento
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDim,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('رصيدك المتاح', style: AppTypography.cairo(fontSize: 10, color: AppColors.textSecondary)),
                            Text(
                              '\$${agentBalance.toStringAsFixed(2)}',
                              style: AppTypography.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondary, size: 16),
                        Column(
                          children: [
                            Text('رصيد العميل الحالي', style: AppTypography.cairo(fontSize: 10, color: AppColors.textSecondary)),
                            Text(
                              '\$${client.balance.toStringAsFixed(2)}',
                              style: AppTypography.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.accentGreen),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Amount Chips
                  Wrap(
                    spacing: 8,
                    children: [5, 10, 25, 50, 100].map((amt) {
                      return ChoiceChip(
                        label: Text('\$$amt', style: AppTypography.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12)),
                        selected: currentInput == amt.toDouble(),
                        onSelected: (selected) {
                          setModalState(() {
                            currentInput = amt.toDouble();
                            amountController.text = amt.toString();
                          });
                        },
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(color: currentInput == amt.toDouble() ? Colors.white : AppColors.darkNav),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Amount Input Field
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTypography.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      labelText: 'المبلغ المراد تحويله (USDT)',
                      labelStyle: AppTypography.cairo(fontSize: 12),
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceDim,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        currentInput = double.tryParse(val) ?? 0.0;
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Note Field
                  TextField(
                    controller: noteController,
                    style: AppTypography.cairo(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'ملاحظة أو بيان التحويل (اختياري)',
                      labelStyle: AppTypography.cairo(fontSize: 12),
                      prefixIcon: const Icon(Icons.note_alt_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceDim,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Execute Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('الرجاء إدخال مبلغ صحيح أكبر من صفر', style: AppTypography.cairo(color: Colors.white))),
                        );
                        return;
                      }

                      if (amount > agentBalance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('رصيدك غير كافٍ لإتمام التحويل (\$${agentBalance.toStringAsFixed(2)})', style: AppTypography.cairo(color: Colors.white)), backgroundColor: AppColors.error),
                        );
                        return;
                      }

                      Navigator.of(ctx).pop();

                      final res = await agentProvider.transferBalance(
                        userId: client.userId ?? client.id,
                        amount: amount,
                        note: noteController.text,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? '', style: AppTypography.cairo(color: Colors.white)),
                            backgroundColor: res['success'] == true ? AppColors.accentGreen : AppColors.error,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'تأكيد تحويل \$${currentInput.toStringAsFixed(2)} فوراً',
                      style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 2. Scam Freeze Modal (إيقاف وتجميد الحساب في حال النصب)
  void _showScamFreezeModal(AgentUserModel client) {
    final reasonController = TextEditingController(text: 'احتيال ونصب مالي وعدم سداد المستحقات');
    final agentProvider = Provider.of<AgentProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Danger Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.gpp_bad_rounded, color: AppColors.error, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تجميد حساب العميل لمنع الاحتيال',
                              style: AppTypography.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.error,
                              ),
                            ),
                            Text(
                              'العميل: ${client.name} (${client.displayId})',
                              style: AppTypography.cairo(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Explanatory Scam Warning Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.ticketAmber.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: AppColors.secondaryBright, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'تستخدم هذه الميزة في حال العميل نصب على الوكيل:',
                              style: AppTypography.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• سيتم طرد العميل فوراً وإلغاء صلاحية تسجيل دخوله وقطع جلسته.\n• لن يتمكن من إجراء أي طلبات أو سحب أو استهلاك الرصيد.\n• عند محاولته الدخول، ستظهر له رسالة توضح تجميده بسبب عدم سداد مستحقات الوكيل.',
                          style: AppTypography.cairo(
                            fontSize: 10.5,
                            color: AppColors.slate700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Preset Reasons Chips
                  Text(
                    'اختر أو اكتب سبب الإيقاف:',
                    style: AppTypography.cairo(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      'احتيال ونصب مالي وعدم سداد المستحقات',
                      'عدم سداد قيمة شحنة رصيد معلقة',
                      'مطالبة مالية متنازع عليها مع الوكيل',
                      'مخالفة اتفاقية التعامل التجاري',
                    ].map((reason) {
                      final isSelected = reasonController.text == reason;
                      return ChoiceChip(
                        label: Text(
                          reason,
                          style: AppTypography.cairo(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.error,
                        backgroundColor: AppColors.surfaceDim,
                        onSelected: (selected) {
                          setModalState(() {
                            reasonController.text = reason;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Custom Reason Input
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    style: AppTypography.cairo(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'اكتب تفاصيل إضافية عن سبب التجميد...',
                      hintStyle: AppTypography.cairo(fontSize: 11, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceDim,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Confirm Freeze
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.block_rounded, size: 18),
                    label: Text(
                      'تجميد حساب العميل فوراً ⛔',
                      style: AppTypography.cairo(fontSize: 13.5, fontWeight: FontWeight.w900),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final res = await agentProvider.toggleUserStatus(
                        userId: client.userId ?? client.id,
                        isActive: false,
                        reason: reasonController.text.trim(),
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? '', style: AppTypography.cairo(color: Colors.white)),
                            backgroundColor: res['success'] == true ? AppColors.error : AppColors.textPrimary,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 3. Reactivate Sub-User Modal
  void _showReactivateModal(AgentUserModel client) {
    final agentProvider = Provider.of<AgentProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: AppColors.accentGreen, size: 22),
            const SizedBox(width: 10),
            Text('إلغاء التجميد وإعادة التفعيل', style: AppTypography.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من تسوية الخلاف وإلغاء تجميد حساب العميل "${client.name}"؟',
              style: AppTypography.cairo(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتمكن العميل مجدداً من تسجيل الدخول إلى حسابه واستخدام رصيده لتنفيذ طلبات الشحن.',
              style: AppTypography.cairo(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('إلغاء', style: AppTypography.cairo(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final res = await agentProvider.toggleUserStatus(
                userId: client.userId ?? client.id,
                isActive: true,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? '', style: AppTypography.cairo(color: Colors.white)),
                    backgroundColor: AppColors.accentGreen,
                  ),
                );
              }
            },
            child: Text('إعادة التفعيل الآن', style: AppTypography.cairo(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // 4. Create New Sub-User Modal
  void _showCreateUserModal() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final initBalCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final agentProvider = Provider.of<AgentProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryBlue, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تسجيل مستخدم تابع للوكيل', style: AppTypography.cairo(fontSize: 16, fontWeight: FontWeight.w900)),
                        Text('سيتم ربطه بحسابك وتوليد آيدي خاص به فوراً', style: AppTypography.cairo(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم العميل الكامل',
                    prefixIcon: const Icon(Icons.badge_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceDim,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني للعميل',
                    prefixIcon: const Icon(Icons.email_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceDim,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'كلمة مرور الحساب (6 خانات على الأقل)',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceDim,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                    prefixIcon: const Icon(Icons.phone_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceDim,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: initBalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'رصيد ابتدائي يُخصم من محفظتك (اختياري)',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceDim,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 18),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('الرجاء تعبئة الاسم والبريد وكلمة المرور', style: AppTypography.cairo(color: Colors.white))),
                      );
                      return;
                    }

                    Navigator.of(ctx).pop();
                    final res = await agentProvider.createUserUnderAgent(
                      name: nameCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      password: passCtrl.text,
                      phone: phoneCtrl.text.trim(),
                      initialBalance: double.tryParse(initBalCtrl.text),
                      notes: notesCtrl.text.trim(),
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res['message'] ?? '', style: AppTypography.cairo(color: Colors.white)),
                          backgroundColor: res['success'] == true ? AppColors.accentGreen : AppColors.error,
                        ),
                      );
                    }
                  },
                  child: Text('إنشاء الحساب وربطه بالوكيل', style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 5. Link Existing User Modal
  void _showLinkUserModal() {
    final identifierCtrl = TextEditingController();
    final agentProvider = Provider.of<AgentProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
        title: Row(
          children: [
            const Icon(Icons.link_rounded, color: AppColors.primaryBlue, size: 24),
            const SizedBox(width: 10),
            Text('ربط عميل قائم بحسابك', style: AppTypography.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أدخل آيدي العميل (مثل chx26101571944) أو بريده الإلكتروني لربطه ليصبح تحت إدارتك:',
              style: AppTypography.cairo(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: identifierCtrl,
              decoration: InputDecoration(
                hintText: 'chx... أو example@gmail.com',
                prefixIcon: const Icon(Icons.person_pin_rounded),
                filled: true,
                fillColor: AppColors.surfaceDim,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('إلغاء', style: AppTypography.cairo(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              final id = identifierCtrl.text.trim();
              if (id.isEmpty) return;

              Navigator.of(ctx).pop();
              final res = await agentProvider.linkUserToAgent(id);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? '', style: AppTypography.cairo(color: Colors.white)),
                    backgroundColor: res['success'] == true ? AppColors.accentGreen : AppColors.error,
                  ),
                );
              }
            },
            child: Text('ربط العميل', style: AppTypography.cairo(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
