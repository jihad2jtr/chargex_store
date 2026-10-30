import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_icon_assets.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_model.dart';
import '../../models/order_model.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/app_catalog_provider.dart';
import '../../providers/virtual_numbers_provider.dart';
import '../../widgets/app_thumb.dart';
import '../../widgets/status_pill.dart';
import 'app_products_screen.dart';
import 'manual_order_details_screen.dart';

class OrdersHistoryScreen extends StatefulWidget {
  final bool showAppBar;
  const OrdersHistoryScreen({super.key, this.showAppBar = true});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  String _selectedFilter = 'all';

  /// فلتر نوع الخدمة: all / app / game / service / number — طبقة مستقلّة عن
  /// فلتر الحالة، وفوقه شريط «الكل/قيد الانتظار/...» كما كان.
  String _selectedKind = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _autoRefreshTimer;

  /// مفاتيح التذاكر الفردة تفاصيلها — القائمة مطوية افتراضياً كي تكون أقصر
  final Set<String> _openTickets = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppCatalogProvider>(context, listen: false).fetchMyOrders();
      // سجل الأرقام الوهمية مدمج هنا (لم يعد له سجل منعزل في صفحة الأرقام)
      Provider.of<VirtualNumbersProvider>(
        context,
        listen: false,
      ).fetchMyRequests();
    });

    // Auto-refresh orders every 15 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        Provider.of<AppCatalogProvider>(context, listen: false).fetchMyOrders();
        Provider.of<VirtualNumbersProvider>(
          context,
          listen: false,
        ).fetchMyRequests(quiet: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// أيقونة المنتج في التذكرة: الأيقونة المربعة (assets/icons) أولاً —
  /// من المسار المخزّن أو مستنتجة من الاسم — فلا تُعرض بطاقة عريضة
  /// مقتطعة في مربّع صغير، وتقع الصورة المخزّنة للمنتجات المجهولة فقط.
  AppItemModel _orderAppItem(OrderModel order) {
    final String stored = (order.appIcon ?? '').trim();
    final String? icon =
        iconAssetForApp(iconUrl: stored, name: order.appName) ??
        builtinIconAssetForName(order.appName);
    return AppItemModel(
      id: order.appId,
      name: order.appName,
      iconUrl: icon ?? stored,
    );
  }

  void _copyOrderSummary(OrderModel order) {
    final sb = StringBuffer();
    sb.writeln('🎟️ تذكرة طلب: #${order.orderNumber}');
    sb.writeln('📱 التطبيق: ${order.appName}');
    sb.writeln('📦 الباقة: ${order.productName}');
    sb.writeln('💰 السعر: \$${order.amount.toStringAsFixed(2)} USD');
    sb.writeln('📊 الحالة: ${order.status}');
    if (order.accountInput.isNotEmpty) {
      sb.writeln('📋 بيانات الشحن:');
      order.accountInput.forEach((key, val) {
        sb.writeln('   • $key: $val');
      });
    }
    if (order.deliveredCode != null && order.deliveredCode!.isNotEmpty) {
      sb.writeln('🔑 الكود المستلم: ${order.deliveredCode}');
    }
    sb.writeln(
      '🕒 التاريخ: ${DateFormat('yyyy/MM/dd hh:mm a').format(order.createdAt)}',
    );
    sb.writeln('⚡ متجر JGO Store');

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ ملخص التذكرة للحافظة بنجاح 📋',
          style: AppTypography.cairo(),
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reorderApp(OrderModel order, AppCatalogProvider catalog) {
    AppItemModel? targetApp;
    try {
      targetApp = catalog.apps.firstWhere((a) => a.id == order.appId);
    } catch (_) {
      try {
        targetApp = catalog.apps.firstWhere(
          (a) =>
              a.name.trim().toLowerCase() ==
                  order.appName.trim().toLowerCase() ||
              a.name.contains(order.appName) ||
              order.appName.contains(a.name),
        );
      } catch (_) {
        targetApp = AppItemModel(
          id: order.appId,
          name: order.appName,
          iconUrl: order.appIcon ?? '',
        );
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AppProductsScreen(app: targetApp!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = Provider.of<AppCatalogProvider>(context);
    final numbers = Provider.of<VirtualNumbersProvider>(context);
    final allOrders = catalog.myOrders;

    // سجل الأرقام الوهمية مدمج في «طلباتي»: الرقم الحيّ يُدار من صفحة
    // الأرقام، وهنا تُعرض الأرقام المنتهية كتذاكر مثل بقية الطلبات.
    final numberHistory = numbers.myRequests.where((r) => !r.isLive).toList()
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );

    // عدد كل نوع (بلا فلترة) لشريط الأنواع
    final appCount = allOrders.where((o) => o.serviceKind == 'app').length;
    final gameCount = allOrders.where((o) => o.serviceKind == 'game').length;
    final serviceCount = allOrders
        .where((o) => o.serviceKind == 'service')
        .length;
    final numberCount = numberHistory.length;

    // إبقاء العناصر بترتيبها الزمني المختلط: الطلبات والأرقام تُزمن معاً
    final entries = <_HistoryRow>[
      ...allOrders.map((o) => _HistoryRow.order(o, o.createdAt)),
      ...numberHistory.map(
        (r) => _HistoryRow.number(r, r.createdAt ?? DateTime(0)),
      ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    // Filter calculations
    final completedCount = allOrders
        .where((o) => o.isCompleted || o.isDelivered)
        .length;
    final pendingCount = allOrders
        .where(
          (o) => o.isPending || o.isInProgress || o.isAccepted || o.isAssigned,
        )
        .length;
    final manualCount = allOrders.where((o) => o.isManual).length;
    final rejectedCount = allOrders
        .where((o) => o.isRejected || o.isDisputed)
        .length;
    final totalSpent = allOrders
        .where((o) => o.isCompleted || o.isDelivered)
        .fold(0.0, (sum, o) => sum + o.amount);

    final filtered = entries.where((row) => _passesFilter(row)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 1,
              centerTitle: false,
              title: Text(
                'طلباتي وتذاكر الشحن الرقمية',
                style: AppTypography.cairo(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  tooltip: 'تحديث الطلبات',
                  onPressed: () {
                    catalog.fetchMyOrders();
                    numbers.fetchMyRequests();
                  },
                ),
                const SizedBox(width: 10),
              ],
            )
          : null,
      body: RefreshIndicator(
        color: const Color(0xFF0F172A),
        onRefresh: () async {
          await catalog.fetchMyOrders();
          await numbers.fetchMyRequests();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          children: [
            // 1. Compact stats bar
            _buildExecutiveSummaryBanner(
              totalOrders: allOrders.length + numberHistory.length,
              completedCount: completedCount,
              pendingCount: pendingCount,
              totalSpent: totalSpent,
            ),
            const SizedBox(height: 9),

            // 2. Real-time Search Input
            _buildSearchBar(),
            const SizedBox(height: 8),

            // 3. Type filter (أرقام/تطبيقات/ألعاب/خدمات)
            _buildKindChips(
              totalCount: entries.length,
              appCount: appCount,
              gameCount: gameCount,
              serviceCount: serviceCount,
              numberCount: numberCount,
            ),
            const SizedBox(height: 8),

            // 4. Tactile Filter Pills (الحالة)
            _buildFilterChips(
              totalCount: allOrders.length,
              completedCount: completedCount,
              pendingCount: pendingCount,
              manualCount: manualCount,
              rejectedCount: rejectedCount,
            ),
            const SizedBox(height: 11),

            // 5. Merged list or Empty State
            if (filtered.isEmpty)
              _buildEmptyState(entries.isEmpty)
            else
              ...filtered.map((row) {
                final dateStr = DateFormat(
                  'yyyy/MM/dd • hh:mm a',
                ).format(row.at);
                return switch (row) {
                  _OrderHistoryRow(:final order) => _buildOrderTicket(
                    order,
                    dateStr,
                    catalog,
                  ),
                  _NumberHistoryRow(:final request) => _buildNumberTicket(
                    request,
                    dateStr,
                  ),
                };
              }),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// يطبّق فلتر الحالة + فلتر النوع + البحث على صف مدمج (طلب أو رقم)
  bool _passesFilter(_HistoryRow row) {
    // 1. Status filter
    if (_selectedFilter != 'all') {
      if (row case _OrderHistoryRow(:final order)) {
        if (_selectedFilter == 'completed') {
          if (!order.isCompleted && !order.isDelivered) return false;
        } else if (_selectedFilter == 'pending') {
          if (!order.isPending &&
              !order.isInProgress &&
              !order.isAccepted &&
              !order.isAssigned) {
            return false;
          }
        } else if (_selectedFilter == 'manual') {
          if (!order.isManual) return false;
        } else if (_selectedFilter == 'rejected') {
          if (!order.isRejected && !order.isDisputed) return false;
        }
      } else {
        // الأرقام: الرقم المنتهي لا يُعدّ قيد الانتظار/مرفوضاً في الفلترة اليدوية
        if (_selectedFilter == 'pending' || _selectedFilter == 'manual') {
          return false;
        }
      }
    }

    // 2. Type filter
    if (_selectedKind != 'all' && row.kind != _selectedKind) return false;

    // 3. Search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      if (row case _OrderHistoryRow(:final order)) {
        final matchNum = order.orderNumber.toLowerCase().contains(q);
        final matchApp = order.appName.toLowerCase().contains(q);
        final matchProd = order.productName.toLowerCase().contains(q);
        final matchInputs = order.accountInput.values.any(
          (v) => v.toString().toLowerCase().contains(q),
        );
        final matchCode = (order.deliveredCode ?? '').toLowerCase().contains(q);
        if (!matchNum &&
            !matchApp &&
            !matchProd &&
            !matchInputs &&
            !matchCode) {
          return false;
        }
      } else if (row case _NumberHistoryRow(:final request)) {
        final haystack = <String>[
          request.requestNumber,
          request.title,
          request.countryName,
          request.phoneNumber ?? '',
          request.smsCode ?? '',
        ];
        if (!haystack.any((v) => v.toLowerCase().contains(q))) return false;
      }
    }

    return true;
  }

  // ===========================================================================
  // 1. COMPACT STATS BAR
  // ===========================================================================
  Widget _buildExecutiveSummaryBanner({
    required int totalOrders,
    required int completedCount,
    required int pendingCount,
    required double totalSpent,
  }) {
    // شريط إحصاء واحد بدل لوحة bento: نفس الأرقام بربع الارتفاع
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E1B4B)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatPill(
            label: 'الإجمالي',
            value: '$totalOrders',
            color: Colors.white,
            icon: Icons.confirmation_number_outlined,
          ),
          _buildStatDivider(),
          _buildStatPill(
            label: 'مكتملة',
            value: '$completedCount',
            color: const Color(0xFF34D399),
            icon: Icons.check_circle_outline_rounded,
          ),
          _buildStatDivider(),
          _buildStatPill(
            label: 'قيد التنفيذ',
            value: '$pendingCount',
            color: const Color(0xFFFBBF24),
            icon: Icons.hourglass_top_rounded,
          ),
          _buildStatDivider(),
          _buildStatPill(
            label: 'المصروف',
            value: '\$${totalSpent.toStringAsFixed(1)}',
            color: const Color(0xFF38BDF8),
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.technicalCode(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppTypography.cairo(color: Colors.white70, fontSize: 8.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 18,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }

  // ===========================================================================
  // TICKET EXPANSION STATE — القائمة قصيرة والتفاصيل عند الطلب
  // ===========================================================================
  String _ticketKey(OrderModel order) =>
      order.id.isNotEmpty ? order.id : order.orderNumber;

  bool _isOpen(OrderModel order) => _openTickets.contains(_ticketKey(order));

  void _toggleTicket(OrderModel order) {
    setState(() {
      final String key = _ticketKey(order);
      if (!_openTickets.remove(key)) _openTickets.add(key);
    });
  }

  // ===========================================================================
  // 2. SEARCH BAR
  // ===========================================================================
  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: AppTypography.cairo(fontSize: 11.5),
        decoration: InputDecoration(
          hintText: 'ابحث برقم الطلب أو ID',
          hintStyle: AppTypography.cairo(
            fontSize: 11,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 17,
            color: Color(0xFF64748B),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: Color(0xFF94A3B8),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 9,
            horizontal: 9,
          ),
        ),
        onChanged: (val) {
          setState(() => _searchQuery = val);
        },
      ),
    );
  }

  // ===========================================================================
  // 3. FILTER CHIPS
  // ===========================================================================
  Widget _buildFilterChips({
    required int totalCount,
    required int completedCount,
    required int pendingCount,
    required int manualCount,
    required int rejectedCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip('all', 'الكل', totalCount, Icons.dashboard_outlined),
          const SizedBox(width: 8),
          _buildFilterChip(
            'pending',
            'قيد الانتظار',
            pendingCount,
            Icons.hourglass_top_rounded,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'completed',
            'مكتملة',
            completedCount,
            Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'manual',
            'خدمات يدوية',
            manualCount,
            Icons.support_agent_outlined,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'rejected',
            'مرفوضة',
            rejectedCount,
            Icons.cancel_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, int count, IconData icon) {
    final isSelected = _selectedFilter == key;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = key;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F172A)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.015),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11.5,
              color: isSelected
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$count',
                style: AppTypography.technicalCode(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. ORDER TICKET — صف مدمج قابل لفرد التفاصيل
  // ===========================================================================
  Widget _buildOrderTicket(
    OrderModel order,
    String dateStr,
    AppCatalogProvider catalog,
  ) {
    final bool open = _isOpen(order);
    final Color borderColor = order.isCompleted
        ? const Color(0xFF10B981).withValues(alpha: 0.25)
        : (order.isRejected
              ? const Color(0xFFEF4444).withValues(alpha: 0.25)
              : const Color(0xFFE2E8F0));
    // الخدمة اليدوية تفتح شاشة تفاصيلها، وبقية التذاكر تفرد/تطوى
    final VoidCallback onTap = order.isManual
        ? () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => ManualOrderDetailsScreen(order: order),
                  ),
                )
                .then((_) => catalog.fetchMyOrders());
          }
        : () => _toggleTicket(order);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===============================================================
          // PASS HEAD — النصف العلوي من التذكرة: نصفا الفتحة على حافته
          // ===============================================================
          _ticketSection(
            top: true,
            borderColor: borderColor,
            onTap: onTap,
            children: [
              // ===============================================================
              // PASS HEAD: فن + عنوان + سعر/حالة + مؤشر الفرد
              // ===============================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 8, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // App / Game Icon — أيقونة مربعة لا صورة بطاقة
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: AppThumb(
                        app: _orderAppItem(order),
                        size: 36,
                        radius: 8,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Titles & Product Info
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
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Flexible(
                                flex: 3,
                                child: Text(
                                  order.appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.cairo(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              // الشارة تنكمش مع الاسم بدل أن تُدفع خارج التذكرة
                              Flexible(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    order.type == 'codes'
                                        ? 'كود  🎟️'
                                        : (order.isManual
                                              ? 'خدمة يدوية 🛡️'
                                              : ' فوري ⚡'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.cairo(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Price & Status: عمود بعرض ثابت كي لا يبتلع مكان العنوان،
                    // و FittedBox يصغّر النص على الشاشات الضيقة
                    SizedBox(
                      width: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text(
                              '\$${order.amount.toStringAsFixed(2)}',
                              style: AppTypography.price(
                                fontSize: 13.5,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerEnd,
                            child: StatusPill(status: order.status),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 2),

                    // مؤشر فرد/طي تفاصيل التذكرة
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        size: 17,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ===============================================================
          // PASS BOTTOM — النصف السفلي: الميتا والتفاصيل (يكمل الفتحتين)
          // ===============================================================
          _ticketSection(
            top: false,
            borderColor: borderColor,
            onTap: onTap,
            children: [
              // ===============================================================
              // META LINE: رقم التذكرة + التاريخ + إشارة الكود المسلَّم
              // ===============================================================
              Padding(
                padding: EdgeInsets.fromLTRB(11, 6, 11, open ? 2 : 9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // رقم التذكرة — ينسخ بضغطة ولا يطرد بقية العناصر
                    Flexible(
                      flex: 5,
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: order.orderNumber),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم نسخ رقم التذكرة: #${order.orderNumber}',
                                style: AppTypography.cairo(),
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.tag_rounded,
                              size: 10,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'TKT #${order.orderNumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.technicalCode(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.copy_rounded,
                              size: 8,
                              color: Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // التاريخ والوقت
                    Flexible(
                      flex: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 10,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              dateStr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.plusJakartaSans(
                                fontSize: 9,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((order.deliveredCode ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      // إشارة موجزة: يوجد كود مستلم داخل التفاصيل
                      Flexible(
                        flex: 3,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.vpn_key_rounded,
                              size: 10,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                open ? 'كود داخل' : 'كود مُسلَّم',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cairo(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // التفاصيل تُطوى افتراضياً كي تبقى قائمة السجل قصيرة
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: open
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ===============================================================
                          // PASS BOTTOM: بيانات الحساب، الكود، والمُخرجات عند الفرد
                          // ===============================================================
                          Padding(
                            padding: const EdgeInsets.fromLTRB(11, 1, 11, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Player / Account Inputs Grid
                                if (order.accountInput.isNotEmpty) ...[
                                  const SizedBox(height: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.badge_outlined,
                                              size: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'بيانات الحساب المدخلة للشحن:',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.cairo(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(
                                                    0xFF475569,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        // كل رقاقة تنحصر داخل عرض الصندوق حتى لا تفيض
                                        // معرّفات IDs الطويلة على حدود التذكرة
                                        LayoutBuilder(
                                          builder: (context, inner) {
                                            return Wrap(
                                              spacing: 6,
                                              runSpacing: 3,
                                              children: order.accountInput.entries.map((
                                                entry,
                                              ) {
                                                return ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxWidth:
                                                        inner.maxWidth.isFinite
                                                        ? inner.maxWidth
                                                        : double.infinity,
                                                  ),
                                                  child: InkWell(
                                                    onTap: () {
                                                      Clipboard.setData(
                                                        ClipboardData(
                                                          text: entry.value
                                                              .toString(),
                                                        ),
                                                      );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'تم نسخ ${entry.key}: ${entry.value}',
                                                            style:
                                                                AppTypography.cairo(),
                                                          ),
                                                          duration:
                                                              const Duration(
                                                                seconds: 1,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFFCBD5E1,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Flexible(
                                                            flex: 2,
                                                            child: Text(
                                                              '${entry.key}: ',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: AppTypography.cairo(
                                                                fontSize: 9.5,
                                                                color:
                                                                    const Color(
                                                                      0xFF64748B,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                          Flexible(
                                                            flex: 3,
                                                            child: Text(
                                                              '${entry.value}',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: AppTypography.technicalCode(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    const Color(
                                                                      0xFF0F172A,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 3,
                                                          ),
                                                          const Icon(
                                                            Icons.copy_rounded,
                                                            size: 8,
                                                            color: Color(
                                                              0xFF94A3B8,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Digital Code Voucher Scratch-Box (if codes product)
                                if (order.deliveredCode != null &&
                                    order.deliveredCode!.isNotEmpty) ...[
                                  const SizedBox(height: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFFBEB),
                                          Color(0xFFFEF3C7),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFF59E0B,
                                        ).withValues(alpha: 0.45),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFF59E0B,
                                          ).withValues(alpha: 0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.vpn_key_rounded,
                                                    size: 11,
                                                    color: Color(0xFFD97706),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      'كود البطاقة الرقمية المستلمة',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          AppTypography.cairo(
                                                            fontSize: 9.5,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: const Color(
                                                              0xFFB45309,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              SelectableText(
                                                order.deliveredCode!,
                                                style:
                                                    AppTypography.technicalCode(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: const Color(
                                                        0xFF0F172A,
                                                      ),
                                                      letterSpacing: 0.8,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // زر نسخ مصغّر بدل ElevatedButton الكبير
                                        Tooltip(
                                          message: 'نسخ الكود',
                                          child: InkWell(
                                            onTap: () {
                                              Clipboard.setData(
                                                ClipboardData(
                                                  text: order.deliveredCode!,
                                                ),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'تم نسخ كود البطاقة بنجاح ✅',
                                                    style:
                                                        AppTypography.cairo(),
                                                  ),
                                                  backgroundColor: const Color(
                                                    0xFF059669,
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 1,
                                                  ),
                                                ),
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(
                                              7,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF59E0B),
                                                borderRadius:
                                                    BorderRadius.circular(7),
                                              ),
                                              child: const Icon(
                                                Icons.copy_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Manual Service Interactive Banner
                                if (order.isManual) ...[
                                  const SizedBox(height: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: order.isDelivered
                                          ? const Color(0xFFECFDF5)
                                          : (order.isDisputed
                                                ? const Color(0xFFFEF2F2)
                                                : const Color(0xFFF0FDF4)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: order.isDelivered
                                            ? const Color(
                                                0xFF10B981,
                                              ).withValues(alpha: 0.4)
                                            : (order.isDisputed
                                                  ? const Color(
                                                      0xFFEF4444,
                                                    ).withValues(alpha: 0.35)
                                                  : const Color(
                                                      0xFF6366F1,
                                                    ).withValues(alpha: 0.3)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: order.isDelivered
                                                ? const Color(
                                                    0xFF10B981,
                                                  ).withValues(alpha: 0.15)
                                                : (order.isDisputed
                                                      ? const Color(
                                                          0xFFEF4444,
                                                        ).withValues(
                                                          alpha: 0.15,
                                                        )
                                                      : const Color(
                                                          0xFF6366F1,
                                                        ).withValues(
                                                          alpha: 0.15,
                                                        )),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            order.isDelivered
                                                ? Icons.verified_rounded
                                                : (order.isDisputed
                                                      ? Icons
                                                            .report_problem_rounded
                                                      : Icons
                                                            .support_agent_rounded),
                                            size: 15,
                                            color: order.isDelivered
                                                ? const Color(0xFF059669)
                                                : (order.isDisputed
                                                      ? const Color(0xFFDC2626)
                                                      : const Color(
                                                          0xFF6366F1,
                                                        )),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                order.isDelivered
                                                    ? 'تم تسليم النتيجة! اضغط للمراجعة والتأكيد'
                                                    : (order.isDisputed
                                                          ? 'اعتراض قيد المعالجة من الإدارة'
                                                          : 'خدمة يدوية بإشراف مشرف مختص'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.cairo(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: order.isDelivered
                                                      ? const Color(0xFF059669)
                                                      : (order.isDisputed
                                                            ? const Color(
                                                                0xFFDC2626,
                                                              )
                                                            : const Color(
                                                                0xFF0F172A,
                                                              )),
                                                ),
                                              ),
                                              Text(
                                                'اضغط لفتح الجدول الزمني، المحادثة والملفات المرفقة',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.cairo(
                                                  fontSize: 9,
                                                  color: const Color(
                                                    0xFF64748B,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 12,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Admin Notes (if rejected or notice)
                                if (order.adminNotes != null &&
                                    order.adminNotes!.isNotEmpty) ...[
                                  const SizedBox(height: 7),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFEF4444,
                                        ).withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          size: 14,
                                          color: Color(0xFFDC2626),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'ملاحظة الإدارة: ${order.adminNotes!}',
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.cairo(
                                              fontSize: 10,
                                              color: const Color(0xFF991B1B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 8),

                                // Quick Actions Footer
                                Row(
                                  children: [
                                    // Copy Full Summary Action
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF475569,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFFCBD5E1),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 5,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 13,
                                        ),
                                        label: Text(
                                          'نسخ الملخص',
                                          style: AppTypography.cairo(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _copyOrderSummary(order),
                                      ),
                                    ),
                                    const SizedBox(width: 7),

                                    // Quick Re-Order Action
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF0F172A,
                                          ),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 5,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.replay_rounded,
                                          size: 13,
                                        ),
                                        label: Text(
                                          'إعادة الطلب',
                                          style: AppTypography.cairo(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _reorderApp(order, catalog),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TICKET SECTION — نصف تذكرة JGO بفتحتَي نصف دائرة مقتطعتَين فعلياً
  // ===========================================================================
  Widget _ticketSection({
    required bool top,
    required Color borderColor,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    final _TicketHalfClipper clipper = _TicketHalfClipper(top: top);
    return CustomPaint(
      // الحدّ وخط التثقيب يُرسمان على مسار الكليب نفسه فلا خطوط زائدة
      foregroundPainter: _TicketEdgePainter(
        clipper: clipper,
        color: borderColor,
      ),
      child: PhysicalShape(
        clipper: clipper,
        // أبيض الكرت والظل يتبعان الشكل المقطوع بما فيه الفتحتان
        color: Colors.white,
        elevation: 1.2,
        shadowColor: const Color(0x140F172A),
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

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================
  Widget _buildEmptyState(bool isCompletelyEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 44,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isCompletelyEmpty
                  ? 'لايوجد لديك طلبات أو عمليات شحن'
                  : 'لا توجد نتائج تطابق هذا التصنيف أو البحث',
              style: AppTypography.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isCompletelyEmpty
                  ? 'ابدأ شحن ألعابك وتطبيقاتك المفضلة وستظهر جميع فواتيرك وتذاكرك هنا فوراً وبشكل تلقائي!'
                  : 'جرّب البحث باسم آخر أو تغيير التبويب المحدد لرؤية الطلبات الأخرى.',
              style: AppTypography.cairo(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            if (!isCompletelyEmpty) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  'عرض جميع الطلبات',
                  style: AppTypography.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _selectedFilter = 'all';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TYPE FILTER — شريط الأنواع: الكل / تطبيقات / ألعاب / خدمات / أرقام
  // الأرقام تُقرأ من مزود الأرقام، والبقية تُصنَّف من نوع التطبيق (appType)
  // بحيث الاشتراكات واليدوي وكل بلا نوع يدخل تحت «خدمات».
  // ===========================================================================
  Widget _buildKindChips({
    required int totalCount,
    required int appCount,
    required int gameCount,
    required int serviceCount,
    required int numberCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip('all', 'الكل', totalCount, Icons.dashboard_outlined),
          const SizedBox(width: 8),
          _buildKindChip('app', 'تطبيقات', appCount, Icons.apps_rounded),
          const SizedBox(width: 8),
          _buildKindChip('game', 'ألعاب', gameCount, Icons.sports_esports),
          const SizedBox(width: 8),
          _buildKindChip(
            'service',
            'خدمات',
            serviceCount,
            Icons.support_agent_outlined,
          ),
          const SizedBox(width: 8),
          _buildKindChip(
            'number',
            'أرقام',
            numberCount,
            Icons.sim_card_download_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildKindChip(String key, String label, int count, IconData icon) {
    final isSelected = _selectedKind == key;

    return InkWell(
      onTap: () => setState(() => _selectedKind = key),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4338CA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4338CA)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.18)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$count',
                style: AppTypography.technicalCode(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // NUMBER TICKET — تذكرة رقم وهمي مدمجة بنفس شكل تذاكر الطلبات
  // ===========================================================================
  String _numberTicketKey(VirtualNumberRequestModel r) =>
      r.id.isNotEmpty ? r.id : r.requestNumber;

  bool _isNumberOpen(VirtualNumberRequestModel r) =>
      _openTickets.contains('n:${_numberTicketKey(r)}');

  void _toggleNumberTicket(VirtualNumberRequestModel r) {
    setState(() {
      final String key = 'n:${_numberTicketKey(r)}';
      if (!_openTickets.remove(key)) _openTickets.add(key);
    });
  }

  /// أيقونة الخدمة: من سجل الأيقونات المربعة باسم الخدمة، وإلا سلسلة فارغة
  /// فيستعمل AppThumb رمزه الافتراضي
  AppItemModel _numberAppItem(VirtualNumberRequestModel r) {
    final String name = r.nameAr.isNotEmpty ? r.nameAr : r.title;
    String? icon = r.icon.isNotEmpty
        ? (r.icon.startsWith('assets/') ? r.icon : 'assets/icons/${r.icon}.png')
        : null;
    icon ??= builtinIconAssetExact(r.icon) ??
        builtinIconAssetForQuery(r.icon) ??
        builtinIconAssetForName(name) ??
        builtinIconAssetForName(r.service);
    return AppItemModel(
      id: r.service,
      name: name.isNotEmpty ? name : 'رقم تحقق',
      iconUrl: icon ?? '',
    );
  }

  /// يلائم شارة الحالة: لون أخضر للّرمز المستلَم، وكهرماني للإرجاع، وأحمر للفشل
  ({Color fg, Color bg, String label}) _numberPill(
    VirtualNumberRequestModel r,
  ) {
    if (r.hasCode || r.status == VirtualNumberRequestModel.completed) {
      return (
        fg: const Color(0xFF059669),
        bg: const Color(0xFFD1FAE5),
        label: r.statusLabel,
      );
    }
    if (r.status == VirtualNumberRequestModel.received) {
      return (
        fg: const Color(0xFF0284C7),
        bg: const Color(0xFFE0F2FE),
        label: r.statusLabel,
      );
    }
    if (r.isRefunded || r.status == VirtualNumberRequestModel.expired) {
      return (
        fg: const Color(0xFFD97706),
        bg: const Color(0xFFFEF3C7),
        label: r.statusLabel,
      );
    }
    if (r.status == VirtualNumberRequestModel.cancelled ||
        r.status == VirtualNumberRequestModel.failed) {
      return (
        fg: const Color(0xFFDC2626),
        bg: const Color(0xFFFEE2E2),
        label: r.statusLabel,
      );
    }
    return (
      fg: const Color(0xFF64748B),
      bg: const Color(0xFFF1F5F9),
      label: r.statusLabel,
    );
  }

  /// شارة حالة الرقم: لون/نص مخصصان (StatusPill لا يعرف حالات الأرقام العربية)
  Widget _numberPillWidget(({Color fg, Color bg, String label}) pill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: pill.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pill.fg.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: pill.fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              pill.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                color: pill.fg,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyValue(String value, String label) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text('تم نسخ $label', style: AppTypography.cairo()),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildNumberTicket(VirtualNumberRequestModel request, String dateStr) {
    final bool open = _isNumberOpen(request);
    final pill = _numberPill(request);
    final Color borderColor = pill.fg.withValues(alpha: 0.25);
    final String phone = request.phoneNumber ?? '';
    final String code = request.smsCode ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ticketSection(
            top: true,
            borderColor: borderColor,
            onTap: () => _toggleNumberTicket(request),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 8, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: AppThumb(
                        app: _numberAppItem(request),
                        size: 36,
                        radius: 8,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Flexible(
                                flex: 3,
                                child: Text(
                                  '${request.flag.isNotEmpty ? "${request.flag} " : ""}${request.countryName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.cairo(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'رقم وهمي 📱',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.cairo(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text(
                              '\$${request.amount.toStringAsFixed(2)}',
                              style: AppTypography.price(
                                fontSize: 13.5,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerEnd,
                            child: _numberPillWidget(pill),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        size: 17,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _ticketSection(
            top: false,
            borderColor: borderColor,
            onTap: () => _toggleNumberTicket(request),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(11, 6, 11, open ? 10 : 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'VN #${request.requestNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.technicalCode(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: AppTypography.technicalCode(
                            fontSize: 9,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    if (open) ...[
                      const Divider(
                        height: 16,
                        thickness: 0.6,
                        color: Color(0xFFE2E8F0),
                      ),
                      if (phone.isNotEmpty)
                        _numberDetailRow(
                          icon: Icons.phone_rounded,
                          label: 'الرقم',
                          value: phone,
                          onCopy: () => _copyValue(phone, 'رقم التحقق'),
                        ),
                      if (code.isNotEmpty)
                        _numberDetailRow(
                          icon: Icons.key_rounded,
                          label: 'رمز التحقق',
                          value: code,
                          onCopy: () => _copyValue(code, 'رمز التحقق'),
                        ),
                      if (request.note.isNotEmpty)
                        _numberDetailRow(
                          icon: Icons.info_outline_rounded,
                          label: 'ملاحظة',
                          value: request.note,
                        ),
                      if (phone.isEmpty && code.isEmpty)
                        Text(
                          'لم يصل رمز لهذا الرقم${request.isRefunded ? '، وأُرجع المبلغ' : ''}',
                          style: AppTypography.cairo(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numberDetailRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            '$label:',
            style: AppTypography.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.technicalCode(
                fontSize: 11,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: const Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// MERGED HISTORY ROW — يوحّد تذاكر الطلبات وتذاكر الأرقام في قائمة واحدة
// =============================================================================
sealed class _HistoryRow {
  final DateTime at;
  const _HistoryRow(this.at);

  /// نوع الصف لفلتر «أرقام/تطبيقات/ألعاب/خدمات»
  String get kind;

  const factory _HistoryRow.order(OrderModel order, DateTime at) =
      _OrderHistoryRow;

  const factory _HistoryRow.number(
    VirtualNumberRequestModel request,
    DateTime at,
  ) = _NumberHistoryRow;
}

class _OrderHistoryRow extends _HistoryRow {
  final OrderModel order;
  const _OrderHistoryRow(this.order, super.at);

  @override
  String get kind => order.serviceKind;
}

class _NumberHistoryRow extends _HistoryRow {
  final VirtualNumberRequestModel request;
  const _NumberHistoryRow(this.request, super.at);

  @override
  String get kind => 'number';
}

// =============================================================================
// TICKET HALF CLIPPER — فتحتا نصف دائرة مقتطعتان فعلياً (هوية JGO)
// =============================================================================

/// نصف كرت التذكرة: زوايا مستديرة من جهة الحافة الخارجية، وفتحة نصف دائرية
/// مقتطعة فعلياً من الحافتين اليمنى واليسرى عند خط التثقيب.
///
/// يُستعمل نصفان متقابلان (علوي للرأس، سفلي للذيل والتفاصيل)، وكل نصف يقطع
/// نصف دائرة عند حدّه المشترك، فيكتمل الثقب دائرة كاملة **مهما تغيّر ارتفاع
/// الكرت** (مطوياً كان أو مفرداً) بلا حاجة لقياس ارتفاع الرأس.
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
      ..color = const Color(0xFFCBD5E1)
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
