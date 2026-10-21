import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/order_model.dart';
import '../../providers/app_catalog_provider.dart';
import '../../widgets/status_pill.dart';
import 'manual_order_details_screen.dart';

class OrdersHistoryScreen extends StatefulWidget {
  final bool showAppBar;
  const OrdersHistoryScreen({super.key, this.showAppBar = true});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  String _selectedFilter = 'all';
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppCatalogProvider>(context, listen: false).fetchMyOrders();
    });

    // Auto-refresh orders every 15 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        Provider.of<AppCatalogProvider>(context, listen: false).fetchMyOrders();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = Provider.of<AppCatalogProvider>(context);
    final allOrders = catalog.myOrders;

    final filteredOrders = allOrders.where((order) {
      if (_selectedFilter == 'all') return true;
      return order.status.toLowerCase() == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              title: Text(
                'سجل الطلبات والتذاكر',
                style: AppTypography.cairo(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate900),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.slate600),
                  tooltip: 'تحديث',
                  onPressed: () => catalog.fetchMyOrders(),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: Column(
        children: [
          // Filter Chips (Swiss Neo-Bento)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('all', 'الكل (${allOrders.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('pending', 'قيد الانتظار'),
                const SizedBox(width: 8),
                _buildFilterChip('completed', 'مكتملة'),
                const SizedBox(width: 8),
                _buildFilterChip('rejected', 'مرفوضة'),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: filteredOrders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 54, color: AppColors.slate600.withValues(alpha: 0.4)),
                          const SizedBox(height: 14),
                          Text(
                            'لا توجد طلبات في هذا القسم',
                            style: AppTypography.cairo(fontSize: 14, color: AppColors.slate600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      final dateStr = DateFormat('yyyy/MM/dd - hh:mm a').format(order.createdAt);

                      return _buildOrderTicket(order, dateStr, catalog);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = key;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.slate900 : AppColors.outline,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.slate900.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: isSelected
              ? AppTypography.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)
              : AppTypography.cairo(fontSize: 12, color: AppColors.slate600),
        ),
      ),
    );
  }

  Widget _buildOrderTicket(OrderModel order, String dateStr, AppCatalogProvider catalog) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: order.isManual
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ManualOrderDetailsScreen(order: order)),
                  ).then((_) => catalog.fetchMyOrders());
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ticket Header: Order #, Pass Badge & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: const Icon(Icons.receipt_outlined, size: 16, color: AppColors.slate600),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TKT #${order.orderNumber}',
                          style: AppTypography.spaceMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    StatusPill(status: order.status),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: AppColors.outline),
                const SizedBox(height: 12),

                // Item Details & Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.productName,
                            style: AppTypography.arabicCardTitle(
                              fontSize: 15,
                              color: AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            order.appName,
                            style: AppTypography.cairo(fontSize: 12, color: AppColors.slate600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '\$${order.amount.toStringAsFixed(2)}',
                        style: AppTypography.price(
                          fontSize: 16,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),

                // Delivered Code Voucher Section (if codes product)
                if (order.deliveredCode != null && order.deliveredCode!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.ticketAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.ticketAmber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'كود البطاقة الرقمية المستلمة',
                                style: AppTypography.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.ticketAmber),
                              ),
                              const SizedBox(height: 2),
                              SelectableText(
                                order.deliveredCode!,
                                style: AppTypography.spaceMono(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.slate900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16, color: AppColors.ticketAmber),
                          tooltip: 'نسخ الكود',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: order.deliveredCode!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم نسخ كود البطاقة بنجاح', style: AppTypography.cairo()),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                // Admin Rejection Notes (if rejected)
                if (order.status == 'rejected' && order.adminNotes != null && order.adminNotes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.rose.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.rose),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ملاحظات الإدارة: ${order.adminNotes!}',
                            style: AppTypography.cairo(fontSize: 11, color: AppColors.rose),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Manual Human Service Interactive Banner
                if (order.isManual) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: order.isDelivered
                          ? AppColors.emerald.withValues(alpha: 0.08)
                          : (order.isDisputed ? AppColors.rose.withValues(alpha: 0.08) : AppColors.primaryBlue.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: order.isDelivered
                            ? AppColors.emerald.withValues(alpha: 0.3)
                            : (order.isDisputed ? AppColors.rose.withValues(alpha: 0.3) : AppColors.primaryBlue.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          order.isDelivered
                              ? Icons.verified_outlined
                              : (order.isDisputed ? Icons.report_problem_outlined : Icons.support_agent_outlined),
                          size: 18,
                          color: order.isDelivered
                              ? AppColors.emerald
                              : (order.isDisputed ? AppColors.rose : AppColors.primaryBlue),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.isDelivered
                                    ? 'تم تسليم النتيجة! اضغط للمراجعة والتأكيد'
                                    : (order.isDisputed
                                        ? 'اعتراض قيد المعالجة من الإدارة'
                                        : 'خدمة يدوية بإشراف مباشر'),
                                style: AppTypography.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: order.isDelivered
                                      ? AppColors.emerald
                                      : (order.isDisputed ? AppColors.rose : AppColors.primaryBlue),
                                ),
                              ),
                              Text(
                                'اضغط لفتح السجل الزمني، المحادثة والبيانات السرية',
                                style: AppTypography.cairo(fontSize: 10, color: AppColors.slate600),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: order.isDelivered
                              ? AppColors.emerald
                              : (order.isDisputed ? AppColors.rose : AppColors.primaryBlue),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateStr, style: AppTypography.plusJakartaSans(fontSize: 10, color: AppColors.slate600)),
                    Text('ChargeX Verified Pass', style: AppTypography.technicalCode(fontSize: 9, color: AppColors.slate600.withValues(alpha: 0.6))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
