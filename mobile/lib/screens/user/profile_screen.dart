import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/margin_provider.dart';
import '../../widgets/balance_badge.dart';
import '../../widgets/margin_dialog.dart';
import '../../widgets/update_check_dialog.dart';
import '../auth/login_screen.dart';
import 'topup_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, color: AppColors.rose, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'تسجيل الخروج',
              style: AppTypography.cairo(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من هذا الحساب؟',
          style: AppTypography.cairo(color: AppColors.slate600, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('إلغاء', style: AppTypography.cairo(color: AppColors.slate600, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            child: Text('تسجيل الخروج', style: AppTypography.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final marginProvider = Provider.of<MarginProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'الملف الشخصي',
          style: AppTypography.cairo(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BalanceBadge(
              balance: user?.balance ?? 0.0,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TopupScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await auth.refreshProfile();
        },
        color: AppColors.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Swiss Neo-Bento Executive Passport Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.slate900.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Passport Pass Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, size: 12, color: AppColors.primaryBlue),
                              const SizedBox(width: 5),
                              Text(
                                'JGO USER PASS',
                                style: AppTypography.technicalCode(fontSize: 9, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        // VIP status pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.ticketAmber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.ticketAmber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.ticketAmber, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(
                                'عضو موثق VIP',
                                style: AppTypography.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.ticketAmber),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Avatar with glowing ring
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryBlue, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.slate800,
                        child: Text(
                          user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                          style: AppTypography.plusJakartaSans(fontSize: 30, color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      user?.name ?? 'المستخدم',
                      style: AppTypography.cairo(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? '',
                      style: AppTypography.plusJakartaSans(fontSize: 12, color: Colors.white70),
                    ),
                    if (user?.phone != null && user!.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.phone!,
                        style: AppTypography.plusJakartaSans(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // User ID copy capsule
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.badge_outlined, size: 14, color: Colors.white60),
                          const SizedBox(width: 6),
                          Text('معرف الحساب: ', style: AppTypography.cairo(fontSize: 11, color: Colors.white70)),
                          Text(
                            user?.displayId ?? user?.id ?? '',
                            style: AppTypography.spaceMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ticketAmber),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: user?.displayId ?? user?.id ?? ''));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم نسخ معرف الحساب بنجاح ✅', style: AppTypography.cairo()),
                                  backgroundColor: AppColors.emerald,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Icons.copy, size: 14, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Wallet Balance Neo-Bento Card
              Container(
                padding: const EdgeInsets.all(18),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.emerald, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('رصيد المحفظة المتاح', style: AppTypography.cairo(fontSize: 11, color: AppColors.slate600)),
                          const SizedBox(height: 2),
                          Text(
                            '\$${(user?.balance ?? 0.0).toStringAsFixed(2)}',
                            style: AppTypography.price(fontSize: 22, color: AppColors.emerald),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TopupScreen()),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('شحن رصيد', style: AppTypography.cairo(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Settings & Quick Menu Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'الإعدادات والخدمات',
                  style: AppTypography.cairo(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.slate900),
                ),
              ),
              const SizedBox(height: 6),

              // Option: تحديد نسبة
              _buildActionTile(
                icon: Icons.percent_rounded,
                iconColor: AppColors.ticketAmber,
                title: 'تحديد نسبة الربح للموزعين',
                subtitle: marginProvider.isEnabled
                    ? 'مفعلة (${marginProvider.marginPercent.toStringAsFixed(1)}%)'
                    : 'غير مفعلة (اضغط للتحديد والتفعيل)',
                badge: marginProvider.isEnabled ? '${marginProvider.marginPercent.toStringAsFixed(0)}%' : null,
                onTap: () => MarginDialog.show(context),
              ),
              const SizedBox(height: 10),

              // Option: شحن رصيد
              _buildActionTile(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: AppColors.emerald,
                title: 'شحن رصيد المحفظة',
                subtitle: 'شام كاش، بينانس USDT، أو قسائم التعبئة',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TopupScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Option: التحقق من التحديثات
              _buildActionTile(
                icon: Icons.system_update_outlined,
                iconColor: AppColors.primaryBlue,
                title: 'التحقق من التحديثات',
                subtitle: 'الإصدار الحالي: v1.0.0 (JGO Final)',
                badge: 'أحدث إصدار',
                onTap: () => UpdateCheckDialog.show(context),
              ),
              const SizedBox(height: 20),

              // Logout Tile
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.logout_rounded, color: AppColors.rose, size: 20),
                  ),
                  title: Text(
                    'تسجيل الخروج',
                    style: AppTypography.cairo(color: AppColors.rose, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'الخروج من الحساب الحالي على هذا الجهاز',
                    style: AppTypography.cairo(color: AppColors.slate600, fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.rose),
                  onTap: () => _showLogoutDialog(context),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: AppTypography.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900)),
        subtitle: Text(subtitle, style: AppTypography.cairo(color: AppColors.slate600, fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badge,
                  style: AppTypography.plusJakartaSans(color: iconColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.slate600),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
