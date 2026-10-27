import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/order_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_pill.dart';
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
  String _selectedFilter = 'all';
  String? _selectedSupervisorId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    await Future.wait([
      admin.fetchManualOrders(),
      admin.fetchAllUsers(silent: true),
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

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    var result = orders;

    // Filter by supervisor if selected
    if (_selectedSupervisorId != null && _selectedSupervisorId != 'all') {
      result = result
          .where((o) => o.assignedSupervisorId == _selectedSupervisorId)
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

    return result;
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
      backgroundColor: AppColors.paper,
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
                'إدارة الخدمات اليدوية والمشرفين',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 16,
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
          padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 16),

              // Supervisor Filter Dropdown
              _buildSupervisorFilter(_supervisorList(admin)),
              const SizedBox(height: 12),

              // Status Filter Chips
              _buildStatusFilterChips(),
              const SizedBox(height: 16),

              // Orders List Header
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
                      fontSize: 15,
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
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (admin.isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryBlue,
                      ),
                    ),
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
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            'إجمالي الطلبات',
            total.toString(),
            Icons.receipt_long_rounded,
            AppColors.primaryBlue,
            AppColors.brandGradient,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            'قيد التنفيذ',
            inProgress.toString(),
            Icons.hourglass_top_rounded,
            AppColors.ticketAmber,
            AppColors.ticketGoldGradient,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            'تأخير SLA',
            delayed.toString(),
            Icons.alarm_off_rounded,
            AppColors.rose,
            const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            'اعتراضات/رفض',
            issues.toString(),
            Icons.report_problem_rounded,
            const Color(0xFF8B5CF6),
            const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    String title,
    String value,
    IconData icon,
    Color color,
    LinearGradient gradient,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: AppTypography.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            title,
            style: AppTypography.cairo(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.slate500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorFilter(List<Map<String, dynamic>> supervisors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
      {'key': 'all', 'label': 'الكل', 'color': AppColors.primaryBlue},
      {'key': 'new', 'label': 'جديدة ومسندة', 'color': const Color(0xFF6366F1)},
      {
        'key': 'in_progress',
        'label': 'قيد التنفيذ',
        'color': AppColors.ticketAmber,
      },
      {
        'key': 'waiting_client',
        'label': 'بانتظار العميل',
        'color': const Color(0xFF0EA5E9),
      },
      {'key': 'delayed', 'label': 'متأخرة', 'color': AppColors.rose},
      {
        'key': 'issues',
        'label': 'اعتراضات/رفض',
        'color': const Color(0xFF8B5CF6),
      },
      {'key': 'completed', 'label': 'مكتملة', 'color': AppColors.tertiary},
      {'key': 'refunded', 'label': 'مسترجعة', 'color': AppColors.slate400},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          final Color color = f['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(f['label'] as String),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (val) {
                if (val) setState(() => _selectedFilter = f['key'] as String);
              },
              selectedColor: color,
              backgroundColor: Colors.white,
              labelStyle: AppTypography.cairo(
                fontSize: 12,
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
    if (order.status == 'completed') return AppColors.tertiary;
    if (order.status == 'refunded') return AppColors.slate400;
    if (order.isDisputed ||
        order.status == 'revision_requested' ||
        order.status == 'rejected') {
      return const Color(0xFF8B5CF6);
    }
    if (order.isDelayed && !order.isCompleted) return AppColors.rose;
    if (order.status == 'in_progress' || order.status == 'accepted') {
      return AppColors.ticketAmber;
    }
    if (order.status == 'delivered' || order.status == 'info_requested') {
      return const Color(0xFF0EA5E9);
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
            // شريط لون الحالة على الحافة
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, Color.lerp(color, Colors.white, 0.55)!],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                                        color: const Color(
                                          0xFF7C3AED,
                                        ).withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF7C3AED,
                                          ).withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.lock_rounded,
                                            size: 10,
                                            color: Color(0xFF7C3AED),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            'مشفر',
                                            style: AppTypography.cairo(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF7C3AED),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تمت إعادة إسناد الطلب بنجاح وإشعار المشرف الجديد',
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم استرجاع المبلغ بنجاح إلى محفظة العميل'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
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

  // --- SUPERVISORS MANAGEMENT MODAL ---
  void _showSupervisorsManagementSheet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UsersManagementScreen()),
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
