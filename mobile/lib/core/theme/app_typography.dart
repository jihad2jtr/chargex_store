import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ChargeX Typography System: Swiss Neo-Bento FinTech
///
/// 1. Arabic Typographic Stack: Cairo
/// 2. Primary English & Numeric Font: Plus Jakarta Sans
/// 3. Monospace Technical Font: Space Mono / JetBrains Mono
class AppTypography {
  AppTypography._();

  // ---------------------------------------------------------------------------
  // 1. Base Font Factories
  // ---------------------------------------------------------------------------

  /// Arabic Primary Font: Cairo
  static TextStyle cairo({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.cairo(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// English, Numbers & Currency: Plus Jakarta Sans
  static TextStyle plusJakartaSans({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.plusJakartaSans(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// Technical Codes & Server Tags: Space Mono
  static TextStyle spaceMono({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.spaceMono(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Pre-Configured FinTech Typography Tokens
  // ---------------------------------------------------------------------------

  /// Balance display (e.g. $1,248.50)
  static TextStyle balance({Color color = const Color(0xFF0F172A), double fontSize = 12.0}) {
    return plusJakartaSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: color,
      letterSpacing: -0.2,
    );
  }

  /// Ticket price display (e.g. $0.99, $1.50)
  static TextStyle price({
    Color color = const Color(0xFFFDE047),
    double fontSize = 15.0,
    FontWeight fontWeight = FontWeight.w900,
  }) {
    return plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.3,
    );
  }

  /// Technical Code Tag (e.g. TKT #PUBG, SSL 256-BIT, GATE A1)
  static TextStyle technicalCode({
    Color color = Colors.white,
    double fontSize = 8.5,
    FontWeight fontWeight = FontWeight.bold,
    double letterSpacing = 0.3,
  }) {
    return spaceMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// FinTech Badge (e.g. VIP GOLD, PROMO PASS 15% OFF, GATEWAY 0% FEE)
  static TextStyle fintechBadge({
    Color color = Colors.black,
    double fontSize = 9.0,
    FontWeight fontWeight = FontWeight.w900,
  }) {
    return plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.4,
    );
  }

  /// Arabic Card Title (e.g. ببجي موبايل, فري فاير)
  static TextStyle arabicCardTitle({
    Color color = Colors.white,
    double fontSize = 14.0,
  }) {
    return cairo(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: color,
      height: 1.2,
    );
  }

  /// Arabic Button Text (e.g. شحن, شحن فوري, التذاكر)
  static TextStyle arabicButton({
    Color color = Colors.black,
    double fontSize = 11.5,
  }) {
    return cairo(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: color,
      height: 1.1,
    );
  }
}
