import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/manual_services_provider.dart';
import '../../widgets/status_pill.dart';
import '../user/manual_order_details_screen.dart';
import '../../widgets/unified_tactile_header.dart';
import '../../widgets/live_status_console.dart';
import '../../widgets/floating_role_dashboard_shield.dart';
import '../user/user_main_screen.dart';

class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  String _selectedFilter = 'all';
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });

    // Auto-refresh orders silently every 12 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        final provider = Provider.of<ManualServicesProvider>(
          context,
          listen: false,
        );
        provider.fetchSupervisorOrders(null, true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final provider = Provider.of<ManualServicesProvider>(
      context,
      listen: false,
    );
    await provider.fetchSupervisorOrders();
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    if (_selectedFilter == 'new') {
      return orders
          .where((o) => o.status == 'assigned' || o.status == 'pending')
          .toList();
    } else if (_selectedFilter == 'in_progress') {
      return orders
          .where((o) => o.status == 'in_progress' || o.status == 'accepted')
          .toList();
    } else if (_selectedFilter == 'waiting_client') {
      return orders
          .where((o) => o.status == 'delivered' || o.status == 'info_requested')
          .toList();
    } else if (_selectedFilter == 'issues') {
      return orders
          .where(
            (o) => o.status == 'disputed' || o.status == 'revision_requested',
          )
          .toList();
    } else if (_selectedFilter == 'completed') {
      return orders.where((o) => o.status == 'completed').toList();
    }
    return orders;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final manualProvider = Provider.of<ManualServicesProvider>(context);
    final allOrders = manualProvider.supervisorOrders;
    final filteredOrders = _filterOrders(allOrders);

    // KPIs
    final newCount = allOrders
        .where((o) => o.status == 'assigned' || o.status == 'pending')
        .length;
    final inProgressCount = allOrders
        .where((o) => o.status == 'in_progress' || o.status == 'accepted')
        .length;
    final waitingClientCount = allOrders
        .where((o) => o.status == 'delivered' || o.status == 'info_requested')
        .length;
    final issuesCount = allOrders
        .where(
          (o) => o.status == 'disputed' || o.status == 'revision_requested',
        )
        .length;
    final delayedCount = allOrders
        .where((o) => o.isDelayed && !o.isCompleted)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadOrders,
              color: AppColors.secondary,
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
                    _buildSupervisorBanner(auth, delayedCount),
                    const SizedBox(height: 16),

                    // KPI Stats Grid
                    _buildKpiGrid(
                      newCount,
                      inProgressCount,
                      waitingClientCount,
                      issuesCount,
                      delayedCount,
                    ),
                    const SizedBox(height: 20),

                    // Filter Chips
                    _buildFilterChips(),
                    const SizedBox(height: 16),

                    // Orders List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'قائمة الطلبات (${filteredOrders.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        if (manualProvider.isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.secondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // List of Orders
                    if (manualProvider.isLoading && allOrders.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(
                            color: AppColors.secondary,
                          ),
                        ),
                      )
                    else if (filteredOrders.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredOrders.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          return _buildOrderCard(order);
                        },
                      ),

                    const SizedBox(height: 40),
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

  Widget _buildSupervisorBanner(AuthProvider auth, int delayedCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkNav,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.5),
              ),
            ),
            child: const Icon(
              Icons.engineering_rounded,
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
                    Text(
                      'أهلاً بك، ${auth.currentUser?.name ?? "مشرف العمليات"}',
                      style: AppTypography.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'QUEUE ACTIVE',
                        style: AppTypography.technicalCode(
                          fontSize: 8.5,
                          color: const Color(0xFF6EE7B7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  delayedCount > 0
                      ? '⚠️ تنبيه: يوجد $delayedCount طلبات متأخرة بحاجة لتسليم سريع!'
                      : 'جميع الطلبات المسندة إليك تحت السيطرة وضمن الوقت المحدد.',
                  style: AppTypography.cairo(
                    color: delayedCount > 0
                        ? AppColors.ticketAmber
                        : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: delayedCount > 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(
    int newCount,
    int inProgressCount,
    int waitingClient,
    int issues,
    int delayed,
  ) {
    final metrics = [
      LiveStatusMetric(
        label: 'طلبات جديدة',
        sub: 'بحاجة للمراجعة والتوزيع',
        value: newCount.toString(),
        icon: Icons.mark_email_unread_rounded,
        accent: const Color(0xFF0284C7),
        statusText: newCount > 0 ? 'جديد' : 'مستقر',
        isAlert: newCount > 0,
        rawValue: newCount,
        onTap: () => setState(() => _selectedFilter = 'new'),
      ),
      LiveStatusMetric(
        label: 'قيد التنفيذ',
        sub: 'جاري العمل عليها حالياً',
        value: inProgressCount.toString(),
        icon: Icons.hourglass_top_rounded,
        accent: const Color(0xFFD97706),
        statusText: 'نشط',
        rawValue: inProgressCount,
        onTap: () => setState(() => _selectedFilter = 'in_progress'),
      ),
      LiveStatusMetric(
        label: 'بانتظار العميل',
        sub: 'بانتظار رد العميل',
        value: waitingClient.toString(),
        icon: Icons.pending_actions_rounded,
        accent: const Color(0xFF7C3AED),
        statusText: 'معلّق',
        rawValue: waitingClient,
        onTap: () => setState(() => _selectedFilter = 'waiting_client'),
      ),
      LiveStatusMetric(
        label: 'اعتراضات / تعديل',
        sub: 'تحتاج معالجة عاجلة',
        value: issues.toString(),
        icon: Icons.report_problem_rounded,
        accent: AppColors.error,
        statusText: issues > 0 ? 'تنبيه' : 'مستقر',
        isAlert: issues > 0,
        rawValue: issues,
        onTap: () => setState(() => _selectedFilter = 'issues'),
      ),
      LiveStatusMetric(
        label: 'متأخرة (SLA)',
        sub: 'تجاوزت الوقت المحدد',
        value: delayed.toString(),
        icon: Icons.timer_off_rounded,
        accent: const Color(0xFFDC2626),
        statusText: delayed > 0 ? 'متأخر' : 'في الوقت',
        isAlert: delayed > 0,
        rawValue: delayed,
      ),
    ];

    return LiveStatusConsole(title: 'حالة طلبات الخدمات', metrics: metrics);
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'الكل'},
      {'key': 'new', 'label': 'جديدة'},
      {'key': 'in_progress', 'label': 'قيد التنفيذ'},
      {'key': 'waiting_client', 'label': 'بانتظار العميل'},
      {'key': 'issues', 'label': 'اعتراضات وتعديلات'},
      {'key': 'completed', 'label': 'مكتملة'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = f['key']!),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.darkNav : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.darkNav : AppColors.outline,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  f['label']!,
                  style: AppTypography.cairo(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final isDelayed = order.isDelayed && !order.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDelayed
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.outline,
          width: isDelayed ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDelayed
                ? AppColors.error.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: ID, Status, Sensitive icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '#${order.orderNumber.isNotEmpty ? order.orderNumber : order.id.substring(order.id.length - 6)}',
                      style: AppTypography.technicalCode(
                        fontSize: 12.5,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (order.isSensitive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              size: 11,
                              color: Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'مشفر',
                              style: AppTypography.cairo(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                StatusPill(status: order.status),
              ],
            ),
            const SizedBox(height: 10),

            // Product Title & Customer Info
            Text(
              order.productName,
              style: AppTypography.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'العميل: ${order.customerName ?? order.userId}',
                  style: AppTypography.cairo(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${order.amount.toStringAsFixed(2)}',
                  style: AppTypography.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.ticketAmber,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: AppColors.outline),

            // SLA / Deadline Counter Box
            _buildDeadlineIndicator(order),

            // Dispute / Revision alert message if any
            if (order.isDisputed && order.disputeReason != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'اعتراض مفتوح من العميل:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                          Text(
                            order.disputeReason!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (order.isRevisionRequested && order.revisionNotes != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'العميل طلب تعديل:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          Text(
                            order.revisionNotes!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Action Buttons
            _buildActionButtons(order),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineIndicator(OrderModel order) {
    if (order.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: AppColors.tertiary,
            ),
            const SizedBox(width: 6),
            const Text(
              'تم استلام وتأكيد الطلب من العميل وإغلاقه بنجاح.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final isDelayed = order.isDelayed;
    final deadline = order.deadlineAt;

    String deadlineText;
    if (deadline != null) {
      final now = DateTime.now();
      final diff = deadline.difference(now);
      if (diff.isNegative) {
        deadlineText =
            'متأخر عن الوقت المحدد بـ ${diff.inMinutes.abs()} دقيقة!';
      } else if (diff.inHours > 0) {
        deadlineText =
            'الوقت المتبقي: ${diff.inHours} ساعة و ${diff.inMinutes % 60} دقيقة';
      } else {
        deadlineText = 'الوقت المتبقي: ${diff.inMinutes} دقيقة فقط';
      }
    } else {
      deadlineText = 'الوقت المتوقع للتنفيذ: ${order.estimatedMinutes} دقيقة';
    }

    final bgColor = isDelayed
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFF0FDF4);
    final textColor = isDelayed ? AppColors.error : AppColors.tertiary;
    final iconColor = isDelayed ? AppColors.error : AppColors.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isDelayed ? Icons.alarm_off_rounded : Icons.timer_outlined,
            size: 16,
            color: iconColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              deadlineText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          Text(
            DateFormat('hh:mm a').format(order.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(OrderModel order) {
    final status = order.status;

    return Row(
      children: [
        // Detail / Chat button (always available)
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManualOrderDetailsScreen(order: order),
              ),
            ).then((_) => _loadOrders());
          },
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
          label: const Text('المحادثة والسجل'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const Spacer(),

        // Status specific buttons
        if (status == 'assigned' || status == 'pending') ...[
          // Reject button
          OutlinedButton(
            onPressed: () => _showRejectDialog(order),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('رفض'),
          ),
          const SizedBox(width: 8),
          // Accept button
          ElevatedButton(
            onPressed: () => _acceptOrder(order),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tertiary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('قبول الطلب'),
          ),
        ] else if (status == 'accepted') ...[
          // Start Execution button
          ElevatedButton.icon(
            onPressed: () => _startOrder(order),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('بدء التنفيذ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ] else if (status == 'in_progress' ||
            status == 'revision_requested') ...[
          // Request Info
          OutlinedButton(
            onPressed: () => _showRequestInfoDialog(order),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD97706),
              side: const BorderSide(color: Color(0xFFD97706)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('طلب معلومات'),
          ),
          const SizedBox(width: 8),
          // Deliver Result
          ElevatedButton.icon(
            onPressed: () => _showDeliverDialog(order),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('تسليم النتيجة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ] else if (status == 'info_requested') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'بانتظار رد العميل بالمعلومات',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFD97706),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ] else if (status == 'delivered') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'تم التسليم - بانتظار تأكيد العميل',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF7C3AED),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- ACTIONS ---

  void _acceptOrder(OrderModel order) async {
    final provider = Provider.of<ManualServicesProvider>(
      context,
      listen: false,
    );
    final ok = await provider.supervisorAcceptOrder(order.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول الطلب بنجاح! يمكنك الآن بدء التنفيذ'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'تعذر قبول الطلب')),
      );
    }
  }

  void _startOrder(OrderModel order) async {
    final provider = Provider.of<ManualServicesProvider>(
      context,
      listen: false,
    );
    final ok = await provider.supervisorStartOrder(order.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم بدء تنفيذ الطلب بنجاح')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'تعذر بدء التنفيذ')),
      );
    }
  }

  void _showRejectDialog(OrderModel order) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('رفض استلام الطلب', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'يرجى توضيح سبب الرفض لإبلاغ الإدارة لإعادة إسناد الطلب لمشرف آخر:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'مثال: ضغط عمل حالي / عدم توفر المتطلبات الفنية...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.error),
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
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال سبب الرفض')),
                );
                return;
              }
              Navigator.pop(ctx);
              final provider = Provider.of<ManualServicesProvider>(
                context,
                listen: false,
              );
              final ok = await provider.supervisorRejectOrder(order.id, reason);
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تسجيل رفض الطلب وإبلاغ الإدارة'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.errorMessage ?? 'فشل رفض الطلب'),
                  ),
                );
              }
            },
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
  }

  void _showRequestInfoDialog(OrderModel order) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('طلب معلومات إضافية', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل الاستفسار أو المتطلبات الناقصة لإرسالها للعميل:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'مثال: يرجى تزويدنا برقم الهاتف لتأكيد الحساب أو رمز التحقق...',
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
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final note = noteCtrl.text.trim();
              if (note.isEmpty) return;
              Navigator.pop(ctx);
              final provider = Provider.of<ManualServicesProvider>(
                context,
                listen: false,
              );
              final ok = await provider.supervisorRequestInfo(order.id, note);
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال طلب المعلومات للعميل بنجاح'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.errorMessage ?? 'تعذر إرسال الطلب'),
                  ),
                );
              }
            },
            child: const Text('إرسال للعميل'),
          ),
        ],
      ),
    );
  }

  void _showDeliverDialog(OrderModel order) {
    final notesCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final backupCtrl = TextEditingController();
    final extraCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: AppColors.tertiary),
              SizedBox(width: 8),
              Text('تسليم نتيجة الخدمة', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ملاحظات التسليم للعميل:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'تم إنشاء الحساب وضبط الإعدادات بنجاح...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // If sensitive or general credential input
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.security_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'البيانات السرية (تشفير AES-256 تلقائي)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'سيتم تشفير هذه البيانات فوراً ولن تظهر في الإشعارات، وتُحذف نهائياً بعد استلام العميل.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailCtrl,
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني / اسم المستخدم',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: passCtrl,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: backupCtrl,
                          decoration: InputDecoration(
                            labelText:
                                'البريد البديل / رمز الاسترداد (اختياري)',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: extraCtrl,
                          decoration: InputDecoration(
                            labelText: 'أي بيانات إضافية (اختياري)',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final notes = notesCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final pass = passCtrl.text.trim();

                Map<String, dynamic>? credentials;
                if (email.isNotEmpty || pass.isNotEmpty) {
                  credentials = {};
                  if (email.isNotEmpty) credentials['email'] = email;
                  if (pass.isNotEmpty) credentials['password'] = pass;
                  if (backupCtrl.text.trim().isNotEmpty)
                    credentials['recovery'] = backupCtrl.text.trim();
                  if (extraCtrl.text.trim().isNotEmpty)
                    credentials['notes'] = extraCtrl.text.trim();
                }

                Navigator.pop(ctx);
                final provider = Provider.of<ManualServicesProvider>(
                  context,
                  listen: false,
                );
                final ok = await provider.supervisorDeliverOrder(
                  orderId: order.id,
                  resultNotes: notes.isNotEmpty
                      ? notes
                      : 'تم إنجاز الخدمة بنجاح.',
                  credentials: credentials,
                );

                if (!mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تم تسليم الخدمة بنجاح إلى العميل وبانتظار تأكيده',
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.errorMessage ?? 'تعذر تسليم الخدمة',
                      ),
                    ),
                  );
                }
              },
              child: const Text('تأكيد وتسليم للعميل'),
            ),
          ],
        ),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد طلبات في هذا التصنيف',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'سيتم إشعارك فور إسناد أي طلب يدوي جديد إليك',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
