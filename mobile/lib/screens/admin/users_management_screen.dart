import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/digital_pass_card.dart';

/// صفحة إدارة المستخدمين: عرض كل الحسابات، البحث، الترقية إلى وكيل أو مشرف،
/// الإرجاع إلى عميل، تفعيل/تعطيل الحسابات، وشحن/خصم رصيد العميل مباشرة.
/// قاعدة العمل: يفترض أن يُرقّى العميل تلقائياً إلى مشرف عند إسناد خدمة له،
/// ويرقية «الوكيل» يدوية حصراً من هنا لأنه يبني شبكة عملاء على رصيده.
class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

/// هوية رتبة الوكيل البصرية في هذه الصفحة
const Color _agentColor = Color(0xFF8B5CF6);

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _roleFilter = 'all';

  // مقاسات التذكرة الموحّدة في هذه الشاشة (نفس هوية بقية صفحات الأدمن)
  static const double _radius = 16;
  static const double _notch = 8;
  static const double _stubWidth = 70;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchAllUsers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> users) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return users.where((u) {
      if (_roleFilter != 'all' && _roleOfUser(u) != _roleFilter) return false;
      if (q.isEmpty) return true;
      final haystack = [
        u['name'] ?? '',
        u['email'] ?? '',
        u['phone'] ?? '',
        u['userId'] ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  void _openDetails(Map<String, dynamic> user, AdminProvider admin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailsSheet(user: user, admin: admin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    final all = admin.allUsers;
    final filtered = _applyFilters(all);

    final supervisorsCount = all
        .where((u) => _roleOfUser(u) == 'supervisor')
        .length;
    final agentsCount = all.where((u) => _roleOfUser(u) == 'agent').length;
    final customersCount = all.where((u) => _roleOfUser(u) == 'user').length;
    final suspendedCount = all.where((u) => u['isActive'] == false).length;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.outline),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'إدارة المستخدمين',
                style: AppTypography.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slate600),
            tooltip: 'تحديث',
            onPressed: admin.isLoading ? null : () => admin.fetchAllUsers(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => admin.fetchAllUsers(),
        color: AppColors.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsTicket(
                total: all.length,
                agents: agentsCount,
                supervisors: supervisorsCount,
                customers: customersCount,
                suspended: suspendedCount,
              ),
              const SizedBox(height: 16),

              // Search
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: AppTypography.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو البريد أو الهاتف أو رقم المستخدم',
                  hintStyle: AppTypography.cairo(
                    fontSize: 12.5,
                    color: AppColors.slate400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.slate400,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.slate500,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primaryBlue,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _buildRoleChips(),
              const SizedBox(height: 14),

              if (admin.isLoading && all.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 50),
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                _buildEmptyState()
              else
                _buildUsersList(filtered, admin, loading: admin.isLoading),

              const SizedBox(height: 40),
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
  Widget _stripCell(String label, String value, IconData icon, Color color) {
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
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
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

  // ---------------------------------------------------------------------------
  // بطاقة عدّادات واحدة: الإجمالي والوكلاء والمشرفون والعملاء والموقوفون
  // ---------------------------------------------------------------------------
  Widget _buildStatsTicket({
    required int total,
    required int agents,
    required int supervisors,
    required int customers,
    required int suspended,
  }) {
    return _ticketShell(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
            child: Row(
              children: [
                _iconChip(AppColors.primaryBlue, Icons.people_alt_rounded),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'عدّادات الحسابات',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                      Text(
                        'USERS LEDGER · $total',
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
                  'الإجمالي',
                  '$total',
                  Icons.groups_rounded,
                  AppColors.primaryBlue,
                ),
              ),
              _stripDivider(),
              Expanded(
                child: _stripCell(
                  'وكلاء',
                  '$agents',
                  Icons.support_agent_rounded,
                  _agentColor,
                ),
              ),
              _stripDivider(),
              Expanded(
                child: _stripCell(
                  'مشرفون',
                  '$supervisors',
                  Icons.verified_user_rounded,
                  AppColors.ticketAmber,
                ),
              ),
              _stripDivider(),
              Expanded(
                child: _stripCell(
                  'عملاء',
                  '$customers',
                  Icons.person_rounded,
                  AppColors.tertiary,
                ),
              ),
              _stripDivider(),
              Expanded(
                child: _stripCell(
                  'موقوفون',
                  '$suspended',
                  Icons.block_rounded,
                  AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Role Filter Chips ---
  Widget _buildRoleChips() {
    final filters = <Map<String, dynamic>>[
      {'key': 'all', 'label': 'الكل', 'color': AppColors.primaryBlue},
      {'key': 'user', 'label': 'عملاء', 'color': const Color(0xFF6366F1)},
      {
        'key': 'supervisor',
        'label': 'مشرفون',
        'color': const Color(0xFF38BDF8),
      },
      {'key': 'agent', 'label': 'وكلاء', 'color': _agentColor},
      {'key': 'admin', 'label': 'أدمن', 'color': AppColors.ticketAmber},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _roleFilter == f['key'];
          final Color color = f['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(f['label'] as String),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (val) {
                if (val) setState(() => _roleFilter = f['key'] as String);
              },
              selectedColor: color,
              backgroundColor: Colors.white,
              labelStyle: AppTypography.cairo(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.slate600,
              ),
              side: BorderSide(
                color: isSelected ? color : AppColors.outline,
                width: isSelected ? 1.2 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // قائمة المستخدمين بتذكرة واحدة: رأس هوية ثم صفوف تفصلها خطوط مثقّبة
  // ---------------------------------------------------------------------------
  Widget _buildUsersList(
    List<Map<String, dynamic>> users,
    AdminProvider admin, {
    required bool loading,
  }) {
    return _ticketShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
            child: Row(
              children: [
                _iconChip(AppColors.primaryBlue, Icons.groups_rounded),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المستخدمون',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                      Text(
                        'USERS · ${users.length}',
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
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryBlue,
                    ),
                  ),
              ],
            ),
          ),
          _dashedRule(color: AppColors.outline),
          for (int i = 0; i < users.length; i++) ...[
            if (i != 0) _dashedRule(),
            _buildUserTile(users[i], admin),
          ],
        ],
      ),
    );
  }

  // --- User Tile ---
  /// صف مستخدم داخل التذكرة: جسم بالاسم والشارات وكعب بالرصيد على الحافة
  Widget _buildUserTile(Map<String, dynamic> user, AdminProvider admin) {
    final role = _roleOfUser(user);
    final roleColor = _roleColorOf(role);
    final name = (user['name'] ?? 'مستخدم').toString();
    final balance = (user['balance'] is num)
        ? (user['balance'] as num).toDouble()
        : 0.0;
    final isActive = user['isActive'] != false;

    return Material(
      color: isActive
          ? AppColors.surfaceCard
          : AppColors.rose.withValues(alpha: 0.05),
      child: InkWell(
        onTap: () => _openDetails(user, admin),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color.lerp(roleColor, Colors.white, 0.28)!,
                              roleColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: roleColor.withValues(alpha: 0.26),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          name.isNotEmpty ? name.characters.first : '؟',
                          style: AppTypography.cairo(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTypography.cairo(
                                fontSize: 14,
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
                                _buildRoleBadge(role),
                                _buildStatusPill(isActive),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: AppColors.slate400,
                      ),
                    ],
                  ),
                ),
              ),
              // خط التثقيب الفاصل بين الجسم وكعب الرصيد
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
              // الكعب: عرض ثابت حتى لا يضغط الاسم، والرقم ينكمش بلا طفو
              Container(
                width: _stubWidth,
                color: roleColor.withValues(alpha: 0.06),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '\$${balance.toStringAsFixed(2)}',
                        maxLines: 1,
                        style: AppTypography.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: balance < 0
                              ? AppColors.error
                              : AppColors.tertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الرصيد',
                      maxLines: 1,
                      style: AppTypography.cairo(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withValues(alpha: 0.10),
                    AppColors.primaryBlue.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outline),
              ),
              child: const Icon(
                Icons.group_off_rounded,
                size: 42,
                color: AppColors.slate400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد مستخدمون يطابقون البحث',
              style: AppTypography.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.slate700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'جرّب تعديل كلمة البحث أو الفلتر',
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

// -----------------------------------------------------------------------------
// نافذة تفاصيل المستخدم (عرض كامل + تعديل)
// -----------------------------------------------------------------------------
class _UserDetailsSheet extends StatefulWidget {
  const _UserDetailsSheet({required this.user, required this.admin});

  final Map<String, dynamic> user;
  final AdminProvider admin;

  @override
  State<_UserDetailsSheet> createState() => _UserDetailsSheetState();
}

class _UserDetailsSheetState extends State<_UserDetailsSheet> {
  late Map<String, dynamic> _u;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _u = Map<String, dynamic>.from(widget.user);
    _nameCtrl = TextEditingController(text: (_u['name'] ?? '').toString());
    _emailCtrl = TextEditingController(text: (_u['email'] ?? '').toString());
    _phoneCtrl = TextEditingController(text: (_u['phone'] ?? '').toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _id => (_u['_id'] ?? '').toString();
  String get _role => _roleOfUser(_u);
  String get _name => (_u['name'] ?? 'مستخدم').toString();
  bool get _isActive => _u['isActive'] != false;
  double get _balance =>
      (_u['balance'] is num) ? (_u['balance'] as num).toDouble() : 0.0;

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.tertiary : AppColors.error,
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || email.isEmpty) {
      _snack('الاسم والبريد الإلكتروني مطلوبان', ok: false);
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.admin.updateUserDetails(
      _id,
      name: name,
      email: email,
      phone: phone,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _u['name'] = name;
        _u['email'] = email;
        _u['phone'] = phone;
        _editing = false;
      }
    });
    _snack(
      ok
          ? 'تم تحديث بيانات "$name"'
          : (widget.admin.errorMessage ?? 'تعذر حفظ التعديلات'),
      ok: ok,
    );
  }

  Future<void> _changeRole(String newRole) async {
    final meta = switch (newRole) {
      'agent' => (
        title: 'ترقية إلى وكيل',
        message:
            'سيحصل "$_name" على لوحة الوكيل: إضافة عملاء برقمهم، وإسناد طلبات '
            'يدوية، وتحويل رصيد من محفظته لعملائه.\n'
            'ملاحظة: لن يستطيع التحويل قبل وجود رصيد في حسابه — يمكن شحنه من '
            'نفس هذه النافذة.',
        success: 'تمت ترقية "$_name" إلى وكيل',
        icon: Icons.support_agent_rounded,
        color: _agentColor,
      ),
      'supervisor' => (
        title: 'ترقية إلى مشرف',
        message:
            'سيحصل "$_name" على لوحة المشرف لتنفيذ الخدمات والطلبات المسندة '
            'إليه وإدخال بيانات الشحن للعملاء.',
        success: 'تمت ترقية "$_name" إلى مشرف',
        icon: Icons.upgrade_rounded,
        color: AppColors.primaryBlue,
      ),
      _ => (
        title: _role == 'agent' ? 'إرجاع الوكيل إلى عميل' : 'إرجاع إلى عميل',
        message: _role == 'agent'
            ? 'سيصبح "$_name" عميلاً عادياً وتُغلق لوحة الوكيل لديه.\n'
                  'ملاحظة: إن كان لديه عملاء مرتبطون به ويستخدمون رصيده فسيرفض '
                  'النظام العملية حتى ينقلهم إلى وكيل آخر.'
            : 'سيتم إرجاع "$_name" إلى رتبة عميل وفقدان الوصول إلى لوحة تنفيذ '
                  'الخدمات.\n'
                  'ملاحظة: إن كان ما زال مسؤولاً عن خدمات أو طلبات مسندة إليه '
                  'فسيرفض النظام العملية.',
        success: 'تم إرجاع "$_name" إلى عميل',
        icon: Icons.undo_rounded,
        color: AppColors.slate600,
      ),
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(meta.icon, color: meta.color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                meta.title,
                style: AppTypography.cairo(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          meta.message,
          style: AppTypography.cairo(fontSize: 12.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: meta.color,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await widget.admin.updateUserRole(_id, newRole);
    if (!mounted) return;
    if (ok) setState(() => _u['role'] = newRole);
    _snack(
      ok ? meta.success : (widget.admin.errorMessage ?? 'تعذر تحديث الرتبة'),
      ok: ok,
    );
  }

  // شحن/خصم رصيد العميل من صفحة إدارة المستخدمين
  Future<void> _openCreditSheet() async {
    final double? newBalance = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x660F172A),
      builder: (_) => _BalanceSheet(
        name: _name,
        userId: _id,
        balance: _balance,
        admin: widget.admin,
      ),
    );
    if (!mounted || newBalance == null) return;
    setState(() => _u['balance'] = newBalance);
    _snack('تم تحديث رصيد "$_name" إلى \$${newBalance.toStringAsFixed(2)}');
  }

  Future<void> _toggleActive() async {
    final wasActive = _isActive;
    final ok = await widget.admin.toggleUserActive(_id);
    if (!mounted) return;
    if (ok) setState(() => _u['isActive'] = !wasActive);
    _snack(
      ok
          ? (wasActive ? 'تم إيقاف حساب "$_name"' : 'تم تفعيل حساب "$_name"')
          : (widget.admin.errorMessage ?? 'تعذر تنفيذ العملية'),
      ok: ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColorOf(_role);
    final createdAt = DateTime.tryParse((_u['createdAt'] ?? '').toString());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(roleColor, Colors.white, 0.28)!,
                          roleColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: roleColor.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      _name.isNotEmpty ? _name.characters.first : '؟',
                      style: AppTypography.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: AppTypography.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildRoleBadge(_role),
                            _buildStatusPill(_isActive),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.slate500,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.outline),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_editing)
                      ..._buildEditForm()
                    else
                      ..._buildDetails(createdAt),

                    const SizedBox(height: 18),
                    if (!_editing)
                      _buildOutlineButton(
                        icon: Icons.edit_rounded,
                        label: 'تعديل البيانات',
                        color: AppColors.primaryBlue,
                        onTap: () => setState(() => _editing = true),
                      ),
                    const SizedBox(height: 10),

                    // 1) تعديل الرصيد متاح لكل الرتب: الوكيل يحتاج رصيداً ليبيع،
                    //    والمشرف/العميل قد يحتاج تصحيحاً مالياً
                    _buildGradientButton(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'شحن أو خصم رصيد',
                      colors: const [Color(0xFF059669), Color(0xFF10B981)],
                      onTap: _openCreditSheet,
                    ),
                    const SizedBox(height: 10),

                    // 2) الرتب: العميل يترقى إلى وكيل أو مشرف، والأدمن حساب إداري ثابت
                    if (_role == 'user')
                      Row(
                        children: [
                          Expanded(
                            child: _buildGradientButton(
                              icon: Icons.support_agent_rounded,
                              label: 'ترقية إلى وكيل',
                              colors: const [
                                Color(0xFF7C3AED),
                                Color(0xFF8B5CF6),
                              ],
                              onTap: () => _changeRole('agent'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildGradientButton(
                              icon: Icons.upgrade_rounded,
                              label: 'ترقية إلى مشرف',
                              colors: const [
                                Color(0xFF0284C7),
                                Color(0xFF38BDF8),
                              ],
                              onTap: () => _changeRole('supervisor'),
                            ),
                          ),
                        ],
                      )
                    else if (_role == 'supervisor' || _role == 'agent')
                      _buildOutlineButton(
                        icon: Icons.undo_rounded,
                        label: 'إرجاع إلى عميل',
                        color: AppColors.slate500,
                        onTap: () => _changeRole('user'),
                      )
                    else
                      _buildAccountTag(_role),

                    // توضيح اللوحة التي يملكها الوكيل/المشرف تحت زر الإرجاع
                    if (_role == 'supervisor' || _role == 'agent') ...[
                      const SizedBox(height: 10),
                      _buildAccountTag(_role),
                    ],

                    if (_role != 'admin') ...[
                      const SizedBox(height: 10),
                      _buildOutlineButton(
                        icon: _isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_outline_rounded,
                        label: _isActive ? 'إيقاف الحساب' : 'تفعيل الحساب',
                        color: _isActive ? AppColors.rose : AppColors.tertiary,
                        onTap: _toggleActive,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDetails(DateTime? createdAt) {
    return [
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          children: [
            _detailRow(
              Icons.badge_outlined,
              'رقم المستخدم',
              (_u['userId'] ?? '—').toString(),
            ),
            const Divider(height: 1, color: AppColors.outline),
            _detailRowBlock(
              Icons.alternate_email_rounded,
              'البريد الإلكتروني',
              (_u['email'] ?? '').toString().isEmpty
                  ? '—'
                  : _u['email'].toString(),
            ),
            const Divider(height: 1, color: AppColors.outline),
            _detailRow(
              Icons.phone_outlined,
              'رقم الهاتف',
              (_u['phone'] ?? '').toString().isEmpty
                  ? '—'
                  : _u['phone'].toString(),
            ),
            const Divider(height: 1, color: AppColors.outline),
            _detailRow(
              Icons.account_balance_wallet_outlined,
              'الرصيد',
              '\$${_balance.toStringAsFixed(2)}',
              valueColor: AppColors.tertiary,
            ),
            const Divider(height: 1, color: AppColors.outline),
            _detailRow(
              Icons.event_outlined,
              'تاريخ الانضمام',
              createdAt != null
                  ? DateFormat('yyyy/MM/dd').format(createdAt)
                  : '—',
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildEditForm() {
    return [
      _buildField(_nameCtrl, 'الاسم', Icons.person_outline_rounded),
      const SizedBox(height: 12),
      _buildField(
        _emailCtrl,
        'البريد الإلكتروني',
        Icons.alternate_email_rounded,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 12),
      _buildField(
        _phoneCtrl,
        'رقم الهاتف',
        Icons.phone_outlined,
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: _buildOutlineButton(
              icon: Icons.close_rounded,
              label: 'إلغاء',
              color: AppColors.slate500,
              onTap: _saving
                  ? null
                  : () {
                      _nameCtrl.text = (_u['name'] ?? '').toString();
                      _emailCtrl.text = (_u['email'] ?? '').toString();
                      _phoneCtrl.text = (_u['phone'] ?? '').toString();
                      setState(() => _editing = false);
                    },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _saving
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  )
                : _buildGradientButton(
                    icon: Icons.save_rounded,
                    label: 'حفظ التعديلات',
                    colors: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                    onTap: _save,
                  ),
          ),
        ],
      ),
    ];
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.slate400),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTypography.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: AppTypography.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.slate900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // صف تفاصيل بعرض كامل مع التفاف النص (مثل البريد الإلكتروني)
  Widget _detailRowBlock(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.slate400),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTypography.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 26),
            child: SelectableText(
              value,
              style: AppTypography.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.slate900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      enabled: !_saving,
      style: AppTypography.cairo(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: AppColors.slate900,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.cairo(
          fontSize: 12.5,
          color: AppColors.slate500,
        ),
        prefixIcon: Icon(icon, size: 18, color: AppColors.slate400),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// نافذة شحن/خصم رصيد عميل من لوحة الأدمن (تُسجَّل في سجل الشحن)
// -----------------------------------------------------------------------------
class _BalanceSheet extends StatefulWidget {
  const _BalanceSheet({
    required this.name,
    required this.userId,
    required this.balance,
    required this.admin,
  });

  final String name;
  final String userId;
  final double balance;
  final AdminProvider admin;

  @override
  State<_BalanceSheet> createState() => _BalanceSheetState();
}

class _BalanceSheetState extends State<_BalanceSheet> {
  static const List<double> _quickAmounts = [1, 5, 10, 25, 50, 100];

  final TextEditingController _amountCtrl = TextEditingController();
  late final TextEditingController _noteCtrl;

  bool _debit = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: _defaultNote);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _defaultNote =>
      _debit ? 'خصم رصيد من لوحة الأدمن' : 'شحن رصيد من لوحة الأدمن';

  double get _amount => double.tryParse(_amountCtrl.text.trim()) ?? 0.0;

  /// الرصيد المتوقع بعد العملية (الخادم هو المرجع عند إعادة تحميل القائمة)
  double get _resulting => double.parse(
    (_debit ? widget.balance - _amount : widget.balance + _amount)
        .toStringAsFixed(2),
  );

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.tertiary : AppColors.error,
      ),
    );
  }

  void _setMode(bool debit) {
    final oldNote = _noteCtrl.text.trim();
    if (oldNote.isEmpty || oldNote == _defaultNote) {
      _noteCtrl.text = debit
          ? 'خصم رصيد من لوحة الأدمن'
          : 'شحن رصيد من لوحة الأدمن';
    }
    setState(() => _debit = debit);
  }

  Future<void> _submit() async {
    final amount = _amount;
    if (_busy) return;
    if (amount <= 0) {
      _snack('أدخل مبلغاً أكبر من صفر', ok: false);
      return;
    }
    if (_debit && amount > widget.balance) {
      _snack(
        'المبلغ أكبر من الرصيد الحالي (\$${widget.balance.toStringAsFixed(2)})',
        ok: false,
      );
      return;
    }

    final note = _noteCtrl.text.trim().isEmpty
        ? _defaultNote
        : _noteCtrl.text.trim();

    // الخصم عملية مالية حساسة: تتطلب تأكيداً ثانياً بالمبلغ والرصيد الناتج
    if (_debit) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.remove_circle_outline_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('تأكيد خصم الرصيد', style: TextStyle(fontSize: 15.5)),
            ],
          ),
          content: Text(
            'سيُخصم \$${amount.toStringAsFixed(2)} من رصيد "${widget.name}" '
            'ليصبح \$${_resulting.toStringAsFixed(2)}.\nلا يمكن التراجع عن '
            'العملية من هنا.',
            style: AppTypography.cairo(fontSize: 12.5, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الخصم'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busy = true);
    final ok = await widget.admin.adjustUserBalance(
      widget.userId,
      _debit ? -amount : amount,
      note,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      Navigator.pop(context, _resulting);
    } else {
      _snack(widget.admin.errorMessage ?? 'تعذر تعديل الرصيد', ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _debit ? AppColors.error : AppColors.tertiary;
    final invalidResult = _resulting < 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color.lerp(color, Colors.white, 0.28)!, color],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _debit ? 'خصم رصيد' : 'شحن رصيد',
                          style: AppTypography.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.name,
                          style: AppTypography.cairo(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.slate500,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.outline),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // الرصيد الحالي -> الرصيد المتوقع
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _balanceColumn(
                              'الرصيد الحالي',
                              widget.balance,
                              AppColors.slate900,
                            ),
                          ),
                          Icon(
                            _debit
                                ? Icons.arrow_back_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                            color: AppColors.slate400,
                          ),
                          Expanded(
                            child: _balanceColumn(
                              'الرصيد بعد العملية',
                              _resulting,
                              invalidResult ? AppColors.error : color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // شحن / خصم
                    Row(
                      children: [
                        Expanded(
                          child: _modeButton(
                            label: 'شحن (إضافة)',
                            icon: Icons.add_circle_outline_rounded,
                            color: AppColors.tertiary,
                            selected: !_debit,
                            onTap: () => _setMode(false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _modeButton(
                            label: 'خصم',
                            icon: Icons.remove_circle_outline_rounded,
                            color: AppColors.error,
                            selected: _debit,
                            onTap: () => _setMode(true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _sheetField(
                      _amountCtrl,
                      'المبلغ بالدولار',
                      Icons.attach_money_rounded,
                      hint: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickAmounts
                          .map(
                            (v) => InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _busy
                                  ? null
                                  : () {
                                      _amountCtrl.text = v.toStringAsFixed(2);
                                      setState(() {});
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _amount == v ? color : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _amount == v
                                        ? color
                                        : AppColors.outline,
                                  ),
                                ),
                                child: Text(
                                  '\$${v.toStringAsFixed(0)}',
                                  style: AppTypography.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _amount == v
                                        ? Colors.white
                                        : AppColors.slate600,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),

                    _sheetField(
                      _noteCtrl,
                      'البيان (يظهر للعميل في الإشعار)',
                      Icons.notes_rounded,
                      hint: _defaultNote,
                    ),
                    const SizedBox(height: 16),

                    _busy
                        ? const SizedBox(
                            height: 44,
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          )
                        : _buildGradientButton(
                            icon: _debit
                                ? Icons.remove_circle_outline_rounded
                                : Icons.done_rounded,
                            label: _debit
                                ? 'تأكيد خصم \$${_amount.toStringAsFixed(2)}'
                                : 'تأكيد شحن \$${_amount.toStringAsFixed(2)}',
                            colors: _debit
                                ? const [Color(0xFFDC2626), Color(0xFFEF4444)]
                                : const [Color(0xFF059669), Color(0xFF10B981)],
                            onTap: _submit,
                          ),
                    const SizedBox(height: 10),
                    Text(
                      'تُسجَّل العملية في سجل الشحن ويصل العميل إشعار بها فوراً.',
                      textAlign: TextAlign.center,
                      style: AppTypography.cairo(
                        fontSize: 11,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceColumn(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTypography.cairo(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.slate500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: AppTypography.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : AppColors.outline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? color : AppColors.slate400,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.cairo(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? color : AppColors.slate600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      onChanged: onChanged,
      enabled: !_busy,
      style: AppTypography.cairo(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: AppColors.slate900,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.cairo(
          fontSize: 12.5,
          color: AppColors.slate500,
        ),
        hintText: hint,
        hintStyle: AppTypography.cairo(fontSize: 12, color: AppColors.slate400),
        prefixIcon: Icon(icon, size: 18, color: AppColors.slate400),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helpers مشتركة
// -----------------------------------------------------------------------------
String _roleOfUser(Map<String, dynamic> u) =>
    (u['role'] ?? 'user').toString().toLowerCase();

Color _roleColorOf(String role) {
  switch (role) {
    case 'admin':
      return AppColors.ticketAmber;
    case 'supervisor':
      return const Color(0xFF38BDF8);
    case 'agent':
      return _agentColor;
    default:
      return const Color(0xFF6366F1);
  }
}

Widget _buildRoleBadge(String role) {
  final color = _roleColorOf(role);
  final label = switch (role) {
    'admin' => 'أدمن',
    'supervisor' => 'مشرف',
    'agent' => 'وكيل',
    _ => 'عميل',
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: AppTypography.cairo(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );
}

Widget _buildStatusPill(bool isActive) {
  final color = isActive ? AppColors.tertiary : AppColors.rose;
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
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          isActive ? 'نشط' : 'موقوف',
          style: AppTypography.cairo(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Widget _buildAccountTag(String role) {
  final color = _roleColorOf(role);
  final (IconData icon, String label) = switch (role) {
    'admin' => (Icons.admin_panel_settings_rounded, 'حساب إداري'),
    'agent' => (Icons.support_agent_rounded, 'لوحة الوكيل متاحة'),
    'supervisor' => (Icons.verified_user_rounded, 'لوحة المشرف متاحة'),
    _ => (Icons.person_rounded, 'حساب عميل'),
  };
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cairo(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildGradientButton({
  required IconData icon,
  required String label,
  required List<Color> colors,
  required VoidCallback onTap,
}) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(11),
      boxShadow: [
        BoxShadow(
          color: colors.last.withValues(alpha: 0.30),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildOutlineButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback? onTap,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: color.withValues(alpha: 0.40)),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
