import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/manual_order_model.dart';
import '../../models/order_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/ops_ticket_card.dart';
import '../../widgets/status_pill.dart';

/// لوحة «إدارة الطلبات والشحن»:
/// هيدر عمليات داكن بعدّادات + مبدّل أقسام + فلاتر بعدد الطلبات
/// + بطاقات بأسلوب التذكرة (خط تمزّق وفجوتين) + نوافذ سفلية للإجراءات.
class OrdersManagementScreen extends StatefulWidget {
  const OrdersManagementScreen({super.key});

  @override
  State<OrdersManagementScreen> createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends State<OrdersManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _orderStatusFilter = 'all';
  // فلتر سجل الشحن: all | sham_cash | binance | code | id
  String _topupTypeFilter = 'all';
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
      admin.fetchTopupLog();
    });

    // Auto-refresh orders and topup requests silently every 12 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        final admin = Provider.of<AdminProvider>(context, listen: false);
        admin.fetchAdminOrders(silent: true);
        admin.fetchTopupLog();
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

  // ---------------------------------------------------------------- أدوات

  void _toast(String message, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: ok ? AppColors.tertiary : AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.ticketAmber;
      case 'processing':
      case 'in_progress':
      case 'accepted':
      case 'assigned':
        return AppColors.primaryBlue;
      case 'completed':
      case 'delivered':
      case 'approved':
        return AppColors.accentGreen;
      case 'rejected':
      case 'refunded':
      case 'disputed':
        return AppColors.error;
      default:
        return AppColors.slate500;
    }
  }

  ({String label, IconData icon, Color color, String? brand}) _method(
    String type,
  ) {
    switch (type) {
      case 'sham_cash':
        return (
          label: 'شام كاش',
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.accentGreen,
          brand: BrandLogo.shamCash,
        );
      case 'binance':
        return (
          label: 'Binance Pay',
          icon: Icons.currency_bitcoin_rounded,
          color: const Color(0xFFF0B90B),
          brand: BrandLogo.binance,
        );
      case 'id_recharge':
        return (
          label: 'معرّف مباشر',
          icon: Icons.badge_rounded,
          color: AppColors.primaryBlue,
          brand: null,
        );
      case 'id_topup':
        return (
          label: 'شحن ID',
          icon: Icons.badge_rounded,
          color: AppColors.primaryBlue,
          brand: null,
        );
      case 'code':
        return (
          label: 'كود شحن',
          icon: Icons.qr_code_2_rounded,
          color: const Color(0xFF7C3AED),
          brand: null,
        );
      default:
        return (
          label: 'شحن رصيد',
          icon: Icons.wallet_rounded,
          color: AppColors.primaryBlue,
          brand: null,
        );
    }
  }

  // ------------------------------------------------- نوافذ الإجراءات السفلية

  Widget _sheet(
    BuildContext ctx, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 17, color: color),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.spaceMono(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        tooltip: 'إغلاق',
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    String? errorText,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: AppTypography.cairo(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        labelStyle: AppTypography.cairo(
          fontSize: 11.5,
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTypography.cairo(
          fontSize: 11.5,
          color: AppColors.textMuted,
        ),
        errorStyle: AppTypography.cairo(
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceBright,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: border(AppColors.outline),
        enabledBorder: border(AppColors.outline),
        focusedBorder: border(AppColors.primaryBlue, 1.6),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.6),
      ),
    );
  }

  Widget _sheetButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: AppTypography.cairo(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  Widget _sheetSectionTitle(String text) {
    return Text(
      text,
      style: AppTypography.cairo(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _summaryBox(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? tint,
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: AppTypography.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: mono
                  ? AppTypography.technicalCode(
                      fontSize: 10.5,
                      color: tint ?? AppColors.primaryBlue,
                    )
                  : AppTypography.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: tint ?? AppColors.textPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAcceptOrderSheet(OrderModel order) async {
    final notesCtrl = TextEditingController(text: 'تم شحن الحساب بنجاح');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x660F172A),
      builder: (ctx) => _sheet(
        ctx,
        title: 'قبول وتنفيذ الطلب',
        subtitle: order.orderNumber,
        icon: Icons.verified_rounded,
        color: AppColors.accentGreen,
        children: [
          _summaryBox([
            _summaryRow('الخدمة', '${order.productName} · ${order.appName}'),
            _summaryRow('العميل', order.userName ?? 'عميل'),
            _summaryRow(
              'المبلغ',
              '\$${order.amount.toStringAsFixed(2)}',
              tint: AppColors.secondaryBright,
            ),
          ]),
          if (order.accountInput.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sheetSectionTitle('بيانات الحساب المدخلة من العميل'),
            const SizedBox(height: 6),
            _summaryBox([
              for (final e in order.accountInput.entries)
                _summaryRow(e.key, '${e.value}', mono: true),
            ]),
          ],
          const SizedBox(height: 14),
          _sheetField(
            notesCtrl,
            'ملاحظات الإدارة للعميل',
            Icons.sticky_note_2_outlined,
          ),
          const SizedBox(height: 16),
          _sheetButton(
            label: 'تأكيد القبول والتنفيذ',
            icon: Icons.check_rounded,
            color: AppColors.accentGreen,
            onTap: () async {
              final admin = Provider.of<AdminProvider>(context, listen: false);
              Navigator.of(ctx).pop();
              final ok = await admin.acceptManualOrder(
                order.id,
                notesCtrl.text.trim(),
              );
              _toast(
                ok
                    ? 'تم قبول وتنفيذ الطلب بنجاح'
                    : (admin.errorMessage ?? 'حدث خطأ'),
                ok,
              );
            },
          ),
        ],
      ),
    );
    notesCtrl.dispose();
  }

  Future<void> _openRejectOrderSheet(OrderModel order) async {
    final reasonCtrl = TextEditingController();
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x660F172A),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _sheet(
          ctx,
          title: 'رفض الطلب واسترجاع الرصيد',
          subtitle: order.orderNumber,
          icon: Icons.undo_rounded,
          color: AppColors.error,
          children: [
            _summaryBox([
              _summaryRow('الخدمة', '${order.productName} · ${order.appName}'),
              _summaryRow(
                'المبلغ المسترجع',
                '\$${order.amount.toStringAsFixed(2)}',
                tint: AppColors.error,
              ),
            ]),
            const SizedBox(height: 14),
            _sheetField(
              reasonCtrl,
              'سبب الرفض (يُرسل للعميل)',
              Icons.report_gmailerrorred_rounded,
              hint: 'معرف اللاعب غير صحيح، الحساب محظور...',
              maxLines: 2,
              errorText: error,
            ),
            const SizedBox(height: 16),
            _sheetButton(
              label: 'تأكيد الرفض والاسترجاع',
              icon: Icons.close_rounded,
              color: AppColors.error,
              onTap: () async {
                if (reasonCtrl.text.trim().isEmpty) {
                  setSheet(() => error = 'يرجى كتابة سبب الرفض للعميل');
                  return;
                }
                final admin = Provider.of<AdminProvider>(
                  context,
                  listen: false,
                );
                Navigator.of(ctx).pop();
                final ok = await admin.rejectManualOrder(
                  order.id,
                  reasonCtrl.text.trim(),
                );
                _toast(
                  ok
                      ? 'تم رفض الطلب واسترجاع المبلغ للعميل'
                      : (admin.errorMessage ?? 'حدث خطأ'),
                  ok,
                );
              },
            ),
          ],
        ),
      ),
    );
    reasonCtrl.dispose();
  }

  Future<void> _openApproveTopupSheet(ManualOrderModel request) async {
    final amountCtrl = TextEditingController(
      text: request.amount.toStringAsFixed(2),
    );
    final notesCtrl = TextEditingController(
      text: 'تم تأكيد الإيداع وشحن الرصيد',
    );
    final meta = _method(request.type);
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x660F172A),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _sheet(
          ctx,
          title: 'الموافقة على طلب شحن الرصيد',
          subtitle: meta.label,
          icon: Icons.verified_rounded,
          color: AppColors.accentGreen,
          children: [
            _summaryBox([
              _summaryRow('العميل', request.userName ?? 'عميل'),
              _summaryRow('طريقة الدفع', meta.label, tint: meta.color),
              if (request.details.isNotEmpty)
                _summaryRow(
                  'تفاصيل التحويل',
                  request.details.values
                      .map((v) => '$v')
                      .where((v) => v.trim().isNotEmpty)
                      .join(' · '),
                  mono: true,
                ),
            ]),
            const SizedBox(height: 14),
            _sheetField(
              amountCtrl,
              'المبلغ المعتمد للشحن (\$ USD)',
              Icons.attach_money_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              errorText: error,
            ),
            const SizedBox(height: 12),
            _sheetField(
              notesCtrl,
              'ملاحظات الإدارة',
              Icons.sticky_note_2_outlined,
            ),
            const SizedBox(height: 16),
            _sheetButton(
              label: 'تأكيد الموافقة وشحن الرصيد',
              icon: Icons.check_rounded,
              color: AppColors.accentGreen,
              onTap: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) {
                  setSheet(() => error = 'يرجى إدخال مبلغ صحيح أكبر من صفر');
                  return;
                }
                final admin = Provider.of<AdminProvider>(
                  context,
                  listen: false,
                );
                Navigator.of(ctx).pop();
                final ok = await admin.approveTopupRequest(
                  request.id,
                  approvedAmount: amount,
                  notes: notesCtrl.text.trim(),
                );
                _toast(
                  ok
                      ? 'تمت الموافقة وشحن المحفظة بنجاح'
                      : (admin.errorMessage ?? 'حدث خطأ'),
                  ok,
                );
              },
            ),
          ],
        ),
      ),
    );
    amountCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _openRejectTopupSheet(ManualOrderModel request) async {
    final reasonCtrl = TextEditingController();
    final meta = _method(request.type);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x660F172A),
      builder: (ctx) => _sheet(
        ctx,
        title: 'رفض طلب شحن الرصيد',
        subtitle: meta.label,
        icon: Icons.block_rounded,
        color: AppColors.error,
        children: [
          _summaryBox([
            _summaryRow('العميل', request.userName ?? 'عميل'),
            _summaryRow(
              'المبلغ المطلوب',
              '\$${request.amount.toStringAsFixed(2)}',
              tint: AppColors.error,
            ),
          ]),
          const SizedBox(height: 14),
          _sheetField(
            reasonCtrl,
            'سبب الرفض للعميل',
            Icons.report_gmailerrorred_rounded,
            hint: 'لم يصل أي تحويل، الإيصال غير مطابق...',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _sheetButton(
            label: 'تأكيد الرفض',
            icon: Icons.close_rounded,
            color: AppColors.error,
            onTap: () async {
              final notes = reasonCtrl.text.trim();
              final admin = Provider.of<AdminProvider>(context, listen: false);
              Navigator.of(ctx).pop();
              final ok = await admin.rejectTopupRequest(
                request.id,
                notes.isNotEmpty ? notes : 'تم الرفض لعدم تطابق التحويل',
              );
              _toast(
                ok
                    ? 'تم رفض طلب الشحن بنجاح'
                    : (admin.errorMessage ?? 'حدث خطأ'),
                ok,
              );
            },
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
  }

  void _submitIdRecharge() async {
    final userId = _idUserIdCtrl.text.trim();
    final amount = double.tryParse(_idAmountCtrl.text.trim()) ?? 0.0;
    final desc = _idDescCtrl.text.trim();

    if (userId.isEmpty || amount == 0) {
      _toast('يرجى إدخال آيدي العميل والمبلغ المطلوب', false);
      return;
    }

    final admin = Provider.of<AdminProvider>(context, listen: false);
    final ok = await admin.adjustUserBalance(userId, amount, desc);

    if (!mounted) return;

    if (ok) {
      _idUserIdCtrl.clear();
      _idAmountCtrl.clear();
      _toast('تم شحن رصيد العميل بنجاح', true);
    } else {
      _toast(admin.errorMessage ?? 'فشل تعديل الرصيد', false);
    }
  }

  // ---------------------------------------------------------------- الواجهة

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(admin),
            _buildSegmentSwitcher(admin),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTopupRequestsTab(admin),
                  _buildPurchaseOrdersTab(admin),
                  _buildIdTopupToolTab(admin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// هيدر العمليات: عنوان + مؤشر تحديث حي + ثلاث عدّادات قابلة للضغط.
  Widget _buildHeader(AdminProvider admin) {
    final now = DateTime.now();
    final int pendingOrders = admin.adminOrders
        .where((o) => o.status == 'pending')
        .length;
    final int pendingTopups = admin.manualTopupRequests
        .where((r) => r.status == 'pending')
        .length;
    final int doneToday = admin.adminOrders.where((o) {
      final DateTime d = o.completedAt ?? o.createdAt;
      return o.status == 'completed' &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).length;

    final bool canPop = Navigator.of(context).canPop();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkNav, AppColors.slate800],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkNav.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (canPop) ...[
                _headerIconButton(
                  Icons.arrow_forward_rounded,
                  () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 19,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة الطلبات والشحن',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.accentGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'تحديث تلقائي كل 12 ثانية',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.62),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _headerIconButton(Icons.refresh_rounded, () {
                admin.fetchAdminOrders();
                admin.fetchTopupLog();
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  value: '$pendingOrders',
                  label: 'طلب قيد الانتظار',
                  color: AppColors.ticketAmber,
                  icon: Icons.hourglass_bottom_rounded,
                  onTap: () {
                    setState(() => _orderStatusFilter = 'pending');
                    _tabController.animateTo(1);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  value: '$pendingTopups',
                  label: 'شحن رصيد معلّق',
                  color: AppColors.primaryBlue,
                  icon: Icons.account_balance_wallet_rounded,
                  onTap: () => _tabController.animateTo(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  value: '$doneToday',
                  label: 'مكتمل اليوم',
                  color: AppColors.accentGreen,
                  icon: Icons.check_circle_rounded,
                  onTap: () {
                    setState(() => _orderStatusFilter = 'completed');
                    _tabController.animateTo(1);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 17, color: Colors.white),
        ),
      ),
    );
  }

  Widget _metricTile({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    value,
                    maxLines: 1,
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
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.66),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// مبدّل الأقسام: ثلاث بطاقات/أقسام داخل شريط أبيض واحد (بدل TabBar التقليدي).
  Widget _buildSegmentSwitcher(AdminProvider admin) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final int active = _tabController.index;
          return Row(
            children: [
              Expanded(
                child: _segmentItem(
                  active,
                  0,
                  'شحن الرصيد',
                  Icons.account_balance_wallet_rounded,
                  admin.manualTopupRequests.length,
                ),
              ),
              Expanded(
                child: _segmentItem(
                  active,
                  1,
                  'المشتريات',
                  Icons.shopping_bag_rounded,
                  admin.adminOrders.length,
                ),
              ),
              Expanded(
                child: _segmentItem(
                  active,
                  2,
                  'شحن ID',
                  Icons.badge_rounded,
                  null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _segmentItem(
    int active,
    int index,
    String label,
    IconData icon,
    int? count,
  ) {
    final bool selected = active == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkNav : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppColors.surfaceDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------- تبويب المشتريات

  Widget _buildPurchaseOrdersTab(AdminProvider admin) {
    final List<OrderModel> filtered = admin.adminOrders.where((o) {
      if (_orderStatusFilter == 'all') return true;
      return o.status == _orderStatusFilter;
    }).toList();

    int countOf(String status) =>
        admin.adminOrders.where((o) => o.status == status).length;

    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            children: [
              _filterChip(
                'all',
                'الكل',
                Icons.layers_rounded,
                AppColors.slate700,
                admin.adminOrders.length,
              ),
              const SizedBox(width: 8),
              _filterChip(
                'pending',
                'قيد الانتظار',
                Icons.hourglass_bottom_rounded,
                AppColors.ticketAmber,
                countOf('pending'),
              ),
              const SizedBox(width: 8),
              _filterChip(
                'completed',
                'مكتملة',
                Icons.check_circle_rounded,
                AppColors.accentGreen,
                countOf('completed'),
              ),
              const SizedBox(width: 8),
              _filterChip(
                'rejected',
                'مرفوضة',
                Icons.cancel_rounded,
                AppColors.error,
                countOf('rejected'),
              ),
            ],
          ),
        ),
        Expanded(child: _buildOrdersBody(admin, filtered)),
      ],
    );
  }

  Widget _buildOrdersBody(AdminProvider admin, List<OrderModel> filtered) {
    if (admin.isLoading && admin.adminOrders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }
    if (filtered.isEmpty) {
      return _emptyState(
        icon: Icons.inbox_rounded,
        title: 'لا توجد طلبات هنا',
        subtitle:
            'ستظهر طلبات الشراء فور ورودها من العملاء، ومعها زرّا القبول والرفض.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildOrderCard(filtered[index]),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final Color accent = _statusColor(order.status);
    final String dateStr = DateFormat(
      'yyyy/MM/dd - hh:mm a',
    ).format(order.createdAt);
    final String account = order.accountInput.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('  ·  ');
    final String email = (order.userEmail ?? '').trim();

    final IconData icon = order.isManual
        ? Icons.handyman_rounded
        : (order.type == 'codes'
              ? Icons.confirmation_number_rounded
              : Icons.bolt_rounded);

    return OpsTicketCard(
      accent: accent,
      icon: icon,
      tag: order.orderNumber,
      title: order.productName,
      subtitle: [
        order.appName,
        order.userName ?? 'عميل',
      ].where((s) => s.trim().isNotEmpty).join(' · '),
      amount: Text(
        '\$${order.amount.toStringAsFixed(2)}',
        style: AppTypography.plusJakartaSans(
          fontSize: 15.5,
          fontWeight: FontWeight.w900,
          color: AppColors.secondaryBright,
        ),
      ),
      status: StatusPill(status: order.status),
      rows: [
        OpsTicketInfoRow(
          icon: Icons.person_outline_rounded,
          label: 'العميل',
          value:
              '${order.userName ?? 'عميل'}${email.isNotEmpty ? ' · $email' : ''}',
        ),
        if (account.isNotEmpty)
          OpsTicketInfoRow(
            icon: Icons.key_rounded,
            label: 'بيانات الحساب',
            value: account,
            mono: true,
            trailing: _copyButton(account),
          ),
        if ((order.deliveredCode ?? '').isNotEmpty)
          OpsTicketInfoRow(
            icon: Icons.credit_card_rounded,
            label: 'كود البطاقة',
            value: order.deliveredCode!,
            mono: true,
            tint: AppColors.accentGreen,
            trailing: _copyButton(order.deliveredCode!),
          ),
      ],
      note: order.adminNotes,
      meta: dateStr,
      actions: order.status == 'pending'
          ? [
              _cardAction(
                label: 'قبول',
                icon: Icons.check_rounded,
                color: AppColors.accentGreen,
                onTap: () => _openAcceptOrderSheet(order),
              ),
              const SizedBox(width: 8),
              _cardAction(
                label: 'رفض',
                icon: Icons.close_rounded,
                color: AppColors.error,
                filled: false,
                onTap: () => _openRejectOrderSheet(order),
              ),
            ]
          : const [],
    );
  }

  // --------------------------------------------------- تبويب شحن الرصيد

  /// هل تنتمي العملية لنوع الفلتر المختار؟
  /// فلتر «آيدي» يجمع شحن الأدمن المباشر (id_topup) مع طلبات العميل (id_recharge).
  bool _matchesTopupType(String type, [String? filter]) {
    final String f = filter ?? _topupTypeFilter;
    if (f == 'all') return true;
    if (f == 'id') return type == 'id_topup' || type == 'id_recharge';
    return type == f;
  }

  /// سجل عمليات الشحن بالآيدي وحدها
  List<ManualOrderModel> _idTopupLog(AdminProvider admin) => admin
      .manualTopupRequests
      .where((r) => r.type == 'id_topup' || r.type == 'id_recharge')
      .toList();

  Widget _buildTopupRequestsTab(AdminProvider admin) {
    final List<ManualOrderModel> all = admin.manualTopupRequests;
    final List<ManualOrderModel> requests = all
        .where((r) => _matchesTopupType(r.type))
        .toList();

    int countOf(String key) =>
        all.where((r) => _matchesTopupType(r.type, key)).length;

    if (admin.isLoading && all.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }

    final List<ManualOrderModel> pending = requests
        .where((r) => r.status == 'pending')
        .toList();
    final List<ManualOrderModel> reviewed = requests
        .where((r) => r.status != 'pending')
        .toList();

    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            children: [
              _choiceChip(
                label: 'الكل',
                icon: Icons.layers_rounded,
                color: AppColors.slate700,
                count: all.length,
                selected: _topupTypeFilter == 'all',
                onTap: () => setState(() => _topupTypeFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _choiceChip(
                label: 'شام كاش',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.accentGreen,
                count: countOf('sham_cash'),
                selected: _topupTypeFilter == 'sham_cash',
                onTap: () => setState(() => _topupTypeFilter = 'sham_cash'),
              ),
              const SizedBox(width: 8),
              _choiceChip(
                label: 'Binance',
                icon: Icons.currency_bitcoin_rounded,
                color: const Color(0xFFF0B90B),
                count: countOf('binance'),
                selected: _topupTypeFilter == 'binance',
                onTap: () => setState(() => _topupTypeFilter = 'binance'),
              ),
              const SizedBox(width: 8),
              _choiceChip(
                label: 'كروت الشحن',
                icon: Icons.qr_code_2_rounded,
                color: const Color(0xFF7C3AED),
                count: countOf('code'),
                selected: _topupTypeFilter == 'code',
                onTap: () => setState(() => _topupTypeFilter = 'code'),
              ),
              const SizedBox(width: 8),
              _choiceChip(
                label: 'آيدي',
                icon: Icons.badge_rounded,
                color: AppColors.primaryBlue,
                count: countOf('id'),
                selected: _topupTypeFilter == 'id',
                onTap: () => setState(() => _topupTypeFilter = 'id'),
              ),
            ],
          ),
        ),
        Expanded(
          child: all.isEmpty
              ? _emptyState(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'لا توجد عمليات شحن',
                  subtitle:
                      'سجل واحد لكل عمليات الشحن: شام كاش / Binance / كود شحن / شحن بالآيدي.',
                )
              : requests.isEmpty
              ? _emptyState(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'لا توجد عمليات بهذا الفلتر',
                  subtitle: 'اختر «الكل» لعرض كل وسائل الشحن المسجّلة.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    if (pending.isNotEmpty) ...[
                      _listSectionLabel(
                        Icons.hourglass_bottom_rounded,
                        'بانتظار المراجعة',
                        pending.length,
                      ),
                      ...pending.map(_buildTopupCard),
                    ],
                    if (reviewed.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _listSectionLabel(
                        Icons.history_rounded,
                        'سجل العمليات',
                        reviewed.length,
                      ),
                      ...reviewed.map(_buildTopupCard),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTopupCard(ManualOrderModel req) {
    final meta = _method(req.type);
    final String dateStr = DateFormat(
      'yyyy/MM/dd - hh:mm a',
    ).format(req.createdAt);
    final String email = (req.userEmail ?? '').trim();
    final String phone = (req.userPhone ?? '').trim();
    final String details = req.details.values
        .map((v) => '$v')
        .where((v) => v.trim().isNotEmpty)
        .join('  ·  ');
    final String receipt = (req.receiptImageUrl ?? '').trim();

    return OpsTicketCard(
      accent: meta.color,
      icon: meta.icon,
      leading: meta.brand == null
          ? null
          : BrandLogo(asset: meta.brand!, size: 24, radius: 7),
      tag: 'طلب شحن رصيد',
      title: meta.label,
      subtitle:
          '${req.userName ?? 'عميل'}${email.isNotEmpty ? ' · $email' : ''}',
      amount: Text(
        req.amount < 0
            ? '-\$${req.amount.abs().toStringAsFixed(2)}'
            : '\$${req.amount.toStringAsFixed(2)}',
        style: AppTypography.plusJakartaSans(
          fontSize: 15.5,
          fontWeight: FontWeight.w900,
          color: req.amount < 0 ? AppColors.error : AppColors.secondaryBright,
        ),
      ),
      status: StatusPill(status: req.status),
      rows: [
        if (details.isNotEmpty)
          OpsTicketInfoRow(
            icon: req.type == 'id_topup'
                ? Icons.badge_outlined
                : Icons.receipt_long_rounded,
            label: req.type == 'id_topup' ? 'آيدي العميل' : 'تفاصيل التحويل',
            value: details,
            mono: true,
            tint: meta.color,
            trailing: _copyButton(details),
          ),
        if (phone.isNotEmpty)
          OpsTicketInfoRow(
            icon: Icons.phone_rounded,
            label: 'الهاتف',
            value: phone,
          ),
      ],
      media: receipt.isNotEmpty ? _receiptBlock(receipt) : null,
      note: req.adminNotes,
      meta: dateStr,
      actions: req.status == 'pending'
          ? [
              _cardAction(
                label: 'موافقة',
                icon: Icons.check_rounded,
                color: AppColors.accentGreen,
                onTap: () => _openApproveTopupSheet(req),
              ),
              const SizedBox(width: 8),
              _cardAction(
                label: 'رفض',
                icon: Icons.close_rounded,
                color: AppColors.error,
                filled: false,
                onTap: () => _openRejectTopupSheet(req),
              ),
            ]
          : const [],
    );
  }

  Widget _receiptBlock(String url) {
    return Row(
      children: [
        _buildReceiptThumb(url),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إيصال التحويل',
                style: AppTypography.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'اضغط على الصورة للتكبير',
                style: AppTypography.cairo(
                  fontSize: 9.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// مصغّرة إيصال الشحن (رابط http أو data URL) مع نافذة تكبير باللمس
  Widget _buildReceiptThumb(String url) {
    return InkWell(
      onTap: () => _showReceiptZoom(url),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 56,
        height: 56,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceBright,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.outline),
        ),
        child: _receiptImage(url),
      ),
    );
  }

  Widget _receiptImage(String url) {
    if (url.startsWith('data:')) {
      final parts = url.split(',');
      if (parts.length < 2) return const Icon(Icons.broken_image_outlined);
      try {
        final bytes = base64Decode(parts.last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return const Icon(Icons.broken_image_outlined, size: 20);
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.broken_image_outlined, size: 20),
    );
  }

  void _showReceiptZoom(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: url.startsWith('data:')
                    ? _receiptImage(url)
                    : Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------- تبويب الشحن بالآيدي

  Widget _buildIdTopupToolTab(AdminProvider admin) {
    final List<ManualOrderModel> idLog = _idTopupLog(admin);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.badge_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'شحن رصيد مباشر ',
                        style: AppTypography.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'يصل الرصيد فورًا ويصل إشعار للعميل داخل التطبيق',
                        style: AppTypography.cairo(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sheetField(
                  _idUserIdCtrl,
                  'معرف العميل (User ID)',
                  Icons.badge_outlined,
                  hint: 'JGO26101512345',
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _idUserIdCtrl,
                  builder: (context, value, _) {
                    final String id = value.text.trim();
                    if (id.isEmpty) return const SizedBox.shrink();
                    // الآيدي القديمة كانت jgo صغيرة، فلا تفرقة بين الحروف
                    final bool valid = RegExp(
                      r'^JGO\d{11}$',
                      caseSensitive: false,
                    ).hasMatch(id);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            valid
                                ? Icons.verified_rounded
                                : Icons.info_outline_rounded,
                            size: 13,
                            color: valid
                                ? AppColors.accentGreen
                                : AppColors.ticketAmber,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              valid
                                  ? 'صيغة الآيدي صحيحة'
                                  : 'الصيغة المتوقعة: JGO متبوعة بـ 11 رقمًا',
                              style: AppTypography.cairo(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: valid
                                    ? AppColors.accentGreen
                                    : AppColors.ticketAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _sheetField(
                  _idAmountCtrl,
                  'المبلغ المراد إضافته (\$ USD)',
                  Icons.attach_money_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final v in const [5.0, 10.0, 25.0, 50.0])
                      GestureDetector(
                        onTap: () => setState(
                          () => _idAmountCtrl.text = v.toStringAsFixed(0),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDim,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: Text(
                            '+\$${v.toStringAsFixed(0)}',
                            style: AppTypography.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _sheetField(
                  _idDescCtrl,
                  'البيان / الوصف (يظهر للعميل في سجل الحساب)',
                  Icons.description_outlined,
                ),
                const SizedBox(height: 16),
                _sheetButton(
                  label: 'إتمام الشحن الفوري',
                  icon: Icons.bolt_rounded,
                  color: AppColors.primaryBlue,
                  onTap: _submitIdRecharge,
                ),
                const SizedBox(height: 8),
                Text(
                  'يُسجَّل الشحن في محفظة العميل ويظهر له فورًا في سجل العمليات.',
                  textAlign: TextAlign.center,
                  style: AppTypography.cairo(
                    fontSize: 9.5,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (idLog.isNotEmpty) ...[
            const SizedBox(height: 18),
            _listSectionLabel(
              Icons.history_rounded,
              'سجل الشحن ID',
              idLog.length,
            ),
            ...idLog.take(10).map(_buildTopupCard),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------- عناصر عامة

  Widget _filterChip(
    String key,
    String label,
    IconData icon,
    Color color,
    int count,
  ) {
    return _choiceChip(
      label: label,
      icon: icon,
      color: color,
      count: count,
      selected: _orderStatusFilter == key,
      onTap: () => setState(() => _orderStatusFilter = key),
    );
  }

  /// رقاقة اختيار موحّدة (فلاتر الطلبات وفلاتر سجل الشحن)
  Widget _choiceChip({
    required String label,
    required IconData icon,
    required Color color,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? color : AppColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: selected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: AppTypography.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listSectionLabel(IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '($count)',
            style: AppTypography.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool filled = true,
  }) {
    return Material(
      color: filled ? color : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: filled ? Colors.white : color),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: filled ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _copyButton(String value) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        _toast('تم نسخ البيانات', true);
      },
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Icon(
          Icons.copy_rounded,
          size: 12,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outline),
              ),
              child: Icon(icon, size: 27, color: AppColors.slate400),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
