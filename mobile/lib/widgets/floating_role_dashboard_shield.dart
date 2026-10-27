import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_typography.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import '../providers/manual_services_provider.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/supervisor/supervisor_dashboard_screen.dart';
import '../screens/agent/agent_dashboard_screen.dart';

/// زر عائم فاخر ومصغر بشكل درع تكتيكي للانتقال السريع إلى لوحة التحكم
/// - حجم مدمج وصغير (Compact) بدون نصوص داخلية
/// - يظهر حصرياً للأدوار الإدارية (الآدمن، المشرف، الوكيل)
/// - مخفي تماماً 100% عن العميل العادي
/// - يدعم السحب والتحريك الحر باللمس مع الالتصاق الذكي بأطراف الشاشة (Edge Snapping)
/// - مزود بنبض بصري تكتيكي وشارات للطلبات المعلقة
class FloatingRoleDashboardShield extends StatefulWidget {
  final VoidCallback? onCustomTap;

  const FloatingRoleDashboardShield({super.key, this.onCustomTap});

  @override
  State<FloatingRoleDashboardShield> createState() =>
      _FloatingRoleDashboardShieldState();
}

class _FloatingRoleDashboardShieldState
    extends State<FloatingRoleDashboardShield>
    with TickerProviderStateMixin {
  // أبعاد الدرع المدمجة (Compact & Sleek)
  static const double _shieldWidth = 44.0;
  static const double _shieldHeight = 50.0;

  // موقع الدرع على الشاشة
  Offset? _position;
  bool _isDragging = false;

  // متحكمات الحركة (نبض الحدود + الالتصاق التلقائي)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  @override
  void initState() {
    super.initState();

    // أنيميشن النبض الحيوي للدرع
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // أنيميشن الالتصاق عند ترك اللمس
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ضبط الموقع المبدئي: أسفل يمين الشاشة فوق شريط التنقل السفلي
    if (_position == null) {
      final size = MediaQuery.of(context).size;
      final padding = MediaQuery.of(context).padding;
      _position = Offset(
        size.width - _shieldWidth - 12.0,
        size.height - _shieldHeight - padding.bottom - 95.0,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _snapController.dispose();
    super.dispose();
  }

  void _snapToNearestEdge(Size screenSize, EdgeInsets padding) {
    if (_position == null) return;

    final double minX = 8.0;
    final double maxX = screenSize.width - _shieldWidth - 8.0;
    final double minY = padding.top + 8.0;
    final double maxY =
        screenSize.height - _shieldHeight - padding.bottom - 88.0;

    final double targetX =
        (_position!.dx + _shieldWidth / 2) < (screenSize.width / 2)
        ? minX
        : maxX;
    final double targetY = _position!.dy.clamp(minY, maxY);

    final startOffset = _position!;
    final endOffset = Offset(targetX, targetY);

    _snapAnimation =
        Tween<Offset>(begin: startOffset, end: endOffset).animate(
          CurvedAnimation(parent: _snapController, curve: Curves.easeOutBack),
        )..addListener(() {
          if (mounted) {
            setState(() {
              _position = _snapAnimation!.value;
            });
          }
        });

    _snapController.forward(from: 0.0);
  }

  void _navigateToRoleDashboard(BuildContext context, UserModel currentUser) {
    HapticFeedback.heavyImpact();

    if (widget.onCustomTap != null) {
      widget.onCustomTap!();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.currentUser;

    // شرط الحماية الأساسي: لا يظهر إطلاقاً للعميل العادي أو عند عدم تسجيل الدخول
    if (currentUser == null) return const SizedBox.shrink();

    final bool isPrivileged =
        currentUser.isAdmin || currentUser.isSupervisor || currentUser.isAgent;

    if (!isPrivileged) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // حساب عدد المهام المعلقة للدرع
    int pendingCount = 0;
    if (currentUser.isAdmin) {
      final admin = Provider.of<AdminProvider>(context);
      pendingCount =
          admin.adminOrders.where((o) => o.status == 'pending').length +
          admin.manualTopupRequests.where((r) => r.status == 'pending').length;
    } else if (currentUser.isSupervisor) {
      final supervisor = Provider.of<ManualServicesProvider>(context);
      pendingCount = supervisor.supervisorOrders
          .where((o) => o.status == 'assigned' || o.status == 'pending')
          .length;
    }

    // تحديد ألوان وأيقونة الدور
    final _RoleTheme roleTheme = _getRoleTheme(currentUser);

    // ضمان بقاء الموقع داخل حدود الشاشة
    final double safeX =
        (_position?.dx ?? (screenSize.width - _shieldWidth - 12.0)).clamp(
          6.0,
          screenSize.width - _shieldWidth - 6.0,
        );
    final double safeY =
        (_position?.dy ?? (screenSize.height - _shieldHeight - 110.0)).clamp(
          padding.top + 6.0,
          screenSize.height - _shieldHeight - padding.bottom - 85.0,
        );

    return Positioned(
      left: safeX,
      top: safeY,
      child: Tooltip(
        message: '${roleTheme.label} - لوحة التحكم',
        child: GestureDetector(
          onPanStart: (_) {
            _snapController.stop();
            setState(() {
              _isDragging = true;
            });
            HapticFeedback.selectionClick();
          },
          onPanUpdate: (details) {
            final double newX = (_position!.dx + details.delta.dx).clamp(
              6.0,
              screenSize.width - _shieldWidth - 6.0,
            );
            final double newY = (_position!.dy + details.delta.dy).clamp(
              padding.top + 6.0,
              screenSize.height - _shieldHeight - padding.bottom - 85.0,
            );
            setState(() {
              _position = Offset(newX, newY);
            });
          },
          onPanEnd: (_) {
            setState(() {
              _isDragging = false;
            });
            _snapToNearestEdge(screenSize, padding);
          },
          onTap: () => _navigateToRoleDashboard(context, currentUser),
          child: AnimatedScale(
            scale: _isDragging ? 1.10 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // جسم الدرع الخارجي مع التوهج والحدود
                    CustomPaint(
                      size: const Size(_shieldWidth, _shieldHeight),
                      painter: _ShieldBorderPainter(
                        glowColor: roleTheme.primaryColor.withValues(
                          alpha: _pulseAnimation.value * 0.40,
                        ),
                        gradientColors: roleTheme.borderGradient,
                        pulseAlpha: _pulseAnimation.value,
                      ),
                      child: ClipPath(
                        clipper: _ShieldClipper(),
                        child: Container(
                          width: _shieldWidth,
                          height: _shieldHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF0F172A),
                                const Color(0xFF090D16),
                                roleTheme.primaryColor.withValues(alpha: 0.16),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              roleTheme.icon,
                              size: 22,
                              color: roleTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // شارة الإشعارات / الطلبات المعلقة المصغرة
                    if (pendingCount > 0)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.6),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            pendingCount > 99 ? '99+' : '$pendingCount',
                            style: AppTypography.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  _RoleTheme _getRoleTheme(UserModel user) {
    if (user.isAdmin) {
      return _RoleTheme(
        label: 'الإدارة',
        icon: Icons.admin_panel_settings_rounded,
        primaryColor: const Color(0xFFF59E0B),
        borderGradient: [
          const Color(0xFFFDE68A),
          const Color(0xFFF59E0B),
          const Color(0xFFD97706),
        ],
      );
    } else if (user.isSupervisor) {
      return _RoleTheme(
        label: 'مشرف',
        icon: Icons.verified_user_rounded,
        primaryColor: const Color(0xFF38BDF8),
        borderGradient: [
          const Color(0xFFBAE6FD),
          const Color(0xFF38BDF8),
          const Color(0xFF0284C7),
        ],
      );
    } else {
      // Agent
      return _RoleTheme(
        label: 'الوكيل',
        icon: Icons.shield_rounded,
        primaryColor: const Color(0xFF10B981),
        borderGradient: [
          const Color(0xFFA7F3D0),
          const Color(0xFF10B981),
          const Color(0xFF047857),
        ],
      );
    }
  }
}

class _RoleTheme {
  final String label;
  final IconData icon;
  final Color primaryColor;
  final List<Color> borderGradient;

  _RoleTheme({
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.borderGradient,
  });
}

/// قص شكل الدرع الكلاسيكي المتناسق (Shield Clipper)
class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return _buildShieldPath(size);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// مسار الدرع الهندسي الموحد
Path _buildShieldPath(Size size) {
  final double w = size.width;
  final double h = size.height;
  final Path path = Path();

  final double cornerRadius = w * 0.18;

  // البداية من الزاوية العلوية اليسرى بعد الانحناء
  path.moveTo(cornerRadius, 0);

  // الخط العلوي المستقيم
  path.lineTo(w - cornerRadius, 0);

  // الزاوية العلوية اليمنى المنحنية
  path.quadraticBezierTo(w, 0, w, cornerRadius);

  // الخط الجانبي الأيمن المستقيم حتى منتصف الدرع
  path.lineTo(w, h * 0.54);

  // المنحنى السفلي الأيمن المتجه نحو قمة الدرع بالأسفل
  path.quadraticBezierTo(w * 0.94, h * 0.82, w * 0.5, h);

  // المنحنى السفلي الأيسر الصاعد من قمة الدرع
  path.quadraticBezierTo(w * 0.06, h * 0.82, 0, h * 0.54);

  // الخط الجانبي الأيسر المستقيم الصاعد
  path.lineTo(0, cornerRadius);

  // الزاوية العلوية اليسرى المنحنية
  path.quadraticBezierTo(0, 0, cornerRadius, 0);

  path.close();
  return path;
}

/// رسم إطار الدرع والتوهج المحيط بدقة عالية
class _ShieldBorderPainter extends CustomPainter {
  final Color glowColor;
  final List<Color> gradientColors;
  final double pulseAlpha;

  _ShieldBorderPainter({
    required this.glowColor,
    required this.gradientColors,
    required this.pulseAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _buildShieldPath(size);

    // 1. التوهج الخارجي الساقط (Outer Glow Shadow)
    final Paint glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, glowPaint);

    // 2. إطار الدرع المتدرج (Metallic Border Gradient)
    final Rect rect = Offset.zero & size;
    final Paint borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldBorderPainter oldDelegate) {
    return oldDelegate.pulseAlpha != pulseAlpha ||
        oldDelegate.glowColor != glowColor;
  }
}
