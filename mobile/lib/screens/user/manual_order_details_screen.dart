import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/order_model.dart';
import '../../providers/manual_services_provider.dart';
import '../../providers/app_catalog_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/status_pill.dart';

class ManualOrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const ManualOrderDetailsScreen({super.key, required this.order});

  @override
  State<ManualOrderDetailsScreen> createState() =>
      _ManualOrderDetailsScreenState();
}

class _ManualOrderDetailsScreenState extends State<ManualOrderDetailsScreen>
    with SingleTickerProviderStateMixin {
  late OrderModel _currentOrder;
  late TabController _tabController;
  Timer? _chatRefreshTimer;

  // Chat
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  List<OrderChatMessageModel> _messages = [];
  bool _isLoadingMessages = false;

  // Decrypted Credentials (e.g. Gmail pass)
  Map<String, dynamic>? _decryptedCredentials;
  bool _isLoadingCredentials = false;
  bool _showSecrets = false;

  // Decrypted customer input (for supervisor/admin)
  Map<String, dynamic>? _decryptedInput;
  bool _isLoadingInput = false;
  bool _showInput = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _tabController = TabController(length: 2, vsync: this);
    _loadOrderDetails();
    _loadMessages();

    // Auto-refresh chat messages & order status every 5 seconds silently
    _chatRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _silentRefresh();
      }
    });
  }

  Future<void> _silentRefresh() async {
    final stick = _isChatNearBottom;
    final provider = Provider.of<ManualServicesProvider>(
      context,
      listen: false,
    );
    final msgs = await provider.fetchOrderMessages(_currentOrder.id);
    final updatedOrder = await provider.fetchOrderById(_currentOrder.id);
    if (mounted) {
      setState(() {
        _messages = msgs;
        if (updatedOrder != null) {
          _currentOrder = updatedOrder;
        }
      });
      if (stick) _scrollChatToBottom(animate: false);
    }
  }

  /// هل المستخدم ملتصق بأسفل المحادثة؟ (لمنع قفز العرض أثناء الرد)
  bool get _isChatNearBottom {
    if (!_chatScrollCtrl.hasClients) return true;
    final pos = _chatScrollCtrl.position;
    return pos.maxScrollExtent - pos.pixels < 120;
  }

  /// التمرير التلقائي إلى آخر رسالة (مثل واتساب)
  void _scrollChatToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollCtrl.hasClients) return;
      final target = _chatScrollCtrl.position.maxScrollExtent;
      if (animate) {
        _chatScrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _chatScrollCtrl.jumpTo(target);
      }
    });
  }

  @override
  void dispose() {
    _chatRefreshTimer?.cancel();
    _tabController.dispose();
    _messageCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    // If sensitive, attempt to load decrypted credentials
    if (_currentOrder.isSensitive &&
        (_currentOrder.isDelivered || _currentOrder.isCompleted)) {
      setState(() => _isLoadingCredentials = true);
      final provider = Provider.of<ManualServicesProvider>(
        context,
        listen: false,
      );
      final res = await provider.fetchDecryptedCredentials(_currentOrder.id);
      if (mounted) {
        setState(() {
          _decryptedCredentials = res;
          _isLoadingCredentials = false;
        });
      }
    }
  }

  // كشف/إخفاء مدخلات العميل الحساسة (للمشرف المسند أو الأدمن فقط)
  bool get _canRevealInput {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.isSupervisor || auth.isAdmin;
  }

  Future<void> _revealInput() async {
    if (_showInput) {
      setState(() => _showInput = false);
      return;
    }
    setState(() => _isLoadingInput = true);
    final provider = Provider.of<ManualServicesProvider>(
      context,
      listen: false,
    );
    final res = await provider.fetchDecryptedInput(_currentOrder.id);
    if (!mounted) return;
    setState(() {
      _isLoadingInput = false;
      final input = res?['accountInput'];
      if (input is Map) {
        _decryptedInput = Map<String, dynamic>.from(input);
        _showInput = true;
      }
    });
    if (_decryptedInput == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'تعذر كشف البيانات'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoadingMessages = true);
    final provider = Provider.of<ManualServicesProvider>(
      context,
      listen: false,
    );
    final msgs = await provider.fetchOrderMessages(_currentOrder.id);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoadingMessages = false;
      });
      _scrollChatToBottom(animate: false);
    }
  }

  void _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    _messageCtrl.clear();
    final provider = Provider.of<ManualServicesProvider>(
      context,
      listen: false,
    );
    final sent = await provider.sendOrderMessage(
      orderId: _currentOrder.id,
      message: text,
    );

    if (sent != null && mounted) {
      setState(() {
        _messages.add(sent);
      });
      _scrollChatToBottom();
    }
  }

  // --- Customer Confirm Receipt ---
  void _confirmReceipt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.emerald,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'تأكيد استلام الخدمة',
              style: AppTypography.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من استلام الخدمة ورضاك عنها بالكامل؟\n\nعند التأكيد سيتم إغلاق الطلب بنجاح، ولأسباب الأمان سيتم حذف البيانات السرية تلقائياً من خوادمنا لحماية خصوصيتك.',
          style: AppTypography.cairo(
            fontSize: 13,
            height: 1.5,
            color: AppColors.slate600,
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
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<ManualServicesProvider>(
                context,
                listen: false,
              );
              final ok = await provider.customerConfirmOrder(_currentOrder.id);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تم تأكيد استلام الخدمة وإغلاق الطلب بنجاح ✅',
                    ),
                    backgroundColor: AppColors.emerald,
                  ),
                );
                Provider.of<AppCatalogProvider>(
                  context,
                  listen: false,
                ).fetchMyOrders();
                Navigator.pop(context);
              }
            },
            child: Text(
              'نعم، تأكيد الاستلام',
              style: AppTypography.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- Customer Request Revision ---
  void _openRevisionDialog() {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.edit_note_rounded,
              color: AppColors.ticketAmber,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'طلب تعديل على النتيجة',
              style: AppTypography.cairo(
                fontWeight: FontWeight.bold,
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
              'يرجى توضيح النقاط المطلوب تعديلها أو تصحيحها ليقوم المشرف بتنفيذها:',
              style: AppTypography.cairo(
                fontSize: 13,
                color: AppColors.slate600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اكتب ملاحظات التعديل بالتفصيل...',
                hintStyle: AppTypography.cairo(
                  color: AppColors.slate400,
                  fontSize: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
              ),
            ),
          ],
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
              backgroundColor: AppColors.ticketAmber,
              foregroundColor: AppColors.slate900,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final text = noteCtrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              final provider = Provider.of<ManualServicesProvider>(
                context,
                listen: false,
              );
              final ok = await provider.customerRequestRevision(
                _currentOrder.id,
                text,
              );
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال طلب التعديل للمشرف بنجاح 🔄'),
                    backgroundColor: AppColors.ticketAmber,
                  ),
                );
                Provider.of<AppCatalogProvider>(
                  context,
                  listen: false,
                ).fetchMyOrders();
                Navigator.pop(context);
              }
            },
            child: Text(
              'إرسال التعديل',
              style: AppTypography.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- Customer Open Dispute ---
  void _openDisputeDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.report_problem_rounded,
              color: AppColors.rose,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'فتح اعتراض رسمي',
              style: AppTypography.cairo(
                fontWeight: FontWeight.bold,
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
              'سيتم تحويل هذا الطلب فوراً إلى إدارة المنصة للتدخل والتحقق من صحة التنفيذ:',
              style: AppTypography.cairo(
                fontSize: 13,
                color: AppColors.slate600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اكتب سبب الاعتراض والمشكلة التي واجهتك...',
                hintStyle: AppTypography.cairo(
                  color: AppColors.slate400,
                  fontSize: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
              ),
            ),
          ],
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
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final text = reasonCtrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              final provider = Provider.of<ManualServicesProvider>(
                context,
                listen: false,
              );
              final ok = await provider.customerOpenDispute(
                _currentOrder.id,
                text,
              );
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تم فتح الاعتراض وسيتدخل فريق الإدارة لحله 🚨',
                    ),
                    backgroundColor: AppColors.rose,
                  ),
                );
                Provider.of<AppCatalogProvider>(
                  context,
                  listen: false,
                ).fetchMyOrders();
                Navigator.pop(context);
              }
            },
            child: Text(
              'تأكيد الاعتراض',
              style: AppTypography.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'طلب ',
              style: AppTypography.cairo(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
            Text(
              '#${_currentOrder.orderNumber}',
              style: AppTypography.spaceMono(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlue,
          indicatorWeight: 3,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.slate500,
          labelStyle: AppTypography.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: AppTypography.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 20), text: 'تفاصيل الطلب'),
            Tab(
              icon: Icon(Icons.chat_bubble_outline, size: 20),
              text: 'المحادثة والمرفقات',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildOrderDetailsTab(), _buildChatTab()],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildOrderDetailsTab() {
    final dateStr = DateFormat(
      'yyyy/MM/dd - hh:mm a',
    ).format(_currentOrder.createdAt);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status & Header Card (Neo-Bento White Card)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _currentOrder.productName,
                        style: AppTypography.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                    ),
                    StatusPill(status: _currentOrder.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_currentOrder.appName} • تاريخ الطلب: $dateStr',
                  style: AppTypography.cairo(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'المبلغ المدفوع: ',
                            style: AppTypography.cairo(
                              fontSize: 12,
                              color: AppColors.slate600,
                            ),
                          ),
                          Text(
                            '\$${_currentOrder.amount.toStringAsFixed(2)}',
                            style: AppTypography.price(
                              fontWeight: FontWeight.w800,
                              color: AppColors.emerald,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_currentOrder.isSensitive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primaryBlue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'خدمة مشفرة آمنة',
                              style: AppTypography.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Supervisor & ETA Card
          if (_currentOrder.assignedSupervisorName != null) ...[
            Container(
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryBlue.withValues(
                      alpha: 0.15,
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المشرف المسؤول عن التنفيذ:',
                          style: AppTypography.cairo(
                            fontSize: 11,
                            color: AppColors.slate500,
                          ),
                        ),
                        Text(
                          _currentOrder.assignedSupervisorName!,
                          style: AppTypography.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate900,
                          ),
                        ),
                        if (_currentOrder.deadlineAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _currentOrder.isDelayed
                                ? '⚠️ تأخر عن الوقت المتوقع'
                                : 'الوقت المتوقع: ${_currentOrder.estimatedMinutes} دقيقة',
                            style: AppTypography.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _currentOrder.isDelayed
                                  ? AppColors.rose
                                  : AppColors.emerald,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    tooltip: 'محادثة المشرف',
                    onPressed: () => _tabController.animateTo(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Delivery Result Card (When delivered or completed)
          if (_currentOrder.resultNotes != null ||
              _decryptedCredentials != null ||
              _currentOrder.isResultPurged) ...[
            _buildResultCard(),
            const SizedBox(height: 16),
          ],

          // Customer Submitted Input Parameters
          if (_currentOrder.accountInput.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'البيانات المدخلة للخدمة:',
                        style: AppTypography.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                      const Spacer(),
                      if (_canRevealInput &&
                          _currentOrder.sensitiveFields.isNotEmpty)
                        TextButton.icon(
                          onPressed: _isLoadingInput ? null : _revealInput,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: _isLoadingInput
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _showInput
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 16,
                                  color: const Color(0xFF7C3AED),
                                ),
                          label: Text(
                            _showInput ? 'إخفاء' : 'كشف',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._currentOrder.accountInput.entries.map((entry) {
                    final isSecret =
                        _currentOrder.sensitiveFields.contains(entry.key) ||
                        (_currentOrder.isSensitive &&
                            entry.value.toString().contains(':'));
                    final shownValue = isSecret && _showInput
                        ? '${_decryptedInput?[entry.key] ?? ''}'
                        : entry.value.toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            '${entry.key}: ',
                            style: AppTypography.cairo(
                              fontSize: 13,
                              color: AppColors.slate500,
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              isSecret && !_showInput
                                  ? '•••••••• (مشفر بأمان)'
                                  : shownValue,
                              style: isSecret
                                  ? AppTypography.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.slate800,
                                    )
                                  : AppTypography.spaceMono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.slate900,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Chronological Audit Trail (السجل الزمني)
          _buildTimelineCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Delivery Result Card with Secure Credential Box
  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                color: AppColors.primaryBlue,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'تفاصيل النتيجة والتسليم',
                style: AppTypography.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_currentOrder.resultNotes != null &&
              _currentOrder.resultNotes!.isNotEmpty)
            Text(
              _currentOrder.resultNotes!,
              style: AppTypography.cairo(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.slate800,
              ),
            ),
          const SizedBox(height: 14),

          // Secure Credentials Box (e.g. Gmail Account & Password)
          if (_isLoadingCredentials)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            )
          else if (_currentOrder.isResultPurged)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: AppColors.slate500,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم حذف البيانات السرية تلقائياً من النظام بعد تأكيدك للاستلام لحماية أمانك.',
                      style: AppTypography.cairo(
                        fontSize: 12,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_decryptedCredentials != null &&
              _decryptedCredentials!['credentials'] != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 18,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'البيانات السرية (الحساب / كلمة المرور)',
                            style: AppTypography.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          _showSecrets
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                          color: AppColors.primaryBlue,
                        ),
                        tooltip: _showSecrets ? 'إخفاء' : 'إظهار',
                        onPressed: () =>
                            setState(() => _showSecrets = !_showSecrets),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: AppColors.outline),
                  if (_decryptedCredentials!['credentials'] is Map)
                    ...(_decryptedCredentials!['credentials'] as Map).entries
                        .map((e) {
                          final val = e.value.toString();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${e.key}:',
                                  style: AppTypography.cairo(
                                    fontSize: 13,
                                    color: AppColors.slate600,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _showSecrets ? val : '••••••••••••',
                                      style: AppTypography.spaceMono(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.slate900,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy,
                                        size: 16,
                                        color: AppColors.primaryBlue,
                                      ),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: val),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'تم نسخ ${e.key} للحافظة',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        })
                  else
                    Text(
                      _decryptedCredentials!['credentials'].toString(),
                      style: AppTypography.spaceMono(fontSize: 13),
                    ),
                ],
              ),
            ),
          ],

          // Proof Attachments
          if (_currentOrder.resultAttachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'مرفقات وإثباتات التنفيذ:',
              style: AppTypography.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.slate600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentOrder.resultAttachments.map((url) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: AppColors.paper,
                    child: _buildAttachmentThumb(url),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentThumb(String url) {
    if (url.startsWith('data:image')) {
      try {
        final b64 = url.split(',').last;
        return Image.memory(base64Decode(b64), fit: BoxFit.cover);
      } catch (_) {
        return const Icon(Icons.image, color: AppColors.primaryBlue);
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.attachment),
    );
  }

  // Chronological Audit Trail (السجل الزمني للمراحل)
  Widget _buildTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'السجل الزمني ومراحل الطلب',
                style: AppTypography.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_currentOrder.timeline.isEmpty)
            Text(
              'لا توجد سجلات مسجلة بعد',
              style: AppTypography.cairo(
                fontSize: 12,
                color: AppColors.slate500,
              ),
            )
          else
            Column(
              children: List.generate(_currentOrder.timeline.length, (index) {
                final ev = _currentOrder.timeline[index];
                final isLast = index == _currentOrder.timeline.length - 1;
                final timeStr = DateFormat(
                  'MM/dd - hh:mm a',
                ).format(ev.timestamp);

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // السكة اليسرى: عقدة + خط ربط بين العقد فقط
                      SizedBox(
                        width: 22,
                        child: Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: isLast ? 16 : 12,
                              height: isLast ? 16 : 12,
                              decoration: BoxDecoration(
                                color: isLast
                                    ? AppColors.primaryBlue
                                    : AppColors.slate400,
                                shape: BoxShape.circle,
                                border: isLast
                                    ? null
                                    : Border.all(
                                        color: AppColors.slate200,
                                        width: 2,
                                      ),
                                boxShadow: isLast
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryBlue
                                              .withValues(alpha: 0.35),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: AppColors.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      ev.title,
                                      style: AppTypography.cairo(
                                        fontSize: isLast ? 13.5 : 12.5,
                                        fontWeight: isLast
                                            ? FontWeight.w800
                                            : FontWeight.w700,
                                        color: isLast
                                            ? AppColors.slate900
                                            : AppColors.slate700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    timeStr,
                                    style: AppTypography.cairo(
                                      fontSize: 10.5,
                                      color: AppColors.slate500,
                                    ),
                                  ),
                                ],
                              ),
                              if (ev.description != null &&
                                  ev.description!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  ev.description!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.cairo(
                                    fontSize: 12,
                                    color: AppColors.slate600,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.person_outline_rounded,
                                      size: 12,
                                      color: AppColors.primaryBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'بواسطة: ${ev.performerName}',
                                      style: AppTypography.cairo(
                                        fontSize: 10.5,
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  // ===== Chat helpers (بنمط واتساب) =====
  bool _isChatMine(OrderChatMessageModel msg) {
    final myId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.id;
    if (myId != null && myId.isNotEmpty && msg.senderId.isNotEmpty) {
      return msg.senderId == myId;
    }
    return msg.senderRole == 'user';
  }

  bool _sameChatDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// تجميع الرسائل المتتالية لنفس المرسل خلال 5 دقائق
  bool _sameChatGroup(OrderChatMessageModel? a, OrderChatMessageModel? b) {
    if (a == null || b == null) return false;
    if (a.senderId != b.senderId) return false;
    if (!_sameChatDay(a.createdAt, b.createdAt)) return false;
    return b.createdAt.difference(a.createdAt).inMinutes.abs() < 5;
  }

  Color _chatRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppColors.ticketAmber;
      case 'supervisor':
        return const Color(0xFF38BDF8);
      case 'agent':
        return AppColors.tertiary;
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _chatRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'الإدارة';
      case 'supervisor':
        return 'مشرف';
      case 'agent':
        return 'وكيل';
      default:
        return 'عميل';
    }
  }

  bool _isChatImageUrl(String url) {
    if (url.startsWith('data:image')) return true;
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  /// ترويسة المحادثة: الطرف الآخر + رقم الطلب
  Widget _buildChatHeader() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isStaff = auth.isAdmin || auth.isSupervisor || auth.isAgent;
    final title = isStaff
        ? (_currentOrder.userName ?? 'العميل')
        : (_currentOrder.assignedSupervisorName ?? 'فريق الدعم الفني');
    final subtitle = isStaff ? 'عميل الطلب' : 'المشرف المسؤول عن طلبك';
    final headerColor = isStaff
        ? const Color(0xFF6366F1)
        : const Color(0xFF38BDF8);
    final trimmed = title.trim();
    final initial = trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);
    final orderRef = _currentOrder.orderNumber.isNotEmpty
        ? _currentOrder.orderNumber
        : _currentOrder.id.substring(_currentOrder.id.length - 6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [headerColor, headerColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: headerColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: AppTypography.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: headerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      subtitle,
                      style: AppTypography.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '#$orderRef',
              style: AppTypography.spaceMono(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outline),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 36,
                color: AppColors.primaryBlue.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد رسائل بعد',
              style: AppTypography.cairo(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.slate800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ابدأ المحادثة لمتابعة تفاصيل الطلب مع الطرف الآخر.',
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                color: AppColors.slate500,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outline),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            _chatDateLabel(date),
            style: AppTypography.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.slate500,
            ),
          ),
        ),
      ),
    );
  }

  String _chatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildChatBubble(
    OrderChatMessageModel msg, {
    required bool isMe,
    required bool isFirst,
    required bool isLast,
  }) {
    final bubbleColor = isMe ? AppColors.primaryBlue : Colors.white;
    final textColor = isMe ? Colors.white : AppColors.slate900;
    final roleColor = _chatRoleColor(msg.senderRole);
    final maxWidth = MediaQuery.of(context).size.width * 0.76;
    final isImage =
        msg.attachmentUrl != null && _isChatImageUrl(msg.attachmentUrl!);

    final content = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(isMe && isLast ? 0 : 12),
          bottomRight: Radius.circular(!isMe && isLast ? 0 : 12),
        ),
        border: isMe ? null : Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (isFirst && !isMe) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.senderName,
                  style: AppTypography.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: roleColor,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _chatRoleLabel(msg.senderRole),
                    style: AppTypography.cairo(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (isImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 190,
                height: 140,
                color: AppColors.paper,
                child: _buildAttachmentThumb(msg.attachmentUrl!),
              ),
            ),
            if (msg.message.isNotEmpty) const SizedBox(height: 6),
          ] else if (msg.attachmentUrl != null) ...[
            _buildChatAttachmentCard(msg, isMe),
            if (msg.message.isNotEmpty) const SizedBox(height: 6),
          ],
          if (msg.message.isNotEmpty)
            Text(
              msg.message,
              style: AppTypography.cairo(
                fontSize: 13.5,
                height: 1.45,
                color: textColor,
              ),
            ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.isSensitive) ...[
                Icon(
                  Icons.lock_rounded,
                  size: 10,
                  color: isMe ? Colors.white70 : AppColors.ticketAmber,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                DateFormat('hh:mm a').format(msg.createdAt),
                style: AppTypography.cairo(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.slate400,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final tail = isLast
        ? CustomPaint(
            size: const Size(7, 12),
            painter: _ChatTailPainter(color: bubbleColor, pointLeft: isMe),
          )
        : const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 10 : 2),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isMe ? [content, tail] : [tail, content],
      ),
    );
  }

  Widget _buildChatAttachmentCard(OrderChatMessageModel msg, bool isMe) {
    final fgColor = isMe ? Colors.white : AppColors.slate700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.16) : AppColors.paper,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_rounded, size: 16, color: fgColor),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              msg.attachmentName ?? 'مرفق',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Chat Tab (بنمط واتساب) ---
  Widget _buildChatTab() {
    return Column(
      children: [
        _buildChatHeader(),
        Expanded(
          child: Container(
            color: const Color(0xFFEDF2F7),
            child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? _buildChatEmptyState()
                : ListView.builder(
                    controller: _chatScrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = _isChatMine(msg);
                      final prev = index > 0 ? _messages[index - 1] : null;
                      final next = index < _messages.length - 1
                          ? _messages[index + 1]
                          : null;
                      final showDate =
                          prev == null ||
                          !_sameChatDay(prev.createdAt, msg.createdAt);
                      final isFirst = showDate || !_sameChatGroup(prev, msg);
                      final isLast = !_sameChatGroup(msg, next);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDate) _buildChatDateSeparator(msg.createdAt),
                          _buildChatBubble(
                            msg,
                            isMe: isMe,
                            isFirst: isFirst,
                            isLast: isLast,
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),

        // Chat Input Bar (بنمط واتساب)
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  textAlignVertical: TextAlignVertical.center,
                  style: AppTypography.cairo(
                    fontSize: 13.5,
                    color: AppColors.slate900,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالة...',
                    hintStyle: AppTypography.cairo(
                      color: AppColors.slate400,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: AppColors.primaryBlue,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // زر الإرسال الدائري
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Material(
                    color: AppColors.primaryBlue,
                    shape: const CircleBorder(),
                    elevation: 2,
                    shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _sendMessage,
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Bottom Action Buttons for Customer ---
  Widget? _buildBottomActions() {
    if (_currentOrder.status == 'delivered') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(
                      'تأكيد الاستلام وإغلاق الطلب ✅',
                      style: AppTypography.cairo(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _confirmReceipt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ticketAmber,
                      side: const BorderSide(color: AppColors.ticketAmber),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: AppColors.ticketAmber,
                    ),
                    label: Text(
                      'طلب تعديل',
                      style: AppTypography.cairo(
                        color: AppColors.ticketAmber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _openRevisionDialog,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rose,
                      side: const BorderSide(color: AppColors.rose),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(
                      Icons.report_problem,
                      size: 18,
                      color: AppColors.rose,
                    ),
                    label: Text(
                      'فتح اعتراض',
                      style: AppTypography.cairo(
                        color: AppColors.rose,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _openDisputeDialog,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return null;
  }
}

/// ذيل فقاعة المحادثة (بنمط واتساب)
class _ChatTailPainter extends CustomPainter {
  final Color color;
  final bool pointLeft;

  const _ChatTailPainter({required this.color, required this.pointLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (pointLeft) {
      path
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChatTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointLeft != pointLeft;
}
