import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/virtual_number_model.dart';
import '../../providers/virtual_numbers_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/status_pill.dart';
import 'topup_screen.dart';

/// صفحة الأرقام الوهمية: بدل صفحة «شحن الاشتراكات».
/// الاختلاف الجوهري عن بقية المشتريات أن الرمز يصل بعد ثوانٍ أو دقائق، فالصفحة
/// تُبقي الرقم الحيّ في الأعلى وتفحصه دورياً، وتُرجع المبلغ تلقائياً عند انتهاء
/// المهلة بلا رسالة — لذلك تُظهر العدّاد وحالة الإرجاع بوضوح.
class VirtualNumbersScreen extends StatefulWidget {
  final bool showAppBar;
  const VirtualNumbersScreen({super.key, this.showAppBar = true});

  @override
  State<VirtualNumbersScreen> createState() => _VirtualNumbersScreenState();
}

class _VirtualNumbersScreenState extends State<VirtualNumbersScreen> {
  final Set<String> _codeAnnounced = {};
  final Set<String> _refundAnnounced = {};

  VirtualNumbersProvider? _provider;
  Timer? _ticker;
  bool _tickerRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<VirtualNumbersProvider>();
      // ما هو مُستلَم أو مُرجَع بالفعل في المخزن لا يُعاد التنبيه عنه عند كل فتح
      for (final request in provider.myRequests) {
        if (request.hasCode) _codeAnnounced.add(request.id);
        if (request.isRefunded) _refundAnnounced.add(request.id);
      }
      _provider = provider..addListener(_onProviderChanged);
      provider.fetchOptions();
      provider.fetchMyRequests().then((_) {
        if (mounted) provider.startAutoPolling();
      });
      context.read<WalletProvider>().fetchBalance();
      _syncTicker();
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    _provider?.stopPolling();
    _ticker?.cancel();
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    final provider = _provider;
    if (provider == null) return;

    final active = provider.activeRequest;
    if (active != null &&
        active.hasCode &&
        !_codeAnnounced.contains(active.id)) {
      _codeAnnounced.add(active.id);
      _notify(
        'وصل رمز التحقق',
        'افتح الرقم وانسخ الرمز قبل انتهاء نافذة العرض',
        AppColors.emerald,
      );
    }

    for (final request in provider.myRequests) {
      if (request.isRefunded && !_refundAnnounced.contains(request.id)) {
        _refundAnnounced.add(request.id);
        _notify(
          'أُرجع المبلغ إلى محفظتك',
          '${request.title}: ${request.note}',
          AppColors.ticketAmber,
        );
        if (mounted) {
          context.read<WalletProvider>().fetchBalance();
        }
      }
    }

    _syncTicker();
  }

  /// الرسائل تأجل إلى ما بعد الإطارية: notifyListeners قد يحدث أثناء البناء
  void _notify(String title, String body, Color tone) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: tone,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title — $body',
                  style: AppTypography.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// عدّاد الثواني يعمل فقط أثناء وجود مهلة جارية (لا مؤقّت بلا حاجة)
  void _syncTicker() {
    final needsTicker = _provider?.activeRequest != null;
    if (needsTicker && !_tickerRunning) {
      _tickerRunning = true;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needsTicker && _tickerRunning) {
      _tickerRunning = false;
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _refreshAll() async {
    final provider = context.read<VirtualNumbersProvider>();
    await provider.fetchMyRequests();
    await provider.fetchOptions(forceRefresh: true);
    provider.startAutoPolling();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VirtualNumbersProvider>();
    final active = provider.activeRequest;

    final body = RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: widget.showAppBar ? 12 : 4,
          bottom: widget.showAppBar ? 28 : 104,
        ),
        children: [
          if (provider.errorMessage != null &&
              provider.options.services.isEmpty &&
              active == null) ...[
            _buildAlert(provider.errorMessage!),
            const SizedBox(height: 14),
          ],
          if (active != null) ...[
            _buildSectionHeader('رقمك النشط', 'LIVE NUMBER'),
            const SizedBox(height: 10),
            _LiveNumberPass(
              request: active,
              waitMinutes: provider.options.waitMinutes,
              onCopy: _copy,
              onClose: () => _closeActive(active),
            ),
            const SizedBox(height: 18),
          ] else ...[
            _buildSectionHeader('اختر الخدمة', 'ACTIVATE'),
            const SizedBox(height: 10),
            _buildServicesArea(provider),
            const SizedBox(height: 18),
          ],
          // سجل الأرقام الوهمية لم يعد منعزلاً هنا: هو مدمج في «طلباتي»
        ],
      ),
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('الأرقام الوهمية'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              provider.stopPolling();
              _refreshAll().then((_) => provider.startAutoPolling());
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: body,
    );
  }

  // ---------------------------------------------------------------------------
  // بطاقات الصفحة
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title, String badge) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.slate900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.slate200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: AppTypography.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: AppColors.slate700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesArea(VirtualNumbersProvider provider) {
    if (provider.isLoadingOptions && provider.options.services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final services = provider.options.services;
    if (services.isEmpty) {
      return _buildEmptyCatalog(provider);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 4 : 2,
        childAspectRatio: 1.42,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return _ServiceCard(
          service: service,
          onTap: () => _openCountrySheet(service),
        );
      },
    );
  }

  Widget _buildEmptyCatalog(VirtualNumbersProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.numbers_rounded,
            size: 40,
            color: AppColors.slate400,
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد أرقام متاحة',
            style: AppTypography.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.slate900,
            ),
          ),

          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => provider.fetchOptions(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('إعادة جلب القائمة'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlert(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorLight,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.errorLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // الإجراءات
  // ---------------------------------------------------------------------------

  void _copy(String value, String label) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.slate800,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'تم نسخ $label',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _openCountrySheet(VirtualNumberServiceOption service) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _CountrySheet(
        service: service,
        balance: context.read<WalletProvider>().balance,
        waitMinutes: context.read<VirtualNumbersProvider>().options.waitMinutes,
        onSubmit: (country, operator) => _submit(service, country, operator),
      ),
    );
    if (mounted) context.read<VirtualNumbersProvider>().startAutoPolling();
  }

  /// يُعيد true عند نجاح الطلب كي تُغلق النافذة نفسها
  Future<bool> _submit(
    VirtualNumberServiceOption service,
    VirtualNumberCountryOption country,
    VirtualNumberOperator? operator,
  ) async {
    final provider = context.read<VirtualNumbersProvider>();
    final wallet = context.read<WalletProvider>();

    if (country.salePrice > wallet.balance) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('رصيد غير كافٍ'),
          content: Text(
            'السعر \$${country.salePrice.toStringAsFixed(2)} ورصيدك '
            '\$${wallet.balance.toStringAsFixed(2)}. اشحن رصيدك ثم أعد المحاولة.',
            style: AppTypography.cairo(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('الذهاب للشحن'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const TopupScreen()));
      }
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تفعيل رقم ${service.name}'),
        content: Text(
          'الدولة: ${country.name}\n'
          'المشغّل: ${operator?.name ?? 'أي مشغّل متاح'}\n'
          'السعر: \$${country.salePrice.toStringAsFixed(2)} يُخصم من رصيدك\n\n'
          'يصل الرمز تلقائياً خلال الانتظار، وإن لم تصل رسالة تُرجع المبلغ كاملاً.',
          style: AppTypography.cairo(fontSize: 12.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تفعيل الرقم'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    final message = await provider.requestNumber(
      service: service.code,
      country: country.code,
      operator: operator?.code,
    );

    if (!mounted) return message != null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: message != null ? AppColors.slate800 : AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message ?? provider.errorMessage ?? 'تعذّر تفعيل الرقم',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
    return message != null;
  }

  Future<void> _closeActive(VirtualNumberRequestModel request) async {
    final provider = context.read<VirtualNumbersProvider>();
    final gotCode = request.hasCode;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gotCode ? 'إغلاق الرقم' : 'إلغاء الرقم'),
        content: Text(
          gotCode
              ? 'سيُغلق الرقم بعد استلام الرمز. لا يُرجع المبلغ لأن الخدمة سُلّمت.'
              : 'لم يصل رمز بعد — يُلغى الرقم حالياً ويُرجع المبلغ \$${request.amount.toStringAsFixed(2)} إلى رصيدك.',
          style: AppTypography.cairo(fontSize: 12.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(gotCode ? 'إغلاق' : 'إلغاء واسترجاع'),
          ),
        ],
      ),
    );
    if (go != true) return;

    final message = await provider.closeRequest(request.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: message != null ? AppColors.slate800 : AppColors.rose,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message ?? provider.errorMessage ?? 'تعذّر إغلاق الرقم',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
    await context.read<WalletProvider>().fetchBalance();
  }
}

// =============================================================================
// بطاقة الرقم الحيّ: الرقم للنسخ، العدّاد، ثم الرمز عندما يصل
// =============================================================================

class _LiveNumberPass extends StatelessWidget {
  final VirtualNumberRequestModel request;
  final int waitMinutes;
  final void Function(String value, String label) onCopy;
  final VoidCallback onClose;

  const _LiveNumberPass({
    required this.request,
    required this.waitMinutes,
    required this.onCopy,
    required this.onClose,
  });

  String _countdown() {
    final left = request.remainingSeconds();
    if (left == null) return '—';
    final minutes = (left / 60).floor();
    final seconds = left % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = request.hasCode;
    final accent = hasCode ? AppColors.emerald : AppColors.ticketAmber;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شريط الحالة العلوي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.slate900,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${request.title} • ${request.countryName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                StatusPill(status: request.status, label: request.statusLabel),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _numberRow(),
                const SizedBox(height: 10),
                if (hasCode) ...[
                  _codePanel(request.smsCode!, request.smsText),
                ] else
                  _waitingPanel(),
                if (request.note.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    request.note,
                    style: AppTypography.cairo(
                      fontSize: 10.5,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            onCopy(request.phoneNumber ?? '', 'الرقم'),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('نسخ الرقم'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.slate900,
                          side: const BorderSide(color: AppColors.slate300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onClose,
                        style: FilledButton.styleFrom(
                          backgroundColor: hasCode
                              ? AppColors.emerald
                              : AppColors.slate700,
                        ),
                        icon: Icon(
                          hasCode
                              ? Icons.check_circle_rounded
                              : Icons.close_rounded,
                          size: 16,
                        ),
                        label: Text(hasCode ? 'تم — إغلاق' : 'إلغاء واسترجاع'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.phoneNumber == null
                      ? 'جارٍ تجهيز الرقم…'
                      : 'أدخل هذا الرقم في التطبيق',
                  style: AppTypography.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  request.phoneNumber ?? '— — —',
                  style: AppTypography.technicalCode(
                    color: AppColors.slate900,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          _countdownBadge(),
        ],
      ),
    );
  }

  Widget _countdownBadge() {
    final left = request.remainingSeconds();
    final urgent = left != null && left <= 120;
    final tone = request.hasCode
        ? AppColors.emerald
        : (urgent ? AppColors.rose : AppColors.slate700);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _countdown(),
            style: AppTypography.technicalCode(
              color: tone,
              fontSize: 15,
              letterSpacing: 0.6,
            ),
          ),
          Text(
            request.hasCode ? 'نافذة العرض' : 'متبقٍ',
            style: AppTypography.cairo(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ticketAmberLight),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.ticketAmber,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بانتظار وصول رسالة التحقق…',
                  style: AppTypography.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'يظهر الرمز هنا تلقائياً خلال دقائق، وإن مرّت $waitMinutes دقيقة بلا رمز يُرجع المبلغ لرصيدك.',
                  style: AppTypography.cairo(
                    fontSize: 10.5,
                    height: 1.5,
                    color: AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _codePanel(String code, String? smsText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.mark_email_read_rounded,
                size: 17,
                color: AppColors.tertiaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                'رمز التحقق وصل',
                style: AppTypography.cairo(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onTertiaryContainer,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'نسخ الرمز',
                onPressed: () => onCopy(code, 'الرمز'),
                icon: const Icon(
                  Icons.copy_all_rounded,
                  size: 18,
                  color: AppColors.tertiaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SelectableText(
            code,
            textAlign: TextAlign.center,
            style: AppTypography.technicalCode(
              color: AppColors.slate900,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 7,
            ),
          ),
          if (smsText != null && smsText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              smsText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 10,
                height: 1.45,
                color: AppColors.slate600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// بطاقة خدمة في الشبكة
// =============================================================================

class _ServiceCard extends StatelessWidget {
  final VirtualNumberServiceOption service;
  final VoidCallback onTap;

  const _ServiceCard({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.slate900,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      service.code.isEmpty
                          ? '#'
                          : service.code.substring(0, 1).toUpperCase(),
                      style: AppTypography.fintechBadge(
                        color: const Color(0xFFFDE047),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 13,
                    color: AppColors.slate400,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                service.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${service.countries.length} دولة • من \$${service.bestPrice.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// نافذة اختيار الدولة والمشغّل
// =============================================================================

class _CountrySheet extends StatefulWidget {
  final VirtualNumberServiceOption service;
  final double balance;
  final int waitMinutes;
  final Future<bool> Function(
    VirtualNumberCountryOption country,
    VirtualNumberOperator? operator,
  )
  onSubmit;

  const _CountrySheet({
    required this.service,
    required this.balance,
    required this.waitMinutes,
    required this.onSubmit,
  });

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  VirtualNumberCountryOption? _country;
  String? _operatorCode;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.service.countries.isNotEmpty) {
      _country = widget.service.countries.first;
    }
  }

  Future<void> _submit() async {
    final country = _country;
    if (country == null || _submitting) return;
    setState(() => _submitting = true);
    final ok = await widget.onSubmit(country, _operatorFor(country));
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Navigator.of(context).pop();
  }

  VirtualNumberOperator? _operatorFor(VirtualNumberCountryOption country) {
    if (_operatorCode == null || country.operators.isEmpty) return null;
    for (final operator in country.operators) {
      if (operator.code == _operatorCode) return operator;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final countries = widget.service.countries;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 42,
            height: 4,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'أرقام ${widget.service.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate900,
                    ),
                  ),
                ),
                Text(
                  'رصيدك \$${widget.balance.toStringAsFixed(2)}',
                  style: AppTypography.balance(
                    fontSize: 11.5,
                    color: AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'اختر الدولة — وإن كانت متاحة اختر المشغّل. '
              'تُرجَع المبلغ تلقائياً إن مرّت ${widget.waitMinutes} دقيقة بلا رمز.',
              style: AppTypography.cairo(
                fontSize: 10.5,
                height: 1.5,
                color: AppColors.slate500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (countries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('لا دول متاحة لهذه الخدمة'),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: countries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final country = countries[index];
                  final selected = _country?.code == country.code;
                  final affordable = country.salePrice <= widget.balance;
                  return _countryTile(country, selected, affordable);
                },
              ),
            ),
          if (_country != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Text(
                'المشغّل',
                style: AppTypography.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate600,
                ),
              ),
            ),
            _operatorRow(),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: FilledButton(
              onPressed: _country == null || _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.slate900,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'تفعيل الرقم \$${(_country?.salePrice ?? 0).toStringAsFixed(2)}',
                      style: AppTypography.arabicButton(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countryTile(
    VirtualNumberCountryOption country,
    bool selected,
    bool affordable,
  ) {
    return Material(
      color: selected ? const Color(0xFFFFF7E6) : AppColors.slate50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _country = country;
          _operatorCode = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.ticketAmber : AppColors.slate200,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 17,
                color: selected
                    ? AppColors.secondaryBright
                    : AppColors.slate400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate900,
                      ),
                    ),
                    if (country.count > 0)
                      Text(
                        'متاح ${country.count} رقم',
                        style: AppTypography.cairo(
                          fontSize: 9.5,
                          color: AppColors.slate500,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '\$${country.salePrice.toStringAsFixed(2)}',
                style: AppTypography.price(
                  color: affordable ? AppColors.slate900 : AppColors.rose,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _operatorRow() {
    final country = _country;
    final operators = country?.operators ?? const <VirtualNumberOperator>[];
    if (operators.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'يُختار المشغّل تلقائياً',
          style: AppTypography.cairo(fontSize: 10.5, color: AppColors.slate500),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          _operatorChip(null, 'أي مشغّل'),
          ...operators.map((o) => _operatorChip(o.code, o.name)),
        ],
      ),
    );
  }

  Widget _operatorChip(String? code, String label) {
    final selected = _operatorCode == code;
    return Padding(
      padding: const EdgeInsets.only(left: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _operatorCode = code),
        labelStyle: AppTypography.cairo(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.slate700,
        ),
        selectedColor: AppColors.slate900,
        backgroundColor: AppColors.slate100,
      ),
    );
  }
}
