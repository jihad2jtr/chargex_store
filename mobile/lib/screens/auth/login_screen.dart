import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';
import '../user/user_main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى ملء جميع الحقول', style: AppTypography.cairo(fontSize: 13, color: Colors.white)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(email, password);

    if (!mounted) return;

    if (success) {
      // All roles land on UserMainScreen, top bar button provides entry to each role's dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const UserMainScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'فشل تسجيل الدخول', style: AppTypography.cairo(fontSize: 13, color: Colors.white)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _fillAdminDemo() {
    _emailController.text = 'admin@chargex.com';
    _passwordController.text = 'Admin@123456';
    _submit();
  }

  void _fillSupervisorDemo() {
    _emailController.text = 'supervisor@chargex.com';
    _passwordController.text = 'Supervisor@123456';
    _submit();
  }

  void _fillAgentDemo() {
    _emailController.text = 'agent@chargex.com';
    _passwordController.text = 'Agent@123456';
    _submit();
  }

  void _fillUserDemo() {
    _emailController.text = 'user@chargex.com';
    _passwordController.text = 'User@123456';
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ChargeX Passport Emblem & Status Tag
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF18223).withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/app_icon.png',
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'JGO',
                              style: AppTypography.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.ticketAmberLight.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.ticketAmber.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'EXPRESS GATE',
                                style: AppTypography.technicalCode(
                                  color: AppColors.secondaryBright,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'بوابة الشحن السريع والبطاقات الرقمية الموثقة',
                          style: AppTypography.cairo(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Server Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'SSL 256-BIT',
                                style: AppTypography.technicalCode(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• حالة الخادم: متصل ومؤمن',
                                style: AppTypography.cairo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Neo-Bento Card Container
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.outline),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 3.5,
                              height: 18,
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'تسجيل الدخول إلى المحفظة',
                              style: AppTypography.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Email Field
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: AppTypography.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            labelStyle: AppTypography.cairo(fontSize: 13, color: AppColors.textSecondary),
                            hintText: 'user@chargex.com',
                            hintStyle: AppTypography.plusJakartaSans(fontSize: 13, color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppColors.primaryBlue),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: AppTypography.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            labelStyle: AppTypography.cairo(fontSize: 13, color: AppColors.textSecondary),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.primaryBlue),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Login Action Button (Cyan FinTech gradient)
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryButtonGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: auth.isLoading ? null : _submit,
                              borderRadius: BorderRadius.circular(14),
                              child: Center(
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.login_rounded, color: Colors.white, size: 19),
                                          const SizedBox(width: 8),
                                          Text(
                                            'دخول فوري للمنصة',
                                            style: AppTypography.arabicButton(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Quick Demo Access Header
                        Row(
                          children: [
                            const Expanded(child: Divider(color: AppColors.outline)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'حسابات التجربة السريعة (DEMO ACCESS)',
                                style: AppTypography.technicalCode(
                                  fontSize: 9.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: AppColors.outline)),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Client Demo Bento Pill
                        _buildDemoCard(
                          title: 'دخول سريع كعميل (Client Demo)',
                          code: 'USER PASS • \$1,248.50 USDT',
                          icon: Icons.person_rounded,
                          accentColor: AppColors.ticketAmber,
                          bgColor: const Color(0xFFFEF3C7),
                          onTap: auth.isLoading ? null : _fillUserDemo,
                        ),
                        const SizedBox(height: 8),

                        // Supervisor Demo Bento Pill
                        _buildDemoCard(
                          title: 'مشرف الخدمات اليدوية (Supervisor)',
                          code: 'SUPERVISOR PORTAL • SLA QUEUE',
                          icon: Icons.assignment_ind_rounded,
                          accentColor: AppColors.primaryBlue,
                          bgColor: const Color(0xFFE0F2FE),
                          onTap: auth.isLoading ? null : _fillSupervisorDemo,
                        ),
                        const SizedBox(height: 8),

                        // Agent Demo Bento Pill
                        _buildDemoCard(
                          title: 'الوكيل المعتمد (Authorized Agent)',
                          code: 'AGENT HUB • CLIENTS & TRANSFERS',
                          icon: Icons.storefront_rounded,
                          accentColor: AppColors.accentGreen,
                          bgColor: const Color(0xFFD1FAE5),
                          onTap: auth.isLoading ? null : _fillAgentDemo,
                        ),
                        const SizedBox(height: 8),

                        // Admin Demo Bento Pill
                        _buildDemoCard(
                          title: 'مدير النظام التنفيذي (Admin)',
                          code: 'ROOT ENTERPRISE • FULL CONTROL',
                          icon: Icons.shield_rounded,
                          accentColor: AppColors.darkNav,
                          bgColor: const Color(0xFFF1F5F9),
                          onTap: auth.isLoading ? null : _fillAdminDemo,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ليس لديك حساب بعد؟ ',
                        style: AppTypography.cairo(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: Text(
                          'إنشاء حساب جديد',
                          style: AppTypography.cairo(
                            color: AppColors.secondaryBright,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoCard({
    required String title,
    required String code,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    code,
                    style: AppTypography.technicalCode(
                      fontSize: 8.5,
                      color: accentColor == AppColors.darkNav ? AppColors.textSecondary : accentColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

