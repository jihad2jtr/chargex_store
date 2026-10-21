import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/order_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_pill.dart';
import '../user/manual_order_details_screen.dart';

class ManualServicesManagementScreen extends StatefulWidget {
  const ManualServicesManagementScreen({super.key});

  @override
  State<ManualServicesManagementScreen> createState() => _ManualServicesManagementScreenState();
}

class _ManualServicesManagementScreenState extends State<ManualServicesManagementScreen> {
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
      admin.fetchSupervisors(),
    ]);
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    var result = orders;

    // Filter by supervisor if selected
    if (_selectedSupervisorId != null && _selectedSupervisorId != 'all') {
      result = result.where((o) => o.assignedSupervisorId == _selectedSupervisorId).toList();
    }

    // Filter by status category
    if (_selectedFilter == 'new') {
      result = result.where((o) => o.status == 'assigned' || o.status == 'pending').toList();
    } else if (_selectedFilter == 'in_progress') {
      result = result.where((o) => o.status == 'in_progress' || o.status == 'accepted').toList();
    } else if (_selectedFilter == 'waiting_client') {
      result = result.where((o) => o.status == 'delivered' || o.status == 'info_requested').toList();
    } else if (_selectedFilter == 'delayed') {
      result = result.where((o) => o.isDelayed && !o.isCompleted).toList();
    } else if (_selectedFilter == 'issues') {
      result = result.where((o) => o.status == 'disputed' || o.status == 'revision_requested' || o.status == 'rejected').toList();
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

    final delayedCount = allOrders.where((o) => o.isDelayed && !o.isCompleted).length;
    final issuesCount = allOrders.where((o) => o.status == 'disputed' || o.status == 'revision_requested' || o.status == 'rejected').length;
    final inProgressCount = allOrders.where((o) => o.status == 'in_progress' || o.status == 'accepted').length;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          'إدارة الخدمات اليدوية والمشرفين',
          style: AppTypography.cairo(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate900),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined, color: AppColors.primaryBlue),
            tooltip: 'إدارة المشرفين',
            onPressed: () => _showSupervisorsManagementSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slate600),
            tooltip: 'تحديث',
            onPressed: admin.isLoading ? null : _loadData,
          ),
          const SizedBox(width: 8),
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
              _buildSupervisorFilter(admin.supervisors),
              const SizedBox(height: 12),

              // Status Filter Chips
              _buildStatusFilterChips(),
              const SizedBox(height: 16),

              // Orders List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الطلبات اليدوية (${filteredOrders.length})',
                    style: AppTypography.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                    ),
                  ),
                  if (admin.isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (admin.isLoading && allOrders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 50),
                    child: CircularProgressIndicator(color: AppColors.primaryBlue),
                  ),
                )
              else if (filteredOrders.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildAdminOrderCard(order, admin.supervisors);
                  },
                ),

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
            title: 'إجمالي الطلبات',
            value: total.toString(),
            color: AppColors.primaryBlue,
            bgColor: AppColors.primaryBlue.withValues(alpha: 0.08),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'قيد التنفيذ',
            value: inProgress.toString(),
            color: AppColors.ticketAmber,
            bgColor: AppColors.ticketAmber.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'تأخير SLA',
            value: delayed.toString(),
            color: AppColors.rose,
            bgColor: AppColors.rose.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'اعتراضات/رفض',
            value: issues.toString(),
            color: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTypography.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.slate600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorFilter(List<Map<String, dynamic>> supervisors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedSupervisorId ?? 'all',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Row(
                children: [
                  Icon(Icons.people_outline_rounded, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('جميع المشرفين', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ...supervisors.map((s) {
              final id = s['_id']?.toString() ?? '';
              final name = s['name']?.toString() ?? 'مشرف';
              final email = s['email']?.toString() ?? '';
              return DropdownMenuItem(
                value: id,
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, size: 18, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$name ($email)',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
    );
  }

  Widget _buildStatusFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'الكل'},
      {'key': 'new', 'label': 'جديدة ومسندة'},
      {'key': 'in_progress', 'label': 'قيد التنفيذ'},
      {'key': 'waiting_client', 'label': 'بانتظار العميل'},
      {'key': 'delayed', 'label': 'متأخرة ⚠️'},
      {'key': 'issues', 'label': 'اعتراضات/رفض'},
      {'key': 'completed', 'label': 'مكتملة'},
      {'key': 'refunded', 'label': 'مسترجعة'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedFilter = f['key']!);
              },
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdminOrderCard(OrderModel order, List<Map<String, dynamic>> supervisors) {
    final isDelayed = order.isDelayed && !order.isCompleted;

    // Supervisor display name
    String supervisorName = 'غير مسند';
    if (order.assignedSupervisorId != null) {
      final s = supervisors.firstWhere(
        (sp) => sp['_id']?.toString() == order.assignedSupervisorId,
        orElse: () => {},
      );
      if (s.isNotEmpty) {
        supervisorName = s['name']?.toString() ?? 'مشرف';
      } else {
        supervisorName = 'مشرف (${order.assignedSupervisorId!.substring(0, 5)}...)';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDelayed ? AppColors.rose.withValues(alpha: 0.5) : AppColors.outline,
          width: isDelayed ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDelayed ? AppColors.rose.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.02),
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
            // Top: Order #, Status, Sensitive Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '#${order.orderNumber.isNotEmpty ? order.orderNumber : order.id.substring(order.id.length - 6)}',
                      style: AppTypography.spaceMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    if (order.isSensitive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 4),
                            Text(
                              'مشفر',
                              style: AppTypography.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED)),
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
            const SizedBox(height: 8),

            // Product Name & Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.productName,
                    style: AppTypography.arabicCardTitle(
                      fontSize: 15,
                      color: AppColors.slate900,
                    ),
                  ),
                ),
                Text(
                  '\$${order.amount.toStringAsFixed(2)}',
                  style: AppTypography.price(
                    fontSize: 16,
                    color: AppColors.slate900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Supervisor & Customer
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, size: 16, color: AppColors.primaryBlue),
                      const SizedBox(width: 6),
                      Text(
                        'المشرف المكلف: ',
                        style: AppTypography.cairo(fontSize: 11, color: AppColors.slate600),
                      ),
                      Text(
                        supervisorName,
                        style: AppTypography.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.slate600),
                      const SizedBox(width: 6),
                      Text(
                        'العميل: ',
                        style: AppTypography.cairo(fontSize: 11, color: AppColors.slate600),
                      ),
                      Text(
                        order.customerName ?? order.userId,
                        style: AppTypography.cairo(fontSize: 11, color: AppColors.slate900),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('yyyy/MM/dd hh:mm a').format(order.createdAt),
                        style: AppTypography.plusJakartaSans(fontSize: 10, color: AppColors.slate600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Delay / SLA status banner
            if (isDelayed)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alarm_off_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'تجاوز هذا الطلب الموعد المتوقع للتنفيذ! يرجى التدخل أو إعادة إسناده.',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),

            // Rejection reason if supervisor rejected
            if (order.status == 'rejected' && order.rejectionReason != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'اعتذر المشرف: ${order.rejectionReason!}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Customer Dispute reason if open
            if (order.isDisputed && order.disputeReason != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.report_problem_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'اعتراض العميل: ${order.disputeReason!}',
                        style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Admin Control Actions
            Row(
              children: [
                // View Details & Chat
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ManualOrderDetailsScreen(order: order)),
                    ).then((_) => _loadData());
                  },
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text('السجل والمحادثة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const Spacer(),

                // Reassign button (if not completed or refunded)
                if (!order.isCompleted && order.status != 'refunded') ...[
                  OutlinedButton.icon(
                    onPressed: () => _showReassignDialog(order, supervisors),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('إعادة إسناد'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.secondary),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Instant Refund button (if disputed, rejected, or delayed)
                if (!order.isCompleted && order.status != 'refunded') ...[
                  ElevatedButton.icon(
                    onPressed: () => _showRefundDialog(order),
                    icon: const Icon(Icons.money_off_rounded, size: 16),
                    label: const Text('استرجاع مالي'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- REASSIGN DIALOG ---
  void _showReassignDialog(OrderModel order, List<Map<String, dynamic>> supervisors) {
    String? selectedSupervisor = supervisors.isNotEmpty ? supervisors.first['_id']?.toString() : null;
    final reasonCtrl = TextEditingController(text: 'إعادة إسناد الطلب من قبل الإدارة لمشرف بديل');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: AppColors.secondary),
              SizedBox(width: 8),
              Text('إعادة إسناد الطلب لمشرف آخر', style: TextStyle(fontSize: 16)),
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
                        child: Text('${s['name']} (${s['email']})', style: const TextStyle(fontSize: 13)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              onPressed: selectedSupervisor == null ? null : () async {
                Navigator.pop(ctx);
                final admin = Provider.of<AdminProvider>(context, listen: false);
                final ok = await admin.reassignOrderSupervisor(
                  order.id,
                  selectedSupervisor!,
                  reasonCtrl.text.trim(),
                );
                if (!mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت إعادة إسناد الطلب بنجاح وإشعار المشرف الجديد')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(admin.errorMessage ?? 'تعذر إعادة الإسناد')),
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
    final reasonCtrl = TextEditingController(text: 'استرجاع المبلغ للمحفظة لتعذر إنجاز الخدمة اليدوية');

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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              final ok = await admin.refundOrderAdmin(order.id, reasonCtrl.text.trim());
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم استرجاع المبلغ بنجاح إلى محفظة العميل')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(admin.errorMessage ?? 'تعذر استرجاع المبلغ')),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SupervisorsSheetContent(),
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
              child: const Icon(Icons.done_all_rounded, size: 48, color: AppColors.tertiary),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد طلبات تطابق الفلتر المحدد',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

// Sub-widget for managing supervisors
class SupervisorsSheetContent extends StatefulWidget {
  const SupervisorsSheetContent({super.key});

  @override
  State<SupervisorsSheetContent> createState() => _SupervisorsSheetContentState();
}

class _SupervisorsSheetContentState extends State<SupervisorsSheetContent> {
  bool _showAddForm = false;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _createSupervisor() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء الاسم والبريد الإلكتروني وكلمة المرور')),
      );
      return;
    }

    final admin = Provider.of<AdminProvider>(context, listen: false);
    final ok = await admin.createSupervisor(
      name: name,
      email: email,
      password: pass,
      phone: phone.isNotEmpty ? phone : null,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة المشرف بنجاح')),
      );
      setState(() {
        _showAddForm = false;
        _nameCtrl.clear();
        _emailCtrl.clear();
        _passCtrl.clear();
        _phoneCtrl.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(admin.errorMessage ?? 'فشل إضافة المشرف')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    final supervisors = admin.supervisors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title & Add button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_ind_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'إدارة فريق المشرفين',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => _showAddForm = !_showAddForm),
                icon: Icon(_showAddForm ? Icons.close : Icons.add_rounded, size: 16),
                label: Text(_showAddForm ? 'إلغاء' : 'مشرف جديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showAddForm ? Colors.grey.shade400 : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Add Supervisor Form
          if (_showAddForm) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'بيانات المشرف الجديد',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم المشرف الكامل',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني (لتسجيل الدخول)',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف (اختياري)',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: admin.isLoading ? null : _createSupervisor,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: admin.isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('إنشاء حساب المشرف', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Supervisors List
          Expanded(
            child: supervisors.isEmpty
                ? const Center(child: Text('لا يوجد مشرفون مسجلون حالياً'))
                : ListView.separated(
                    itemCount: supervisors.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = supervisors[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, color: AppColors.primary),
                        ),
                        title: Text(
                          s['name']?.toString() ?? 'مشرف',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${s['email'] ?? ""} ${s['phone'] != null ? " • ${s['phone']}" : ""}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'مشرف نشط',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
