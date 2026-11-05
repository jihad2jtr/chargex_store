import 'package:flutter/material.dart';

/// ChargeX Design System: Swiss Neo-Bento & Digital Ticket Passes
/// Swiss Neo-FinTech aesthetic with Electric Cyan, Ticket Gold/Amber, Deep Slate, and Emerald
class AppColors {
  AppColors._();

  // Brand & Accent Colors
  static const Color primaryBlue = Color(0xFF0284C7); // Electric Cyan / Blue
  static const Color primary = primaryBlue;
  static const Color primaryContainer = Color(0xFF0284C7);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);
  static const Color primaryFixed = Color(0xFFBAE6FD);

  // Ticket Gold & Amber
  static const Color ticketAmber = Color(
    0xFFF59E0B,
  ); // Classic Ticket Gold / Amber
  static const Color ticketAmberLight = Color(0xFFFDE68A); // Amber soft
  static const Color secondary = ticketAmber;
  static const Color secondaryBright = Color(0xFFD97706);
  static const Color secondaryContainer = Color(0xFFFEF3C7);
  static const Color onSecondary = Color(0xFF000000);
  static const Color onSecondaryContainer = Color(0xFF78350F);

  // Active / Settlement Emerald Green
  static const Color accentGreen = Color(
    0xFF10B981,
  ); // Online / Active Node Green
  static const Color tertiary = accentGreen;
  static const Color tertiaryLight = Color(0xFF059669);
  static const Color tertiaryContainer = Color(0xFFD1FAE5);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF065F46);
  static const Color success = accentGreen;

  // Deep Slate for Floating Dock & Bento Vault Cards
  static const Color darkNav = Color(0xFF0F172A); // Deep Slate
  static const Color inverseSurface = darkNav;
  static const Color inverseOnSurface = Color(0xFFF8FAFC);

  // Surface & Neutral Colors (Swiss Neo-Bento Palette from HTML)
  static const Color background = Color(0xFFF4F6F9); // Exact #F4F6F9 bg-paper
  static const Color surface = background;
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF8FAFC);
  static const Color surfaceCard = Color(0xFFFFFFFF); // Pure Card Surface
  static const Color surfaceContainer = surfaceCard;
  static const Color surfaceSecondary = Color(
    0xFFF1F5F9,
  ); // Bento Slot Background
  static const Color surfaceContainerHigh = surfaceSecondary;
  static const Color surfaceContainerHighest = Color(0xFFE2E8F0);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // Swiss Paper Background
  static const Color paper = Color(0xFFF4F6F9);

  // Swiss Slate Palette
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  // Typography & On-Surface
  static const Color textPrimary = slate900;
  static const Color onSurface = textPrimary;
  static const Color textSecondary = slate500;
  static const Color onSurfaceVariant = textSecondary;
  static const Color textMuted = slate400;

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE2E8F0); // Subdued Borders
  static const Color outline = borderLight;
  static const Color outlineVariant = Color(0xFFCBD5E1);
  static const Color borderSubtle = Color(0x1F0284C7);
  static const Color borderFocus = primaryBlue;

  // Status & Warning: Amber / Gold
  static const Color amber = ticketAmber;
  static const Color amberContainer = Color(0xFFFEF3C7);
  static const Color onAmber = Color(0xFF78350F);

  // Active Emerald & Critical Rose
  static const Color emerald = Color(0xFF10B981);
  static const Color rose = Color(0xFFEF4444);

  // Brand Violet (accent لوحات التذاكر — نفس بنفسجي بطاقات المتجر)
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetDeep = Color(0xFF7C3AED);
  static const Color violetMid = Color(0xFF6D28D9);
  static const Color violetInk = Color(0xFF4C1D95);
  static const Color violetDark = Color(0xFF5B21B6);
  static const Color violetHot = Color(0xFF7E22CE);
  static const Color violetBright = Color(0xFFA855F7);
  static const Color violetSoft = Color(0xFFD8B4FE);
  static const Color violetWash = Color(0xFFF5F3FF);

  // Indigo — هوية أقسام الإدارة (المستخدمون، المزودون، الحالات الجديدة)
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoDeep = Color(0xFF4F46E5);
  static const Color indigoSoft = Color(0xFF818CF8);
  static const Color indigoPale = Color(0xFFA5B4FC);
  static const Color indigoNight = Color(0xFF1E1B4B);
  static const Color blueDeep = Color(0xFF1D4ED8);

  // Cyan / Teal — هوية الأرقام والجودة
  static const Color primaryBright = Color(0xFF0EA5E9);
  static const Color primarySky = Color(0xFF38BDF8);
  static const Color primarySkySoft = Color(0xFF7DD3FC);
  static const Color primaryDeep = Color(0xFF075985);
  static const Color primaryInk = Color(0xFF0C4A6E);
  static const Color primaryWash = Color(0xFFE0F2FE);
  static const Color primaryMist = Color(0xFFF0F9FF);
  static const Color cyan = Color(0xFF0891B2);
  static const Color cyanInk = Color(0xFF155E75);
  static const Color teal = Color(0xFF0D9488);
  static const Color petrol = Color(0xFF034B52);
  static const Color petrolBright = Color(0xFF00BCD4);

  // Amber scale (نفس العائلة، بدون أصفر عشوائي)
  static const Color amberBright = Color(0xFFFBBF24);
  static const Color amberGold = Color(0xFFFCD34D);
  static const Color amberDeep = Color(0xFFB45309);
  static const Color amberInk = Color(0xFF92400E);
  static const Color amberWash = Color(0xFFFFFBEB);
  static const Color amberCream = Color(0xFFFFF7ED);
  static const Color highlight = Color(0xFFFDE047);
  static const Color goldSpark = Color(0xFFFFEE82);
  static const Color selection = Color(0xFFFFF7E6);
  static const Color cryptoGold = Color(0xFFF0B90B);

  // شعار JGO
  static const Color brand = Color(0xFFF18223);

  // Emerald scale
  static const Color successBright = Color(0xFF34D399);
  static const Color successSoft = Color(0xFF6EE7B7);
  static const Color successMint = Color(0xFFA7F3D0);
  static const Color successDeep = Color(0xFF047857);
  static const Color successWash = Color(0xFFECFDF5);
  static const Color mintWash = Color(0xFFF0FDFA);

  // Rose scale
  static const Color roseDeep = Color(0xFFE11D48);
  static const Color roseHot = Color(0xFFF43F5E);
  static const Color roseInk = Color(0xFFBE123C);
  static const Color roseDark = Color(0xFF9F1239);
  static const Color roseSoft = Color(0xFFF87171);
  static const Color errorInk = Color(0xFF991B1B);
  static const Color roseWash = Color(0xFFFEF2F2);
  static const Color roseMist = Color(0xFFFFF1F2);
  static const Color roseBorder = Color(0xFFFECDD3);

  // Near-black ink and cool surfaces used by tickets and sheets
  static const Color ink = Color(0xFF020617);
  static const Color navy = Color(0xFF0B1329);
  static const Color surfaceCool = Color(0xFFE9EFF7);
  static const Color surfaceMuted = Color(0xFFEDF2F7);

  // وسائل الدفع (هوية خارجية تبقى ثابتة)
  static const Color shamBlue = Color(0xFF4E67C3);
  static const Color shamBlueDeep = Color(0xFF2B3F9E);
  static const Color shamTeal = Color(0xFF3F8F9B);

  // Critical / Error
  static const Color error = rose;
  static const Color errorLight = Color(0xFFDC2626);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onError = Color(0xFFFFFFFF);

  // Gradients
  static const LinearGradient cardOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC090D16), Color(0xF5090D16)],
    stops: [0.25, 0.70, 1.0],
  );

  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [primary, primaryBright],
  );

  static const LinearGradient ticketGoldGradient = LinearGradient(
    colors: [ticketAmber, secondaryBright],
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, primaryBright],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient rainbowEdgeGradient = LinearGradient(
    colors: [primary, ticketAmber, accentGreen],
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
  );

  static const LinearGradient holographicCardGradient = LinearGradient(
    colors: [slate100, slate200, slate50],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [surfaceBright, slate50, slate100],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Backward compatibility alias
typedef ChargeXTheme = AppColors;
