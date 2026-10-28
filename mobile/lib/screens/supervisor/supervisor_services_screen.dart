import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/product_model.dart';
import '../../providers/manual_services_provider.dart';
import '../../widgets/digital_pass_card.dart';

/// هوية الخدمات الحساسة (مشفّرة) — لا يوجد رمز لوني بنفسجي في AppColors
const Color _violet = Color(0xFF7C3AED);

/// صفحة مستقلة للخدمات المسندة لمقدم الخدمة: عرضها بحالتها، إيقافها مؤقتاً
/// أو إعادة تفعيلها، ونسخ بيانات كل خدمة. تُفتح من بطاقة «خدماتي المسندة»
/// في لوحة المشرف، وتقرأ نفس مزّد الحالة فتبقى متزامنة معه.
class SupervisorServicesScreen extends StatefulWidget {
  const SupervisorServicesScreen({super.key});

  @override
  State<SupervisorServicesScreen> createState() =>
      _SupervisorServicesScreenState();
}

class _SupervisorServicesScreenState extends State<SupervisorServicesScreen> {
  // مقاسات التذكرة الموحّدة (نفس هوية بقية صفحات النظام)
  static const double _radius = 16;
  static const double _notch = 8;
  static const double _serviceStubWidth = 74;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = Provider.of<ManualServicesProvider>(
      context,
      listen: false,
    );
    await provider.fetchAssignedServices(
      silent: provider.assignedServices.isNotEmpty,
    );
    // عدّاد «طلب نشط» لكل خدمة يحتاج أحدث قائمة طلبات
    await provider.fetchSupervisorOrders(null, true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ManualServicesProvider>(context);
    final services = provider.assignedServices;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        scrolledUnderElevation: 1,
        foregroundColor: AppColors.slate900,
        title: Text(
          'خدماتي المسندة',
          style: AppTypography.cairo(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: AppColors.slate900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث الخدمات',
            icon: provider.isLoading
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
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryBlue,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            _sectionHeader(
              'الخدمات المسندة إليك',
              'SERVICES · ${services.length}',
            ),
            if (services.isEmpty)
              _buildNoServicesTicket()
            else ...[
              ...services.map(
                (service) => _buildServiceTicket(service, provider),
              ),
              _note(
                icon: Icons.visibility_off_rounded,
                text:
                    'الإيقاف المؤقت يخفي الخدمة عن واجهة العملاء ويمنع الطلبات الجديدة، ولا يُلغي الطلبات الجارية',
                color: AppColors.slate600,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // عناصر هوية التذكرة المشتركة (نسخة محلية كما في بقية الصفحات)
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

  // ---------------------------------------------------------------------------
  // الخدمات المسندة لمقدم الخدمة: إيقاف مؤقت / إعادة تفعيل
  // ---------------------------------------------------------------------------

  /// عدد الطلبات غير المكتملة على هذه الخدمة (من قائمة المشرف نفسها)
  int _openOrdersFor(String serviceId, ManualServicesProvider provider) {
    return provider.supervisorOrders
        .where((o) => o.productId == serviceId && !o.isCompleted)
        .length;
  }

  /// نص بيانات الخدمة الجاهز للنسخ (يُسلَّم للمشرف لتعبئته للعميل)
  String _serviceDataForCopy(ProductModel service) {
    final buffer = StringBuffer(service.name)
      ..writeln()
      ..writeln('السعر: \$${service.salePrice.toStringAsFixed(2)}')
      ..writeln('مدة التنفيذ: ${service.estimatedMinutes} دقيقة');
    if (service.quantityLabel.isNotEmpty) {
      buffer.writeln('الكمية: ${service.quantityLabel}');
    }
    if (service.requiredFields.isNotEmpty) {
      buffer.writeln(
        'البيانات المطلوبة: ${service.requiredFields.join(' / ')}',
      );
    }
    if (service.instructions != null && service.instructions!.isNotEmpty) {
      buffer.write('التعليمات: ${service.instructions}');
    }
    return buffer.toString().trim();
  }

  Future<void> _toggleServiceActive(ProductModel service) async {
    final provider = Provider.of<ManualServicesProvider>(
      context,
      listen: false,
    );
    final wasActive = service.isActive;
    final ok = await provider.toggleServiceActive(service.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (wasActive
                      ? 'تم إيقاف "${service.name}" مؤقتاً — لا تظهر للعملاء حتى تعيد تفعيلها'
                      : 'تم تفعيل "${service.name}" وهي متاحة للعملاء الآن ✅')
                : (provider.errorMessage ?? 'تعذر تعديل حالة الخدمة'),
            style: AppTypography.cairo(),
          ),
          backgroundColor: ok
              ? (wasActive
                    ? AppColors.secondaryBright
                    : AppColors.tertiaryLight)
              : AppColors.errorLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// خانة بيانات صغيرة داخل التذكرة: عنوان + قيمة لا تفيض أبداً
  Widget _metaCell({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
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
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: AppTypography.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: AppColors.slate900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceTicket(
    ProductModel service,
    ManualServicesProvider provider,
  ) {
    final bool isActive = service.isActive;
    final int openOrders = _openOrdersFor(service.id, provider);
    final Color accent = isActive ? AppColors.primaryBlue : AppColors.rose;
    final bool busy = provider.isTogglingService;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _ticketShell(
        borderColor: accent.withValues(alpha: isActive ? 0.30 : 0.45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _iconChip(
                                accent,
                                Icons.construction_rounded,
                                size: 34,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.cairo(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.slate900,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _chip(
                                          isActive
                                              ? Icons.play_circle_fill_rounded
                                              : Icons
                                                    .pause_circle_filled_rounded,
                                          isActive
                                              ? 'متاحة للعملاء'
                                              : 'موقوفة مؤقتاً',
                                          accent,
                                        ),
                                        if (service.quantityLabel.isNotEmpty)
                                          _chip(
                                            Icons.local_offer_outlined,
                                            service.quantityLabel,
                                            AppColors.slate600,
                                          ),
                                        if (service.isSensitive)
                                          _chip(
                                            Icons.lock_rounded,
                                            'بيانات مشفّرة',
                                            _violet,
                                          ),
                                        if (openOrders > 0)
                                          _chip(
                                            Icons.pending_actions_rounded,
                                            '$openOrders طلب نشط',
                                            AppColors.secondaryBright,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          _dashedRule(),
                          const SizedBox(height: 8),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _metaCell(
                                    icon: Icons.sell_outlined,
                                    label: 'سعر البيع',
                                    value:
                                        '\$${service.salePrice.toStringAsFixed(2)}',
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                _verticalRule(),
                                Expanded(
                                  child: _metaCell(
                                    icon: Icons.timer_outlined,
                                    label: 'مدة التنفيذ',
                                    value: '${service.estimatedMinutes} د',
                                    color: AppColors.secondaryBright,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (service.requiredFields.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'البيانات المطلوبة: ${service.requiredFields.join(' / ')}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.cairo(
                                      fontSize: 10.5,
                                      color: AppColors.slate600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'نسخ البيانات المطلوبة',
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 15,
                                    color: AppColors.primaryBlue,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 32,
                                  ),
                                  onPressed: () => _copyText(
                                    'البيانات المطلوبة',
                                    service.requiredFields.join('\n'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (service.instructions != null &&
                              service.instructions!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _note(
                              icon: Icons.assignment_outlined,
                              text: 'التعليمات: ${service.instructions}',
                              color: AppColors.slate600,
                            ),
                          ],
                          if (!isActive) ...[
                            const SizedBox(height: 6),
                            _note(
                              icon: Icons.visibility_off_rounded,
                              text:
                                  'الخدمة موقوفة مؤقتاً — لا تظهر في واجهة العملاء ولا تستقبل طلبات جديدة',
                              color: AppColors.errorLight,
                              background: AppColors.rose.withValues(
                                alpha: 0.07,
                              ),
                              border: AppColors.rose.withValues(alpha: 0.35),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _verticalRule(),
                  Container(
                    width: _serviceStubWidth,
                    color: accent.withValues(alpha: 0.07),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive
                              ? Icons.storefront_rounded
                              : Icons.storefront_outlined,
                          size: 15,
                          color: accent,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الحالة',
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
                            isActive ? 'نشطة' : 'موقوفة',
                            maxLines: 1,
                            style: AppTypography.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: accent,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyText(
                        'بيانات الخدمة',
                        _serviceDataForCopy(service),
                      ),
                      icon: const Icon(Icons.copy_all_rounded, size: 15),
                      label: Text(
                        'نسخ بيانات الخدمة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: BorderSide(
                          color: AppColors.primaryBlue.withValues(alpha: 0.35),
                        ),
                        backgroundColor: AppColors.primaryBlue.withValues(
                          alpha: 0.06,
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: busy
                          ? null
                          : () => _toggleServiceActive(service),
                      icon: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isActive
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 16,
                            ),
                      label: Text(
                        isActive ? 'إيقاف مؤقت' : 'إعادة تفعيل',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive
                            ? AppColors.errorLight
                            : AppColors.tertiaryLight,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
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

  /// لا خدمات مسندة: تذكرة إرشادية بدل الفراغ
  Widget _buildNoServicesTicket() {
    return _ticketShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
        child: Column(
          children: [
            _iconChip(
              AppColors.primaryBlue,
              Icons.construction_rounded,
              size: 46,
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد خدمات مسندة إليك حالياً',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'عند إسناد خدمة يدوية إليك من الإدارة ستظهر هنا، ويمكنك إيقافها مؤقتاً أو إعادة تفعيلها',
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 11.5,
                color: AppColors.slate500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
