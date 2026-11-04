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
import '../../widgets/top_notice.dart';
import 'topup_screen.dart';

/// صفحة انتظار الرمز: تُفتح فور الشراء ومن «طلباتي» بالضغط على الرقم.
/// مستقلة عن صفحة الأرقام — يمكن الرجوع وشراء رقم آخر وهو حيّ، فالـ polling
/// في الـ provider يحدّث كل الطلبات والصفحة تقرأ سجلها بـ id الطلب.
class VirtualNumberWaitScreen extends StatefulWidget {
  final String requestId;

  /// نسخة لحظة الضغط: تُستعمل طلائع قبل أول مزامنة، والمصدر الحقيقي السجل
  final VirtualNumberRequestModel initialRequest;

  const VirtualNumberWaitScreen({
    super.key,
    required this.requestId,
    required this.initialRequest,
  });

  @override
  State<VirtualNumberWaitScreen> createState() =>
      _VirtualNumberWaitScreenState();
}

class _VirtualNumberWaitScreenState extends State<VirtualNumberWaitScreen>
    with SingleTickerProviderStateMixin {
  /// التهيئة في initState لا كسولةً: late final مُهيَّأ عند أول استخدام قد
  /// يُنشئ العدّاد داخل dispose بعد موت العنصر فترمي «deactivated ancestor»
  late final AnimationController _breath;

  Timer? _ticker;

  /// الرمز نُسِخ ونُبه عليه مرة واحدة عند وصوله: نسخة + تنبيه + هزة
  bool _codeAnnounced = false;

  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _codeAnnounced = widget.initialRequest.hasCode;
    // عدّاد الثواني للرموز والمهلة — يعمل ما دامت الصفحة مفتوحة
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<VirtualNumbersProvider>();
      provider.fetchMyRequests(quiet: true);
      provider.startAutoPolling();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _breath.dispose();
    super.dispose();
  }

  /// المصدر: سجل الـ provider (يتحدث من الـ polling)؛ والطلائع نسخة الضغط
  VirtualNumberRequestModel _readRequest(VirtualNumbersProvider provider) {
    for (final r in provider.myRequests) {
      if (r.id == widget.requestId) return r;
    }
    return widget.initialRequest;
  }

  void _copy(String value, String label) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showTopSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.slate800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          'تم نسخ $label',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }

  void _announceCode(String code) {
    if (_codeAnnounced) return;
    _codeAnnounced = true;
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: code));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          backgroundColor: AppColors.emerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'وصل رمز التحقق — نُسخ إلى حافظتك',
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

  /// إلغاء العميل بعد بلوغ حد الإبقاء: الخادم يُلغي لدى المزود ثم يُرجع المبلغ
  Future<void> _cancelNumber(VirtualNumberRequestModel request) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'إلغاء الرقم واسترجاع المبلغ',
          style: AppTypography.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 15.5,
          ),
        ),
        content: Text(
          'سيُرسل إلغاء الرقم للمزود أولاً، فإن قُبِل عندك يُرجَع '
          '\$${request.amount.toStringAsFixed(2)} كاملاً إلى رصيدك.\n\n'
          'إن كان الرمز قد وصل لا يمكن الإلغاء — الطلب حينها يُغلق كخدمة مُسلَّمة.',
          style: AppTypography.cairo(fontSize: 12.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'تراجع',
              style: AppTypography.cairo(color: AppColors.slate500),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء واسترجاع'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    setState(() => _cancelling = true);
    final provider = context.read<VirtualNumbersProvider>();
    final message = await provider.closeRequest(request.id);
    if (!mounted) return;
    setState(() => _cancelling = false);

    ScaffoldMessenger.of(context).showTopSnackBar(
      SnackBar(
        backgroundColor: message != null ? AppColors.slate800 : AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message ?? provider.errorMessage ?? 'تعذّر إلغاء الرقم',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
    if (message != null) {
      await context.read<WalletProvider>().fetchBalance();
      if (mounted) Navigator.pop(context);
    }
  }

  /// إغلاق بعد وصول الرمز: تُنهى الخدمة لدى المزود بلا إرجاع
  Future<void> _finishNumber() async {
    final provider = context.read<VirtualNumbersProvider>();
    final message = await provider.closeRequest(widget.requestId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showTopSnackBar(
      SnackBar(
        backgroundColor: message != null ? AppColors.slate800 : AppColors.rose,
        content: Text(
          message ?? provider.errorMessage ?? 'تعذّر إغلاق الرقم',
          style: AppTypography.cairo(fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
    if (message != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VirtualNumbersProvider>();
    final request = _readRequest(provider);
    // انطبعت الحالة النهائية (إلغاء من الإدارة/المسح) وهو مفتوح: تُغلق الصفحة بمحتواها
    if (request.hasCode) _announceCode(request.smsCode!);

    final waiting = request.isWaitingForCode;
    final balance = context.watch<WalletProvider>().balance;
    final lowBalance = balance < 0.5;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'رجوع (الرقم يبقى حيّاً في «طلباتي»)',
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'انتظار الرمز',
              style: AppTypography.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
              ),
            ),
            Text(
              request.requestNumber,
              style: AppTypography.technicalCode(
                fontSize: 10,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: StatusPill(
              status: request.status,
              label: request.statusLabel,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          children: [
            _heroCard(request, waiting),
            const SizedBox(height: 12),
            if (request.hasCode) ...[
              _smsTextCard(request),
              const SizedBox(height: 12),
              _successActions(request),
            ] else ...[
              _timelineCard(request),
              const SizedBox(height: 12),
              _cancelZone(request),
              const SizedBox(height: 14),
              _buyAnotherCard(lowBalance),
            ],
            if (request.note.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.ticketAmberLight),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.secondaryBright,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.note,
                        style: AppTypography.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSecondaryContainer,
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
    );
  }

  // ===========================================================================
  // البطاقة الرئيسية: الرقم + العدّاد الدائري + نبض الانتظار أو الرمز
  // ===========================================================================
  Widget _heroCard(VirtualNumberRequestModel request, bool waiting) {
    final hasCode = request.hasCode;
    final tone = hasCode ? AppColors.emerald : AppColors.ticketAmber;
    // النداء يُفصل عن الرقم للعرض: لا يتوفر حين لا يرسل الخادم نداء الدولة
    // أو لا يطابق بداية الرقم، فيبقى الرقم كاملاً كما كان
    final split = hasCode ? null : _splitDial(request);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.slate900, AppColors.slate800, AppColors.slate900],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(request.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${request.title} • ${request.countryName}'
                  '${request.serverLabel.isNotEmpty ? ' • ${request.serverLabel}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              _gauge(request),
            ],
          ),
          const SizedBox(height: 16),
          // الرقم للنسخ — أو الرمز نفسه عندما يصل
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: tone.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasCode
                            ? 'رمز التحقق وصل ✅'
                            : request.phoneNumber == null
                            ? 'جارٍ تجهيز الرقم…'
                            : 'أدخل هذا الرقم في التطبيق',
                        style: AppTypography.cairo(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // نداء الدولة فوق الرقم: في الرقم الدولي الكامل
                      // (+963999…) يذوب النداء فيصعب تمييزه عمن يملأ التطبيق
                      if (split != null) ...[
                        Row(
                          children: [
                            Text(
                              'النداء:',
                              style: AppTypography.cairo(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              split.dial,
                              style: AppTypography.technicalCode(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ticketAmberLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      SelectableText(
                        hasCode
                            ? request.smsCode!
                            : (split?.local ??
                                  request.phoneNumber ??
                                  '— — — —'),
                        style: AppTypography.technicalCode(
                          color: hasCode
                              ? const Color(0xFF6EE7B7)
                              : Colors.white,
                          fontSize: hasCode ? 24 : 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: hasCode ? 4 : 1.1,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _copy(
                    hasCode ? request.smsCode! : (request.phoneNumber ?? ''),
                    hasCode ? 'الرمز' : 'الرقم',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: tone.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // نبض الانتظار: موجة تنبض أن الاتصال حيّ والمز يرسل الرمز تلقائياً
          if (waiting) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pulseDot(tone, 0),
                _pulseDot(tone, 1),
                _pulseDot(tone, 2),
                const SizedBox(width: 10),
                // Flexible لا Text عارياً: عند 380dp كانت العبارة تفيض
                // من صف النقاط فيُصرخ RenderFlex في وجه الاختبارات
                Flexible(
                  child: Text(
                    'الرصد تلقائي — يصل الرمز هنا فوراً',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// فصل نداء الدولة عن الرقم المحلي: الخادم يرسل النداء (+963) وحده
  /// والرقم الدولي كاملًا، فإذا طابق النداءُ بدايةَ الرقم عُرِض مفصولًا،
  /// وإلا أُعيد null وبقي الرقم معروضًا كما هو (خادم قديم أو دولة مجهولة)
  ({String dial, String local})? _splitDial(VirtualNumberRequestModel request) {
    final digits = (request.phoneNumber ?? '').replaceFirst('+', '');
    final dial = (request.callingCode ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty || dial.isEmpty || !digits.startsWith(dial)) {
      return null;
    }
    final local = digits.substring(dial.length);
    if (local.isEmpty) return null;
    return (dial: '+$dial', local: local);
  }

  Widget _pulseDot(Color tone, int index) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (_, child) => Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: tone.withValues(
            alpha: 0.35 + 0.65 * _wave(index, _breath.value),
          ),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// موجة متدرجة: كل نقطة تصل ذروتها في وقت مختلف (نظام النقاط الثلاث)
  double _wave(int index, double t) {
    final shifted = (t + index * 0.33) % 1.0;
    return shifted < 0.5 ? shifted * 2 : (1 - shifted) * 2;
  }

  /// العدّاد الدائري: مهلة الانتظار، أو نافذة عرض الرمز بعد وصوله
  Widget _gauge(VirtualNumberRequestModel request) {
    final left = request.remainingSeconds() ?? 0;
    final total = _totalSeconds(request);
    final progress = total > 0 ? (left / total).clamp(0.0, 1.0) : 0.0;
    final hasCode = request.hasCode;
    final urgent = !hasCode && left <= 120;
    final tone = hasCode
        ? AppColors.emerald
        : (urgent ? AppColors.rose : AppColors.ticketAmber);

    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4.5,
              strokeCap: StrokeCap.round,
              backgroundColor: tone.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatClock(left),
                style: AppTypography.technicalCode(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                hasCode ? 'نافذة العرض' : 'متبقٍ',
                style: AppTypography.cairo(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _totalSeconds(VirtualNumberRequestModel request) {
    final end = request.expiresAt;
    if (end == null) return 15 * 60;
    final start = request.hasCode ? request.codeReceivedAt : request.createdAt;
    final span = start == null ? 0 : end.difference(start).inSeconds;
    return span > 0 ? span : 15 * 60;
  }

  String _formatClock(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ===========================================================================
  // نص رسالة SMS الكامل: يفيد حين يقص الرمز المستخرج أو يريد العميل قراءته
  // ===========================================================================
  Widget _smsTextCard(VirtualNumberRequestModel request) {
    final smsText = request.smsText;
    if (smsText == null || smsText.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sms_rounded, size: 16, color: AppColors.emerald),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              smsText,
              style: AppTypography.technicalCode(
                fontSize: 11.5,
                color: AppColors.slate700,
              ).copyWith(height: 1.5),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _copy(smsText, 'نص الرسالة'),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.copy_rounded,
                size: 15,
                color: AppColors.slate500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _successActions(VirtualNumberRequestModel request) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _finishNumber,
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('تم — إغلاق الرقم'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.slate900,
              side: const BorderSide(color: AppColors.slate100),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('رجوع'),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // خط الوقت التعليمي: ثلاث خطوات تُطمئن العميل أن النظام يعمل
  // ===========================================================================
  Widget _timelineCard(VirtualNumberRequestModel request) {
    final numberReady = request.phoneNumber != null;
    final steps = <(String, String, bool)>[
      ('الخصم', '\$${request.amount.toStringAsFixed(2)} من رصيدك', true),
      (
        'تجهيز الرقم',
        numberReady ? 'الرقم جاهز لديك' : 'لحظات عند المزود',
        numberReady,
      ),
      ('وصول الرمز', 'يُرصد ويُعرض هنا تلقائياً', request.hasCode),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_rounded,
                size: 16,
                color: AppColors.slate600,
              ),
              const SizedBox(width: 6),
              Text(
                'كيف يعمل؟',
                style: AppTypography.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (i, step) in steps.indexed) ...[
            if (i > 0)
              Container(
                margin: const EdgeInsets.only(right: 5),
                width: 2,
                height: 14,
                color: AppColors.slate100,
              ),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.$3 ? AppColors.emerald : AppColors.slate100,
                    border: Border.all(
                      color: step.$3 ? AppColors.emerald : AppColors.slate600,
                      width: 1.5,
                    ),
                  ),
                  child: step.$3
                      ? const Icon(
                          Icons.check_rounded,
                          size: 9,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  step.$1,
                  style: AppTypography.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: step.$3 ? AppColors.slate900 : AppColors.slate600,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    step.$2,
                    textAlign: TextAlign.start,
                    style: AppTypography.cairo(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // منطقة الإلغاء: مقفولة بعَدّاد حتى 10 دقائق، ثم زر إلغاء واسترجاع
  // ===========================================================================
  Widget _cancelZone(VirtualNumberRequestModel request) {
    final waitLeft = request.cancelWaitRemaining();

    if (waitLeft != null) {
      // قبل الحد: الإلغاء غير متاح، والبطاقة تشرح ضمان الإرجاع التلقائي
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.slate100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.lock_clock_rounded,
                size: 18,
                color: AppColors.slate600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الإلغاء متاح بعد ${_formatClock(waitLeft)}',
                    style: AppTypography.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'إن لم تصل رسالة خلال المهلة كاملاً يُرجَع المبلغ '
                    'تلقائياً — لا حاجة للإلغاء اليدوي',
                    style: AppTypography.cairo(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.rose,
          side: BorderSide(color: AppColors.rose.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        onPressed: _cancelling ? null : () => _cancelNumber(request),
        icon: _cancelling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cancel_rounded, size: 18),
        label: Text(
          _cancelling
              ? 'جارٍ إرسال الإلغاء للمزود…'
              : 'إلغاء الرقم واسترجاع \$${request.amount.toStringAsFixed(2)}',
          style: AppTypography.cairo(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  // ===========================================================================
  // شراء آخر دون انتظار: الصفحة لا تحبس العميل عند رقم واحد
  // ===========================================================================
  Widget _buyAnotherCard(bool lowBalance) {
    return Material(
      color: lowBalance ? const Color(0xFFFFF7ED) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (lowBalance) {
            _goTopup();
          } else {
            Navigator.pop(context);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: lowBalance
                      ? AppColors.secondaryContainer
                      : AppColors.slate100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  lowBalance
                      ? Icons.account_balance_wallet_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 18,
                  color: lowBalance
                      ? AppColors.secondaryBright
                      : AppColors.slate600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lowBalance ? 'رصيدك منخفض — اشحن أولاً' : 'شراء رقم آخر',
                      style: AppTypography.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lowBalance
                          ? 'هذا الرقم يبقى حيّاً ويصل رمزه تلقائياً'
                          : 'هذا الرقم يبقى حيّاً في «طلباتي» — عدّ إليه متى شئت',
                      style: AppTypography.cairo(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: AppColors.slate500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goTopup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TopupScreen()));
  }
}
