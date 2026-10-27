import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/agent_user_model.dart';
import '../../models/user_model.dart';
import '../../providers/agent_provider.dart';
import '../../providers/auth_provider.dart';
import '../user/user_main_screen.dart';
import '../../widgets/unified_tactile_header.dart';
import '../../widgets/digital_pass_card.dart';
import '../../widgets/floating_role_dashboard_shield.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen>
    with SingleTickerProviderStateMixin {
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
        Provider.of<AgentProvider>(
          context,
          listen: false,
        ).refreshAll(silent: true);
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

  @override
  Widget build(BuildContext context) {
    final agentProvider = Provider.of<AgentProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final stats = agentProvider.stats;
    final agentUser = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.primaryBlue,
              onRefresh: () => agentProvider.refreshAll(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // 0. Unified Top Bar
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: UnifiedTactileHeader(isDashboard: true),
                    ),
                  ),

                  // 1. شريط الهوية المضغوط (بديل الكرت العلوي)
                  SliverToBoxAdapter(child: _identityStrip(agentUser)),

                  // 2. جدول ملخص العمليات (مضغوط + هوية تذكرة)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _opsSummaryTable(stats, agentUser),
                    ),
                  ),

                  // 3. أزرار الإجراءات السريعة
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildQuickActionBar(),
                    ),
                  ),

                  // 4. التبويبات (العملاء / سجل التحويلات)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDim,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(11),
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
                          labelStyle: AppTypography.cairo(
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                          unselectedLabelStyle: AppTypography.cairo(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          tabs: [
                            Tab(
                              height: 38,
                              child: _tabLabel(
                                Icons.people_alt_rounded,
                                'العملاء (${stats.totalSubUsers})',
                              ),
                            ),
                            Tab(
                              height: 38,
                              child: _tabLabel(
                                Icons.swap_vert_rounded,
                                'التحويلات (${agentProvider.transfers.length})',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 5. المحتوى (العملاء / سجل التحويلات)
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

  // --- شريط الهوية المضغوط (بديل الكرت العلوي) ---
  Widget _identityStrip(UserModel? agentUser) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          _iconChip(AppColors.primaryBlue, Icons.storefront_rounded, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        agentUser?.name ?? 'الوكيل المعتمد',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _pill(
                        'وكيل معتمد',
                        AppColors.accentGreen,
                        dot: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'TKT #${agentUser?.displayId ?? 'AGENT'}',
                      maxLines: 1,
                      style: AppTypography.technicalCode(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryBright,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        agentUser?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 9.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadData,
            tooltip: 'تحديث البيانات',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- جدول ملخص العمليات (مصغّر + هوية تذكرة) ---
  Widget _opsSummaryTable(AgentDashboardStats stats, UserModel? agentUser) {
    final double balance = stats.agentBalance > 0
        ? stats.agentBalance
        : (agentUser?.balance ?? 0.0);

    return _ticketShell(
      radius: 16,
      notch: 8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            child: Row(
              children: [
                _iconChip(
                  AppColors.primaryBlue,
                  Icons.insights_rounded,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'ملخص العمليات',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'OPS SUMMARY',
                  maxLines: 1,
                  style: AppTypography.technicalCode(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          _dashedRule(),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _summaryCell(
                    'رصيد الوكيل',
                    '\$${balance.toStringAsFixed(2)}',
                    Icons.account_balance_wallet_rounded,
                    AppColors.primaryBlue,
                  ),
                ),
                _summaryDivider(),
                Expanded(
                  child: _summaryCell(
                    'مستلم من الإدارة',
                    '\$${stats.totalReceived.toStringAsFixed(2)}',
                    Icons.call_received_rounded,
                    AppColors.accentGreen,
                  ),
                ),
                _summaryDivider(),
                Expanded(
                  child: _summaryCell(
                    'محوّل للعملاء',
                    '\$${stats.totalTransferred.toStringAsFixed(2)}',
                    Icons.call_made_rounded,
                    AppColors.ticketAmber,
                  ),
                ),
              ],
            ),
          ),
          _dashedRule(),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _summaryCell(
                    'العملاء',
                    '${stats.totalSubUsers}',
                    Icons.groups_rounded,
                    AppColors.primaryBlue,
                  ),
                ),
                _summaryDivider(),
                Expanded(
                  child: _summaryCell(
                    'نشط',
                    '${stats.activeSubUsers}',
                    Icons.check_circle_rounded,
                    AppColors.accentGreen,
                  ),
                ),
                _summaryDivider(),
                Expanded(
                  child: _summaryCell(
                    'موقوف',
                    '${stats.suspendedSubUsers}',
                    Icons.gpp_bad_rounded,
                    AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return SizedBox(
      width: 1,
      child: CustomPaint(
        painter: VerticalDashedLinePainter(
          color: AppColors.outline,
          dashHeight: 4,
          dashSpace: 4,
        ),
      ),
    );
  }

  Widget _tabLabel(IconData icon, String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // --- أساسيات هوية التذكرة ---
  Widget _ticketShell({
    required Widget child,
    double radius = 16,
    double notch = 8,
    double elevation = 6,
    Color? borderColor,
  }) {
    return CustomPaint(
      painter: TicketPassShadowPainter(
        cornerRadius: radius,
        notchRadius: notch,
        notchPositionFraction: 0.5,
        shadowColor: AppColors.slate900,
        elevation: elevation,
      ),
      foregroundPainter: TicketPassBorderPainter(
        cornerRadius: radius,
        notchRadius: notch,
        notchPositionFraction: 0.5,
        borderColor: borderColor ?? AppColors.outline,
        borderWidth: 1,
      ),
      child: ClipPath(
        clipper: TicketPassClipper(
          cornerRadius: radius,
          notchRadius: notch,
          notchPositionFraction: 0.5,
        ),
        child: Material(color: AppColors.surfaceCard, child: child),
      ),
    );
  }

  Widget _dashedRule({Color color = AppColors.outline, double gap = 0}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: gap),
      child: SizedBox(
        height: 1,
        child: CustomPaint(
          painter: DashedLinePainter(color: color, dashWidth: 4, dashSpace: 4),
        ),
      ),
    );
  }

  Widget _iconChip(Color color, IconData icon, {double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.lerp(color, Colors.white, 0.28)!, color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.26),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }

  Widget _pill(String label, Color color, {bool dot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- تذكرة تحويل (وارد من الإدارة / صادر إلى عميل) ---
  Widget _transferTicket(AgentTransferRecord transfer) {
    final bool incoming = transfer.isIncoming;
    final Color accent = incoming
        ? AppColors.accentGreen
        : AppColors.ticketAmber;
    final String date = transfer.createdAt != null
        ? DateFormat('yyyy-MM-dd • hh:mm a').format(transfer.createdAt!)
        : 'الآن';
    // هوية العميل التابع: اسمًا وآيديًا من المستقبلين أو من تفاصيل الوصف
    final String titleLine = incoming
        ? transfer.counterpartyName
        : (transfer.resolvedRecipientName.isNotEmpty
              ? transfer.resolvedRecipientName
              : 'عميل تابع');
    final String idLine = incoming
        ? 'من الإدارة'
        : (transfer.resolvedRecipientId.isNotEmpty
              ? transfer.resolvedRecipientId
              : 'بدون معرّف');

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: _ticketShell(
        radius: 14,
        notch: 7,
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          child: Row(
            children: [
              _iconChip(
                accent,
                incoming
                    ? Icons.call_received_rounded
                    : Icons.call_made_rounded,
                size: 30,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            idLine.isEmpty ? '—' : idLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.technicalCode(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          '•',
                          style: TextStyle(
                            fontSize: 8,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 8.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (transfer.note != null &&
                        transfer.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'ملاحظة: ${transfer.note!.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${incoming ? '+' : '-'}\$${transfer.amount.toStringAsFixed(2)}',
                        maxLines: 1,
                        style: AppTypography.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: incoming
                              ? AppColors.accentGreen
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        incoming ? 'IN // إدارة' : 'OUT // عميل',
                        maxLines: 1,
                        style: AppTypography.technicalCode(
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transferFilterChip(
    String key,
    String label,
    AgentProvider provider,
    Color color,
  ) {
    final bool isSelected = provider.transferFilter == key;

    return InkWell(
      onTap: () => provider.setTransferFilter(key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : AppColors.outline),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: AppTypography.cairo(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _emptyTransfers(AgentProvider provider) {
    final bool filtered = provider.transferFilter != 'all';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _iconChip(
              filtered ? AppColors.textMuted : AppColors.primaryBlue,
              filtered ? Icons.filter_alt_off_rounded : Icons.swap_vert_rounded,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              filtered
                  ? 'لا توجد تحويلات بهذا الاتجاه'
                  : 'لا يوجد سجل تحويلات حتى الآن',
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              filtered
                  ? 'جرّب «الكل» لعرض الوارد والصادر معاً'
                  : 'سيظهر هنا ما تستلمه من الإدارة وما تحوّله إلى عملائك',
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
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
              padding: const EdgeInsets.symmetric(vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.person_add_rounded, size: 17),
            label: Text(
              'إنشاء عميل جديد',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
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
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(
              Icons.link_rounded,
              size: 17,
              color: AppColors.primaryBlue,
            ),
            label: Text(
              'ربط عميل قائم',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
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
                    hintText:
                        'ابحث بالاسم، الآيدي (JGO...)، الهاتف، أو البريد...',
                    hintStyle: AppTypography.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (val) {
                    provider.setSearchQuery(val);
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      'all',
                      'الكل (${provider.subUsers.length})',
                      provider,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'active',
                      'نشط (${provider.stats.activeSubUsers})',
                      provider,
                      activeColor: AppColors.accentGreen,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'suspended',
                      'موقوف (احتيال) (${provider.stats.suspendedSubUsers})',
                      provider,
                      activeColor: AppColors.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: provider.isLoading && provider.subUsers.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryBlue,
                  ),
                )
              : subUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search_rounded,
                        size: 52,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لا يوجد عملاء مطابقين',
                        style: AppTypography.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'استخدم زر "إنشاء عميل جديد" أو "ربط عميل قائم" لإضافة عملاء تابعين لك',
                        style: AppTypography.cairo(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
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
                    return _buildUserTicketCard(subUsers[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    String key,
    String label,
    AgentProvider provider, {
    Color? activeColor,
  }) {
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
          border: Border.all(color: isSelected ? color : AppColors.outline),
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

  // --- تذكرة العميل المضغوطة (قائمة العملاء) ---
  Widget _buildUserTicketCard(AgentUserModel client) {
    final isSuspended = client.isSuspendedByAgent;
    final Color accent = isSuspended ? AppColors.error : AppColors.primaryBlue;
    final String contact =
        (client.phone != null && client.phone!.trim().isNotEmpty)
        ? client.phone!.trim()
        : client.email;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: _ticketShell(
        radius: 14,
        notch: 7,
        elevation: 5,
        borderColor: isSuspended
            ? AppColors.error.withValues(alpha: 0.45)
            : null,
        child: Column(
          children: [
            // جسم التذكرة: الهوية + الرصيد
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
              child: Row(
                children: [
                  _iconChip(
                    accent,
                    isSuspended
                        ? Icons.person_off_rounded
                        : Icons.person_rounded,
                    size: 30,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // الاسم يأخذ كامل عرض التذكرة: شارة الحالة نُقلت للكعب
                        // حتى لا تقتطع من بقية الاسم الطويل.
                        Text(
                          client.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(child: _clientIdChip(client)),
                            const SizedBox(width: 5),
                            const Text(
                              '•',
                              style: TextStyle(
                                fontSize: 8,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                contact.isEmpty ? '—' : contact,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cairo(
                                  fontSize: 8.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // سطر تجميد واحد بدل لافتة كبيرة
                        if (isSuspended) ...[
                          const SizedBox(height: 3),
                          Text(
                            (client.agentDeactivationReason != null &&
                                    client.agentDeactivationReason!.isNotEmpty)
                                ? 'مجمّد: ${client.agentDeactivationReason!.trim()}'
                                : 'مجمّد بقرار الوكيل (احتيال / عدم سداد)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // عمود الرصيد بعرض أقصى ثابت ليأخذ الاسم كل بقية السطر
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${client.balance.toStringAsFixed(2)}',
                            maxLines: 1,
                            style: AppTypography.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: isSuspended
                                  ? AppColors.error
                                  : AppColors.accentGreen,
                            ),
                          ),
                          Text(
                            'CLIENT BALANCE',
                            maxLines: 1,
                            style: AppTypography.technicalCode(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _dashedRule(),
            // كعب التذكرة: شارة الحالة + التحويل السريع + قائمة الإجراءات
            // (زر «إيقاف» أُزيل من الكرت ليصير داخل قائمة ...)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
              child: Row(
                children: [
                  _pill(
                    isSuspended ? 'موقوف' : 'نشط',
                    isSuspended ? AppColors.error : AppColors.accentGreen,
                    dot: true,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSuspended
                            ? AppColors.surfaceDim
                            : AppColors.accentGreen,
                        foregroundColor: isSuspended
                            ? AppColors.textSecondary
                            : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 14),
                      label: Text(
                        'تحويل رصيد',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onPressed: () => _showTransferModal(client),
                    ),
                  ),
                  _clientMenu(client, isSuspended),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// آيدي العميل داخل التذكرة: لمسة واحدة تنسخه
  Widget _clientIdChip(AgentUserModel client) {
    return InkWell(
      onTap: () => _copyClientId(client),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                client.displayId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.technicalCode(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkNav,
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.copy_rounded,
              size: 9,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  /// نسخ آيدي العميل (من الشارة أو من قائمة الإجراءات)
  void _copyClientId(AgentUserModel client) {
    Clipboard.setData(ClipboardData(text: client.displayId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الآيدي: ${client.displayId}',
          style: AppTypography.cairo(color: Colors.white),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// قائمة إجراءات العميل: أزرار التجميد/التفعيل اختُزلت هنا
  /// بدل أن تزاحم الاسم والرصيد في كعب التذكرة.
  Widget _clientMenu(AgentUserModel client, bool isSuspended) {
    return PopupMenuButton<String>(
      tooltip: 'إجراءات العميل',
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      offset: const Offset(0, 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outline),
      ),
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: AppColors.textSecondary,
      ),
      onSelected: (value) {
        if (value == 'transfer') _showTransferModal(client);
        if (value == 'copy') _copyClientId(client);
        if (value == 'freeze') _showScamFreezeModal(client);
        if (value == 'reactivate') _showReactivateModal(client);
      },
      itemBuilder: (context) => [
        _menuItem(
          'transfer',
          Icons.bolt_rounded,
          AppColors.accentGreen,
          'تحويل رصيد',
        ),
        _menuItem(
          'copy',
          Icons.copy_rounded,
          AppColors.primaryBlue,
          'نسخ الآيدي',
        ),
        if (isSuspended)
          _menuItem(
            'reactivate',
            Icons.lock_open_rounded,
            AppColors.accentGreen,
            'إلغاء التجميد والتفعيل',
          )
        else
          _menuItem(
            'freeze',
            Icons.block_rounded,
            AppColors.error,
            'إيقاف الحساب ',
          ),
      ],
    );
  }

  PopupMenuEntry<String> _menuItem(
    String value,
    IconData icon,
    Color color,
    String label,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Transfers History Tab (وارد من الإدارة / صادر إلى العملاء) ---
  Widget _buildTransfersTab(AgentProvider provider) {
    final transfers = provider.filteredTransfers;
    final int total =
        provider.incomingTransferCount + provider.outgoingTransferCount;

    return Column(
      children: [
        // فلاتر اتجاه التحويل
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _transferFilterChip(
                  'all',
                  'الكل ($total)',
                  provider,
                  AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                _transferFilterChip(
                  'in',
                  'من الإدارة (${provider.incomingTransferCount})',
                  provider,
                  AppColors.accentGreen,
                ),
                const SizedBox(width: 8),
                _transferFilterChip(
                  'out',
                  'إلى العملاء (${provider.outgoingTransferCount})',
                  provider,
                  AppColors.ticketAmber,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: transfers.isEmpty
              ? _emptyTransfers(provider)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: transfers.length,
                  itemBuilder: (context, index) =>
                      _transferTicket(transfers[index]),
                ),
        ),
      ],
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
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: AppColors.accentGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تحويل رصيد فوري للعميل',
                              style: AppTypography.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'المستلم: ${client.name} (${client.displayId})',
                              style: AppTypography.cairo(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
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
                            Text(
                              'رصيدك المتاح',
                              style: AppTypography.cairo(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '\$${agentBalance.toStringAsFixed(2)}',
                              style: AppTypography.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                        Column(
                          children: [
                            Text(
                              'رصيد العميل الحالي',
                              style: AppTypography.cairo(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '\$${client.balance.toStringAsFixed(2)}',
                              style: AppTypography.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accentGreen,
                              ),
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
                        label: Text(
                          '\$$amt',
                          style: AppTypography.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        selected: currentInput == amt.toDouble(),
                        onSelected: (selected) {
                          setModalState(() {
                            currentInput = amt.toDouble();
                            amountController.text = amt.toString();
                          });
                        },
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(
                          color: currentInput == amt.toDouble()
                              ? Colors.white
                              : AppColors.darkNav,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Amount Input Field
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: AppTypography.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      labelText: 'المبلغ المراد تحويله (USDT)',
                      labelStyle: AppTypography.cairo(fontSize: 12),
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceDim,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Execute Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'الرجاء إدخال مبلغ صحيح أكبر من صفر',
                              style: AppTypography.cairo(color: Colors.white),
                            ),
                          ),
                        );
                        return;
                      }

                      if (amount > agentBalance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'رصيدك غير كافٍ لإتمام التحويل (\$${agentBalance.toStringAsFixed(2)})',
                              style: AppTypography.cairo(color: Colors.white),
                            ),
                            backgroundColor: AppColors.error,
                          ),
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
                            content: Text(
                              res['message'] ?? '',
                              style: AppTypography.cairo(color: Colors.white),
                            ),
                            backgroundColor: res['success'] == true
                                ? AppColors.accentGreen
                                : AppColors.error,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'تأكيد تحويل \$${currentInput.toStringAsFixed(2)} فوراً',
                      style: AppTypography.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
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

  // 2. Scam Freeze Modal (إيقاف وتجميد الحساب في حال )
  void _showScamFreezeModal(AgentUserModel client) {
    final reasonController = TextEditingController(
      text: 'احتيال  مالي وعدم سداد المستحقات',
    );
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
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.gpp_bad_rounded,
                          color: AppColors.error,
                          size: 28,
                        ),
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
                              style: AppTypography.cairo(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
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
                      border: Border.all(
                        color: AppColors.ticketAmber.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              color: AppColors.secondaryBright,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'تستخدم هذه الميزة في حال العميل احتال على الوكيل:',
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
                    style: AppTypography.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        [
                          'احتيال  مالي وعدم سداد المستحقات',
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
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
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
                      hintStyle: AppTypography.cairo(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceDim,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Confirm Freeze
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.block_rounded, size: 18),
                    label: Text(
                      'تجميد حساب العميل فوراً ⛔',
                      style: AppTypography.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
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
                            content: Text(
                              res['message'] ?? '',
                              style: AppTypography.cairo(color: Colors.white),
                            ),
                            backgroundColor: res['success'] == true
                                ? AppColors.error
                                : AppColors.textPrimary,
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
            const Icon(
              Icons.lock_open_rounded,
              color: AppColors.accentGreen,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'إلغاء التجميد وإعادة التفعيل',
              style: AppTypography.cairo(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من تسوية الخلاف وإلغاء تجميد حساب العميل "${client.name}"؟',
              style: AppTypography.cairo(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتمكن العميل مجدداً من تسجيل الدخول إلى حسابه واستخدام رصيده لتنفيذ طلبات الشحن.',
              style: AppTypography.cairo(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'إلغاء',
              style: AppTypography.cairo(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
                    content: Text(
                      res['message'] ?? '',
                      style: AppTypography.cairo(color: Colors.white),
                    ),
                    backgroundColor: AppColors.accentGreen,
                  ),
                );
              }
            },
            child: Text(
              'إعادة التفعيل الآن',
              style: AppTypography.cairo(fontWeight: FontWeight.w800),
            ),
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
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
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
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppColors.primaryBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تسجيل مستخدم تابع للوكيل',
                          style: AppTypography.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'سيتم ربطه بحسابك وتوليد آيدي خاص به فوراً',
                          style: AppTypography.cairo(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: initBalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'رصيد ابتدائي يُخصم من محفظتك (اختياري)',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceDim,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty ||
                        emailCtrl.text.trim().isEmpty ||
                        passCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'الرجاء تعبئة الاسم والبريد وكلمة المرور',
                            style: AppTypography.cairo(color: Colors.white),
                          ),
                        ),
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
                          content: Text(
                            res['message'] ?? '',
                            style: AppTypography.cairo(color: Colors.white),
                          ),
                          backgroundColor: res['success'] == true
                              ? AppColors.accentGreen
                              : AppColors.error,
                        ),
                      );
                    }
                  },
                  child: Text(
                    'إنشاء الحساب وربطه بالوكيل',
                    style: AppTypography.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
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
            const Icon(
              Icons.link_rounded,
              color: AppColors.primaryBlue,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'ربط عميل قائم بحسابك',
              style: AppTypography.cairo(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أدخل آيدي العميل (مثل JGO26101571944) أو بريده الإلكتروني لربطه ليصبح تحت إدارتك:',
              style: AppTypography.cairo(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: identifierCtrl,
              decoration: InputDecoration(
                hintText: 'JGO... أو example@gmail.com',
                prefixIcon: const Icon(Icons.person_pin_rounded),
                filled: true,
                fillColor: AppColors.surfaceDim,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'إلغاء',
              style: AppTypography.cairo(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
                    content: Text(
                      res['message'] ?? '',
                      style: AppTypography.cairo(color: Colors.white),
                    ),
                    backgroundColor: res['success'] == true
                        ? AppColors.accentGreen
                        : AppColors.error,
                  ),
                );
              }
            },
            child: Text(
              'ربط العميل',
              style: AppTypography.cairo(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
