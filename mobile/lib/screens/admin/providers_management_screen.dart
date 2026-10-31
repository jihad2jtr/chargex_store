import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/provider_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/digital_pass_card.dart';
import '../../widgets/status_pill.dart';
import '../../providers/virtual_numbers_provider.dart';
import 'provider_form_dialog.dart';
import 'provider_products_screen.dart';
import 'virtual_number_catalog_screen.dart';

class ProvidersManagementScreen extends StatefulWidget {
  const ProvidersManagementScreen({super.key, this.virtualNumbersOnly = false});

  /// `true`: صفحة مزودي الأرقام الوهمية (5sim / Hero-SMS / DogeSMS / SMSPool).
  /// نفس التذكرة والمعالجة، لكن القائمة محصورة بهم وحدهم؛ منتجاتهم دول
  /// أرقام تُنتقى من كتالوج المزود إلى تطبيقات الأرقام — مثل منتجات
  /// المزود العاديين في المتجر تماماً.
  final bool virtualNumbersOnly;

  @override
  State<ProvidersManagementScreen> createState() =>
      _ProvidersManagementScreenState();
}

class _ProvidersManagementScreenState extends State<ProvidersManagementScreen> {
  bool _isCheckingAll = false;

  /// نصف المزودين الذي تعرضه هذه الصفحة: أرقام وهمية أو متاجر
  bool get _virtualOnly => widget.virtualNumbersOnly;

  // مقاسات التذكرة الموحّدة في هذه الشاشة (نفس هوية بقية صفحات الأدمن)
  static const double _radius = 16;
  static const double _notch = 8;
  static const double _stubWidth = 72;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchProviders();
    });
  }

  Future<void> _checkAllProviders() async {
    setState(() => _isCheckingAll = true);
    final admin = Provider.of<AdminProvider>(context, listen: false);
    // فحص الصفحة الحالية فقط: صفحات المزودين مفصولة، فلا يُفحص ما لا يظهر هنا
    final targets = admin.providers
        .where((p) => p.isVirtualNumber == _virtualOnly)
        .toList();
    for (final p in targets) {
      await admin.checkProviderStatus(p.id);
    }
    if (mounted) {
      setState(() => _isCheckingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _virtualOnly
                ? 'تم الانتهاء من فحص اتصال مزودي الأرقام وتحديث الأرصدة بنجاح ✅'
                : 'تم الانتهاء من فحص اتصال جميع المزودين وتحديث الأرصدة بنجاح ✅',
            style: AppTypography.cairo(),
          ),
          backgroundColor: AppColors.tertiaryLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// ورقة إضافة/تعديل المزود: كيان مستقل يملك حقوله ويصرّفها بنفسه
  void _openAddEditDialog([ProviderModel? provider]) {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    showDialog<void>(
      context: context,
      builder: (_) => ProviderFormDialog(
        admin: admin,
        provider: provider,
        virtualNumbersOnly: _virtualOnly,
      ),
    );
  }

  void _openProviderProducts(ProviderModel provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProviderProductsScreen(provider: provider),
      ),
    );
  }

  /// انتقاء دول الأرقام: كتالوج المزود ← تطبيقات الأرقام ← تفعيل/إخفاء
  void _openNumberCatalog(ProviderModel provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VirtualNumberCatalogScreen(providerId: provider.id),
      ),
    );
    // العودة بعد الانتقاء أو تبديل التفعيل: عدّادات التطبيقات تتحدث
    Future.microtask(() async {
      if (mounted) {
        await context.read<VirtualNumbersProvider>().fetchAdminApps(
          quiet: true,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    // كل صفحة تعرض نصفها فقط: مزودو المتاجر في «إدارة المزودين»
    // ومزودو الأرقام في صفحتهم المستقلة
    final providers = admin.providers
        .where((p) => p.isVirtualNumber == _virtualOnly)
        .toList();
    final onlineCount = providers.where((p) => p.status == 'online').length;
    final totalBalance = providers.fold<double>(
      0.0,
      (acc, p) => acc + p.balance,
    );
    final suspendedCount = providers.where((p) => !p.isActive).length;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          _virtualOnly ? 'مزودو الأرقام الوهمية' : 'إدارة المزودين',
          style: AppTypography.cairo(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: AppColors.slate900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _virtualOnly
                ? 'فحص اتصال مزودي الأرقام'
                : 'فحص اتصال جميع المزودين',
            icon: _isCheckingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryBlue,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.primaryBlue,
                  ),
            onPressed: _isCheckingAll ? null : _checkAllProviders,
          ),
          IconButton(
            tooltip: _virtualOnly ? 'إضافة مزود أرقام' : 'إضافة مزود جديد',
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
            ),
            onPressed: () => _openAddEditDialog(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: admin.isLoading && admin.providers.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          : RefreshIndicator(
              color: AppColors.primaryBlue,
              onRefresh: () => admin.fetchProviders(forceRefresh: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. بطاقة عدّادات واحدة بنمط التذكرة
                    _buildStatsTicket(
                      total: providers.length,
                      online: onlineCount,
                      suspended: suspendedCount,
                      totalBalance: totalBalance,
                    ),

                    const SizedBox(height: 16),

                    if (_virtualOnly) _buildWebhookInfoCard(),

                    // 2. تذاكر المزودين
                    _sectionHeader(
                      _virtualOnly
                          ? 'مزودو أرقام التحقق'
                          : 'المزودين المربوطين بالنظام',
                      _virtualOnly
                          ? 'SMS PROVIDERS · ${providers.length}'
                          : 'PROVIDERS · ${providers.length}',
                    ),

                    if (providers.isEmpty)
                      _buildEmptyState()
                    else
                      ...providers.map(
                        (provider) => _buildProviderCard(provider, admin),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // عناصر هوية التذكرة المشتركة (نفس مقاسات بقية صفحات الأدمن)
  // ---------------------------------------------------------------------------

  /// غلاف التذكرة: ظل + حد + قصّ بفتحتي تثقيب
  Widget _ticketShell({
    required Widget child,
    double radius = _radius,
    double notch = _notch,
    double elevation = 3,
    Color borderColor = AppColors.outline,
  }) {
    return CustomPaint(
      painter: TicketPassShadowPainter(
        cornerRadius: radius,
        notchRadius: notch,
        notchPositionFraction: 0.5,
        shadowColor: AppColors.slate900,
        elevation: elevation,
      ),
      child: CustomPaint(
        foregroundPainter: TicketPassBorderPainter(
          cornerRadius: radius,
          notchRadius: notch,
          notchPositionFraction: 0.5,
          borderColor: borderColor,
          borderWidth: 1,
        ),
        child: ClipPath(
          clipper: TicketPassClipper(
            cornerRadius: radius,
            notchRadius: notch,
            notchPositionFraction: 0.5,
          ),
          child: Material(color: AppColors.surfaceCard, child: child),
        ),
      ),
    );
  }

  /// فاصل مثقّب أفقي (نقّاط) بدل الخط الصلب
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

  /// خط تثقيب رأسي يفصل خانات العدّادات داخل البطاقة الواحدة
  Widget _stripDivider() {
    return SizedBox(
      height: 44,
      child: CustomPaint(
        painter: VerticalDashedLinePainter(
          color: AppColors.outline,
          dashHeight: 4,
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

  /// خانة عدّاد: أيقونة ملوّنة + رقم + تسمية. FittedBox يمنع طفو أي عنصر
  Widget _stripCell(
    String label,
    String value,
    IconData icon,
    Color color, {
    double valueSize = 15.5,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.26)),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.plusJakartaSans(
                fontSize: valueSize,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTypography.cairo(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.slate500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// عنوان قسم داخل الصفحة: شريط لوني + اسم + سطر تقني + خط مثقّب
  Widget _sectionHeader(String title, String code) {
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

  // ---------------------------------------------------------------------------
  // 1. بطاقة عدّادات واحدة: المزودون / متصلون / موقوفون / إجمالي الأرصدة
  // ---------------------------------------------------------------------------
  Widget _buildStatsTicket({
    required int total,
    required int online,
    required int suspended,
    required double totalBalance,
  }) {
    return _ticketShell(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
            child: Row(
              children: [
                _iconChip(AppColors.primaryBlue, Icons.hub_rounded),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _virtualOnly
                            ? 'بوابة مزودي الأرقام'
                            : 'بوابة اتصال المزودين',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                      Text(
                        _virtualOnly
                            ? 'SMS PROVIDERS LEDGER · $online/$total متصل'
                            : 'PROVIDERS LEDGER · $online/$total متصل',
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
          ),
          _dashedRule(color: AppColors.outline),
          Row(
            children: [
              Expanded(
                child: _stripCell(
                  'المزودون',
                  '$total',
                  Icons.hub_outlined,
                  AppColors.primaryBlue,
                ),
              ),
              _stripDivider(),
              Expanded(
                child: _stripCell(
                  'متصلون',
                  '$online',
                  Icons.cloud_done_rounded,
                  AppColors.emerald,
                ),
              ),
              _stripDivider(),
              Expanded(
                child: _stripCell(
                  'موقوفون',
                  '$suspended',
                  Icons.power_settings_new_rounded,
                  AppColors.rose,
                ),
              ),
              _stripDivider(),
              Expanded(
                child: _stripCell(
                  'إجمالي الأرصدة',
                  '\$${totalBalance.toStringAsFixed(2)}',
                  Icons.account_balance_wallet_rounded,
                  AppColors.tertiary,
                  valueSize: 13,
                ),
              ),
            ],
          ),
          _dashedRule(color: AppColors.outline),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue.withValues(
                    alpha: 0.08,
                  ),
                  foregroundColor: AppColors.primaryBlue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                    side: BorderSide(
                      color: AppColors.primaryBlue.withValues(alpha: 0.28),
                    ),
                  ),
                ),
                icon: _isCheckingAll
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryBlue,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  _isCheckingAll ? 'جارٍ فحص الاتصال…' : 'فحص الأرصدة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: _isCheckingAll ? null : _checkAllProviders,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebhookInfoCard() {
    final webhookUrl = ApiConstants.virtualNumbersWebhookUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.08),
              AppColors.tertiary.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: 0.25),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رابط الويب هوك لاستقبال الأكواد فورياً',
                        style: AppTypography.cairo(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate900,
                        ),
                      ),
                      Text(
                        'Webhook URL · يُرسل المزود الأكواد إليه في نفس اللحظة',
                        style: AppTypography.cairo(
                          fontSize: 11,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'طريقة الربط',
                  icon: const Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  onPressed: _showWebhookHelpDialog,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      webhookUrl,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: AppColors.slate800,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: webhookUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم نسخ رابط الويب هوك بنجاح ✅',
                            style: AppTypography.cairo(),
                          ),
                          backgroundColor: AppColors.emerald,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'نسخ',
                            style: AppTypography.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWebhookHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Text(
              'دليل تفعيل الويب هوك',
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
              'لتسريع استلام أكواد التحقق للعملاء دون انتظار، ضع رابط الويب هوك في إعدادات حسابك لدى المزود:',
              style: AppTypography.cairo(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              '1. مزود Hero-SMS / SMS-Activate:',
              style: AppTypography.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primaryBlue,
              ),
            ),
            Text(
              'توجه إلى إعدادات الحساب (Settings/API) وضع الرابط في حقل Push URL أو Webhook URL.',
              style: AppTypography.cairo(
                fontSize: 12,
                color: AppColors.slate700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '2. مزود 5sim:',
              style: AppTypography.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.emerald,
              ),
            ),
            Text(
              'توجه إلى لوحة تحكم 5sim في قسم الإشعارات (Notifications) وضع الرابط لاستقبال تحديثات الطلبات.',
              style: AppTypography.cairo(
                fontSize: 12,
                color: AppColors.slate700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'حسناً',
              style: AppTypography.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. تذكرة المزود: جسم بالهوية والبيانات وكعب بالرصيد على الحافة
  // ---------------------------------------------------------------------------
  Widget _buildProviderCard(ProviderModel provider, AdminProvider admin) {
    final bool isOnline = provider.status == 'online';
    final bool isActive = provider.isActive;
    final Color statusColor = !isActive
        ? AppColors.rose
        : isOnline
        ? AppColors.emerald
        : AppColors.slate400;
    final String marginValue = provider.profitMarginType == 'fixed'
        ? '\$${provider.profitMarginValue.toStringAsFixed(2)}'
        : '${provider.profitMarginValue.toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _ticketShell(
        borderColor: !isActive
            ? AppColors.rose.withValues(alpha: 0.45)
            : isOnline
            ? AppColors.primaryBlue.withValues(alpha: 0.30)
            : AppColors.outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // جسم التذكرة: الهوية + الرابط + بيانات المزود
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _providerAvatar(provider, isOnline),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      provider.name,
                                      style: AppTypography.cairo(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.slate900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    // Wrap بدل Row: الشارات تنزل سطرًا عند ضيق المساحة
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        StatusPill(status: provider.status),
                                        if (!isActive) _buildSuspendedPill(),
                                        if (provider.lastCheckAt != null)
                                          _chip(
                                            Icons.schedule_rounded,
                                            'آخر فحص ${_clockOf(provider.lastCheckAt!)}',
                                            AppColors.slate500,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          _urlPill(provider),
                          const SizedBox(height: 10),
                          _dashedRule(),
                          const SizedBox(height: 8),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _metaCell(
                                    icon: Icons.trending_up_rounded,
                                    label: 'هامش الربح',
                                    value: marginValue,
                                    note: _virtualOnly
                                        ? 'تُطبَّق على أسعار الأرقام'
                                        : 'تُطبَّق على كل المنتجات',
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                SizedBox(
                                  width: 1,
                                  child: CustomPaint(
                                    painter: VerticalDashedLinePainter(
                                      color: AppColors.outlineVariant,
                                      dashHeight: 4,
                                      dashSpace: 4,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _metaCell(
                                    icon: Icons.key_rounded,
                                    label: 'مفتاح API',
                                    value: _maskKey(provider.apiKey),
                                    note:
                                        provider.apiSecret != null &&
                                            provider.apiSecret!.isNotEmpty
                                        ? 'مرفق بـ API Secret'
                                        : 'مفتاح واحد فقط',
                                    color: AppColors.slate700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (provider.lastError != null &&
                              provider.lastError!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _note(
                              icon: Icons.error_outline_rounded,
                              text: 'تنبيه: ${provider.lastError}',
                              color: AppColors.rose,
                            ),
                          ],

                          // تنبيه الإيقاف: كل ما يرتبط بهذا المزود مخفي عن العملاء
                          if (!isActive) ...[
                            const SizedBox(height: 8),
                            _note(
                              icon: Icons.visibility_off_rounded,
                              text: _virtualOnly
                                  ? 'المزود موقوف — لن تُصدَر أرقام للعملاء'
                                  : 'المزود موقوف — كل التطبيقات والألعاب المرتبطة به لا تظهر للعملاء',
                              color: AppColors.errorLight,
                              background: AppColors.rose.withValues(
                                alpha: 0.07,
                              ),
                              border: AppColors.rose.withValues(alpha: 0.35),
                              maxLines: 3,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // خط التثقيب بين الجسم والكعب
                  SizedBox(
                    width: 1,
                    child: CustomPaint(
                      painter: VerticalDashedLinePainter(
                        color: AppColors.outlineVariant,
                        dashHeight: 5,
                        dashSpace: 4,
                      ),
                    ),
                  ),
                  // الكعب: حالة المزود ورصده في عمود ثابت العرض
                  Container(
                    width: _stubWidth,
                    color: statusColor.withValues(alpha: 0.07),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOnline
                              ? Icons.link_rounded
                              : Icons.link_off_rounded,
                          size: 15,
                          color: statusColor,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الرصيد',
                          maxLines: 1,
                          style: AppTypography.cairo(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate500,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '\$${provider.balance.toStringAsFixed(2)}',
                            maxLines: 1,
                            style: AppTypography.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: provider.balance <= 0
                                  ? AppColors.rose
                                  : AppColors.slate900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _dashedRule(color: AppColors.outline),

            // Actions Footer — صفّان: الإجراء الرئيسي + زر التفعيل، ثم أدوات الإدارة
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // مزود الأرقام منتجاته دول تُنتقى من كتالوجه — نفس مسار المتجر
                      if (_virtualOnly) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            icon: const Icon(Icons.public_rounded, size: 15),
                            label: Text(
                              'انتقاء الدول والتطبيقات',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => _openNumberCatalog(provider),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.slate700,
                            side: const BorderSide(color: AppColors.slate300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          icon: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 15,
                          ),
                          onPressed: () =>
                              admin.checkProviderStatus(provider.id),
                          label: Text(
                            'فحص الرصيد',
                            style: AppTypography.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else ...[
                        // Prominent "View Products" Button
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            icon: const Icon(
                              Icons.inventory_2_rounded,
                              size: 15,
                            ),
                            label: Text(
                              'عرض المنتجات',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => _openProviderProducts(provider),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // إيقاف/تفعيل المزود (يُخفي/يُظهر كل تطبيقاته)
                      _buildPowerButton(provider, admin, isActive),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Fast Tools (Sync, Check, Edit, Delete)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Sync
                      if (!_virtualOnly)
                        _buildCardIconButton(
                          tooltip: 'مزامنة المنتجات والأسعار',
                          icon: Icons.sync_rounded,
                          color: AppColors.primaryBlue,
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'جاري مزامنة المنتجات والأسعار من المزود...',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            final res = await admin.syncProviderProducts(
                              provider.id,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res?['message'] ?? 'تمت المزامنة بنجاح ✅',
                                  ),
                                  backgroundColor: res != null
                                      ? AppColors.tertiaryLight
                                      : AppColors.errorLight,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),

                      // Test Status
                      if (!_virtualOnly)
                        _buildCardIconButton(
                          tooltip: 'فحص الاتصال وتحديث الرصيد',
                          icon: Icons.flash_on_rounded,
                          color: AppColors.secondaryBright,
                          onPressed: () =>
                              admin.checkProviderStatus(provider.id),
                        ),

                      // Edit
                      _buildCardIconButton(
                        tooltip: 'تعديل المزود',
                        icon: Icons.edit_rounded,
                        color: AppColors.slate500,
                        onPressed: () => _openAddEditDialog(provider),
                      ),

                      // Delete
                      _buildCardIconButton(
                        tooltip: 'حذف المزود',
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.rose,
                        onPressed: () =>
                            _confirmDeleteProvider(provider, admin),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// أفاتار المزود: الحرف الأول داخل شارة متدرّجة بحدّ حالة الاتصال
  Widget _providerAvatar(ProviderModel provider, bool isOnline) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? AppColors.emerald : AppColors.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Text(
        provider.name.isNotEmpty
            ? provider.name.substring(0, 1).toUpperCase()
            : 'P',
        style: AppTypography.cairo(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  /// رابط المزود قابل للنسخ: Flexible + ellipsis حتى لا يفيض على الحافة
  Widget _urlPill(ProviderModel provider) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: provider.baseUrl));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم نسخ رابط المزود: ${provider.baseUrl}',
              style: AppTypography.cairo(),
            ),
            backgroundColor: AppColors.primaryBlue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dns_rounded, size: 12, color: AppColors.slate400),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                provider.baseUrl,
                style: AppTypography.technicalCode(
                  fontSize: 10.5,
                  color: AppColors.slate500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.copy_rounded, size: 11, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }

  /// شارة بيانات مصغّرة (آخر فحص / حالة) داخل صف الشارات
  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// خانة بيانات داخل التذكرة: عنوان صغير + قيمة + ملاحظة
  Widget _metaCell({
    required IconData icon,
    required String label,
    required String value,
    required String note,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.technicalCode(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// سطر تنبيه بلون واحد: الخطأ أو إشعار الإيقاف
  Widget _note({
    required IconData icon,
    required String text,
    required Color color,
    Color? background,
    Color? border,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border ?? color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTypography.cairo(
                fontSize: 10.5,
                height: 1.4,
                color: color,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// ساعة آخر فحص بصيغة HH:mm
  String _clockOf(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  /// إظهار آخر أربع خانات من المفتاح فقط — السر لا يُعرض كاملاً
  String _maskKey(String key) {
    if (key.length <= 6) return '••••';
    return '•••${key.substring(key.length - 4)}';
  }

  // زر إيقاف/تفعيل المزود بجانب الإجراء الرئيسي في البطاقة
  Widget _buildPowerButton(
    ProviderModel provider,
    AdminProvider admin,
    bool isActive,
  ) {
    final color = isActive ? AppColors.errorLight : AppColors.tertiaryLight;
    return Tooltip(
      message: isActive
          ? (_virtualOnly
                ? 'إيقاف مزود الأرقام عن العملاء'
                : 'إيقاف المزود وإخفاء تطبيقاته')
          : 'تفعيل المزود',
      child: InkWell(
        onTap: () => _confirmToggleProvider(provider, admin),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Icon(
            isActive
                ? Icons.power_settings_new_rounded
                : Icons.play_circle_fill_rounded,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }

  // زر أيقونة مدمج لا يتجاوز عرضه 38dp كي لا تفيض صفوف الإجراءات
  Widget _buildCardIconButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 19, color: color),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
    );
  }

  Widget _buildSuspendedPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.power_settings_new_rounded,
            size: 11,
            color: AppColors.errorLight,
          ),
          const SizedBox(width: 3),
          Text(
            'موقوف',
            style: AppTypography.cairo(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.errorLight,
            ),
          ),
        ],
      ),
    );
  }

  /// نافذة تأكيد فاتحة بهوية التذكرة: شارة + عنوان + سطر تقني + خط مثقّب
  Future<bool?> _confirmTicket({
    required String title,
    required String code,
    required String body,
    required String confirmLabel,
    required String cancelLabel,
    required Color danger,
    required IconData icon,
  }) {
    return showDialog<bool>(
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
            _iconChip(danger, icon, size: 28),
            const SizedBox(width: 9),
            // Expanded: عنوان عربي طويل بلا طفو على حافة النافذة
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      color: AppColors.slate900,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
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
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _dashedRule(color: AppColors.outline),
            const SizedBox(height: 10),
            Text(
              body,
              style: AppTypography.cairo(
                color: AppColors.slate600,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              cancelLabel,
              style: AppTypography.cairo(color: AppColors.slate500),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: AppTypography.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmToggleProvider(
    ProviderModel provider,
    AdminProvider admin,
  ) async {
    // الإيقاف يُخفي خدمات المزود (تطبيقات أو أرقام)، لذا يُطلب تأكيد صريح قبل التنفيذ
    if (provider.isActive) {
      final confirmed = await _confirmTicket(
        title: _virtualOnly ? 'إيقاف مزود الأرقام' : 'إيقاف مزود الخدمة',
        code: 'SUSPEND · ${provider.name}',
        body: _virtualOnly
            ? 'سيتم إيقاف "${provider.name}" فلن تُصدَر أرقام جديدة للعملاء\n'
                  'من صفحة الأرقام الوهمية فوراً. يمكنك تفعيله مجدداً في أي وقت.'
            : 'سيتم إيقاف "${provider.name}" وإخفاء كل التطبيقات والألعاب والخدمات المرتبطة به\n'
                  'من واجهة العملاء فوراً. يمكنك تفعيله مجدداً في أي وقت.',
        confirmLabel: 'إيقاف المزود',
        cancelLabel: 'إلغاء',
        danger: AppColors.errorLight,
        icon: Icons.power_settings_new_rounded,
      );
      if (confirmed != true) return;
    }

    final wasActive = provider.isActive;
    final ok = await admin.toggleProviderActive(provider.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (wasActive
                    ? (_virtualOnly
                          ? 'تم إيقاف "${provider.name}" فلن تُصدَر أرقام جديدة للعملاء 🚫'
                          : 'تم إيقاف "${provider.name}" وإخفاء كل تطبيقاته عن العملاء 🚫')
                    : (_virtualOnly
                          ? 'تم تفعيل "${provider.name}" ويمكنه إصدار أرقام للعملاء ✅'
                          : 'تم تفعيل "${provider.name}" وإظهار تطبيقاته المتاحة ✅'))
              : (admin.errorMessage ?? 'تعذّر تعديل حالة المزود'),
          style: AppTypography.cairo(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: ok
            ? (wasActive ? AppColors.errorLight : AppColors.tertiaryLight)
            : AppColors.errorLight,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmDeleteProvider(ProviderModel provider, AdminProvider admin) {
    _confirmTicket(
      title: _virtualOnly ? 'حذف مزود الأرقام' : 'حذف مزود الخدمة',
      code: 'DELETE · ${provider.name}',
      body: _virtualOnly
          ? 'هل أنت متأكد من حذف المزود "${provider.name}"؟ ستتوقف صفحة الأرقام الوهمية عن إصدار أرقام حتى تضيف مزوداً بديلاً.'
          : 'هل أنت متأكد من حذف المزود "${provider.name}"؟ قد يؤثر ذلك على المنتجات المربوطة به.',
      confirmLabel: 'تأكيد الحذف',
      cancelLabel: 'إلغاء',
      danger: AppColors.rose,
      icon: Icons.delete_outline_rounded,
    ).then((confirmed) {
      if (confirmed == true) admin.deleteProvider(provider.id);
    });
  }

  Widget _buildEmptyState() {
    return _ticketShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _iconChip(
              _virtualOnly ? AppColors.tertiary : AppColors.primaryBlue,
              _virtualOnly ? Icons.sim_card_rounded : Icons.hub_outlined,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              _virtualOnly
                  ? 'لا يوجد مزود أرقام بعد'
                  : 'لا يوجد مزودين مضافين حالياً',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _virtualOnly
                  ? 'أضف 5sim أو Hero-SMS لتفعيل صفحة الأرقام الوهمية وإصدار أرقام للعملاء'
                  : 'أضف مزودين مثل Smile One أو SEAGM لجلب المنتجات والأسعار تلقائياً',
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 12,
                color: AppColors.slate500,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _openAddEditDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                _virtualOnly ? 'إضافة مزود أرقام' : 'إضافة أول مزود',
                style: AppTypography.cairo(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
