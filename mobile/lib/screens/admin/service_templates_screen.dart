import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/service_template_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/digital_pass_card.dart';

/// أنواع الحقول الثابتة المدعومة عند بناء قالب خدمة
const List<Map<String, String>> kServiceFieldTypes = [
  {'value': 'player_id', 'label': 'الايدي (Player ID)'},
  {'value': 'phone', 'label': 'رقم هاتف'},
  {'value': 'name', 'label': 'الاسم'},
  {'value': 'email', 'label': 'البريد الإلكتروني'},
  {'value': 'password', 'label': 'كلمة المرور'},
  {'value': 'quantity', 'label': 'الكمية (أسهمي +/-)'},
  {'value': 'custom', 'label': 'حقل مخصص'},
];

/// شاشة «أنواع قوالب الخدمة»: كل قالب تذكرة لها — جسم على اليمين وكعب
/// يعدّ حقول الإدخال على اليسار، وفواصل مثقّبة بدل الخطوط الصلبة.
class ServiceTemplatesScreen extends StatefulWidget {
  const ServiceTemplatesScreen({super.key});

  @override
  State<ServiceTemplatesScreen> createState() => _ServiceTemplatesScreenState();
}

class _ServiceTemplatesScreenState extends State<ServiceTemplatesScreen> {
  // مقاسات التذكرة الموحّدة في هذه الشاشة
  static const double _radius = 16;
  static const double _notch = 8;
  static const double _stubWidth = 62;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(
        context,
        listen: false,
      ).fetchServiceTemplates();
    });
  }

  // ---------------------------------------------------------------------------
  // عناصر الهوية المشتركة
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

  Widget _iconChip(Color color, IconData icon, {double size = 40}) {
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
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }

  Widget _pill(String label, Color color, {bool dot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String code, [String count = '']) {
    final String meta = count.isEmpty ? code : '$code · $count';
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
              meta,
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
  // الهيكل العام
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    final templates = admin.serviceTemplates;
    final activeCount = templates.where((t) => t.isActive).length;
    final inactiveCount = templates.length - activeCount;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _iconChip(
                  AppColors.primaryBlue,
                  Icons.dashboard_customize_rounded,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'أنواع قوالب الخدمة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'SERVICE TEMPLATES // FIELD BUILDER',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.technicalCode(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.slate600,
              size: 20,
            ),
            tooltip: 'تحديث',
            onPressed: admin.isLoading ? null : admin.fetchServiceTemplates,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('قالب جديد'),
      ),
      body: admin.isLoading && templates.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          : RefreshIndicator(
              color: AppColors.primaryBlue,
              onRefresh: admin.fetchServiceTemplates,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
                children: [
                  _statusStrip(
                    total: templates.length,
                    active: activeCount,
                    inactive: inactiveCount,
                  ),
                  const SizedBox(height: 14),
                  _sectionHeader(
                    'القوالب المتاحة',
                    'TEMPLATES',
                    '${templates.length}',
                  ),
                  const SizedBox(height: 10),
                  if (templates.isEmpty)
                    _emptyTicket()
                  else
                    for (final template in templates)
                      _templateTicket(admin, template),
                ],
              ),
            ),
    );
  }

  /// شريط العدّادات: بطاقة واحدة بثلاث خانات تفصلها خطوط مثقّبة
  Widget _statusStrip({
    required int total,
    required int active,
    required int inactive,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _stripCell(
              'القوالب',
              '$total',
              Icons.dashboard_customize_rounded,
              AppColors.primaryBlue,
            ),
          ),
          _stripDivider(),
          Expanded(
            child: _stripCell(
              'مفعّلة',
              '$active',
              Icons.check_circle_rounded,
              AppColors.accentGreen,
            ),
          ),
          _stripDivider(),
          Expanded(
            child: _stripCell(
              'معطّلة',
              '$inactive',
              Icons.pause_circle_rounded,
              AppColors.rose,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stripDivider() {
    return SizedBox(
      height: 46,
      child: CustomPaint(
        painter: VerticalDashedLinePainter(
          color: AppColors.outline,
          dashHeight: 4,
          dashSpace: 4,
        ),
      ),
    );
  }

  Widget _stripCell(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: color.withValues(alpha: 0.26)),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: AppTypography.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // تذكرة القالب
  // ---------------------------------------------------------------------------
  Widget _templateTicket(AdminProvider admin, ServiceTemplateModel template) {
    final Color opColor = _opColor(template.operationType);
    final bool hasSensitive = template.fields.any((f) => f.isSensitive);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _ticketShell(
        child: Stack(
          children: [
            // كعب عدد الحقول — Positioned يمتد بكامل ارتفاع التذكرة
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _fieldsStub(template, opColor, hasSensitive),
            ),
            // خط التثقيب الفاصل بين الجسم والكعب
            Positioned(
              left: _stubWidth,
              top: 12,
              bottom: 12,
              width: 1,
              child: CustomPaint(
                painter: VerticalDashedLinePainter(
                  color: AppColors.outlineVariant,
                  dashHeight: 5,
                  dashSpace: 4,
                ),
              ),
            ),
            // جسم التذكرة
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: _stubWidth + 12),
                    child: _ticketHeader(admin, template, opColor),
                  ),
                  if (template.description.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        left: _stubWidth + 12,
                        top: 6,
                        right: 2,
                      ),
                      child: Text(
                        template.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: _stubWidth + 12,
                      top: 10,
                      right: 2,
                    ),
                    child: _dashedRule(color: AppColors.outline),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: _stubWidth + 12,
                      top: 10,
                      right: 2,
                    ),
                    child: _fieldsFooter(admin, template),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ticketHeader(
    AdminProvider admin,
    ServiceTemplateModel template,
    Color opColor,
  ) {
    return Row(
      children: [
        _iconChip(opColor, _opIcon(template.operationType)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Flexible(
                    child: _pill(
                      _operationLabel(template.operationType),
                      opColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: _pill(
                      template.isActive ? 'مفعّل' : 'معطّل',
                      template.isActive
                          ? AppColors.accentGreen
                          : AppColors.rose,
                      dot: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _templateMenu(admin, template),
      ],
    );
  }

  Widget _templateMenu(AdminProvider admin, ServiceTemplateModel template) {
    return PopupMenuButton<String>(
      tooltip: 'إجراءات القالب',
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: AppColors.slate600,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      color: AppColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: AppColors.slate900.withValues(alpha: 0.30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outline),
      ),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 16, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text('تعديل القالب'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_rounded, size: 16, color: AppColors.rose),
              SizedBox(width: 8),
              Text('حذف القالب'),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'edit') _openEditor(template);
        if (val == 'delete') _confirmDelete(admin, template);
      },
    );
  }

  /// الكعب: عدد الحقول + رمز الحالة (مشفّر / فوري / حقول)
  Widget _fieldsStub(
    ServiceTemplateModel template,
    Color opColor,
    bool hasSensitive,
  ) {
    final Color stubColor = template.isActive ? opColor : AppColors.slate400;
    return SizedBox(
      width: _stubWidth,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(stubColor, Colors.white, 0.92)!,
              Color.lerp(stubColor, Colors.white, 0.80)!,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${template.fields.length}',
              style: AppTypography.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: stubColor,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              template.fields.length == 1 ? 'حقل' : 'حقول',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cairo(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.slate600,
              ),
            ),
            _dashedRule(color: stubColor.withValues(alpha: 0.45), gap: 5),
            Icon(
              hasSensitive
                  ? Icons.lock_rounded
                  : template.fields.isEmpty
                  ? Icons.bolt_rounded
                  : Icons.input_rounded,
              size: 13,
              color: hasSensitive
                  ? AppColors.secondaryBright
                  : stubColor.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 3),
            Text(
              hasSensitive
                  ? 'ENCRYPTED'
                  : template.fields.isEmpty
                  ? 'INSTANT'
                  : 'FIELDS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.technicalCode(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: AppColors.slate500,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// التذييل: رقائق الحقول + مفتاح التفعيل
  Widget _fieldsFooter(AdminProvider admin, ServiceTemplateModel template) {
    return Row(
      children: [
        Expanded(
          child: template.fields.isEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: AppColors.accentGreen,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'بدون حقول إدخال · تسليم فوري',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate600,
                        ),
                      ),
                    ),
                  ],
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: template.fields.map(_buildFieldChip).toList(),
                ),
        ),
        const SizedBox(width: 6),
        Transform.scale(
          scale: 0.78,
          child: Switch(
            value: template.isActive,
            activeThumbColor: AppColors.accentGreen,
            onChanged: admin.isLoading
                ? null
                : (_) => admin.toggleServiceTemplateActive(template.id),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldChip(ServiceFieldDef f) {
    final color = f.isSensitive ? AppColors.ticketAmber : AppColors.primaryBlue;
    return ConstrainedBox(
      // سقف عرض حتى لا تتجاوز رقاقة واحدة عرض الجسم على الشاشات الضيقة
      constraints: const BoxConstraints(maxWidth: 150),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_fieldChipIcon(f.type), size: 13, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                f.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate700,
                ),
              ),
            ),
            if (f.isSensitive) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.lock_rounded,
                size: 11,
                color: AppColors.secondaryBright,
              ),
            ] else if (f.required) ...[
              const SizedBox(width: 3),
              Text(
                '*',
                style: AppTypography.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.rose,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyTicket() {
    return _ticketShell(
      radius: 18,
      notch: 9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
        child: Column(
          children: [
            _iconChip(
              AppColors.primaryBlue,
              Icons.dashboard_customize_rounded,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد قوالب خدمة بعد',
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'أنشئ قالباً لتحديد حقول الإدخال (ايدي، هاتف، كلمة مرور...) وربطه بخدمات الشحن اليدوي.',
              textAlign: TextAlign.center,
              style: AppTypography.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.slate500,
                height: 1.4,
              ),
            ),
            _dashedRule(gap: 14),
            const SizedBox(height: 4),
            SizedBox(
              width: 190,
              child: ElevatedButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text(
                  'إنشاء أول قالب',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // خرائط الألوان والأيقونات والنصوص
  // ---------------------------------------------------------------------------
  Color _opColor(String type) {
    switch (type) {
      case 'direct_api':
        return AppColors.ticketAmber;
      case 'codes':
        return AppColors.tertiary;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _opIcon(String type) {
    switch (type) {
      case 'direct_api':
        return Icons.bolt_rounded;
      case 'codes':
        return Icons.confirmation_number_rounded;
      default:
        return Icons.support_agent_rounded;
    }
  }

  String _operationLabel(String type) {
    switch (type) {
      case 'direct_api':
        return 'شحن مباشر (API)';
      case 'codes':
        return 'بطاقات/أكواد';
      default:
        return 'شحن يدوي';
    }
  }

  IconData _fieldChipIcon(String type) {
    switch (type) {
      case 'phone':
        return Icons.phone_outlined;
      case 'name':
        return Icons.person_outline;
      case 'email':
        return Icons.email_outlined;
      case 'password':
        return Icons.lock_outline;
      case 'quantity':
        return Icons.numbers;
      case 'player_id':
        return Icons.badge_outlined;
      default:
        return Icons.edit_outlined;
    }
  }

  String _fieldLabelFor(String type) {
    for (final t in kServiceFieldTypes) {
      if (t['value'] == type) return t['label']!;
    }
    return 'حقل مخصص';
  }

  // ---------------------------------------------------------------------------
  // حقول النموذج الموحّدة
  // ---------------------------------------------------------------------------
  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    String? errorText,
    String? helper,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      errorText: errorText,
      helperText: helper,
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      prefixIcon: icon == null
          ? null
          : Icon(
              icon,
              size: 18,
              color: errorText != null ? AppColors.rose : AppColors.slate400,
            ),
      labelStyle: AppTypography.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.slate500,
      ),
      hintStyle: AppTypography.cairo(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: AppColors.slate400,
      ),
      enabledBorder: border(AppColors.outline),
      border: border(AppColors.outline),
      focusedBorder: border(AppColors.primaryBlue, 1.5),
      errorBorder: border(AppColors.rose),
      focusedErrorBorder: border(AppColors.errorLight, 1.5),
    );
  }

  /// شارة اختيار نوع العملية — ثلاث شرائح بدل القائمة المنسدلة
  Widget _opChoice({
    required String value,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final Color color = _opColor(value);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.13)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.outline,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? color : AppColors.slate400),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? color : AppColors.slate600,
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              Icon(Icons.check_rounded, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }

  /// مفتاح الحقل (مطلوب / حساس) كشارة قابلة للضغط بدل SwitchListTile
  Widget _toggleChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.outlineVariant,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? icon : Icons.circle_outlined,
              size: 12,
              color: selected ? color : AppColors.slate400,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: selected ? color : AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // محرّر القالب (إضافة / تعديل)
  // ---------------------------------------------------------------------------
  void _openEditor([ServiceTemplateModel? template]) {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    final bool isEditing = template != null;
    final String? templateId = template?.id;
    String operationType = template?.operationType ?? 'manual';
    final List<ServiceFieldDef> fields = List<ServiceFieldDef>.from(
      template?.fields ?? const [],
    );
    String? nameError;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        // المتحكمات النصية يملكها Widget خاص كي يُتلفها عند زوال العنصر،
        // لأن pop ينهي مسار الشيت قبل نهاية أنيميشن الخروج.
        return _SheetControllers(
          initialName: template?.name ?? '',
          initialDescription: template?.description ?? '',
          builder: (nameCtrl, descCtrl) {
            return StatefulBuilder(
              builder: (sheetCtx, setSheetState) {
                final Color accent = _opColor(operationType);

                void saveField(int index, ServiceFieldDef next) =>
                    setSheetState(() => fields[index] = next);

                Future<void> submit() async {
                  if (nameCtrl.text.trim().isEmpty) {
                    setSheetState(() => nameError = 'اسم القالب مطلوب');
                    return;
                  }
                  setSheetState(() {
                    nameError = null;
                    saving = true;
                  });
                  final data = <String, dynamic>{
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'operationType': operationType,
                    'fields': fields.map((f) => f.toJson()).toList(),
                  };
                  final bool ok = isEditing
                      ? await admin.updateServiceTemplate(templateId!, data)
                      : await admin.createServiceTemplate(data);
                  if (!sheetCtx.mounted) return;
                  if (ok) {
                    Navigator.of(sheetCtx).pop();
                    _notify(
                      isEditing ? 'تم تحديث القالب ✅' : 'تم إنشاء القالب ✅',
                    );
                  } else {
                    setSheetState(() => saving = false);
                    _notify(
                      admin.errorMessage ?? 'فشل حفظ القالب',
                      color: AppColors.errorLight,
                    );
                  }
                }

                return Padding(
                  // إزاحة أسفل الشيت عند ظهور لوحة المفاتيح حتى لا تُقصّ الأزرار
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
                  ),
                  child: Material(
                    key: const Key('template-editor-sheet'),
                    color: AppColors.surfaceCard,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // مقبض السحب
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.outlineVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        _sheetHeader(
                          sheetCtx,
                          isEditing,
                          accent,
                          operationType,
                        ),
                        // فاصل التذكرة المثقّب تحت الترويسة
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _dashedRule(color: AppColors.outlineVariant),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _sectionHeader('هوية القالب', 'IDENTITY'),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: nameCtrl,
                                  textInputAction: TextInputAction.next,
                                  decoration: _inputDecoration(
                                    label:
                                        'اسم القالب (مثال: خدمة شحن عبر الحساب)',
                                    icon: Icons.label_outline_rounded,
                                    errorText: nameError,
                                  ),
                                  onChanged: (_) {
                                    if (nameError != null) {
                                      setSheetState(() => nameError = null);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: descCtrl,
                                  maxLines: 2,
                                  decoration: _inputDecoration(
                                    label: 'وصف مختصر (اختياري)',
                                    icon: Icons.notes_rounded,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'نوع العملية',
                                  style: AppTypography.cairo(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.slate700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final type in const [
                                      'manual',
                                      'direct_api',
                                      'codes',
                                    ])
                                      _opChoice(
                                        value: type,
                                        label: _operationLabel(type),
                                        icon: _opIcon(type),
                                        selected: operationType == type,
                                        onTap: () => setSheetState(
                                          () => operationType = type,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _sectionHeader(
                                  'حقول الإدخال',
                                  'FIELDS',
                                  '${fields.length}',
                                ),
                                const SizedBox(height: 10),
                                if (fields.isEmpty)
                                  _noFieldsSlot()
                                else
                                  for (int i = 0; i < fields.length; i++)
                                    _fieldSlot(
                                      fields,
                                      i,
                                      setField: (next) => saveField(i, next),
                                      onRemove: () => setSheetState(
                                        () => fields.removeAt(i),
                                      ),
                                    ),
                                const SizedBox(height: 2),
                                _addFieldSlot(
                                  accent,
                                  () => setSheetState(
                                    () => fields.add(
                                      ServiceFieldDef(
                                        type: 'player_id',
                                        label: _fieldLabelFor('player_id'),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _sheetFooter(
                          sheetCtx,
                          saving: saving,
                          isEditing: isEditing,
                          accent: accent,
                          onSubmit: submit,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sheetHeader(
    BuildContext sheetCtx,
    bool isEditing,
    Color accent,
    String operationType,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Row(
        children: [
          _iconChip(accent, _opIcon(operationType), size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'تعديل قالب الخدمة' : 'قالب خدمة جديد',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cairo(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEditing
                      ? 'SERVICE TEMPLATE // EDIT'
                      : 'SERVICE TEMPLATE // CREATE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.technicalCode(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(sheetCtx).pop(),
            tooltip: 'إغلاق',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 19,
              color: AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetFooter(
    BuildContext sheetCtx, {
    required bool saving,
    required bool isEditing,
    required Color accent,
    required VoidCallback onSubmit,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : () => Navigator.of(sheetCtx).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.slate600,
                side: const BorderSide(color: AppColors.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('إلغاء'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: saving ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                disabledBackgroundColor: AppColors.surfaceContainerHigh,
                disabledForegroundColor: AppColors.slate500,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isEditing ? Icons.save_rounded : Icons.add_rounded,
                      size: 17,
                    ),
              label: Text(
                saving
                    ? 'جارٍ الحفظ…'
                    : isEditing
                    ? 'حفظ'
                    : 'إنشاء',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noFieldsSlot() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 16,
            color: AppColors.accentGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'لم تُضف حقول بعد — مثل بطاقات الشحن لا تتطلب أي إدخال.',
              style: AppTypography.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.slate500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addFieldSlot(Color accent, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 17, color: accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'إضافة حقل إدخال',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// خانة حقل واحدة: رقم + نوع + رقائق (مطلوب / حساس) + حذف
  Widget _fieldSlot(
    List<ServiceFieldDef> fields,
    int index, {
    required void Function(ServiceFieldDef next) setField,
    required VoidCallback onRemove,
  }) {
    final field = fields[index];
    final bool isCustom = field.type == 'custom';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  '${index + 1}',
                  style: AppTypography.technicalCode(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: field.type,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'نوع الحقل',
                    icon: _fieldChipIcon(field.type),
                  ),
                  items: kServiceFieldTypes
                      .map(
                        (t) => DropdownMenuItem(
                          value: t['value'],
                          child: Text(
                            t['label']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate800,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setField(
                      ServiceFieldDef(
                        type: val,
                        label: val == 'custom'
                            ? 'حقل مخصص'
                            : _fieldLabelFor(val),
                        required: field.required,
                        isSensitive: val == 'password',
                        placeholder: field.placeholder,
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                tooltip: 'حذف الحقل',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.rose,
                  size: 20,
                ),
              ),
            ],
          ),
          if (isCustom) ...[
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('custom-label-$index-${field.type}'),
              initialValue: field.label,
              decoration: _inputDecoration(
                label: 'اسم الحقل المخصص',
                icon: Icons.drive_file_rename_outline_rounded,
              ),
              onChanged: (val) => setField(
                ServiceFieldDef(
                  type: field.type,
                  label: val,
                  required: field.required,
                  isSensitive: field.isSensitive,
                  placeholder: field.placeholder,
                ),
              ),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              _toggleChip(
                label: 'مطلوب',
                icon: Icons.star_rounded,
                selected: field.required,
                color: AppColors.primaryBlue,
                onTap: () => setField(
                  ServiceFieldDef(
                    type: field.type,
                    label: field.label,
                    required: !field.required,
                    isSensitive: field.isSensitive,
                    placeholder: field.placeholder,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _toggleChip(
                label: 'حساس (مشفّر)',
                icon: Icons.lock_rounded,
                selected: field.isSensitive,
                color: AppColors.ticketAmber,
                onTap: () => setField(
                  ServiceFieldDef(
                    type: field.type,
                    label: field.label,
                    required: field.required,
                    isSensitive: !field.isSensitive,
                    placeholder: field.placeholder,
                  ),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  field.label.isEmpty ? '—' : field.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTypography.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate400,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // التأكيدات والتنبيهات
  // ---------------------------------------------------------------------------
  void _notify(String message, {Color color = AppColors.slate900}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  void _confirmDelete(AdminProvider admin, ServiceTemplateModel template) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        child: _ticketShell(
          radius: 18,
          notch: 8,
          borderColor: AppColors.rose.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _iconChip(AppColors.rose, Icons.delete_rounded, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حذف القالب',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'DELETE // NOT RESTORABLE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.technicalCode(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _dashedRule(color: AppColors.outline, gap: 12),
                Text(
                  'هل أنت متأكد من حذف «${template.name}»؟ القوالب المرتبطة بخدمات قائمة قد تتأثر.',
                  style: AppTypography.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    admin.deleteServiceTemplate(template.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rose,
                    foregroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.delete_rounded, size: 16),
                  label: const Text(
                    'حذف نهائي',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.slate600,
                    side: const BorderSide(color: AppColors.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// يملك المتحكمات النصية لمحرّر القالب ويتلفها مع زوال العنصر،
/// فلا تُستخدم بعد الإغلاق أثناء أنيميشن الخروج.
class _SheetControllers extends StatefulWidget {
  const _SheetControllers({
    required this.initialName,
    required this.initialDescription,
    required this.builder,
  });

  final String initialName;
  final String initialDescription;
  final Widget Function(
    TextEditingController nameCtrl,
    TextEditingController descCtrl,
  )
  builder;

  @override
  State<_SheetControllers> createState() => _SheetControllersState();
}

class _SheetControllersState extends State<_SheetControllers> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _descCtrl = TextEditingController(
    text: widget.initialDescription,
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_nameCtrl, _descCtrl);
}
