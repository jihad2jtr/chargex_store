import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/user/profile_screen.dart';
import '../screens/user/topup_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/supervisor/supervisor_dashboard_screen.dart';
import '../screens/agent/agent_dashboard_screen.dart';
import 'margin_dialog.dart';
import 'update_check_dialog.dart';
import 'user_avatar.dart';

class UnifiedTactileHeader extends StatelessWidget {
  final UserModel? user;
  final bool isDashboard;
  final VoidCallback? onRefresh;

  const UnifiedTactileHeader({
    super.key,
    this.user,
    this.isDashboard = false,
    this.onRefresh,
  });

  void _navigateToRoleDashboard(BuildContext context, UserModel? currentUser) {
    if (currentUser == null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
      return;
    }
    if (currentUser.isAdmin) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
    } else if (currentUser.isSupervisor) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SupervisorDashboardScreen()),
      );
    } else if (currentUser.isAgent) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AgentDashboardScreen()));
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    }
  }

  void _openTopupScreen(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TopupScreen()));
  }

  void _openProfileScreen(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // خلفية داكنة: العنوان أبيض، فكان نصّه غير مقروء على الأبيض سابقاً
        backgroundColor: AppColors.darkNav,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.2,
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFF87171),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'تسجيل الخروج',
              style: AppTypography.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من تطبيق JGO؟',
          style: AppTypography.cairo(
            color: const Color(0xFF94A3B8),
            fontSize: 13.5,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'إلغاء',
                    style: AppTypography.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final auth = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    await auth.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  child: Text(
                    'تسجيل الخروج',
                    style: AppTypography.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQrUidDialog(BuildContext context, UserModel? currentUser) {
    final uid = currentUser?.displayId ?? currentUser?.id ?? '8940-CX';
    final clientName =
        (currentUser?.name != null && currentUser!.name.trim().isNotEmpty)
        ? currentUser.name.trim()
        : 'عميل JGO';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 10, 15, 26),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(18, 16, 12, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF38BDF8),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'باركود الحساب',
                  style: AppTypography.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white60,
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // كرت الباركود الأبيض البسيط والواضح
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: uid,
                      version: QrVersions.auto,
                      size: 140.0,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: uid,
                      width: double.infinity,
                      height: 38,
                      drawText: false,
                      color: const Color(0xFF0F172A),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      uid,
                      style: AppTypography.technicalCode(
                        color: const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // أزرار سريعة: نسخ ومشاركة
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: Text(
                        'نسخ الآيدي',
                        style: AppTypography.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم نسخ آيدي الحساب: $uid بنجاح',
                              style: AppTypography.cairo(),
                            ),
                            backgroundColor: const Color(0xFF059669),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 15),
                      label: Text(
                        'مشاركة',
                        style: AppTypography.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () async {
                        final shareText =
                            '''
بطاقة حساب JGO:
👤 الاسم: $clientName
🆔 آيدي الحساب (UID): $uid
⚡ يمكن استخدام هذا الآيدي للتحويل المالي المباشر أو شحن الرصيد الفوري.
'''
                                .trim();
                        final box = context.findRenderObject() as RenderBox?;
                        final origin = box != null
                            ? box.localToGlobal(Offset.zero) & box.size
                            : null;
                        await SharePlus.instance.share(
                          ShareParams(
                            text: shareText,
                            subject: 'JGO Account ID - $uid',
                            sharePositionOrigin: origin,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String value,
    UserModel? currentUser,
  ) {
    switch (value) {
      case 'dashboard':
        _navigateToRoleDashboard(context, currentUser);
        break;
      case 'account':
        _openProfileScreen(context);
        break;
      case 'topup':
        _openTopupScreen(context);
        break;
      case 'barcode':
        _showQrUidDialog(context, currentUser);
        break;
      case 'margin':
        MarginDialog.show(context);
        break;
      case 'update':
        UpdateCheckDialog.show(context);
        break;
      case 'logout':
        _showLogoutDialog(context);
        break;
    }
  }

  PopupMenuItem<String> _buildPopupItem({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? textColor,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      height: 38,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          // صف الخروج: خانة مُصبغة بلون الخطأ فوق السطح الفاتح
          color: isDestructive
              ? AppColors.rose.withValues(alpha: 0.07)
              : Colors.transparent,
          border: isDestructive
              ? Border.all(color: AppColors.rose.withValues(alpha: 0.22))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.30),
                  width: 0.8,
                ),
              ),
              child: Icon(icon, size: 13.5, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: textColor ?? AppColors.slate900,
                      height: 1.15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 0.5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.technicalCode(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? AppColors.rose.withValues(alpha: 0.80)
                            : AppColors.slate500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              size: 14,
              color: isDestructive
                  ? AppColors.rose.withValues(alpha: 0.60)
                  : AppColors.slate300,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = user ?? auth.currentUser;
    final balanceVal = currentUser?.balance ?? 1248.50;
    final balanceStr = balanceVal.toStringAsFixed(2);

    final String clientName =
        (currentUser?.name != null && currentUser!.name.trim().isNotEmpty)
        ? currentUser.name.trim()
        : 'عميل JGO';
    final String clientId = currentUser?.displayId ?? '8940-CX';

    // Role badge text and tailored luxury color tokens
    // الخلفية داكنة الآن (كلوحة الشريط السفلي)، فيُعرض شارة الدور كلون مُصبّغ
    // فوق الداكن بدل خلفيات فاتحة كانت مصمّمة للشريط الأبيض.
    final String roleBadgeText;
    final Color roleAccent;
    final Color roleBadgeTextCol;

    if (currentUser?.isAdmin == true) {
      roleBadgeText = "ادمن";
      roleAccent = const Color(0xFFA855F7);
      roleBadgeTextCol = const Color(0xFFD8B4FE);
    } else if (currentUser?.isSupervisor == true ||
        currentUser?.role.toLowerCase() == 'provider') {
      roleBadgeText = "مقدم خدمة";
      roleAccent = const Color(0xFF0EA5E9);
      roleBadgeTextCol = const Color(0xFF7DD3FC);
    } else if (currentUser?.isAgent == true) {
      roleBadgeText = "وكيل";
      roleAccent = AppColors.ticketAmber;
      roleBadgeTextCol = const Color(0xFFFCD34D);
    } else {
      roleBadgeText = "عميل";
      roleAccent = AppColors.accentGreen;
      roleBadgeTextCol = const Color(0xFF6EE7B7);
    }

    final Color roleBadgeBg = roleAccent.withValues(alpha: 0.16);
    final Color roleBadgeBorder = roleAccent.withValues(alpha: 0.42);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        // نفس لوحة الشريط السفلي العائم: داكن slate + حدّ أدكن منه
        color: AppColors.darkNav,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate800, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // -------------------------------------------------------------
          // 1. START: Clean Brand Emblem & Customer Identity Station
          // -------------------------------------------------------------
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minimalist Emblem
                InkWell(
                  onTap: isDashboard
                      ? null
                      : () => _navigateToRoleDashboard(context, currentUser),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFF18223,
                          ).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/app_icon.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 7),

                // Customer Name (Top) & Customer ID + Role Badge (Below)
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // اسم العميل
                      Text(
                        clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // ايدي العميل وبجانبه نوع الدور (role)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '#$clientId',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.technicalCode(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate400,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // شارة الدور قابلة للتقلّص: على العروض الضيقة (320dp) تمنع
                          // طفو الصف حين تضيق مساحة الهوية بسبب كتلة الأدوات اليمنى.
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: roleBadgeBg,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: roleBadgeBorder,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                roleBadgeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cairo(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: roleBadgeTextCol,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // -------------------------------------------------------------
          // 2. END: Unified 36px Action Tools Cluster (Identical for Everyone!)
          // -------------------------------------------------------------
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tool A: Balance Pill
              Tooltip(
                message: 'المحفظة وشحن الرصيد',
                child: InkWell(
                  onTap: () => _openTopupScreen(context),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.slate700),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "\$$balanceStr",
                          style: AppTypography.balance(
                            fontSize: 11.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Tool C: QR / Barcode UID Pass Button
              Tooltip(
                message: 'باركود الحساب والمشاركة',
                child: InkWell(
                  onTap: () => _showQrUidDialog(context, currentUser),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.slate700),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 18,
                      color: AppColors.slate300,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Tool D: User Profile Avatar with Fast Menu (القائمة الجانبية)
              PopupMenuButton<String>(
                tooltip: 'القائمة الجانبية',
                offset: const Offset(0, 44),
                // سطح البطاقة الفاتح المعتمد في كل بطاقات التطبيق بدل الأسود
                color: AppColors.surfaceCard,
                surfaceTintColor: Colors.transparent,
                elevation: 6,
                shadowColor: AppColors.slate900.withValues(alpha: 0.30),
                // لمسة التذكرة: فتحتا تثقيب على الطرفين وخط مثقَّب بينهما
                shape: const _TicketMenuShape(),
                clipBehavior: Clip.antiAlias,
                // حشو رأسي متماثل مع صفوف متساوية = التثقيب في المنتصف بالظبط
                menuPadding: const EdgeInsets.symmetric(vertical: 8),
                constraints: const BoxConstraints(minWidth: 210, maxWidth: 234),
                onSelected: (value) =>
                    _handleMenuAction(context, value, currentUser),
                itemBuilder: (context) {
                  return [
                    _buildPopupItem(
                      value: 'account',
                      icon: Icons.person_rounded,
                      iconColor: AppColors.primaryBlue,
                      title: 'الملف الشخصي',
                      subtitle: 'MY PROFILE // INFO',
                    ),
                    _buildPopupItem(
                      value: 'margin',
                      icon: Icons.percent_rounded,
                      iconColor: AppColors.ticketAmber,
                      title: 'تحديد نسبة الربح',
                      subtitle: 'PROFIT MARGIN RATE',
                    ),
                    _buildPopupItem(
                      value: 'update',
                      icon: Icons.system_update_rounded,
                      iconColor: AppColors.accentGreen,
                      title: 'التحقق من التحديثات',
                      subtitle: 'SYSTEM // OTA CHECK',
                    ),
                    _buildPopupItem(
                      value: 'logout',
                      icon: Icons.logout_rounded,
                      iconColor: AppColors.rose,
                      title: 'تسجيل الخروج',
                      subtitle: 'TERMINATE SESSION',
                      textColor: AppColors.errorLight,
                      isDestructive: true,
                    ),
                  ];
                },
                child: Container(
                  width: 38,
                  height: 38,
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.slate700, width: 1.2),
                  ),
                  // الصورة الشخصية المرفوعة، أو أول حرف من الاسم عند غيابها
                  child: UserAvatar(
                    url: currentUser?.avatar,
                    initial: currentUser?.initial ?? 'U',
                    size: 36,
                    circular: false,
                    backgroundColor: AppColors.slate800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// لمسة التذكرة للقائمة السريعة: نفس مسارات TicketPassClipper المستخدمة في
// بطاقات التطبيق (زوايا دائرية + فتحة تثقيب في كل جانب) مع خط مثقَّب يرسم
// نفسه على ارتفاع الفتحات تماماً، فلا يحتاج أي فاصل بين الصفوف.
// التثقيب عند منتصف الارتفاع: القائمة عدد صفوفها زوجي ومتساوية والحشو
// الرأسي متماثل، لذلك منتصف الارتفاع يقع دائماً على الحد بين صفين.
// ---------------------------------------------------------------------------
class _TicketMenuShape extends ShapeBorder {
  const _TicketMenuShape({
    this.cornerRadius = 14,
    this.notchRadius = 6,
    this.borderColor = AppColors.outlineVariant,
    this.tearColor = AppColors.slate300,
  });

  final double cornerRadius;
  final double notchRadius;
  final Color borderColor;
  final Color tearColor;

  Path _ticketPath(Rect rect) {
    final r = cornerRadius;
    final tearY = rect.top + rect.height / 2;
    final nr = notchRadius < rect.height / 2 ? notchRadius : rect.height / 4;

    return Path()
      ..moveTo(rect.left + r, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + r), radius: Radius.circular(r))
      ..lineTo(rect.right, tearY - nr)
      // الفتحة اليمنى تدخل داخل القائمة
      ..arcToPoint(
        Offset(rect.right, tearY + nr),
        radius: Radius.circular(nr),
        clockwise: false,
      )
      ..lineTo(rect.right, rect.bottom - r)
      ..arcToPoint(
        Offset(rect.right - r, rect.bottom),
        radius: Radius.circular(r),
      )
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(
        Offset(rect.left, rect.bottom - r),
        radius: Radius.circular(r),
      )
      ..lineTo(rect.left, tearY + nr)
      // الفتحة اليسرى تدخل داخل القائمة
      ..arcToPoint(
        Offset(rect.left, tearY - nr),
        radius: Radius.circular(nr),
        clockwise: false,
      )
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(Offset(rect.left + r, rect.top), radius: Radius.circular(r))
      ..close();
  }

  @override
  EdgeInsetsGeometry get dimensions =>
      EdgeInsets.symmetric(horizontal: cornerRadius, vertical: cornerRadius);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _ticketPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _ticketPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // حدود التذكرة تتبع القصّة بما فيها الفتحتان
    canvas.drawPath(
      _ticketPath(rect),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // خط التثقيب: نقط بين الفتحتين بعيداً عن حواف القص
    final tearY = rect.top + rect.height / 2;
    final dash = Paint()
      ..color = tearColor
      ..strokeWidth = 1;
    final right = rect.right - notchRadius - 4;
    double x = rect.left + notchRadius + 4;
    while (x < right) {
      final next = x + 4 > right ? right : x + 4;
      canvas.drawLine(Offset(x, tearY), Offset(next, tearY), dash);
      x += 7;
    }
  }

  @override
  ShapeBorder scale(double t) => _TicketMenuShape(
    cornerRadius: cornerRadius * t,
    notchRadius: notchRadius * t,
    borderColor: borderColor,
    tearColor: tearColor,
  );
}
