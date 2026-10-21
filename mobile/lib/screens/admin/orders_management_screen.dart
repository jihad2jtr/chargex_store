import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/order_model.dart';
import '../../models/manual_order_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_pill.dart';

class OrdersManagementScreen extends StatefulWidget {
  const OrdersManagementScreen({super.key});

  @override
  State<OrdersManagementScreen> createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends State<OrdersManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _orderStatusFilter = 'all';
  Timer? _autoRefreshTimer;

  // ID Topup Controllers
  final _idUserIdCtrl = TextEditingController();
  final _idAmountCtrl = TextEditingController();
  final _idDescCtrl = TextEditingController(text: 'شحن رصيد مباشر من الإدارة');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = Provider.of<AdminProvider>(context, listen: false);
      admin.fetchAdminOrders();
      admin.fetchManualTopupRequests();
    });

    // Auto-refresh orders and topup requests silently every 12 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
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
    _tabController.dispose();
    _idUserIdCtrl.dispose();
    _idAmountCtrl.dispose();
    _idDescCtrl.dispose();
    super.dispose();
  }

  void _openAcceptOrderDialog(OrderModel order) {
    final notesCtrl = TextEditingController(text: 'تم شحن الحساب بنجاح');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('قبول وتنفيذ الطلب اليدوي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('الخدمة: ${order.productName} (${order.appName})', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('العميل: ${order.userName ?? 'عميل'}'),
              if (order.accountInput.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('بيانات الحساب المدخلة من العميل:', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                for (final e in order.accountInput.entries)
                  Text('${e.key}: ${e.value}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBright)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات الإدارة للعميل'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.tertiary),
              onPressed: () async {
                final admin = Provider.of<AdminProvider>(context, listen: false);
                final ok = await admin.acceptManualOrder(order.id, notesCtrl.text.trim());
                if (ctx.mounted) Navigator.of(ctx).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'تم قبول وتنفيذ الطلب بنجاح' : 'حدث خطأ'),
                      backgroundColor: ok ? AppColors.tertiary : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('تأكيد القبول والتنفيذ'),
            ),
          ],
        );
      },
    );
  }

  void _openRejectOrderDialog(OrderModel order) {
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('رفض الطلب اليدوي واسترجاع الرصيد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('الخدمة: ${order.productName} (${order.appName})', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('المبلغ المسترجع: \$${order.amount.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'سبب الرفض (سيتم إرساله للعميل)',
                  hintText: 'معرف اللاعب غير صحيح، الحساب محظور، الخ...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                final notes = notesCtrl.text.trim();
                if (notes.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى كتابة سبب الرفض للعميل')),
                  );
                  return;
                }

                final admin = Provider.of<AdminProvider>(context, listen: false);
                final ok = await admin.rejectManualOrder(order.id, notes);
                if (ctx.mounted) Navigator.of(ctx).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'تم رفض الطلب واسترجاع المبلغ للعميل' : 'حدث خطأ'),
                      backgroundColor: ok ? AppColors.tertiary : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('تأكيد الرفض والاسترجاع'),
            ),
          ],
        );
      },
    );
  }

  void _openApproveTopupDialog(ManualOrderModel request) {
    final amountCtrl = TextEditingController(text: request.amount.toString());
    final notesCtrl = TextEditingController(text: 'تم تأكيد الإيداع وشحن الرصيد');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('الموافقة على طلب شحن الرصيد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('العميل: ${request.userName ?? ''}'),
              Text('الطريقة: ${request.type}'),
              if (request.details.isNotEmpty)
                Text('تفاصيل التحويل: ${request.details.values.join(' - ')}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ المعتمد للشحن (\$ USD)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات الإدارة'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.tertiary),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? request.amount;
                final admin = Provider.of<AdminProvider>(context, listen: false);
                final ok = await admin.approveTopupRequest(request.id, approvedAmount: amount, notes: notesCtrl.text.trim());
                if (ctx.mounted) Navigator.of(ctx).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'تمت الموافقة وشحن المحفظة بنجاح' : 'حدث خطأ'),
                      backgroundColor: ok ? AppColors.tertiary : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('تأكيد الموافقة'),
            ),
          ],
        );
      },
    );
  }

  void _openRejectTopupDialog(ManualOrderModel request) {
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('رفض طلب شحن الرصيد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('العميل: ${request.userName ?? ''}'),
              Text('المبلغ المطلوب: \$${request.amount}'),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'سبب الرفض للعميل',
                  hintText: 'لم يصل أي تحويل، الإيصال غير مطابق...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                final notes = notesCtrl.text.trim();
                final admin = Provider.of<AdminProvider>(context, listen: false);
                final ok = await admin.rejectTopupRequest(request.id, notes.isNotEmpty ? notes : 'تم الرفض لعدم تطابق التحويل');
                if (ctx.mounted) Navigator.of(ctx).pop();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'تم رفض طلب الشحن بنجاح' : 'حدث خطأ'),
                      backgroundColor: ok ? AppColors.tertiary : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('تأكيد الرفض'),
            ),
          ],
        );
      },
    );
  }

  void _submitIdRecharge() async {
    final userId = _idUserIdCtrl.text.trim();
    final amount = double.tryParse(_idAmountCtrl.text.trim()) ?? 0.0;
    final desc = _idDescCtrl.text.trim();

    if (userId.isEmpty || amount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال آيدي العميل والمبلغ المطلوب')),
      );
      return;
    }

    final admin = Provider.of<AdminProvider>(context, listen: false);
    final ok = await admin.adjustUserBalance(userId, amount, desc);

    if (!mounted) return;

    if (ok) {
      _idUserIdCtrl.clear();
      _idAmountCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم شحن رصيد العميل بنجاح 🎉'), backgroundColor: AppColors.tertiary),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(admin.errorMessage ?? 'فشل تعديل الرصيد'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'إدارة الطلبات والشحن',
          style: AppTypography.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlue,
          indicatorWeight: 3,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTypography.cairo(fontWeight: FontWeight.w900, fontSize: 12),
          unselectedLabelStyle: AppTypography.cairo(fontWeight: FontWeight.w600, fontSize: 12),
          isScrollable: true,
          tabs: [
            Tab(text: 'طلبات الشراء (${admin.adminOrders.length})'),
            Tab(text: 'طلبات شحن الرصيد (${admin.manualTopupRequests.length})'),
            const Tab(text: 'الشحن عبر الآيدي (ID)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Purchase Orders
          _buildPurchaseOrdersTab(admin),
          // Tab 1: Topup Requests
          _buildTopupRequestsTab(admin),
          // Tab 2: ID Direct Topup Tool
          _buildIdTopupToolTab(),
        ],
      ),
    );
  }

  Widget _buildPurchaseOrdersTab(AdminProvider admin) {
    final filtered = admin.adminOrders.where((o) {
      if (_orderStatusFilter == 'all') return true;
      return o.status == _orderStatusFilter;
    }).toList();

    return Column(
      children: [
        // Status filter pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildFilterChoice('all', 'الكل'),
              const SizedBox(width: 8),
              _buildFilterChoice('pending', 'قيد الانتظار'),
              const SizedBox(width: 8),
              _buildFilterChoice('completed', 'مكتملة'),
              const SizedBox(width: 8),
              _buildFilterChoice('rejected', 'مرفوضة'),
            ],
          ),
        ),

        Expanded(
          child: admin.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد طلبات في هذا القسم',
                        style: AppTypography.cairo(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final order = filtered[index];
                        final dateStr = DateFormat('yyyy/MM/dd - hh:mm a').format(order.createdAt);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.outline),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
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
                                    order.orderNumber,
                                    style: AppTypography.spaceMono(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                  StatusPill(status: order.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.productName,
                                        style: AppTypography.cairo(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'العميل: ${order.userName ?? 'عميل'} (${order.userEmail ?? ''})',
                                        style: AppTypography.cairo(fontSize: 11.5, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '\$${order.amount.toStringAsFixed(2)}',
                                    style: AppTypography.plusJakartaSans(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.ticketAmber,
                                    ),
                                  ),
                                ],
                              ),
                              if (order.accountInput.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceDim,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'بيانات الحساب: ${order.accountInput.entries.map((e) => '${e.key}: ${e.value}').join(' | ')}',
                                    style: AppTypography.technicalCode(fontSize: 10, color: AppColors.primaryBlue),
                                  ),
                                ),
                              ],
                              if (order.deliveredCode != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'كود البطاقة: ${order.deliveredCode}',
                                  style: AppTypography.technicalCode(fontSize: 11, color: AppColors.accentGreen),
                                ),
                              ],
                              if (order.adminNotes != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'ملاحظات الإدارة: ${order.adminNotes}',
                                  style: AppTypography.cairo(fontSize: 11.5, color: AppColors.ticketAmber),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateStr,
                                    style: AppTypography.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  // Accept / Reject buttons for pending orders
                                  if (order.status == 'pending') ...[
                                    Row(
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.tertiary,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          ),
                                          onPressed: () => _openAcceptOrderDialog(order),
                                          child: const Text('قبول'),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.error,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          ),
                                          onPressed: () => _openRejectOrderDialog(order),
                                          child: const Text('رفض'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTopupRequestsTab(AdminProvider admin) {
    if (admin.manualTopupRequests.isEmpty) {
      return const Center(
        child: Text('لا توجد طلبات شحن رصيد معلقة', style: TextStyle(color: AppColors.onSurfaceVariant)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: admin.manualTopupRequests.length,
      itemBuilder: (context, index) {
        final req = admin.manualTopupRequests[index];
        final dateStr = DateFormat('yyyy/MM/dd - hh:mm a').format(req.createdAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('طلب شحن عبر ${req.type}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  StatusPill(status: req.status),
                ],
              ),
              const SizedBox(height: 6),
              Text('العميل: ${req.userName ?? ''} (${req.userEmail ?? ''})', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(
                'المبلغ المطلوب: \$${req.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.secondaryBright),
              ),
              if (req.details.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('تفاصيل التحويل: ${req.details}', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
              ],
              if (req.adminNotes != null) ...[
                const SizedBox(height: 6),
                Text('ملاحظات: ${req.adminNotes}', style: const TextStyle(fontSize: 12, color: AppColors.amber)),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  if (req.status == 'pending') ...[
                    Row(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tertiary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          onPressed: () => _openApproveTopupDialog(req),
                          child: const Text('موافقة'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          onPressed: () => _openRejectTopupDialog(req),
                          child: const Text('رفض'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIdTopupToolTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_add_alt_1_outlined, size: 52, color: AppColors.secondary),
            const SizedBox(height: 12),
            const Text(
              'أداة شحن رصيد العميل مباشرة عبر الآيدي (User ID)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'أدخل معرّف العميل والمبلغ المطلوب ليتم إضافة الرصيد لحسابه وإرسال إشعار فوري إليه.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _idUserIdCtrl,
              decoration: const InputDecoration(
                labelText: 'معرف العميل (User ID)',
                hintText: 'مثال: chx26101512345 أو معرف العميل',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _idAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ المراد إضافته (\$ USD)',
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _idDescCtrl,
              decoration: const InputDecoration(
                labelText: 'البيان / الوصف (يظهر للعميل في سجل الحساب)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitIdRecharge,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('إتمام الشحن الفوري للعميل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChoice(String key, String label) {
    final isSelected = _orderStatusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _orderStatusFilter = key),
    );
  }
}
