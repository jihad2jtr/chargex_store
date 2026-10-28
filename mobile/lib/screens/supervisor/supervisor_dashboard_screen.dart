import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/manual_services_provider.dart';
import '../../widgets/digital_pass_card.dart';
import '../../widgets/status_pill.dart';
import '../user/manual_order_details_screen.dart';
import '../../widgets/unified_tactile_header.dart';
import '../../widgets/floating_role_dashboard_shield.dart';
import '../user/user_main_screen.dart';
import 'supervisor_services_screen.dart';

/// هوية الخدمات الحساسة (مشفّرة) — لا يوجد رمز لوني بنفسجي في AppColors،
/// ويُعرَّف هنا على مستوى الملف حتى تستخدمه كتلة بيانات العميل أيضاً.
const Color _violet = Color(0xFF7C3AED);
const Color _violetSoft = Color(0xFFEDE9FE);

class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  String _selectedFilter = 'all';
  Timer? _autoRefreshTimer;

  /// تذاكر الطلبات المفتوحة (تُفرد تفاصيلها عند النقر) — بمعرّف الطلب
  final Set<String> _openTickets = <String>{};

  /// مقاسات التذكرة الموحّدة في هذه الشاشة (نفس هوية بقية الصفحات)
  static const double _radius = 16;
  static const double _notch = 8;

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
    // الخدمات المسندة تُجلب مع كل سحب للتحديث حتى يبقى العدّاد صادقاً
    await provider.fetchAssignedServices(
      silent: provider.assignedServices.isNotEmpty,
    );
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
    final services = manualProvider.assignedServices;

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
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadOrders,
              color: AppColors.primaryBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const UnifiedTactileHeader(isDashboard: true),
                    const SizedBox(height: 12),

                    // 1. بطاقة واحدة مدمجة: الترحيب + حالة الطلبات (مساحة صغيرة)
                    _buildQueueTicket(
                      auth,
                      newCount: newCount,
                      inProgressCount: inProgressCount,
                      waitingClientCount: waitingClientCount,
                      issuesCount: issuesCount,
                      delayedCount: delayedCount,
                    ),
                    const SizedBox(height: 14),

                    // 2. بوابة صفحة الخدمات المسندة (انتقلت لشاشة مستقلة)
                    _buildServicesEntry(services),

                    const SizedBox(height: 18),

                    // Filter Chips
                    _buildFilterChips(),
                    const SizedBox(height: 12),

                    // Orders List Header
                    _sectionHeader(
                      'قائمة الطلبات',
                      'ORDERS · ${filteredOrders.length}',
                      trailing: manualProvider.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryBlue,
                              ),
                            )
                          : null,
                    ),
                    if (filteredOrders.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 8),
                        child: Text(
                          'انقر على التذكرة لفرد بيانات العميل وأزرار التنفيذ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cairo(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate400,
                          ),
                        ),
                      ),

                    // List of Orders
                    if (manualProvider.isLoading && allOrders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryBlue,
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
                            const SizedBox(height: 2),
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

  // ---------------------------------------------------------------------------
  // عناصر هوية التذكرة المشتركة (نفس مقاسات بقية صفحات النظام)
  // ---------------------------------------------------------------------------

  /// غلاف التذكرة: ظل + حد + قصّ بفتحتي تثقيب
  Widget _ticketShell({
    required Widget child,
    Color borderColor = AppColors.outline,
  }) {
    return CustomPaint(
      painter: TicketPassShadowPainter(
        cornerRadius: _radius,
        notchRadius: _notch,
        notchPositionFraction: 0.5,
        shadowColor: AppColors.slate900,
        elevation: 3,
      ),
      child: CustomPaint(
        foregroundPainter: TicketPassBorderPainter(
          cornerRadius: _radius,
          notchRadius: _notch,
          notchPositionFraction: 0.5,
          borderColor: borderColor,
          borderWidth: 1,
        ),
        child: ClipPath(
          clipper: TicketPassClipper(
            cornerRadius: _radius,
            notchRadius: _notch,
            notchPositionFraction: 0.5,
          ),
          child: Material(color: AppColors.surfaceCard, child: child),
        ),
      ),
    );
  }

  /// فاصل مثقّب أفقي (نقاط) بدل الخط الصلب
  Widget _dashedRule({Color color = AppColors.outlineVariant, double gap = 0}) {
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

  /// خط تثقيب رأسي يفصل جسم التذكرة عن كعبها
  Widget _verticalRule() {
    return SizedBox(
      width: 1,
      child: CustomPaint(
        painter: VerticalDashedLinePainter(
          color: AppColors.outlineVariant,
          dashHeight: 5,
          dashSpace: 4,
        ),
      ),
    );
  }

  /// شارة أيقونة متدرّجة بهوية التذكرة
  Widget _iconChip(Color color, IconData icon, {double size = 30}) {
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
            color: color.withValues(alpha: 0.28),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }

  /// عنوان قسم داخل الصفحة: شريط لوني + اسم + سطر تقني + خط مثقّب
  Widget _sectionHeader(String title, String code, {Widget? trailing}) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 13,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate700,
                ),
              ),
            ),
            if (trailing != null) ...[trailing, const SizedBox(width: 8)],
            Text(
              code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.technicalCode(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        _dashedRule(gap: 6),
      ],
    );
  }

  /// شارة صغيرة: أيقونة + نص (لا تضايق الاسم أبداً)
  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          // Flexible: النص الطويل يُقتطع بدل أن يفيض داخل Wrap التذاكر
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// سطر تنبيه داخل التذكرة بنغمة لونية
  Widget _note({
    required IconData icon,
    required String text,
    required Color color,
    Color? background,
    Color? border,
    int maxLines = 3,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border ?? color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// نسخة موحّدة للحافظة مع تأكيد مكتوب باسم العنصر
  void _copyText(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('تم نسخ $label للحافظة', style: AppTypography.cairo()),
          backgroundColor: AppColors.slate900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// بطاقة واحدة مدمجة: ترحيب المشرف + حالة طلبات الخدمات.
  /// اندمج كرت الترحيب والكونسول الكبير في تذكرة واحدة قصيرة:
  /// سطر هوية + فاصل مثقّب + شريط من 5 مؤشرات قابلة للنقر للفلترة.
  Widget _buildQueueTicket(
    AuthProvider auth, {
    required int newCount,
    required int inProgressCount,
    required int waitingClientCount,
    required int issuesCount,
    required int delayedCount,
  }) {
    final String name = auth.currentUser?.name ?? 'مشرف العمليات';
    return _ticketShell(
      borderColor: delayedCount > 0
          ? AppColors.rose.withValues(alpha: 0.45)
          : AppColors.primaryBlue.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // سطر الهوية المضغوط
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                _iconChip(
                  AppColors.primaryBlue,
                  Icons.engineering_rounded,
                  size: 28,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أهلاً بك، $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          color: AppColors.slate900,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        delayedCount > 0
                            ? 'SUPERVISOR · $delayedCount متأخر'
                            : 'SUPERVISOR · QUEUE ACTIVE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.technicalCode(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _chip(
                  Icons.workspace_premium_rounded,
                  'مقدم الخدمة',
                  delayedCount > 0 ? AppColors.rose : AppColors.emerald,
                ),
              ],
            ),
          ),
          _dashedRule(color: AppColors.outline),

          // شريط المؤشرات المضغوط (النقر يفلتر قائمة الطلبات بالأسفل)
          // IntrinsicHeight: التثقيب الرأسي يحتاج ارتفاعاً محدداً للتمدد
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _kpiCell(
                  label: 'جديدة',
                  value: newCount,
                  icon: Icons.mark_email_unread_rounded,
                  color: AppColors.primaryBlue,
                  filterKey: 'new',
                ),
                _verticalRule(),
                _kpiCell(
                  label: 'قيد التنفيذ',
                  value: inProgressCount,
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.secondaryBright,
                  filterKey: 'in_progress',
                ),
                _verticalRule(),
                _kpiCell(
                  label: 'بانتظار العميل',
                  value: waitingClientCount,
                  icon: Icons.pending_actions_rounded,
                  color: _violet,
                  filterKey: 'waiting_client',
                ),
                _verticalRule(),
                _kpiCell(
                  label: 'اعتراضات',
                  value: issuesCount,
                  icon: Icons.report_problem_rounded,
                  color: AppColors.rose,
                  filterKey: 'issues',
                ),
                _verticalRule(),
                _kpiCell(
                  label: 'متأخرة',
                  value: delayedCount,
                  icon: Icons.timer_off_rounded,
                  color: AppColors.errorLight,
                  filterKey: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// خلية مؤشر داخل شريط الحالة: أيقونة + رقم + تسمية، وتُظلَّل عند اختيارها
  Widget _kpiCell({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
    String? filterKey,
  }) {
    final bool active = filterKey != null && _selectedFilter == filterKey;
    return Expanded(
      child: InkWell(
        onTap: filterKey == null
            ? null
            : () =>
                  setState(() => _selectedFilter = active ? 'all' : filterKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          color: active ? color.withValues(alpha: 0.10) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // FittedBox: الرقم الطويل والأيقونة ينكمشان بدل أن يفيضا على 320dp
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 3),
                    Text(
                      '$value',
                      maxLines: 1,
                      style: AppTypography.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: value > 0 ? color : AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTypography.cairo(
                    fontSize: 8.5,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    color: active ? color : AppColors.slate500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // بوابة الخدمات المسندة: لمحة الحالة + فتح الشاشة المستقلة
  // ---------------------------------------------------------------------------

  /// بطاقة دخول مضغوطة لصفحة الخدمات المسندة — تذاكرها وأزرار إيقافها
  /// انتقلت إلى `SupervisorServicesScreen` حتى تبقى اللوحة عن الطلبات.
  Widget _buildServicesEntry(List<ProductModel> services) {
    final int activeCount = services.where((s) => s.isActive).length;
    final int suspendedCount = services.length - activeCount;

    return _ticketShell(
      borderColor: suspendedCount > 0
          ? AppColors.rose.withValues(alpha: 0.35)
          : AppColors.primaryBlue.withValues(alpha: 0.30),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SupervisorServicesScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              _iconChip(
                AppColors.primaryBlue,
                Icons.construction_rounded,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'خدماتي المسندة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (services.isEmpty)
                          _chip(
                            Icons.info_outline_rounded,
                            'لم تُسنَّد إليك خدمة بعد',
                            AppColors.slate500,
                          )
                        else ...[
                          _chip(
                            Icons.play_circle_fill_rounded,
                            '$activeCount متاحة للعملاء',
                            AppColors.emerald,
                          ),
                          if (suspendedCount > 0)
                            _chip(
                              Icons.pause_circle_filled_rounded,
                              '$suspendedCount موقوفة مؤقتاً',
                              AppColors.rose,
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'MY SERVICES · ${services.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.technicalCode(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: AppColors.slate400,
              ),
            ],
          ),
        ),
      ),
    );
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
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = f['key']!),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryBlue.withValues(alpha: 0.10)
                      : AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryBlue.withValues(alpha: 0.45)
                        : AppColors.outline,
                  ),
                ),
                child: Text(
                  f['label']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    color: isSelected
                        ? AppColors.primaryBlue
                        : AppColors.slate600,
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

  /// نص بيانات الطلب كنسخة جاهزة للحافظة (الحقول المشفّرة تُستثنى)
  String _orderDataForCopy(OrderModel order) {
    final String code =
        '#${order.orderNumber.isNotEmpty ? order.orderNumber : order.id.substring(order.id.length - 6)}';
    final lines = <String>[
      'رقم الطلب: $code',
      'الخدمة: ${order.productName}',
      'العميل: ${order.customerName ?? order.userId}',
      'القيمة: \$${order.amount.toStringAsFixed(2)}',
    ];
    for (final entry in order.accountInput.entries) {
      if (order.sensitiveFields.contains(entry.key)) continue;
      lines.add('${entry.key}: ${entry.value}');
    }
    return lines.join('\n');
  }

  /// معرّف تذكرة مفتوحة (يبقى ثابتاً بين التحديثات التلقائية)
  String _ticketKey(OrderModel order) => order.id;

  bool _isOpen(OrderModel order) => _openTickets.contains(_ticketKey(order));

  void _toggleTicket(OrderModel order) {
    final String key = _ticketKey(order);
    setState(() {
      if (!_openTickets.remove(key)) _openTickets.add(key);
    });
  }

  /// نصف تذكرة: فتحتا التثقيب مقتطعتان فعلياً على الحافة المشتركة للصف
  Widget _ticketSection({
    required bool top,
    required Color borderColor,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    final _TicketHalfClipper clipper = _TicketHalfClipper(top: top);
    return CustomPaint(
      // الحدّ وخط التثقيب يُرسمان على مسار الكليب نفسه بلا خطوط زائدة
      foregroundPainter: _TicketEdgePainter(
        clipper: clipper,
        color: borderColor,
      ),
      child: PhysicalShape(
        clipper: clipper,
        color: AppColors.surfaceCard,
        elevation: 1.2,
        shadowColor: AppColors.slate900.withValues(alpha: 0.08),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  /// تذكرة الطلب: رأس مضغوط (خدمة + حالة + قيمة) وشريط (عميل + مهلة + نسخ).
  /// باقي التفاصيل والأزرار لا يُبنى ولا يظهر إلا عند النقر على التذكرة.
  Widget _buildOrderCard(OrderModel order) {
    final bool open = _isOpen(order);
    final bool isDelayed = order.isDelayed && !order.isCompleted;
    final Color tint = isDelayed ? AppColors.rose : AppColors.primaryBlue;
    final Color borderColor = isDelayed
        ? AppColors.rose.withValues(alpha: 0.5)
        : (order.isCompleted
              ? AppColors.tertiaryLight.withValues(alpha: 0.4)
              : AppColors.outline);
    final String code =
        '#${order.orderNumber.isNotEmpty ? order.orderNumber : order.id.substring(order.id.length - 6)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ================= النصف العلوي: الرأس =================
          _ticketSection(
            top: true,
            borderColor: borderColor,
            onTap: () => _toggleTicket(order),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 8, 8, 6),
                child: Row(
                  children: [
                    _iconChip(
                      tint,
                      order.isSensitive
                          ? Icons.lock_rounded
                          : Icons.receipt_long_rounded,
                      size: 28,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  code,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.technicalCode(
                                    fontSize: 9.5,
                                    color: AppColors.slate500,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (order.isSensitive) ...[
                                const SizedBox(width: 5),
                                const Icon(
                                  Icons.lock_rounded,
                                  size: 11,
                                  color: _violet,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // المبلغ فوق شارة الحالة: لا يزيح الاسم ولا يفيض على 320dp
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 88),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '\$${order.amount.toStringAsFixed(2)}',
                              maxLines: 1,
                              style: AppTypography.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                color: AppColors.secondaryBright,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 88),
                          child: StatusPill(status: order.status),
                        ),
                      ],
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 17,
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ================= النصف السفلي: الشريط + التفاصيل =================
          _ticketSection(
            top: false,
            borderColor: borderColor,
            onTap: () => _toggleTicket(order),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(11, 6, 4, open ? 3 : 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: AppColors.slate500,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      flex: 5,
                      child: Text(
                        'العميل: ${order.customerName ?? order.userId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 10.5,
                          color: AppColors.slate600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(flex: 4, child: _deadlineBadge(order)),
                    IconButton(
                      tooltip: 'نسخ بيانات الطلب',
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color: AppColors.slate500,
                      ),
                      onPressed: () =>
                          _copyText('بيانات الطلب', _orderDataForCopy(order)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                    ),
                  ],
                ),
              ),

              // التفاصيل مُنشأة فقط أثناء الفرد: صفحة طويلة بقوائم كبيرة تبقى خفيفة
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: open
                    ? _buildOrderDetails(order)
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// شارة مهلة مضغوطة لسطر التذكرة المطوي (الصندوق الكامل يظهر عند الفرد)
  Widget _deadlineBadge(OrderModel order) {
    if (order.isCompleted) {
      return _chip(
        Icons.check_circle_rounded,
        'مكتمل',
        AppColors.tertiaryLight,
      );
    }
    final DateTime? deadline = order.deadlineAt;
    if (deadline == null) {
      return _chip(
        Icons.schedule_rounded,
        '${order.estimatedMinutes} د',
        AppColors.slate500,
      );
    }
    final Duration diff = deadline.difference(DateTime.now());
    if (diff.isNegative) {
      return _chip(
        Icons.alarm_off_rounded,
        'متأخر ${diff.inMinutes.abs()} د',
        AppColors.errorLight,
      );
    }
    if (diff.inHours > 0) {
      return _chip(
        Icons.timer_outlined,
        'متبقي ${diff.inHours} س ${diff.inMinutes % 60} د',
        AppColors.secondaryBright,
      );
    }
    return _chip(
      Icons.timer_outlined,
      'متبقي ${diff.inMinutes} د',
      AppColors.tertiaryLight,
    );
  }

  /// جسم التذكرة المخفي: بيانات العميل، المهلة الكاملة، الاعتراضات، والأزرار
  Widget _buildOrderDetails(OrderModel order) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 0, 11, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dashedRule(color: AppColors.outline),

          // بيانات إدخال العميل (مع إمكانية كشف الحقول الحساسة ونسخها)
          if (order.accountInput.isNotEmpty) ...[
            const SizedBox(height: 9),
            _CustomerInputBlock(order: order, onCopy: _copyText),
          ],

          const SizedBox(height: 9),

          // SLA / Deadline Counter Box
          _buildDeadlineIndicator(order),

          // اعتراض أو طلب تعديل من العميل
          if (order.isDisputed && order.disputeReason != null) ...[
            const SizedBox(height: 8),
            _note(
              icon: Icons.warning_amber_rounded,
              text: 'اعتراض مفتوح من العميل: ${order.disputeReason}',
              color: AppColors.errorLight,
              background: AppColors.errorContainer,
            ),
          ],
          if (order.isRevisionRequested && order.revisionNotes != null) ...[
            const SizedBox(height: 8),
            _note(
              icon: Icons.edit_note_rounded,
              text: 'العميل طلب تعديل: ${order.revisionNotes}',
              color: AppColors.secondaryBright,
              background: AppColors.secondaryContainer,
            ),
          ],

          // أزرار الإجراء في تذييل التذكرة
          _buildActionButtons(order),
        ],
      ),
    );
  }

  Widget _buildDeadlineIndicator(OrderModel order) {
    if (order.isCompleted) {
      return _note(
        icon: Icons.check_circle_rounded,
        text: 'تم استلام وتأكيد الطلب من العميل وإغلاقه بنجاح.',
        color: AppColors.tertiaryLight,
        background: AppColors.tertiaryContainer,
        border: AppColors.tertiary.withValues(alpha: 0.3),
        maxLines: 2,
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

    final textColor = isDelayed
        ? AppColors.errorLight
        : AppColors.tertiaryLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDelayed
            ? AppColors.errorContainer
            : AppColors.tertiaryContainer,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isDelayed ? Icons.alarm_off_rounded : Icons.timer_outlined,
            size: 15,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              deadlineText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            DateFormat('hh:mm a').format(order.createdAt),
            maxLines: 1,
            style: AppTypography.plusJakartaSans(
              fontSize: 10.5,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// تذييل التذكرة: أزرار الإجراءات. Wrap بدل Row حتى لا تفيض على 320dp
  Widget _buildActionButtons(OrderModel order) {
    final status = order.status;

    final List<Widget> actions = [
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
          foregroundColor: AppColors.primaryBlue,
          side: const BorderSide(color: AppColors.outlineVariant),
          backgroundColor: AppColors.surfaceDim,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ];

    if (status == 'assigned' || status == 'pending') {
      actions.add(
        OutlinedButton(
          onPressed: () => _showRejectDialog(order),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.errorLight,
            side: const BorderSide(color: AppColors.rose),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('رفض'),
        ),
      );
      actions.add(
        ElevatedButton(
          onPressed: () => _acceptOrder(order),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.tertiaryLight,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('قبول الطلب'),
        ),
      );
    } else if (status == 'accepted') {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => _startOrder(order),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('بدء التنفيذ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryBright,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    } else if (status == 'in_progress' || status == 'revision_requested') {
      actions.add(
        OutlinedButton(
          onPressed: () => _showRequestInfoDialog(order),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.secondaryBright,
            side: const BorderSide(color: AppColors.secondaryBright),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('طلب معلومات'),
        ),
      );
      actions.add(
        ElevatedButton.icon(
          onPressed: () => _showDeliverDialog(order),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('تسليم النتيجة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    } else if (status == 'info_requested') {
      actions.add(
        _inlineStatusNote(
          'بانتظار رد العميل بالمعلومات',
          AppColors.secondaryBright,
          AppColors.secondaryContainer,
        ),
      );
    } else if (status == 'delivered') {
      actions.add(
        _inlineStatusNote(
          'تم التسليم - بانتظار تأكيد العميل',
          _violet,
          _violetSoft,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: actions),
    );
  }

  /// حالة انتظار نصية توضع مكان أزرار الإجراء
  Widget _inlineStatusNote(String text, Color color, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.cairo(
          fontSize: 11.5,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
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

  /// حقل إدخال بنغمة التذكرة داخل النوافذ
  InputDecoration _dialogField(
    String hint, {
    String? label,
    Color accent = AppColors.primaryBlue,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      hintText: hint,
      labelText: label,
      isDense: true,
      hintStyle: AppTypography.cairo(fontSize: 12, color: AppColors.slate400),
      border: border(AppColors.outlineVariant),
      enabledBorder: border(AppColors.outlineVariant),
      focusedBorder: border(accent),
    );
  }

  /// نافذة إجراء بنمط التذكرة: شارة + عنوان + سطر تقني + خط مثقّب
  void _ticketFormDialog({
    required String title,
    required String code,
    required IconData icon,
    required Color accent,
    required String submitLabel,
    required Widget body,
    required void Function(BuildContext ctx) onSubmit,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.outline),
        ),
        titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        actionsPadding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        title: Row(
          children: [
            _iconChip(accent, icon, size: 28),
            const SizedBox(width: 9),
            // Expanded: العنوان العربي الطويل لا يطغى على حافة النافذة
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate900,
                    ),
                  ),
                  Text(
                    code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.technicalCode(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dashedRule(color: AppColors.outline),
              const SizedBox(height: 10),
              body,
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: AppTypography.cairo(color: AppColors.slate500),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => onSubmit(ctx),
            child: Text(
              submitLabel,
              style: AppTypography.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(OrderModel order) {
    final reasonCtrl = TextEditingController();
    _ticketFormDialog(
      title: 'رفض استلام الطلب',
      code: 'REJECT · ORDER',
      icon: Icons.warning_amber_rounded,
      accent: AppColors.errorLight,
      submitLabel: 'تأكيد الرفض',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'يرجى توضيح سبب الرفض لإبلاغ الإدارة لإعادة إسناد الطلب لمشرف آخر:',
            style: AppTypography.cairo(
              fontSize: 12.5,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            style: AppTypography.cairo(fontSize: 13),
            decoration: _dialogField(
              'مثال: ضغط عمل حالي / عدم توفر المتطلبات الفنية...',
              accent: AppColors.errorLight,
            ),
          ),
        ],
      ),
      onSubmit: (ctx) async {
        final reason = reasonCtrl.text.trim();
        if (reason.isEmpty) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(
                'يرجى إدخال سبب الرفض',
                style: AppTypography.cairo(),
              ),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'تم تسجيل رفض الطلب وإبلاغ الإدارة'
                  : (provider.errorMessage ?? 'فشل رفض الطلب'),
              style: AppTypography.cairo(),
            ),
            backgroundColor: ok ? AppColors.slate900 : AppColors.errorLight,
          ),
        );
      },
    );
  }

  void _showRequestInfoDialog(OrderModel order) {
    final noteCtrl = TextEditingController();
    _ticketFormDialog(
      title: 'طلب معلومات إضافية',
      code: 'INFO REQUEST · ORDER',
      icon: Icons.help_outline_rounded,
      accent: AppColors.secondaryBright,
      submitLabel: 'إرسال للعميل',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أدخل الاستفسار أو المتطلبات الناقصة لإرسالها للعميل:',
            style: AppTypography.cairo(
              fontSize: 12.5,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            maxLines: 4,
            style: AppTypography.cairo(fontSize: 13),
            decoration: _dialogField(
              'مثال: يرجى تزويدنا برقم الهاتف لتأكيد الحساب أو رمز التحقق...',
              accent: AppColors.secondaryBright,
            ),
          ),
        ],
      ),
      onSubmit: (ctx) async {
        final note = noteCtrl.text.trim();
        if (note.isEmpty) return;
        Navigator.pop(ctx);
        final provider = Provider.of<ManualServicesProvider>(
          context,
          listen: false,
        );
        final ok = await provider.supervisorRequestInfo(order.id, note);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'تم إرسال طلب المعلومات للعميل بنجاح'
                  : (provider.errorMessage ?? 'تعذر إرسال الطلب'),
              style: AppTypography.cairo(),
            ),
            backgroundColor: ok ? AppColors.slate900 : AppColors.errorLight,
          ),
        );
      },
    );
  }

  void _showDeliverDialog(OrderModel order) {
    final notesCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final backupCtrl = TextEditingController();
    final extraCtrl = TextEditingController();

    _ticketFormDialog(
      title: 'تسليم نتيجة الخدمة',
      code: 'DELIVER · ORDER',
      icon: Icons.verified_rounded,
      accent: AppColors.tertiaryLight,
      submitLabel: 'تأكيد وتسليم للعميل',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملاحظات التسليم للعميل:',
            style: AppTypography.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.slate700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            style: AppTypography.cairo(fontSize: 13),
            decoration: _dialogField('تم إنشاء الحساب وضبط الإعدادات بنجاح...'),
          ),
          const SizedBox(height: 14),

          // بيانات الاعتماد المشفّرة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceDim,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.security_rounded,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'البيانات السرية (تشفير AES-256 تلقائي)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'سيتم تشفير هذه البيانات فوراً ولن تظهر في الإشعارات، وتُحذف نهائياً بعد استلام العميل.',
                  style: AppTypography.cairo(
                    fontSize: 11,
                    color: AppColors.slate500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  style: AppTypography.cairo(fontSize: 13),
                  decoration: _dialogField(
                    '',
                    label: 'البريد الإلكتروني / اسم المستخدم',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  style: AppTypography.cairo(fontSize: 13),
                  decoration: _dialogField('', label: 'كلمة المرور'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: backupCtrl,
                  style: AppTypography.cairo(fontSize: 13),
                  decoration: _dialogField(
                    '',
                    label: 'البريد البديل / رمز الاسترداد (اختياري)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: extraCtrl,
                  style: AppTypography.cairo(fontSize: 13),
                  decoration: _dialogField(
                    '',
                    label: 'أي بيانات إضافية (اختياري)',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      onSubmit: (ctx) async {
        final notes = notesCtrl.text.trim();
        final email = emailCtrl.text.trim();
        final pass = passCtrl.text.trim();

        Map<String, dynamic>? credentials;
        if (email.isNotEmpty || pass.isNotEmpty) {
          credentials = {};
          if (email.isNotEmpty) credentials['email'] = email;
          if (pass.isNotEmpty) credentials['password'] = pass;
          if (backupCtrl.text.trim().isNotEmpty) {
            credentials['recovery'] = backupCtrl.text.trim();
          }
          if (extraCtrl.text.trim().isNotEmpty) {
            credentials['notes'] = extraCtrl.text.trim();
          }
        }

        Navigator.pop(ctx);
        final provider = Provider.of<ManualServicesProvider>(
          context,
          listen: false,
        );
        final ok = await provider.supervisorDeliverOrder(
          orderId: order.id,
          resultNotes: notes.isNotEmpty ? notes : 'تم إنجاز الخدمة بنجاح.',
          credentials: credentials,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'تم تسليم الخدمة بنجاح إلى العميل وبانتظار تأكيده'
                  : (provider.errorMessage ?? 'تعذر تسليم الخدمة'),
              style: AppTypography.cairo(),
            ),
            backgroundColor: ok
                ? AppColors.tertiaryLight
                : AppColors.errorLight,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return _ticketShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _iconChip(AppColors.primaryBlue, Icons.inbox_rounded, size: 52),
            const SizedBox(height: 14),
            Text(
              'لا توجد طلبات في هذا التصنيف',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'سيتم إشعارك فور إسناد أي طلب يدوي جديد إليك',
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 12,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// يعرض بيانات إدخال العميل في بطاقة المشرف مع إخفاء الحقول الحساسة
/// وإتاحة كشفها/نسخها عند الحاجة لتنفيذ الخدمة.
class _CustomerInputBlock extends StatefulWidget {
  final OrderModel order;
  final void Function(String label, String value) onCopy;

  const _CustomerInputBlock({required this.order, required this.onCopy});

  @override
  State<_CustomerInputBlock> createState() => _CustomerInputBlockState();
}

class _CustomerInputBlockState extends State<_CustomerInputBlock> {
  Map<String, dynamic>? _decrypted;
  bool _isRevealing = false;

  bool _isSensitiveField(String key) =>
      widget.order.sensitiveFields.contains(key);

  Future<void> _reveal() async {
    setState(() => _isRevealing = true);
    final provider = Provider.of<ManualServicesProvider>(
      context,
      listen: false,
    );
    final res = await provider.fetchDecryptedInput(widget.order.id);
    if (!mounted) return;
    setState(() {
      _isRevealing = false;
      final input = res?['accountInput'];
      if (input is Map) {
        _decrypted = Map<String, dynamic>.from(input);
      }
    });
    if (_decrypted == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'تعذر كشف البيانات',
            style: AppTypography.cairo(),
          ),
          backgroundColor: AppColors.errorLight,
        ),
      );
    }
  }

  /// القيمة القابلة للنسخ: الحقول المشفّرة لا تُنسخ إلا بعد الكشف عنها
  String _copyValue(String key) {
    if (_isSensitiveField(key)) {
      return _decrypted == null ? '' : '${_decrypted?[key] ?? ''}';
    }
    return '${widget.order.accountInput[key] ?? ''}';
  }

  void _copyAll() {
    final String text = widget.order.accountInput.entries
        .map((e) => '${e.key}: ${_copyValue(e.key)}')
        .where((line) => !line.endsWith(': '))
        .join('\n');
    widget.onCopy('بيانات العميل', text);
  }

  /// سطر بيانات: المفتوح فوق القيمة مع زر نسخ بجانبها
  Widget _inputRow(String key, String displayValue, {required bool dimmed}) {
    final String value = _copyValue(key);
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 10,
                    color: AppColors.slate500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (value.isNotEmpty)
                IconButton(
                  tooltip: 'نسخ $key',
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: AppColors.slate500,
                  ),
                  onPressed: () => widget.onCopy(key, value),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                ),
            ],
          ),
          Text(
            displayValue,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: dimmed ? FontWeight.w600 : FontWeight.w700,
              color: dimmed ? AppColors.slate400 : AppColors.slate900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.order.accountInput.entries.toList();
    final hasSensitive = widget.order.sensitiveFields.isNotEmpty;
    final revealed = _decrypted != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_ind_outlined,
                size: 15,
                color: AppColors.slate500,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'بيانات إدخال العميل',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate600,
                  ),
                ),
              ),
              if (hasSensitive)
                TextButton.icon(
                  onPressed: _isRevealing ? null : _reveal,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: _isRevealing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _violet,
                          ),
                        )
                      : Icon(
                          revealed
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 16,
                          color: _violet,
                        ),
                  label: Text(
                    revealed ? 'إخفاء' : 'كشف',
                    style: AppTypography.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: _violet,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'نسخ كل البيانات',
                icon: const Icon(
                  Icons.content_copy_rounded,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
                onPressed: _copyAll,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
              ),
            ],
          ),
          // كل سطر بارتفاعه الكامل: لا تضايق على عرض المفتاح كما كان سابقاً
          for (final entry in entries)
            _isSensitiveField(entry.key)
                ? _inputRow(
                    entry.key,
                    revealed
                        ? '${_decrypted?[entry.key] ?? '••••••••'}'
                        : '••••••••',
                    dimmed: !revealed,
                  )
                : _inputRow(entry.key, '${entry.value}', dimmed: false),
        ],
      ),
    );
  }
}

// =============================================================================
// TICKET HALF CLIPPER — فتحتا التذكرة المقتطعتان فعلياً على خط الطية
// =============================================================================

/// نصف كرت التذكرة: زوايا مستديرة على الحافة الخارجية، ونصفا فتحة دائرية
/// مقتطعان من الحافتين عند خط التثقيب. يُستعمل نصفان متقابلان (علوي للرأس
/// وسفلي للتفاصيل)، فيكتمل الثقب دائرة كاملة **مهما تغيّر ارتفاع الكرت**
/// مطوياً كان أو مفرداً، بلا حاجة لقياس ارتفاع الرأس.
class _TicketHalfClipper extends CustomClipper<Path> {
  /// زاوية الكرت
  static const double corner = 14;

  /// نصف قطر الفتحة الجانبية
  static const double notch = 8;

  final bool top;

  const _TicketHalfClipper({required this.top});

  @override
  Path getClip(Size size) => _ticketHalfFillPath(size, top: top);

  @override
  bool shouldReclip(_TicketHalfClipper oldClipper) => oldClipper.top != top;
}

/// مسار الملء: مغلق مع الحدّ المشترك (الخط المستقيم عند خط التثقيب).
Path _ticketHalfFillPath(Size size, {required bool top}) {
  final double w = size.width;
  final double h = size.height;
  final double r = _TicketHalfClipper.corner;
  final double n = _TicketHalfClipper.notch;
  final Path path = Path();

  if (top) {
    path
      ..moveTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, h - n)
      // نصف الفتحة الأيمن: قوس يتجه للداخل
      ..arcToPoint(
        Offset(w - n, h),
        radius: Radius.circular(n),
        clockwise: false,
      )
      ..lineTo(n, h)
      ..arcToPoint(
        Offset(0, h - n),
        radius: Radius.circular(n),
        clockwise: false,
      )
      ..close();
  } else {
    path
      ..moveTo(0, n)
      ..arcToPoint(Offset(n, 0), radius: Radius.circular(n), clockwise: false)
      ..lineTo(w - n, 0)
      ..arcToPoint(Offset(w, n), radius: Radius.circular(n), clockwise: false)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..close();
  }
  return path;
}

/// مسار الحدّ (للرسم فقط): بلا الحدّ المشترك كي لا يُرسم خط صلب مكان التثقيب.
Path _ticketHalfEdgePath(Size size, {required bool top}) {
  final double w = size.width;
  final double h = size.height;
  final double r = _TicketHalfClipper.corner;
  final double n = _TicketHalfClipper.notch;
  final Path path = Path();

  if (top) {
    path
      ..moveTo(n, h)
      ..arcToPoint(
        Offset(0, h - n),
        radius: Radius.circular(n),
        clockwise: false,
      )
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, h - n)
      ..arcToPoint(
        Offset(w - n, h),
        radius: Radius.circular(n),
        clockwise: false,
      );
  } else {
    path
      ..moveTo(w - n, 0)
      ..arcToPoint(Offset(w, n), radius: Radius.circular(n), clockwise: false)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, n)
      ..arcToPoint(Offset(n, 0), radius: Radius.circular(n), clockwise: false);
  }
  return path;
}

/// يرسم حدّ النصف على مسار الكليب نفسه، وخط التثقيب المتقطع بين الفتحتين.
class _TicketEdgePainter extends CustomPainter {
  final _TicketHalfClipper clipper;
  final Color color;

  const _TicketEdgePainter({required this.clipper, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _ticketHalfEdgePath(size, top: clipper.top),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );

    // خط التثقيب يُرسم من النصف العلوي فقط، عند الحدّ المشترك
    if (!clipper.top) return;
    final double n = _TicketHalfClipper.notch;
    final Paint dash = Paint()
      ..color = AppColors.outlineVariant
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final double y = size.height - 1;
    final double end = size.width - n - 4;
    for (double x = n + 4; x < end; x += 7.5) {
      final double x2 = x + 4 > end ? end : x + 4;
      canvas.drawLine(Offset(x, y), Offset(x2, y), dash);
    }
  }

  @override
  bool shouldRepaint(_TicketEdgePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.clipper.top != clipper.top;
}
