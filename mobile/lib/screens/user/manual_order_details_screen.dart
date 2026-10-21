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
import '../../widgets/status_pill.dart';

class ManualOrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const ManualOrderDetailsScreen({super.key, required this.order});

  @override
  State<ManualOrderDetailsScreen> createState() => _ManualOrderDetailsScreenState();
}

class _ManualOrderDetailsScreenState extends State<ManualOrderDetailsScreen> with SingleTickerProviderStateMixin {
  late OrderModel _currentOrder;
  late TabController _tabController;
  Timer? _chatRefreshTimer;

  // Chat
  final TextEditingController _messageCtrl = TextEditingController();
  List<OrderChatMessageModel> _messages = [];
  bool _isLoadingMessages = false;

  // Decrypted Credentials (e.g. Gmail pass)
  Map<String, dynamic>? _decryptedCredentials;
  bool _isLoadingCredentials = false;
  bool _showSecrets = false;

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
    final provider = Provider.of<ManualServicesProvider>(context, listen: false);
    final msgs = await provider.fetchOrderMessages(_currentOrder.id);
    final updatedOrder = await provider.fetchOrderById(_currentOrder.id);
    if (mounted) {
      setState(() {
        _messages = msgs;
        if (updatedOrder != null) {
          _currentOrder = updatedOrder;
        }
      });
    }
  }

  @override
  void dispose() {
    _chatRefreshTimer?.cancel();
    _tabController.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    // If sensitive, attempt to load decrypted credentials
    if (_currentOrder.isSensitive && (_currentOrder.isDelivered || _currentOrder.isCompleted)) {
      setState(() => _isLoadingCredentials = true);
      final provider = Provider.of<ManualServicesProvider>(context, listen: false);
      final res = await provider.fetchDecryptedCredentials(_currentOrder.id);
      if (mounted) {
        setState(() {
          _decryptedCredentials = res;
          _isLoadingCredentials = false;
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoadingMessages = true);
    final provider = Provider.of<ManualServicesProvider>(context, listen: false);
    final msgs = await provider.fetchOrderMessages(_currentOrder.id);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoadingMessages = false;
      });
    }
  }

  void _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    _messageCtrl.clear();
    final provider = Provider.of<ManualServicesProvider>(context, listen: false);
    final sent = await provider.sendOrderMessage(
      orderId: _currentOrder.id,
      message: text,
    );

    if (sent != null && mounted) {
      setState(() {
        _messages.add(sent);
      });
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
            const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 24),
            const SizedBox(width: 8),
            Text('تأكيد استلام الخدمة', style: AppTypography.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من استلام الخدمة ورضاك عنها بالكامل؟\n\nعند التأكيد سيتم إغلاق الطلب بنجاح، ولأسباب الأمان سيتم حذف البيانات السرية تلقائياً من خوادمنا لحماية خصوصيتك.',
          style: AppTypography.cairo(fontSize: 13, height: 1.5, color: AppColors.slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: AppTypography.cairo(color: AppColors.slate500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<ManualServicesProvider>(context, listen: false);
              final ok = await provider.customerConfirmOrder(_currentOrder.id);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تأكيد استلام الخدمة وإغلاق الطلب بنجاح ✅'),
                    backgroundColor: AppColors.emerald,
                  ),
                );
                Provider.of<AppCatalogProvider>(context, listen: false).fetchMyOrders();
                Navigator.pop(context);
              }
            },
            child: Text('نعم، تأكيد الاستلام', style: AppTypography.cairo(fontWeight: FontWeight.bold)),
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
            const Icon(Icons.edit_note_rounded, color: AppColors.ticketAmber, size: 24),
            const SizedBox(width: 8),
            Text('طلب تعديل على النتيجة', style: AppTypography.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'يرجى توضيح النقاط المطلوب تعديلها أو تصحيحها ليقوم المشرف بتنفيذها:',
              style: AppTypography.cairo(fontSize: 13, color: AppColors.slate600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اكتب ملاحظات التعديل بالتفصيل...',
                hintStyle: AppTypography.cairo(color: AppColors.slate400, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: AppTypography.cairo(color: AppColors.slate500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ticketAmber,
              foregroundColor: AppColors.slate900,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final text = noteCtrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              final provider = Provider.of<ManualServicesProvider>(context, listen: false);
              final ok = await provider.customerRequestRevision(_currentOrder.id, text);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال طلب التعديل للمشرف بنجاح 🔄'),
                    backgroundColor: AppColors.ticketAmber,
                  ),
                );
                Provider.of<AppCatalogProvider>(context, listen: false).fetchMyOrders();
                Navigator.pop(context);
              }
            },
            child: Text('إرسال التعديل', style: AppTypography.cairo(fontWeight: FontWeight.bold)),
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
            const Icon(Icons.report_problem_rounded, color: AppColors.rose, size: 24),
            const SizedBox(width: 8),
            Text('فتح اعتراض رسمي', style: AppTypography.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيتم تحويل هذا الطلب فوراً إلى إدارة المنصة للتدخل والتحقق من صحة التنفيذ:',
              style: AppTypography.cairo(fontSize: 13, color: AppColors.slate600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اكتب سبب الاعتراض والمشكلة التي واجهتك...',
                hintStyle: AppTypography.cairo(color: AppColors.slate400, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: AppTypography.cairo(color: AppColors.slate500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final text = reasonCtrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              final provider = Provider.of<ManualServicesProvider>(context, listen: false);
              final ok = await provider.customerOpenDispute(_currentOrder.id, text);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم فتح الاعتراض وسيتدخل فريق الإدارة لحله 🚨'),
                    backgroundColor: AppColors.rose,
                  ),
                );
                Provider.of<AppCatalogProvider>(context, listen: false).fetchMyOrders();
                Navigator.pop(context);
              }
            },
            child: Text('تأكيد الاعتراض', style: AppTypography.cairo(fontWeight: FontWeight.bold)),
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
            Text('طلب ', style: AppTypography.cairo(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.slate900)),
            Text('#${_currentOrder.orderNumber}', style: AppTypography.spaceMono(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryBlue)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlue,
          indicatorWeight: 3,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.slate500,
          labelStyle: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.w800),
          unselectedLabelStyle: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 20), text: 'تفاصيل الطلب'),
            Tab(icon: Icon(Icons.chat_bubble_outline, size: 20), text: 'المحادثة والمرفقات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderDetailsTab(),
          _buildChatTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildOrderDetailsTab() {
    final dateStr = DateFormat('yyyy/MM/dd - hh:mm a').format(_currentOrder.createdAt);

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
                        style: AppTypography.cairo(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.slate900),
                      ),
                    ),
                    StatusPill(status: _currentOrder.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_currentOrder.appName} • تاريخ الطلب: $dateStr',
                  style: AppTypography.cairo(fontSize: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('المبلغ المدفوع: ', style: AppTypography.cairo(fontSize: 12, color: AppColors.slate600)),
                          Text(
                            '\$${_currentOrder.amount.toStringAsFixed(2)}',
                            style: AppTypography.price(fontWeight: FontWeight.w800, color: AppColors.emerald, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_currentOrder.isSensitive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_rounded, size: 14, color: AppColors.primaryBlue),
                            const SizedBox(width: 4),
                            Text('خدمة مشفرة آمنة', style: AppTypography.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
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
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                    child: const Icon(Icons.support_agent_rounded, color: AppColors.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المشرف المسؤول عن التنفيذ:', style: AppTypography.cairo(fontSize: 11, color: AppColors.slate500)),
                        Text(
                          _currentOrder.assignedSupervisorName!,
                          style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slate900),
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
                              color: _currentOrder.isDelayed ? AppColors.rose : AppColors.emerald,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryBlue),
                    tooltip: 'محادثة المشرف',
                    onPressed: () => _tabController.animateTo(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Delivery Result Card (When delivered or completed)
          if (_currentOrder.resultNotes != null || _decryptedCredentials != null || _currentOrder.isResultPurged) ...[
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
                  Text('البيانات المدخلة للخدمة:', style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                  const SizedBox(height: 10),
                  ..._currentOrder.accountInput.entries.map((entry) {
                    final isSecret = _currentOrder.isSensitive && entry.value.toString().contains(':');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text('${entry.key}: ', style: AppTypography.cairo(fontSize: 13, color: AppColors.slate500)),
                          Text(
                            isSecret ? '•••••••• (مشفر بأمان)' : entry.value.toString(),
                            style: isSecret
                                ? AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate800)
                                : AppTypography.spaceMono(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate900),
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
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.5), width: 1.5),
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
              const Icon(Icons.task_alt_rounded, color: AppColors.primaryBlue, size: 22),
              const SizedBox(width: 8),
              Text(
                'تفاصيل النتيجة والتسليم',
                style: AppTypography.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_currentOrder.resultNotes != null && _currentOrder.resultNotes!.isNotEmpty)
            Text(
              _currentOrder.resultNotes!,
              style: AppTypography.cairo(fontSize: 13.5, height: 1.5, color: AppColors.slate800),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
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
                  const Icon(Icons.shield_outlined, color: AppColors.slate500, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم حذف البيانات السرية تلقائياً من النظام بعد تأكيدك للاستلام لحماية أمانك.',
                      style: AppTypography.cairo(fontSize: 12, color: AppColors.slate500),
                    ),
                  ),
                ],
              ),
            )
          else if (_decryptedCredentials != null && _decryptedCredentials!['credentials'] != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_rounded, size: 18, color: AppColors.primaryBlue),
                          const SizedBox(width: 6),
                          Text('البيانات السرية (الحساب / كلمة المرور)', style: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                        ],
                      ),
                      IconButton(
                        icon: Icon(_showSecrets ? Icons.visibility_off : Icons.visibility, size: 20, color: AppColors.primaryBlue),
                        tooltip: _showSecrets ? 'إخفاء' : 'إظهار',
                        onPressed: () => setState(() => _showSecrets = !_showSecrets),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: AppColors.outline),
                  if (_decryptedCredentials!['credentials'] is Map)
                    ...(_decryptedCredentials!['credentials'] as Map).entries.map((e) {
                      final val = e.value.toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${e.key}:', style: AppTypography.cairo(fontSize: 13, color: AppColors.slate600)),
                            Row(
                              children: [
                                Text(
                                  _showSecrets ? val : '••••••••••••',
                                  style: AppTypography.spaceMono(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 16, color: AppColors.primaryBlue),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: val));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('تم نسخ ${e.key} للحافظة')),
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
                    Text(_decryptedCredentials!['credentials'].toString(), style: AppTypography.spaceMono(fontSize: 13)),
                ],
              ),
            ),
          ],

          // Proof Attachments
          if (_currentOrder.resultAttachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('مرفقات وإثباتات التنفيذ:', style: AppTypography.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate600)),
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
    return Image.network(url, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.attachment));
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
              const Icon(Icons.history_rounded, size: 20, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'السجل الزمني ومراحل الطلب',
                style: AppTypography.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentOrder.timeline.isEmpty)
            Text('لا توجد سجلات مسجلة بعد', style: AppTypography.cairo(fontSize: 12, color: AppColors.slate500))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentOrder.timeline.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ev = _currentOrder.timeline[index];
                final timeStr = DateFormat('MM/dd - hh:mm a').format(ev.timestamp);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: index == _currentOrder.timeline.length - 1 ? AppColors.primaryBlue : AppColors.slate400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ev.title,
                                style: AppTypography.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate900),
                              ),
                              Text(timeStr, style: AppTypography.cairo(fontSize: 11, color: AppColors.slate500)),
                            ],
                          ),
                          if (ev.description != null && ev.description!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(ev.description!, style: AppTypography.cairo(fontSize: 12, color: AppColors.slate600)),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            'بواسطة: ${ev.performerName}',
                            style: AppTypography.cairo(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // --- Chat Tab ---
  Widget _buildChatTab() {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_outlined, size: 48, color: AppColors.slate400.withValues(alpha: 0.6)),
                          const SizedBox(height: 12),
                          Text('لا توجد رسائل بعد. يمكنك بدء المحادثة مع المشرف.', style: AppTypography.cairo(color: AppColors.slate500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg.senderRole == 'user';
                        final timeStr = DateFormat('hh:mm a').format(msg.createdAt);

                        return Align(
                          alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primaryBlue : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 2 : 16),
                                bottomRight: Radius.circular(isMe ? 16 : 2),
                              ),
                              border: Border.all(color: isMe ? Colors.transparent : AppColors.outline),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.senderName,
                                  style: AppTypography.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isMe ? Colors.white.withValues(alpha: 0.9) : AppColors.primaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (msg.message.isNotEmpty)
                                  Text(
                                    msg.message,
                                    style: AppTypography.cairo(
                                      fontSize: 13.5,
                                      color: isMe ? Colors.white : AppColors.slate900,
                                    ),
                                  ),
                                if (msg.attachmentUrl != null) ...[
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildAttachmentThumb(msg.attachmentUrl!),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  timeStr,
                                  style: AppTypography.cairo(fontSize: 10, color: isMe ? Colors.white70 : AppColors.slate400),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // Chat Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك للمشرف هنا...',
                    hintStyle: AppTypography.cairo(color: AppColors.slate400, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outline)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primaryBlue),
                onPressed: _sendMessage,
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text('تأكيد الاستلام وإغلاق الطلب ✅', style: AppTypography.cairo(fontWeight: FontWeight.bold)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.refresh, size: 18, color: AppColors.ticketAmber),
                    label: Text('طلب تعديل', style: AppTypography.cairo(color: AppColors.ticketAmber, fontWeight: FontWeight.bold)),
                    onPressed: _openRevisionDialog,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rose,
                      side: const BorderSide(color: AppColors.rose),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.report_problem, size: 18, color: AppColors.rose),
                    label: Text('فتح اعتراض', style: AppTypography.cairo(color: AppColors.rose, fontWeight: FontWeight.bold)),
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
