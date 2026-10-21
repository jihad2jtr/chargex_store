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
  static const Color ticketAmber = Color(0xFFF59E0B); // Classic Ticket Gold / Amber
  static const Color ticketAmberLight = Color(0xFFFDE68A); // Amber soft
  static const Color secondary = ticketAmber;
  static const Color secondaryBright = Color(0xFFD97706);
  static const Color secondaryContainer = Color(0xFFFEF3C7);
  static const Color onSecondary = Color(0xFF000000);
  static const Color onSecondaryContainer = Color(0xFF78350F);

  // Active / Settlement Emerald Green
  static const Color accentGreen = Color(0xFF10B981); // Online / Active Node Green
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
  static const Color surfaceSecondary = Color(0xFFF1F5F9); // Bento Slot Background
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

  // Critical / Error
  static const Color error = rose;
  static const Color errorLight = Color(0xFFDC2626);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onError = Color(0xFFFFFFFF);

  // Gradients
  static const LinearGradient cardOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0xCC090D16),
      Color(0xF5090D16),
    ],
    stops: [0.25, 0.70, 1.0],
  );

  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
  );

  static const LinearGradient ticketGoldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient rainbowEdgeGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFFF59E0B), Color(0xFF10B981)],
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
  );

  static const LinearGradient holographicCardGradient = LinearGradient(
    colors: [
      Color(0xFFF1F5F9),
      Color(0xFFE2E8F0),
      Color(0xFFF8FAFC),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8FAFC),
      Color(0xFFF1F5F9),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Backward compatibility alias
typedef ChargeXTheme = AppColors;
