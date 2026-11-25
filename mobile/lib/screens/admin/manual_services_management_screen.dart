import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/order_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/top_notice.dart';
import '../user/manual_order_details_screen.dart';
import 'users_management_screen.dart';

class ManualServicesManagementScreen extends StatefulWidget {
  const ManualServicesManagementScreen({super.key});

  @override
  State<ManualServicesManagementScreen> createState() =>
      _ManualServicesManagementScreenState();
}

class _ManualServicesManagementScreenState
    extends State<ManualServicesManagementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'all';
  String? _selectedSupervisorId;
  String _sortMode = 'priority'; // priority | newest | price

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    await Future.wait([
      admin.fetchManualOrders(),
      admin.fetchAllUsers(silent: true),
      admin.fetchProviderWalletAdminOverview(silent: true),
    ]);
  }

  /// قائمة كل المستخدمين القابلين للإسناد (عملاء + مشرفون + أدمن)
  List<Map<String, dynamic>> _assignableUsers(AdminProvider admin) =>
      admin.allUsers;

  /// المشرفون الحاليون فقط (للفلترة وعرض اسم المكلف)
  List<Map<String, dynamic>> _supervisorList(AdminProvider admin) => admin
      .allUsers
      .where(
        (u) => (u['role'] ?? 'user').toString().toLowerCase() == 'supervisor',
      )
      .toList();

  int _orderPriority(OrderModel o) {
    if (o.isDelayed && !o.isCompleted) return 0;
    if (o.isDisputed ||
        o.status == 'revision_requested' ||
        o.status == 'rejected') {
      return 1;
    }
    if (o.status == 'assigned' || o.status == 'pending') return 2;
    if (o.status == 'in_progress' || o.status == 'accepted') return 3;
    if (o.status == 'delivered' || o.status == 'info_requested') return 4;
    return 5;
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    final q = _searchCtrl.text.trim().toLowerCase();
    var result = orders;

    // Filter by supervisor if selected
    if (_selectedSupervisorId != null && _selectedSupervisorId != 'all') {
      result = result
          .where((o) => o.assignedSupervisorId == _selectedSupervisorId)
          .toList();
    }

    // Filter by search query
    if (q.isNotEmpty) {
      result = result
          .where(
            (o) =>
                '${o.orderNumber} ${o.productName} ${o.userName ?? ''} ${o.assignedSupervisorName ?? ''}'
                    .toLowerCase()
                    .contains(q),
          )
          .toList();
    }

    // Filter by status category
    if (_selectedFilter == 'new') {
      result = result
          .where((o) => o.status == 'assigned' || o.status == 'pending')
          .toList();
    } else if (_selectedFilter == 'in_progress') {
      result = result
          .where((o) => o.status == 'in_progress' || o.status == 'accepted')
          .toList();
    } else if (_selectedFilter == 'waiting_client') {
      result = result
          .where((o) => o.status == 'delivered' || o.status == 'info_requested')
          .toList();
    } else if (_selectedFilter == 'delayed') {
      result = result.where((o) => o.isDelayed && !o.isCompleted).toList();
    } else if (_selectedFilter == 'issues') {
      result = result
          .where(
            (o) =>
                o.status == 'disputed' ||
                o.status == 'revision_requested' ||
                o.status == 'rejected',
          )
          .toList();
    } else if (_selectedFilter == 'completed') {
      result = result.where((o) => o.status == 'completed').toList();
    } else if (_selectedFilter == 'refunded') {
      result = result.where((o) => o.status == 'refunded').toList();
    }

    final sorted = List<OrderModel>.from(result);
    if (_sortMode == 'priority') {
      sorted.sort((a, b) {
        final p = _orderPriority(a).compareTo(_orderPriority(b));
        if (p != 0) return p;
        return b.createdAt.compareTo(a.createdAt);
      });
    } else if (_sortMode == 'price') {
      sorted.sort((a, b) => b.amount.compareTo(a.amount));
    } else {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    final allOrders = admin.manualOrders;
    final filteredOrders = _filterOrders(allOrders);

    final delayedCount = allOrders
        .where((o) => o.isDelayed && !o.isCompleted)
        .length;
    final issuesCount = allOrders
        .where(
          (o) =>
              o.status == 'disputed' ||
              o.status == 'revision_requested' ||
              o.status == 'rejected',
        )
        .length;
    final inProgressCount = allOrders
        .where((o) => o.status == 'in_progress' || o.status == 'accepted')
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.outline),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.handyman_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'إدارة الخدمات اليدوية',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.manage_accounts_outlined,
              color: AppColors.primaryBlue,
            ),
            tooltip: 'إدارة المستخدمين',
            onPressed: () => _showSupervisorsManagementSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slate600),
            tooltip: 'تحديث',
            onPressed: admin.isLoading ? null : _loadData,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats / Metric Cards
              _buildMetricsRow(
                total: allOrders.length,
                inProgress: inProgressCount,
                delayed: delayedCount,
                issues: issuesCount,
              ),
              const SizedBox(height: 10),
              _buildProviderWalletAdminCard(admin),
              const SizedBox(height: 12),

              // Provider Wallet & Admin Profit Banner
              _buildProviderWalletAdminBanner(admin),
              const SizedBox(height: 12),

              // Search + Supervisor Filter
              _buildSearchAndSupervisorCard(_supervisorList(admin)),
              const SizedBox(height: 10),

              // Status Filter Chips
              _buildStatusFilterChips(),
              const SizedBox(height: 12),

              // Orders List Header + Sort Selector
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'الطلبات اليدوية',
                    style: AppTypography.cairo(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryBlue.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      '${filteredOrders.length}',
                      style: AppTypography.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (admin.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  _buildSortMenu(),
                ],
              ),
              const SizedBox(height: 12),

              if (admin.isLoading && allOrders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 50),
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  ),
                )
              else if (filteredOrders.isEmpty)
                _buildEmptyState()
              else
                _buildOrdersList(filteredOrders, _assignableUsers(admin)),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsRow({
    required int total,
    required int inProgress,
    required int delayed,
    required int issues,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.slate800),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              'إجمالي الطلبات',
              total.toString(),
              Icons.receipt_long_rounded,
              AppColors.primarySky,
              active: _selectedFilter == 'all',
              onTap: () => setState(() => _selectedFilter = 'all'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildMetricTile(
              'قيد التنفيذ',
              inProgress.toString(),
              Icons.hourglass_top_rounded,
              AppColors.ticketAmber,
              active: _selectedFilter == 'in_progress',
              onTap: () => setState(() => _selectedFilter = 'in_progress'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildMetricTile(
              'تأخير SLA',
              delayed.toString(),
              Icons.alarm_off_rounded,
              AppColors.roseHot,
              active: _selectedFilter == 'delayed',
              onTap: () => setState(() => _selectedFilter = 'delayed'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildMetricTile(
              'اعتراضات',
              issues.toString(),
              Icons.report_problem_rounded,
              AppColors.ticketAmber,
              active: _selectedFilter == 'issues',
              onTap: () => setState(() => _selectedFilter = 'issues'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    bool active = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    value,
                    style: AppTypography.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: AppTypography.cairo(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndSupervisorCard(List<Map<String, dynamic>> supervisors) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: AppTypography.cairo(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'ابحث برقم الطلب أو الخدمة أو العميل...',
              hintStyle: AppTypography.cairo(
                fontSize: 11.5,
                color: AppColors.slate400,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 17,
                color: AppColors.slate400,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 34,
                minHeight: 34,
              ),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 15),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    ),
              filled: true,
              fillColor: AppColors.slate50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildSupervisorFilter(supervisors),
        ],
      ),
    );
  }

  Widget _buildSortMenu() {
    final label = _sortMode == 'priority'
        ? 'الأهم أولاً'
        : (_sortMode == 'price' ? 'الأعلى سعراً' : 'الأحدث');
    return PopupMenuButton<String>(
      tooltip: 'ترتيب الطلبات',
      onSelected: (v) => setState(() => _sortMode = v),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outline),
      ),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'priority', child: Text('الأهم أولاً (تأخير/أولوية)')),
        PopupMenuItem(value: 'newest', child: Text('الأحدث أولاً')),
        PopupMenuItem(value: 'price', child: Text('الأعلى سعراً')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sort_rounded,
              size: 14,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.slate700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupervisorFilter(List<Map<String, dynamic>> supervisors) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(
              Icons.person_pin_rounded,
              size: 15,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedSupervisorId ?? 'all',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.slate500,
                  size: 20,
                ),
                style: AppTypography.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate900,
                ),
                dropdownColor: Colors.white,
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      'جميع المشرفين',
                      style: AppTypography.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  ...supervisors.map((s) {
                    final id = s['_id']?.toString() ?? '';
                    final name = s['name']?.toString() ?? 'مشرف';
                    final email = s['email']?.toString() ?? '';
                    return DropdownMenuItem(
                      value: id,
                      child: Text(
                        '$name ($email)',
                        style: AppTypography.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedSupervisorId = val;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    final filters = <Map<String, dynamic>>[
      {'key': 'all', 'label': 'الكل', 'color': AppColors.darkNav},
      {'key': 'new', 'label': 'جديدة ومسندة', 'color': AppColors.primaryBlue},
      {
        'key': 'in_progress',
        'label': 'قيد التنفيذ',
        'color': AppColors.secondaryBright,
      },
      {
        'key': 'waiting_client',
        'label': 'بانتظار العميل',
        'color': AppColors.primaryBright,
      },
      {'key': 'delayed', 'label': 'متأخرة', 'color': AppColors.rose},
      {
        'key': 'issues',
        'label': 'اعتراضات/رفض',
        'color': AppColors.rose,
      },
      {'key': 'completed', 'label': 'مكتملة', 'color': AppColors.accentGreen},
      {'key': 'refunded', 'label': 'مسترجعة', 'color': AppColors.slate500},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          final Color color = f['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
              label: Text(f['label'] as String),
              selected: isSelected,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onSelected: (val) {
                if (val) setState(() => _selectedFilter = f['key'] as String);
              },
              selectedColor: color,
              backgroundColor: Colors.white,
              labelStyle: AppTypography.cairo(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.slate600,
              ),
              side: BorderSide(
                color: isSelected ? color : AppColors.outline,
                width: isSelected ? 1.2 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- قائمة موحدة بدون فراغات بين الصفوف (تفصلها خطوط) ---
  Widget _buildOrdersList(
    List<OrderModel> orders,
    List<Map<String, dynamic>> users,
  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < orders.length; i++) ...[
            if (i != 0)
              const Divider(height: 1, thickness: 1, color: AppColors.outline),
            _buildOrderTile(orders[i], users),
          ],
        ],
      ),
    );
  }

  Color _statusColor(OrderModel order) {
    if (order.status == 'completed') return AppColors.accentGreen;
    if (order.status == 'refunded') return AppColors.slate500;
    if (order.isDisputed ||
        order.status == 'revision_requested' ||
        order.status == 'rejected') {
      return AppColors.rose;
    }
    if (order.isDelayed && !order.isCompleted) return AppColors.rose;
    if (order.status == 'in_progress' || order.status == 'accepted') {
      return AppColors.secondaryBright;
    }
    if (order.status == 'delivered' || order.status == 'info_requested') {
      return AppColors.primaryBright;
    }
    return AppColors.primaryBlue;
  }

  IconData _statusIcon(OrderModel order) {
    if (order.status == 'completed') return Icons.check_circle_rounded;
    if (order.status == 'refunded') return Icons.replay_rounded;
    if (order.isDisputed) return Icons.report_problem_rounded;
    if (order.status == 'rejected') return Icons.cancel_rounded;
    if (order.status == 'revision_requested') return Icons.edit_note_rounded;
    if (order.isDelayed && !order.isCompleted) return Icons.alarm_off_rounded;
    if (order.status == 'in_progress' || order.status == 'accepted') {
      return Icons.hourglass_top_rounded;
    }
    if (order.status == 'delivered' || order.status == 'info_requested') {
      return Icons.inbox_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  String _supervisorNameOf(OrderModel order, List<Map<String, dynamic>> users) {
    if (order.assignedSupervisorName != null &&
        order.assignedSupervisorName!.trim().isNotEmpty) {
      return order.assignedSupervisorName!;
    }
    if (order.assignedSupervisorId == null) return 'غير مسند';
    final s = users.firstWhere(
      (sp) => sp['_id']?.toString() == order.assignedSupervisorId,
      orElse: () => {},
    );
    if (s.isNotEmpty) return s['name']?.toString() ?? 'مشرف';
    return 'مشرف (${order.assignedSupervisorId!.substring(0, 5)}...)';
  }

  /// فتح السجل والمحادثة في نافذة منبثقة بدل الانتقال إلى صفحة كاملة
  void _openOrderDetails(OrderModel order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => LayoutBuilder(
        builder: (ctx, constraints) {
          final insets = MediaQuery.of(ctx).viewInsets.bottom;
          final available = (constraints.maxHeight - insets)
              .clamp(0.0, constraints.maxHeight)
              .toDouble();
          final height = (constraints.maxHeight * 0.92 - insets)
              .clamp(0.0, available)
              .toDouble();
          return AnimatedPadding(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: insets),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: SizedBox(
                height: height,
                child: ManualOrderDetailsScreen(order: order),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => _loadData());
  }

  /// قائمة منبثقة (Bottom Sheet) بإجراءات الطلب بدل الانتقال المباشر
  void _showOrderActions(OrderModel order, List<Map<String, dynamic>> users) {
    final color = _statusColor(order);
    final orderRef = order.orderNumber.isNotEmpty
        ? order.orderNumber
        : order.id.substring(order.id.length - 6);
    final canManage = !order.isCompleted && order.status != 'refunded';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // رأس القائمة: بيانات الطلب
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(_statusIcon(order), color: color, size: 19),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#$orderRef',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.spaceMono(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            order.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(status: order.status),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.outline),

              _buildSheetAction(
                icon: Icons.visibility_rounded,
                title: 'السجل والمحادثة',
                subtitle: 'عرض الخط الزمني ورسائل الطلب والمرفقات',
                color: AppColors.primaryBlue,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openOrderDetails(order);
                },
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.outline),
              if (canManage)
                _buildSheetAction(
                  icon: Icons.swap_horiz_rounded,
                  title: 'إعادة إسناد',
                  subtitle: 'تحويل الطلب إلى مشرف آخر وتنبيهه فوراً',
                  color: AppColors.ticketAmber,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showReassignDialog(order, users);
                  },
                ),
              if (canManage)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.outline,
                ),
              if (canManage)
                _buildSheetAction(
                  icon: Icons.money_off_rounded,
                  title: 'استرجاع مالي',
                  subtitle: 'إرجاع المبلغ إلى محفظة العميل وإلغاء الطلب',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showRefundDialog(order);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: AppColors.slate400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTile(OrderModel order, List<Map<String, dynamic>> users) {
    final color = _statusColor(order);
    final isDelayed = order.isDelayed && !order.isCompleted;
    final orderRef = order.orderNumber.isNotEmpty
        ? order.orderNumber
        : order.id.substring(order.id.length - 6);

    return Material(
      color: isDelayed ? AppColors.rose.withValues(alpha: 0.03) : Colors.white,
      child: InkWell(
        onTap: () => _openOrderDetails(order),
        child: Stack(
          children: [
            // شريط لون الحالة على بداية الصف (RTL/LTR)
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, Color.lerp(color, Colors.white, 0.45)!],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // أيقونة الحالة
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Icon(_statusIcon(order), color: color, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '#$orderRef',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.spaceMono(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  if (order.isSensitive) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.violet.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.violet.withValues(
                                            alpha: 0.28,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.lock_rounded,
                                            size: 10,
                                            color: AppColors.violet,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            'مشفر',
                                            style: AppTypography.cairo(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.violet,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            StatusPill(status: order.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_pin_rounded,
                              size: 13,
                              color: AppColors.slate400,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _supervisorNameOf(order, users),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cairo(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 13,
                              color: AppColors.slate400,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                order.customerName ?? order.userId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cairo(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: AppColors.slate400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'yyyy/MM/dd hh:mm a',
                              ).format(order.createdAt),
                              style: AppTypography.plusJakartaSans(
                                fontSize: 10,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                        if (isDelayed) ...[
                          const SizedBox(height: 6),
                          _buildInlineAlert(
                            Icons.alarm_off_rounded,
                            'تجاوز الموعد المتوقع للتنفيذ! يرجى التدخل أو إعادة الإسناد.',
                            AppColors.rose,
                          ),
                        ],
                        if (order.isDisputed &&
                            order.disputeReason != null) ...[
                          const SizedBox(height: 6),
                          _buildInlineAlert(
                            Icons.report_problem_rounded,
                            'اعتراض العميل: ${order.disputeReason!}',
                            AppColors.rose,
                          ),
                        ],
                        if (order.status == 'rejected' &&
                            order.rejectionReason != null) ...[
                          const SizedBox(height: 6),
                          _buildInlineAlert(
                            Icons.cancel_rounded,
                            'اعتذر المشرف: ${order.rejectionReason!}',
                            AppColors.ticketAmber,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // المبلغ على الطرف
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${order.amount.toStringAsFixed(2)}',
                        style: AppTypography.price(
                          fontSize: 14,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المبلغ',
                        style: AppTypography.cairo(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                  // قائمة الإجراءات (إعادة إسناد / استرجاع مالي)
                  IconButton(
                    onPressed: () => _showOrderActions(order, users),
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: AppColors.slate500,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: 'إجراءات الطلب',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineAlert(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- REASSIGN DIALOG ---
  void _showReassignDialog(
    OrderModel order,
    List<Map<String, dynamic>> supervisors,
  ) {
    String? selectedSupervisor = supervisors.isNotEmpty
        ? supervisors.first['_id']?.toString()
        : null;
    final reasonCtrl = TextEditingController(
      text: 'إعادة إسناد الطلب من قبل الإدارة لمشرف بديل',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: AppColors.secondary),
              SizedBox(width: 8),
              Text(
                'إعادة إسناد الطلب لمشرف آخر',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اختر المشرف الجديد لتحويل الطلب إليه وتنبيهه فورا:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedSupervisor,
                    items: supervisors.map((s) {
                      return DropdownMenuItem<String>(
                        value: s['_id']?.toString() ?? '',
                        child: Text(
                          '${s['name']} (${s['email']})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedSupervisor = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'سبب إعادة الإسناد (يظهر في سجل الطلب)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
              ),
              onPressed: selectedSupervisor == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final admin = Provider.of<AdminProvider>(
                        context,
                        listen: false,
                      );
                      final ok = await admin.reassignOrderSupervisor(
                        order.id,
                        selectedSupervisor!,
                        reasonCtrl.text.trim(),
                      );
                      if (!mounted) return;
                      if (ok) {
                        ScaffoldMessenger.of(context).showTopSnackBar(
                          const SnackBar(
                            content: Text(
                              'تمت إعادة إسناد الطلب بنجاح وإشعار المشرف الجديد',
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showTopSnackBar(
                          SnackBar(
                            content: Text(
                              admin.errorMessage ?? 'تعذر إعادة الإسناد',
                            ),
                          ),
                        );
                      }
                    },
              child: const Text('تأكيد الإسناد'),
            ),
          ],
        ),
      ),
    );
  }

  // --- REFUND DIALOG ---
  void _showRefundDialog(OrderModel order) {
    final reasonCtrl = TextEditingController(
      text: 'استرجاع المبلغ للمحفظة لتعذر إنجاز الخدمة اليدوية',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.monetization_on_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('استرجاع مالي للعميل', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من استرجاع مبلغ ${order.amount.toStringAsFixed(2)} ر.س إلى محفظة العميل فوراً وإلغاء الطلب؟',
              style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'سبب الاسترجاع (يصل إشعار به للعميل)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final admin = Provider.of<AdminProvider>(context, listen: false);
              final ok = await admin.refundOrderAdmin(
                order.id,
                reasonCtrl.text.trim(),
              );
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showTopSnackBar(
                  const SnackBar(
                    content: Text('تم استرجاع المبلغ بنجاح إلى محفظة العميل'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showTopSnackBar(
                  SnackBar(
                    content: Text(admin.errorMessage ?? 'تعذر استرجاع المبلغ'),
                  ),
                );
              }
            },
            child: const Text('تأكيد الاسترجاع'),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderWalletAdminCard(AdminProvider admin) {
    final overview = admin.providerWalletOverview;
    if (overview == null) return const SizedBox.shrink();
    final summary = overview['profitSummary'] is Map
        ? Map<String, dynamic>.from(overview['profitSummary'] as Map)
        : const <String, dynamic>{};
    final pendingCount = (overview['pendingWithdrawalsCount'] as num?)?.toInt() ?? 0;
    final todayProfit = (summary['todayAdminProfit'] as num?)?.toDouble() ?? 0.0;
    final totalAdminProfit =
        (summary['totalAdminProfit'] as num?)?.toDouble() ?? 0.0;
    final totalProviderShare =
        (summary['totalProviderShare'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.savings_outlined,
                size: 18,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'أرباح الأدمن ومحافظ مقدمي الخدمة',
                  style: AppTypography.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showProviderWalletsSheet(context, admin),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 15),
                label: Text(
                  pendingCount > 0
                      ? 'طلبات السحب ($pendingCount)'
                      : 'المحافظ والسحب',
                  style: AppTypography.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _walletStatPill(
                  'أرباح اليوم',
                  '\$${todayProfit.toStringAsFixed(2)}',
                  AppColors.tertiary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _walletStatPill(
                  'إجمالي ربح الأدمن',
                  '\$${totalAdminProfit.toStringAsFixed(2)}',
                  AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _walletStatPill(
                  'حصة مقدمي الخدمة',
                  '\$${totalProviderShare.toStringAsFixed(2)}',
                  AppColors.slate700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _walletStatPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.cairo(
              fontSize: 10,
              color: AppColors.slate600,
            ),
          ),
          Text(
            value,
            style: AppTypography.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProviderWalletsSheet(
    BuildContext context,
    AdminProvider admin,
  ) async {
    await admin.fetchProviderWalletAdminOverview(silent: true);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer<AdminProvider>(
        builder: (ctx, prov, _) {
          final overview = prov.providerWalletOverview ?? const {};
          final withdrawals = (overview['withdrawals'] is List)
              ? List<Map<String, dynamic>>.from(
                  (overview['withdrawals'] as List).whereType<Map>().map(
                    (e) => Map<String, dynamic>.from(e),
                  ),
                )
              : const <Map<String, dynamic>>[];
          final perSupervisor = (overview['perSupervisor'] is List)
              ? List<Map<String, dynamic>>.from(
                  (overview['perSupervisor'] as List).whereType<Map>().map(
                    (e) => Map<String, dynamic>.from(e),
                  ),
                )
              : const <Map<String, dynamic>>[];

          return DraggableScrollableSheet(
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.94,
            expand: false,
            builder: (_, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'طلبات السحب (شام كاش) ومحافظ مقدمي الخدمة',
                  style: AppTypography.cairo(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'طلبات السحب',
                  style: AppTypography.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate700,
                  ),
                ),
                const SizedBox(height: 6),
                if (withdrawals.isEmpty)
                  Text(
                    'لا توجد طلبات سحب حالياً',
                    style: AppTypography.cairo(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                  )
                else
                  for (final w in withdrawals) ...[
                    Builder(
                      builder: (_) {
                        final id = (w['_id'] ?? '').toString();
                        final status = (w['status'] ?? 'pending').toString();
                        final amount =
                            (w['amount'] as num?)?.toDouble() ?? 0.0;
                        final sup = w['supervisorId'] is Map
                            ? Map<String, dynamic>.from(
                                w['supervisorId'] as Map,
                              )
                            : const <String, dynamic>{};
                        final supName = (sup['name'] ?? 'مقدم خدمة').toString();
                        final shamName =
                            (w['shamCashAccountName'] ?? '').toString();
                        final shamId =
                            (w['shamCashAccountId'] ?? '').toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$supName — \$${amount.toStringAsFixed(2)}',
                                      style: AppTypography.cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.slate900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    status == 'approved'
                                        ? 'مقبول'
                                        : status == 'rejected'
                                        ? 'مرفوض'
                                        : 'قيد الانتظار',
                                    style: AppTypography.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: status == 'approved'
                                          ? AppColors.tertiary
                                          : status == 'rejected'
                                          ? AppColors.rose
                                          : AppColors.amber,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'شام كاش: $shamName ($shamId)',
                                style: AppTypography.cairo(
                                  fontSize: 11.5,
                                  color: AppColors.slate700,
                                ),
                              ),
                              if (status == 'pending') ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.tertiary,
                                        ),
                                        onPressed: () async {
                                          final ok = await prov
                                              .approveProviderWithdrawal(id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showTopSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  ok
                                                      ? 'تمت الموافقة على السحب'
                                                      : (prov.errorMessage ??
                                                            'تعذر التنفيذ'),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text('موافقة وتحويل'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.rose,
                                        ),
                                        onPressed: () async {
                                          final ok = await prov
                                              .rejectProviderWithdrawal(
                                                id,
                                                adminNote:
                                                    'تم رفض الطلب وإرجاع الرصيد',
                                              );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showTopSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  ok
                                                      ? 'تم رفض الطلب وإرجاع المبلغ لمحفظة مقدم الخدمة'
                                                      : (prov.errorMessage ??
                                                            'تعذر التنفيذ'),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text('رفض وإرجاع'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                const SizedBox(height: 14),
                Text(
                  'أرصدة وأرباح مقدمي الخدمة',
                  style: AppTypography.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate700,
                  ),
                ),
                const SizedBox(height: 6),
                for (final s in perSupervisor)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s['name'] ?? 'مقدم خدمة'} (${((s['supervisorProfitPercent'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%)',
                                style: AppTypography.cairo(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'رصيد المحفظة: \$${((s['providerBalance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} | ربح الأدمن: \$${((s['totalAdminProfit'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                style: AppTypography.cairo(
                                  fontSize: 11,
                                  color: AppColors.slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- SUPERVISORS MANAGEMENT MODAL ---
  void _showSupervisorsManagementSheet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UsersManagementScreen()),
    );
  }

  Widget _buildProviderWalletAdminBanner(AdminProvider admin) {
    final overview = admin.providerWalletOverview;
    final profitSummary = overview?['profitSummary'] is Map
        ? Map<String, dynamic>.from(overview!['profitSummary'] as Map)
        : const <String, dynamic>{};
    final double todayProfit = (profitSummary['todayAdminProfit'] is num)
        ? (profitSummary['todayAdminProfit'] as num).toDouble()
        : 0.0;
    final double totalProfit = (profitSummary['totalAdminProfit'] is num)
        ? (profitSummary['totalAdminProfit'] as num).toDouble()
        : 0.0;
    final double providerShare = (profitSummary['totalProviderShare'] is num)
        ? (profitSummary['totalProviderShare'] as num).toDouble()
        : 0.0;
    final int pendingCount = (overview?['pendingWithdrawalsCount'] is num)
        ? (overview!['pendingWithdrawalsCount'] as num).toInt()
        : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أرباح الأدمن من مقدمي الخدمة',
                  style: AppTypography.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'اليوم: \$${todayProfit.toStringAsFixed(2)} • الإجمالي: \$${totalProfit.toStringAsFixed(2)} • حصة المزودين: \$${providerShare.toStringAsFixed(2)}',
                  style: AppTypography.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () => _showProviderWalletOverviewSheet(context, admin),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: Text(
              pendingCount > 0 ? 'السحب ($pendingCount)' : 'المحافظ والسحب',
              style: AppTypography.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProviderWalletOverviewSheet(
    BuildContext context,
    AdminProvider admin,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final overview = admin.providerWalletOverview ?? const {};
          final withdrawals = (overview['withdrawals'] is List)
              ? (overview['withdrawals'] as List)
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
              : <Map<String, dynamic>>[];
          final perSupervisor = (overview['perSupervisor'] is List)
              ? (overview['perSupervisor'] as List)
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
              : <Map<String, dynamic>>[];

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            maxChildSize: 0.92,
            builder: (_, ctrl) => ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'طلبات السحب ومحافظ مقدمي الخدمة',
                  style: AppTypography.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'طلبات السحب (شام كاش)',
                  style: AppTypography.cairo(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate800,
                  ),
                ),
                const SizedBox(height: 6),
                if (withdrawals.isEmpty)
                  Text(
                    'لا توجد طلبات سحب حالياً',
                    style: AppTypography.cairo(
                      fontSize: 12.5,
                      color: AppColors.slate500,
                    ),
                  )
                else
                  for (final w in withdrawals)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${w['supervisorName'] ?? 'مقدم خدمة'} — \$${((w['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                    style: AppTypography.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${w['status']}',
                                  style: AppTypography.cairo(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: w['status'] == 'pending'
                                        ? AppColors.amber
                                        : w['status'] == 'approved'
                                        ? AppColors.tertiary
                                        : AppColors.rose,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'شام كاش: ${w['shamCashAccountName'] ?? ''} (${w['shamCashAccountId'] ?? ''})',
                              style: AppTypography.cairo(
                                fontSize: 12,
                                color: AppColors.slate600,
                              ),
                            ),
                            if (w['status'] == 'pending') ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () async {
                                        final ok = await admin
                                            .approveProviderWithdrawal(
                                              (w['_id'] ?? '').toString(),
                                            );
                                        if (ctx.mounted) {
                                          setModalState(() {});
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showTopSnackBar(
                                            SnackBar(
                                              content: Text(
                                                ok
                                                    ? 'تمت الموافقة على السحب'
                                                    : (admin.errorMessage ??
                                                          'تعذر التنفيذ'),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.tertiary,
                                      ),
                                      child: const Text('موافقة'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final ok = await admin
                                            .rejectProviderWithdrawal(
                                              (w['_id'] ?? '').toString(),
                                            );
                                        if (ctx.mounted) {
                                          setModalState(() {});
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showTopSnackBar(
                                            SnackBar(
                                              content: Text(
                                                ok
                                                    ? 'تم رفض الطلب وإرجاع المبلغ لمحفظة المزود'
                                                    : (admin.errorMessage ??
                                                          'تعذر التنفيذ'),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('رفض وإرجاع'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                if (perSupervisor.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'ملخص أرباح مقدمي الخدمة',
                    style: AppTypography.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final s in perSupervisor)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${s['name'] ?? ''} (${((s['supervisorProfitPercent'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%)',
                        style: AppTypography.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'محفظته: \$${((s['providerBalance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} • ربح الأدمن: \$${((s['totalAdminProfit'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                        style: AppTypography.cairo(fontSize: 11.5),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.done_all_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد طلبات تطابق الفلتر المحدد',
              style: AppTypography.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'جرّب تغيير فلتر الحالة أو فلتر المشرف',
              style: AppTypography.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ملاحظة: إدارة المشرفين تتِم عبر صفحة "إدارة المستخدمين" (UsersManagementScreen)
// حيث يُرقّى العميل إلى مشرف تلقائياً عند إسناد خدمة له أو يدوياً من هناك.
