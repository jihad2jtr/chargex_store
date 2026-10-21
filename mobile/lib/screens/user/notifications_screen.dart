import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/app_catalog_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiClient _api = ApiClient();
  bool _isLoading = false;
  bool _isSendingTest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    await Provider.of<AppCatalogProvider>(context, listen: false).fetchNotifications();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _markAllAsRead() async {
    try {
      await _api.patch('/notifications/read-all');
      await _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديد جميع الإشعارات كمقروءة', style: AppTypography.cairo()),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _sendTestNotification() async {
    setState(() => _isSendingTest = true);
    try {
      await _api.post('/notifications/test-push', body: {
        'title': 'اختبار إشعارات Firebase 🔔',
        'body': 'تهانينا! نظام الإشعارات الفورية (FCM) يعمل بنجاح على جهازك.',
      });
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال إشعار تجريبي بنجاح عبر Firebase FCM! 🚀', style: AppTypography.cairo()),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الإشعار: $e', style: AppTypography.cairo()), backgroundColor: AppColors.rose),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = Provider.of<AppCatalogProvider>(context);
    final notifications = catalog.notifications;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          'مركز الإشعارات',
          style: AppTypography.cairo(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate900),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: AppColors.primaryBlue),
              tooltip: 'تحديد الكل كمقروء',
              onPressed: _markAllAsRead,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slate600),
            tooltip: 'تحديث',
            onPressed: _isLoading ? null : _loadNotifications,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: AppColors.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Swiss Neo-Bento Executive Push Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.slate900.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_active_outlined, color: AppColors.ticketAmber, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إشعارات فورية (Firebase FCM)',
                            style: AppTypography.cairo(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'تنبيهات تلقائية بتسليم الطلبات والأكواد',
                            style: AppTypography.cairo(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isSendingTest ? null : _sendTestNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSendingTest
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('اختبار FCM', style: AppTypography.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Notifications List
              if (_isLoading && notifications.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: AppColors.primaryBlue),
                  ),
                )
              else if (notifications.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return _buildNotificationCard(item);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(dynamic item) {
    final title = item['title']?.toString() ?? 'إشعار';
    final body = item['body']?.toString() ?? '';
    final isRead = item['isRead'] == true;
    final createdAtStr = item['createdAt'] != null
        ? DateFormat('yyyy/MM/dd hh:mm a').format(DateTime.tryParse(item['createdAt'].toString()) ?? DateTime.now())
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? AppColors.outline : AppColors.primaryBlue.withValues(alpha: 0.4),
          width: isRead ? 1 : 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isRead ? AppColors.paper : AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.notifications_rounded,
              color: isRead ? AppColors.slate600 : AppColors.primaryBlue,
              size: 20,
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
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.cairo(
                          fontSize: 13,
                          fontWeight: isRead ? FontWeight.bold : FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: AppTypography.cairo(fontSize: 12, color: AppColors.slate600, height: 1.4),
                  ),
                ],
                if (createdAtStr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    createdAtStr,
                    style: AppTypography.plusJakartaSans(fontSize: 10, color: AppColors.slate600.withValues(alpha: 0.7)),
                  ),
                ],
              ],
            ),
          ),
        ],
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
                border: Border.all(color: AppColors.outline),
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.slate600),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد إشعارات حالياً',
              style: AppTypography.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
            const SizedBox(height: 6),
            Text(
              'ستظهر هنا جميع تنبيهات عمليات الشحن وحالة طلباتك',
              style: AppTypography.cairo(fontSize: 12, color: AppColors.slate600),
            ),
          ],
        ),
      ),
    );
  }
}
