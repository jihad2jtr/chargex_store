import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_typography.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/user/profile_screen.dart';
import '../screens/user/topup_screen.dart';
import '../screens/user/user_main_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/supervisor/supervisor_dashboard_screen.dart';
import '../screens/agent/agent_dashboard_screen.dart';
import 'margin_dialog.dart';
import 'update_check_dialog.dart';

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
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      return;
    }
    if (currentUser.isAdmin) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } else if (currentUser.isSupervisor) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SupervisorDashboardScreen()),
      );
    } else if (currentUser.isAgent) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AgentDashboardScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  void _navigateToClientView(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const UserMainScreen()),
      );
    }
  }

  void _openTopupScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TopupScreen()),
    );
  }

  void _openProfileScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 10),
            Text(
              'تسجيل الخروج',
              style: AppTypography.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من تطبيق JGO؟',
          style: AppTypography.cairo(
            color: const Color(0xFF64748B),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'إلغاء',
              style: AppTypography.cairo(color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final auth = Provider.of<AuthProvider>(context, listen: false);
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
              style: AppTypography.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showQrUidDialog(BuildContext context, UserModel? currentUser) {
    final uid = currentUser?.displayId ?? currentUser?.id ?? '8940-CX';
    final clientName = (currentUser?.name != null && currentUser!.name.trim().isNotEmpty)
        ? currentUser.name.trim()
        : 'عميل JGO';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF38BDF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بطاقة العميل // DIGITAL PASS',
                      style: AppTypography.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'باركود الهوية الفورية والمشاركة',
                      style: AppTypography.cairo(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Client Identity Bento Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            clientName.isNotEmpty
                                ? clientName[0].toUpperCase()
                                : 'C',
                            style: AppTypography.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clientName,
                              style: AppTypography.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 11,
                                        color: Color(0xFF34D399),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        currentUser?.isAgent == true
                                            ? 'وكيل معتمد'
                                            : currentUser?.isAdmin == true
                                                ? 'مدير النظام'
                                                : currentUser?.isSupervisor == true
                                                    ? 'مشرف مسؤول'
                                                    : 'عميل موثق',
                                        style: AppTypography.cairo(
                                          color: const Color(0xFF34D399),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
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
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. High-Contrast Barcode & QR Code Digital Canvas
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 1D Linear Barcode (Code 128)
                      BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: uid,
                        width: double.infinity,
                        height: 52,
                        drawText: false,
                        color: const Color(0xFF0F172A),
                      ),
                      const SizedBox(height: 6),
                      // UID Digits Below Barcode
                      Text(
                        uid,
                        style: AppTypography.technicalCode(
                          color: const Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Perforated Dashed Divider
                      Row(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Flex(
                                  direction: Axis.horizontal,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    (constraints.constrainWidth() / 8).floor(),
                                    (_) => const SizedBox(
                                      width: 4,
                                      height: 1.2,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Color(0xFFCBD5E1),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 2D QR Code for Fast Scanning
                      QrImageView(
                        data: uid,
                        version: QrVersions.auto,
                        size: 140.0,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'امسح الباركود للشحن أو التحويل الفوري',
                        style: AppTypography.cairo(
                          color: const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Fast Copy Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.fingerprint_rounded,
                            size: 16,
                            color: Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'آيدي الحساب:',
                            style: AppTypography.cairo(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            uid,
                            style: AppTypography.technicalCode(
                              color: const Color(0xFFFDE68A),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
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
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.copy_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'نسخ',
                                style: AppTypography.cairo(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
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
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          Row(
            children: [
              // Share Button (مشاركة)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(
                    'مشاركة الآيدي',
                    style: AppTypography.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () async {
                    final shareText = '''
بطاقة حساب JGO:
👤 الاسم: $clientName
🆔 آيدي الحساب (UID): $uid
⚡ يمكن استخدام هذا الآيدي للتحويل المالي المباشر أو شحن الرصيد الفوري عبر التطبيق.
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
              const SizedBox(width: 8),

              // Close Button (إغلاق)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'إغلاق',
                  style: AppTypography.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
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
        if (isDashboard) {
          _navigateToClientView(context);
        } else {
          _navigateToRoleDashboard(context, currentUser);
        }
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
    Color? textColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Text(
            title,
            style: AppTypography.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = user ?? auth.currentUser;
    final balanceVal = currentUser?.balance ?? 1248.50;
    final balanceStr = balanceVal.toStringAsFixed(2);

    // Unified role badge text
    final String roleBadgeText = currentUser?.isAdmin == true
        ? "مدير"
        : currentUser?.isSupervisor == true
            ? "مشرف"
            : currentUser?.isAgent == true
                ? "وكيل"
                : "عميل";

    // Unified subtitle for all roles
    const String subtitle = "بوابة الصرف والخدمات الرقمية";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // -------------------------------------------------------------
          // 1. START: Clean Brand Emblem & Title Station
          // -------------------------------------------------------------
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minimalist Emblem
                InkWell(
                  onTap: () {
                    if (isDashboard) {
                      _navigateToClientView(context);
                    } else {
                      _navigateToRoleDashboard(context, currentUser);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF18223).withValues(alpha: 0.25),
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

                // Title & Unified Role Badge
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "JGO",
                            style: AppTypography.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF020617),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Unified Role Badge for Everyone
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              roleBadgeText,
                              style: AppTypography.cairo(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
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
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Tool B: The Unified Control / Client Switch Button (يظهر في لوحة التحكم فقط للعودة لواجهة العميل)
              if (isDashboard) ...[
                Tooltip(
                  message: 'واجهة العميل // CLIENT VIEW',
                  child: InkWell(
                    onTap: () => _navigateToClientView(context),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: const Color(0xFFF59E0B),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            size: 15,
                            color: Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'واجهة العميل',
                            style: AppTypography.cairo(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
              ],

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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 18,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Tool D: User Profile Avatar with Fast Menu
              PopupMenuButton<String>(
                tooltip: 'قائمة الحساب',
                offset: const Offset(0, 46),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                onSelected: (value) => _handleMenuAction(context, value, currentUser),
                itemBuilder: (context) {
                  final bool isPrivileged = currentUser != null &&
                      (currentUser.isAdmin ||
                          currentUser.isSupervisor ||
                          currentUser.isAgent);
                  return [
                    if (isDashboard || isPrivileged) ...[
                      _buildPopupItem(
                        value: 'dashboard',
                        icon: isDashboard
                            ? Icons.storefront_rounded
                            : Icons.dashboard_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: isDashboard
                            ? 'واجهة العميل // CLIENT VIEW'
                            : 'لوحة التحكم // DASHBOARD',
                        textColor: const Color(0xFF0F172A),
                      ),
                      const PopupMenuDivider(),
                    ],
                    _buildPopupItem(
                      value: 'account',
                      icon: Icons.person_outline,
                      iconColor: const Color(0xFF0F172A),
                      title: 'حسابي',
                    ),
                  _buildPopupItem(
                    value: 'topup',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF10B981),
                    title: 'شحن رصيد',
                  ),
                  _buildPopupItem(
                    value: 'margin',
                    icon: Icons.percent_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'تحديد نسبة الربح',
                  ),
                  _buildPopupItem(
                    value: 'update',
                    icon: Icons.system_update_outlined,
                    iconColor: const Color(0xFF0284C7),
                    title: 'التحقق من التحديثات',
                  ),
                  const PopupMenuDivider(),
                  _buildPopupItem(
                    value: 'logout',
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: 'تسجيل خروج',
                    textColor: const Color(0xFFEF4444),
                  ),
                ];
              },
              child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    image: const DecorationImage(
                      image: NetworkImage(
                        "https://lh3.googleusercontent.com/aida-public/AB6AXuB-54C4RiT1G-MnnGHXxePYK4XTwWpp8cZLZq5d9iSS83qt9uQx8-QJaSs6GhCzqqu-Ypi18_ngAvYc8V9bQbgNQCJcMChBuP7S5_tCCf9_0wKIcrA9kXtl8nfSQ-MGPtfNQmaB_3smXptXlY9DRqB3WbIJp7R6RCHNqjn4gkkTOVW5qyP-a2spBPMfjUARwjI6ajSg5K2Cd3YjQU6jg0k1ReaP--SrxuCLe92zWyZHOs6jeJNkvUzL",
                      ),
                      fit: BoxFit.cover,
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
}
