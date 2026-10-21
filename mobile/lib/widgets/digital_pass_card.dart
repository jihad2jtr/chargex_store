import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_typography.dart';
import '../models/app_model.dart';
import '../models/product_model.dart';

// -----------------------------------------------------------------------------
// 1. TICKET NOTCH CLIPPER & DASHED PAINTER
// -----------------------------------------------------------------------------

class TicketPassClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double? notchRadius;
  final double notchPositionFraction;

  TicketPassClipper({
    this.cornerRadius = 14.0,
    this.notchRadius,
    this.notchPositionFraction = 0.50,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final r = cornerRadius;
    // Notch radius matches exactly 35px in 400px height (~8.9% of card height)
    final nr = notchRadius ?? (size.height * 0.089).clamp(8.0, 18.0);
    final notchY = size.height * notchPositionFraction;

    // 1. Start at top-left after corner curve
    path.moveTo(r, 0);

    // 2. Top edge
    path.lineTo(size.width - r, 0);

    // 3. Top-right corner
    path.arcToPoint(
      Offset(size.width, r),
      radius: Radius.circular(r),
      clockwise: true,
    );

    // 4. Right edge down to notch
    path.lineTo(size.width, notchY - nr);

    // 5. Right notch: cuts INWARD into the card (to the left)
    path.arcToPoint(
      Offset(size.width, notchY + nr),
      radius: Radius.circular(nr),
      clockwise: false,
    );

    // 6. Right edge down to bottom-right corner
    path.lineTo(size.width, size.height - r);

    // 7. Bottom-right corner
    path.arcToPoint(
      Offset(size.width - r, size.height),
      radius: Radius.circular(r),
      clockwise: true,
    );

    // 8. Bottom edge
    path.lineTo(r, size.height);

    // 9. Bottom-left corner
    path.arcToPoint(
      Offset(0, size.height - r),
      radius: Radius.circular(r),
      clockwise: true,
    );

    // 10. Left edge up to notch
    path.lineTo(0, notchY + nr);

    // 11. Left notch: cuts INWARD into the card (to the right)
    path.arcToPoint(
      Offset(0, notchY - nr),
      radius: Radius.circular(nr),
      clockwise: false,
    );

    // 12. Left edge up to top-left corner
    path.lineTo(0, r);

    // 13. Top-left corner
    path.arcToPoint(
      Offset(r, 0),
      radius: Radius.circular(r),
      clockwise: true,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant TicketPassClipper oldClipper) =>
      oldClipper.cornerRadius != cornerRadius ||
      oldClipper.notchRadius != notchRadius ||
      oldClipper.notchPositionFraction != notchPositionFraction;
}

class TicketPassBorderPainter extends CustomPainter {
  final double cornerRadius;
  final double? notchRadius;
  final double notchPositionFraction;
  final Color borderColor;
  final double borderWidth;

  TicketPassBorderPainter({
    this.cornerRadius = 14.0,
    this.notchRadius,
    this.notchPositionFraction = 0.50,
    this.borderColor = const Color(0x33FFFFFF),
    this.borderWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clipper = TicketPassClipper(
      cornerRadius: cornerRadius,
      notchRadius: notchRadius,
      notchPositionFraction: notchPositionFraction,
    );
    final path = clipper.getClip(size);

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TicketPassBorderPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.notchRadius != notchRadius ||
      oldDelegate.notchPositionFraction != notchPositionFraction;
}

class TicketPassShadowPainter extends CustomPainter {
  final double cornerRadius;
  final double? notchRadius;
  final double notchPositionFraction;
  final Color shadowColor;
  final double elevation;

  TicketPassShadowPainter({
    this.cornerRadius = 14.0,
    this.notchRadius,
    this.notchPositionFraction = 0.50,
    this.shadowColor = Colors.black,
    this.elevation = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clipper = TicketPassClipper(
      cornerRadius: cornerRadius,
      notchRadius: notchRadius,
      notchPositionFraction: notchPositionFraction,
    );
    final path = clipper.getClip(size);
    canvas.drawShadow(
      path,
      shadowColor.withValues(alpha: 0.35),
      elevation,
      false,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  DashedLinePainter({
    this.color = const Color(0x33FFFFFF),
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// 2. DIGITAL PASS ITEM MODEL & SAMPLE DATA
// -----------------------------------------------------------------------------

class DigitalPassItem {
  final String id;
  final String tktCode;
  final String title;
  final String categoryRange;
  final String priceStarting;
  final String topBadgeText;
  final IconData topBadgeIcon;
  final Color topBadgeBg;
  final Color topBadgeTextCol;
  final Color topBadgeIconCol;
  final String secondaryTag;
  final Color secondaryTagBg;
  final Color secondaryTagBorder;
  final Color secondaryTagTextCol;
  final String buttonLabel;
  final String imageUrl;

  DigitalPassItem({
    required this.id,
    required this.tktCode,
    required this.title,
    required this.categoryRange,
    required this.priceStarting,
    required this.topBadgeText,
    required this.topBadgeIcon,
    this.topBadgeBg = const Color(0xF2FFFFFF),
    this.topBadgeTextCol = const Color(0xFF065F46),
    this.topBadgeIconCol = const Color(0xFF059669),
    required this.secondaryTag,
    this.secondaryTagBg = const Color(0xCC082F49),
    this.secondaryTagBorder = const Color(0x660284C7),
    this.secondaryTagTextCol = const Color(0xFF7DD3FC),
    this.buttonLabel = "شحن",
    required this.imageUrl,
  });

  /// Helper to resolve card image from local assets (600x400) or fallback
  static String resolveCardImage(String name, {String? fallbackUrl}) {
    // If an explicit asset path or remote URL was assigned, honor it directly
    if (fallbackUrl != null && fallbackUrl.trim().isNotEmpty) {
      final trimmed = fallbackUrl.trim();
      if (trimmed.startsWith('assets/') ||
          trimmed.startsWith('http://') ||
          trimmed.startsWith('https://')) {
        return trimmed;
      }
    }

    final lower = name.toLowerCase();

    // 1. Games (18 games)
    if (lower.contains('pubg') || lower.contains('ببجي') || lower.contains('بوبجي')) {
      return 'assets/cards/pubg-mobile.png';
    }
    if (lower.contains('free') || lower.contains('فاير') || lower.contains('fire')) {
      return 'assets/cards/free-fire.png';
    }
    if (lower.contains('call of duty') || lower.contains('كول اوف') || lower.contains('cod') || lower.contains('كود')) {
      return 'assets/cards/call-of-duty-mobile.png';
    }
    if (lower.contains('ea') || lower.contains('fifa') || lower.contains('فيفا') || lower.contains('fc 2') || lower.contains('fc2')) {
      return 'assets/cards/ea-sports-fc.png';
    }
    if (lower.contains('efootball') || lower.contains('pes') || lower.contains('بيس')) {
      return 'assets/cards/efootball.png';
    }
    if (lower.contains('clash royale') || lower.contains('كلاش رويال')) {
      return 'assets/cards/clash-royale.png';
    }
    if (lower.contains('clash') || lower.contains('كلاش')) {
      return 'assets/cards/clash-of-clans.png';
    }
    if (lower.contains('brawl') || lower.contains('براول')) {
      return 'assets/cards/brawl-stars.png';
    }
    if (lower.contains('roblox') || lower.contains('روبلوكس') || lower.contains('روبلكس')) {
      return 'assets/cards/roblox.png';
    }
    if (lower.contains('minecraft') || lower.contains('ماين كرافت') || lower.contains('ماينكرافت')) {
      return 'assets/cards/minecraft.png';
    }
    if (lower.contains('fortnite') || lower.contains('فورتنايت') || lower.contains('فورت نايت')) {
      return 'assets/cards/fortnite.png';
    }
    if (lower.contains('valorant') || lower.contains('فالورانت') || lower.contains('فالورنت')) {
      return 'assets/cards/valorant.png';
    }
    if (lower.contains('league of legends') || lower.contains('lol') || lower.contains('ليج أوف ليجندز') || lower.contains('ليق')) {
      return 'assets/cards/league-of-legends.png';
    }
    if (lower.contains('legends') || lower.contains('ليجند') || lower.contains('mlbb')) {
      return 'assets/cards/mobile-legends.png';
    }
    if (lower.contains('genshin') || lower.contains('قنشن') || lower.contains('جينشين')) {
      return 'assets/cards/genshin-impact.png';
    }
    if (lower.contains('honkai') || lower.contains('star rail') || lower.contains('هونكاي')) {
      return 'assets/cards/honkai-star-rail.png';
    }
    if (lower.contains('asphalt') || lower.contains('اسفلت') || lower.contains('أسفلت')) {
      return 'assets/cards/asphalt-9.png';
    }
    if (lower.contains('among us') || lower.contains('among-us') || lower.contains('امونج') || lower.contains('امونغ')) {
      return 'assets/cards/among-us.png';
    }

    // 2. Apps & Social & AI (14 apps)
    if (lower.contains('chatgpt') || lower.contains('chat gpt') || lower.contains('openai') || lower.contains('جي بي تي')) {
      return 'assets/cards/chatgpt.png';
    }
    if (lower.contains('tiktok') || lower.contains('تيك توك') || lower.contains('تيك')) {
      return 'assets/cards/tiktok.png';
    }
    if (lower.contains('snap') || lower.contains('سناب')) {
      return 'assets/cards/snapchat.png';
    }
    if (lower.contains('instagram') || lower.contains('انستقرام') || lower.contains('انستغرام') || lower.contains('انستا')) {
      return 'assets/cards/instagram.png';
    }
    if (lower.contains('telegram') || lower.contains('تيليجرام') || lower.contains('تليجرام') || lower.contains('تليغرام')) {
      return 'assets/cards/telegram.png';
    }
    if (lower.contains('whatsapp') || lower.contains('واتساب') || lower.contains('واتس')) {
      return 'assets/cards/whatsapp.png';
    }
    if (lower.contains('facebook') || lower.contains('فيسبوك') || lower.contains('فيس')) {
      return 'assets/cards/facebook.png';
    }
    if (lower == 'x' || lower.contains('twitter') || lower.contains('تويتر') || lower.contains('منصة x')) {
      return 'assets/cards/x.png';
    }
    if (lower.contains('discord') || lower.contains('ديسكورد')) {
      return 'assets/cards/discord.png';
    }
    if (lower.contains('spotify') || lower.contains('سبوتيفاي') || lower.contains('سبوتفاي')) {
      return 'assets/cards/spotify.png';
    }
    if (lower.contains('netflix') || lower.contains('نتفلكس') || lower.contains('نتفليكس')) {
      return 'assets/cards/netflix.png';
    }
    if (lower.contains('youtube') || lower.contains('يوتيوب')) {
      return 'assets/cards/youtube-premium.png';
    }
    if (lower.contains('canva') || lower.contains('كانفا')) {
      return 'assets/cards/canva.png';
    }
    if (lower.contains('gmail') || lower.contains('جيميل')) {
      return 'assets/cards/gmail.png';
    }

    // 3. Digital Stores & Consoles (8 services)
    if (lower.contains('playstation') || lower.contains('psn') || lower.contains('بلايستيشن') || lower.contains('بلاي ستيشن') || lower.contains('ps5') || lower.contains('ps4')) {
      return 'assets/cards/playstation.png';
    }
    if (lower.contains('xbox') || lower.contains('اكس بوكس') || lower.contains('إكس بوكس')) {
      return 'assets/cards/xbox.png';
    }
    if (lower.contains('steam') || lower.contains('ستيم')) {
      return 'assets/cards/steam.png';
    }
    if (lower.contains('nintendo') || lower.contains('نينتندو') || lower.contains('سويتش')) {
      return 'assets/cards/nintendo.png';
    }
    if (lower.contains('icloud') || lower.contains('اي كلاود') || lower.contains('آي كلاود')) {
      return 'assets/cards/icloud.png';
    }
    if (lower.contains('microsoft') || lower.contains('مايكروسوفت') || lower.contains('office') || lower.contains('اوفيس')) {
      return 'assets/cards/microsoft-365.png';
    }
    if (lower.contains('google') || lower.contains('جوجل') || lower.contains('قوقل') || lower.contains('play')) {
      return 'assets/cards/google-play.png';
    }
    if (lower.contains('apple') || lower.contains('app store') || lower.contains('ابل') || lower.contains('أبل') || lower.contains('itunes')) {
      return 'assets/cards/app-store.png';
    }

    // Explicit icon or fallback if not matching predefined card artwork
    if (fallbackUrl != null && fallbackUrl.trim().isNotEmpty) {
      return fallbackUrl;
    }
    return 'assets/cards/pubg-mobile.png';
  }

  factory DigitalPassItem.fromApp(AppItemModel app) {
    final nameLower = app.name.toLowerCase();
    final isPubg = nameLower.contains('pubg') || app.name.contains('ببجي');
    final isFF = nameLower.contains('fire') || app.name.contains('فاير');
    final isTikTok = nameLower.contains('tiktok') || app.name.contains('تيك');
    final isML = nameLower.contains('legends') || app.name.contains('ليجند');

    final resolvedImg = resolveCardImage(app.name, fallbackUrl: app.iconUrl);

    if (isPubg) {
      return DigitalPassItem(
        id: app.id,
        tktCode: "TKT #PUBG",
        title: "ببجي موبايل",
        categoryRange: "60 إلى 8100 شدة UC",
        priceStarting: "\$0.99",
        topBadgeText: "FAST-PASS 60s",
        topBadgeIcon: Icons.bolt,
        topBadgeBg: const Color(0xF2FFFFFF),
        topBadgeTextCol: const Color(0xFF065F46),
        topBadgeIconCol: const Color(0xFF059669),
        secondaryTag: "DIRECT",
        secondaryTagBg: const Color(0xCC082F49),
        secondaryTagBorder: const Color(0x660284C7),
        secondaryTagTextCol: const Color(0xFF7DD3FC),
        buttonLabel: "شحن",
        imageUrl: resolvedImg,
      );
    } else if (isFF) {
      return DigitalPassItem(
        id: app.id,
        tktCode: "TKT #FF",
        title: "فري فاير",
        categoryRange: "100 إلى 2180 جوهرة",
        priceStarting: "\$0.85",
        topBadgeText: "ID مباشر",
        topBadgeIcon: Icons.fingerprint,
        topBadgeBg: const Color(0xF2FFFFFF),
        topBadgeTextCol: const Color(0xFF075985),
        topBadgeIconCol: const Color(0xFF0284C7),
        secondaryTag: "G-PASS",
        secondaryTagBg: const Color(0xCC451A03),
        secondaryTagBorder: const Color(0x66F59E0B),
        secondaryTagTextCol: const Color(0xFFFDE68A),
        buttonLabel: "شحن",
        imageUrl: resolvedImg,
      );
    } else if (isTikTok) {
      return DigitalPassItem(
        id: app.id,
        tktCode: "TKT #TKCOIN",
        title: "تيك توك عملات",
        categoryRange: "70 إلى 7000 عملة",
        priceStarting: "\$1.20",
        topBadgeText: "تلقائي AUTO",
        topBadgeIcon: Icons.flash_on,
        topBadgeBg: const Color(0xF2FFFFFF),
        topBadgeTextCol: const Color(0xFF065F46),
        topBadgeIconCol: const Color(0xFF059669),
        secondaryTag: "LIVE",
        secondaryTagBg: const Color(0xCC064E3B),
        secondaryTagBorder: const Color(0x6610B981),
        secondaryTagTextCol: const Color(0xFF6EE7B7),
        buttonLabel: "شحن فوري",
        imageUrl: resolvedImg,
      );
    } else if (isML) {
      return DigitalPassItem(
        id: app.id,
        tktCode: "TKT #MLBB",
        title: "موبايل ليجندز",
        categoryRange: "ماس + باقة النجوم",
        priceStarting: "\$1.50",
        topBadgeText: "شحن خادم",
        topBadgeIcon: Icons.verified,
        topBadgeBg: const Color(0xF2FFFFFF),
        topBadgeTextCol: const Color(0xFF075985),
        topBadgeIconCol: const Color(0xFF0284C7),
        secondaryTag: "VIP PASS",
        secondaryTagBg: const Color(0xCC3B0764),
        secondaryTagBorder: const Color(0x66A855F7),
        secondaryTagTextCol: const Color(0xFFD8B4FE),
        buttonLabel: "شحن فوري",
        imageUrl: resolvedImg,
      );
    }

    final code = "TKT #${app.name.split(' ').first.toUpperCase()}";
    return DigitalPassItem(
      id: app.id,
      tktCode: code,
      title: app.name,
      categoryRange: app.description ?? "شحن فوري 24/7",
      priceStarting: "\$0.99",
      topBadgeText: app.category ?? "فوري",
      topBadgeIcon: Icons.bolt,
      secondaryTag: "PASS",
      buttonLabel: "شحن",
      imageUrl: resolvedImg,
    );
  }

  factory DigitalPassItem.fromProduct(
    ProductModel product,
    AppItemModel app, {
    double? customerPrice,
  }) {
    final double finalPrice = customerPrice ?? product.salePrice;
    final String formattedPrice = "\$${finalPrice.toStringAsFixed(2)}";

    String topBadgeText = "فوري 60s";
    IconData topBadgeIcon = Icons.bolt;
    Color topBadgeTextCol = const Color(0xFF065F46);
    Color topBadgeIconCol = const Color(0xFF059669);

    String secTag = "DIRECT";
    Color secBg = const Color(0xCC082F49);
    Color secBorder = const Color(0x660284C7);
    Color secText = const Color(0xFF7DD3FC);

    if (product.type == 'codes') {
      topBadgeText = "كود رقمي";
      topBadgeIcon = Icons.confirmation_number_outlined;
      topBadgeTextCol = const Color(0xFF7E22CE);
      topBadgeIconCol = const Color(0xFF7E22CE);
      secTag = "CODES";
      secBg = const Color(0xCC3B0764);
      secBorder = const Color(0x66A855F7);
      secText = const Color(0xFFD8B4FE);
    } else if (product.type == 'manual') {
      topBadgeText = "يدوي SLA";
      topBadgeIcon = Icons.person_pin_outlined;
      topBadgeTextCol = const Color(0xFFB45309);
      topBadgeIconCol = const Color(0xFFB45309);
      secTag = "MANUAL";
      secBg = const Color(0xCC451A03);
      secBorder = const Color(0x66F59E0B);
      secText = const Color(0xFFFDE68A);
    }

    // TKT code from product or app
    final String cleanCode = product.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final String tktCode = cleanCode.isNotEmpty
        ? "TKT #${cleanCode.length > 5 ? cleanCode.substring(0, 5).toUpperCase() : cleanCode.toUpperCase()}"
        : "TKT #${app.name.split(' ').first.toUpperCase()}";

    // Resolve card cover image using combination of product name and app name
    final resolvedImg = resolveCardImage(
      "${product.name} ${app.name}",
      fallbackUrl: app.iconUrl,
    );

    return DigitalPassItem(
      id: product.id,
      tktCode: tktCode,
      title: product.name,
      categoryRange: product.description != null && product.description!.isNotEmpty
          ? product.description!
          : (product.type == 'codes'
              ? 'تسليم كود فوري آلياً'
              : (product.type == 'manual'
                  ? 'تنفيذ فوري عبر المشرف'
                  : 'شحن حساب رسمي مباشر')),
      priceStarting: formattedPrice,
      topBadgeText: topBadgeText,
      topBadgeIcon: topBadgeIcon,
      topBadgeBg: const Color(0xF2FFFFFF),
      topBadgeTextCol: topBadgeTextCol,
      topBadgeIconCol: topBadgeIconCol,
      secondaryTag: secTag,
      secondaryTagBg: secBg,
      secondaryTagBorder: secBorder,
      secondaryTagTextCol: secText,
      buttonLabel: "شحن",
      imageUrl: resolvedImg,
    );
  }
}

final List<DigitalPassItem> samplePasses = [
  DigitalPassItem(
    id: "PUBG-60S",
    tktCode: "TKT #PUBG",
    title: "ببجي موبايل",
    categoryRange: "60 إلى 8100 شدة UC",
    priceStarting: "\$0.99",
    topBadgeText: "FAST-PASS 60s",
    topBadgeIcon: Icons.bolt,
    topBadgeBg: const Color(0xF2FFFFFF),
    topBadgeTextCol: const Color(0xFF065F46),
    topBadgeIconCol: const Color(0xFF059669),
    secondaryTag: "DIRECT",
    secondaryTagBg: const Color(0xCC082F49),
    secondaryTagBorder: const Color(0x660284C7),
    secondaryTagTextCol: const Color(0xFF7DD3FC),
    buttonLabel: "شحن",
    imageUrl: "assets/cards/pubg-mobile.png",
  ),
  DigitalPassItem(
    id: "FF-DIRECT",
    tktCode: "TKT #FF",
    title: "فري فاير",
    categoryRange: "100 إلى 2180 جوهرة",
    priceStarting: "\$0.85",
    topBadgeText: "ID مباشر",
    topBadgeIcon: Icons.fingerprint,
    topBadgeBg: const Color(0xF2FFFFFF),
    topBadgeTextCol: const Color(0xFF075985),
    topBadgeIconCol: const Color(0xFF0284C7),
    secondaryTag: "G-PASS",
    secondaryTagBg: const Color(0xCC451A03),
    secondaryTagBorder: const Color(0x66F59E0B),
    secondaryTagTextCol: const Color(0xFFFDE68A),
    buttonLabel: "شحن",
    imageUrl: "assets/cards/free-fire.png",
  ),
  DigitalPassItem(
    id: "TK-COIN",
    tktCode: "TKT #TKCOIN",
    title: "تيك توك عملات",
    categoryRange: "70 إلى 7000 عملة",
    priceStarting: "\$1.20",
    topBadgeText: "تلقائي AUTO",
    topBadgeIcon: Icons.flash_on,
    topBadgeBg: const Color(0xF2FFFFFF),
    topBadgeTextCol: const Color(0xFF065F46),
    topBadgeIconCol: const Color(0xFF059669),
    secondaryTag: "LIVE",
    secondaryTagBg: const Color(0xCC064E3B),
    secondaryTagBorder: const Color(0x6610B981),
    secondaryTagTextCol: const Color(0xFF6EE7B7),
    buttonLabel: "شحن فوري",
    imageUrl: "assets/cards/tiktok.png",
  ),
  DigitalPassItem(
    id: "ML-STAR",
    tktCode: "TKT #MLBB",
    title: "موبايل ليجندز",
    categoryRange: "ماس + باقة النجوم",
    priceStarting: "\$1.50",
    topBadgeText: "شحن خادم",
    topBadgeIcon: Icons.verified,
    topBadgeBg: const Color(0xF2FFFFFF),
    topBadgeTextCol: const Color(0xFF075985),
    topBadgeIconCol: const Color(0xFF0284C7),
    secondaryTag: "VIP PASS",
    secondaryTagBg: const Color(0xCC3B0764),
    secondaryTagBorder: const Color(0x66A855F7),
    secondaryTagTextCol: const Color(0xFFD8B4FE),
    buttonLabel: "شحن فوري",
    imageUrl: "assets/cards/mobile-legends.png",
  ),
  DigitalPassItem(
    id: "COD-M",
    tktCode: "TKT #CODM",
    title: "كول أوف ديوتي",
    categoryRange: "CP نقاط كود وميداليات",
    priceStarting: "\$0.99",
    topBadgeText: "ID حساب",
    topBadgeIcon: Icons.bolt,
    topBadgeBg: const Color(0xF2FFFFFF),
    topBadgeTextCol: const Color(0xFF065F46),
    topBadgeIconCol: const Color(0xFF059669),
    secondaryTag: "DIRECT",
    secondaryTagBg: const Color(0xCC082F49),
    secondaryTagBorder: const Color(0x660284C7),
    secondaryTagTextCol: const Color(0xFF7DD3FC),
    buttonLabel: "شحن",
    imageUrl: "assets/cards/call-of-duty-mobile.png",
  ),
  DigitalPassItem(
    id: "ROBLOX-R",
    tktCode: "TKT #RBLX",
    title: "روبلوكس",
    categoryRange: "روبوكس وبطاقات رقمية",
    priceStarting: "\$1.99",
    topBadgeText: "كود فوري",
    topBadgeIcon: Icons.confirmation_number_outlined,
    topBadgeBg: const Color(0xF2FFFFFF),
    topBadgeTextCol: const Color(0xFF7E22CE),
    topBadgeIconCol: const Color(0xFF7E22CE),
    secondaryTag: "CODES",
    secondaryTagBg: const Color(0xCC3B0764),
    secondaryTagBorder: const Color(0x66A855F7),
    secondaryTagTextCol: const Color(0xFFD8B4FE),
    buttonLabel: "شحن",
    imageUrl: "assets/cards/roblox.png",
  ),
];

// -----------------------------------------------------------------------------
// 3. HERO DIGITAL PROMO PASS TICKET CAROUSEL
// -----------------------------------------------------------------------------

class HeroTicketBanner extends StatefulWidget {
  final VoidCallback onTap;

  const HeroTicketBanner({super.key, required this.onTap});

  @override
  State<HeroTicketBanner> createState() => _HeroTicketBannerState();
}

class _HeroTicketBannerState extends State<HeroTicketBanner> {
  int _currentSlide = 0;
  Timer? _timer;
  late final PageController _pageController;

  final List<Map<String, dynamic>> _slides = [
    {
      "badge": "PROMO PASS 15% OFF",
      "gate": "GATE A1",
      "badgeBg": Color(0xFFF59E0B),
      "badgeTextCol": Color(0xFF0F172A),
      "title": "خصم 15% على شدات PUBG",
      "subtitle": "تعبئة مباشرة عبر الـ ID الرسمي خلال 60 ثانية",
      "barcodeText": "CX-PASS-60S",
      "image":
          "https://lh3.googleusercontent.com/aida-public/AB6AXuDEbSy3ZJqZrOYg9-2BBdsN9dQg0e_4uSqxYmHSfisETG15qihTy9gYE_IaRG7PXfey4Y-0Ebu2lpQ0RTYSdoJWcrY8YgQhqtluo1ePlUnMJJEp-Fw-oyShjGmsbhsOpu2J4yI2jRiH2WwzEbQwfZv5mUWOaELkayMBC6BsyjSVI6DaigzwnZy-xvJLzOvXxksIdR51_kswYS5E9GX75lgpsoo4QC9qr8qu1X10K0yZRoODENLveX5X",
    },
    {
      "badge": "GATEWAY 0% FEE",
      "gate": "GATE B2",
      "badgeBg": Color(0xFF10B981),
      "badgeTextCol": Colors.white,
      "title": "شام كاش & Binance Pay",
      "subtitle": "إيداع وسحب مباشر بدون أي تأخير آلياً",
      "barcodeText": "FAST-SETTLE",
      "image":
          "https://lh3.googleusercontent.com/aida-public/AB6AXuA1R__m4LQ7n_tCbJl6qitZxiUqJYv57OCo1i-ukI83xEbwut5Tz3qDqnga0p3sMvgN4jCkqCcExiLk8u-ZeswFnl4KVF-wrnudy6kGVgiQNo11Zpxfs5eIXuqVGafMaJqDyQjFs3BigFBi0eDbbMKBXGRLUX1EBmggjVAG_LeCNiDLm4DZqEJW9dsdvIVZFzJ_OqYFRGrYicTChBEuZIZAehJ6qx8fc4yjdEFNgFdxTsJ-z_R5FiFX",
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timer = Timer.periodic(const Duration(milliseconds: 4500), (timer) {
      if (mounted) {
        final nextPage = (_currentSlide + 1) % _slides.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: TicketPassClipper(notchRadius: 9.0, notchPositionFraction: 0.5),
      child: Container(
        height: 155,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentSlide = idx),
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                final slide = _slides[index];

                return GestureDetector(
                  onTap: widget.onTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background Artwork
                      Positioned.fill(
                        child: slide['image'].toString().startsWith('assets/')
                            ? Image.asset(
                                slide['image'],
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) =>
                                    Container(color: const Color(0xFF0F172A)),
                              )
                            : Image.network(
                                slide['image'],
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) =>
                                    Container(color: const Color(0xFF0F172A)),
                              ),
                      ),

                      // Gradient Overlay
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                Color(0xFFFFFFFF),
                                Color(0xF2FFFFFF),
                                Color(0x66FFFFFF),
                              ],
                              stops: [0.0, 0.65, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Slide Foreground Text
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 14.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Row: Badges
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: slide['badgeBg'],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      slide['badge'],
                                      style: AppTypography.fintechBadge(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: slide['badgeTextCol'],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    slide['gate'],
                                    style: AppTypography.technicalCode(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Title: Cairo Arabic Font
                              Text(
                                slide['title'],
                                textAlign: TextAlign.right,
                                style: AppTypography.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 3),

                              // Subtitle: Cairo Arabic Font
                              Text(
                                slide['subtitle'],
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cairo(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                              const Spacer(),

                              // Barcode Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    slide['barcodeText'],
                                    style: AppTypography.technicalCode(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CustomPaint(
                                    size: const Size(80, 15),
                                    painter: BarcodePainter(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Pagination Dots
            Positioned(
              bottom: 12,
              left: 16,
              child: Row(
                children: List.generate(_slides.length, (i) {
                  final isActive = _currentSlide == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 4),
                    width: isActive ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.8;

    const pattern = [
      2,
      1,
      3,
      1,
      2,
      1,
      1,
      3,
      2,
      1,
      2,
      1,
      3,
      1,
      2,
      2,
      1,
      3,
      1,
      2,
      1,
      2,
      3,
      1,
    ];
    double x = 0;
    for (int i = 0; i < pattern.length && x < size.width; i++) {
      paint.strokeWidth = pattern[i].toDouble();
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      x += pattern[i] + 1.8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// 4. INDIVIDUAL DIGITAL PASS CARD WIDGET
// -----------------------------------------------------------------------------

class DigitalPassCardWidget extends StatelessWidget {
  final DigitalPassItem item;
  final VoidCallback onTapCharge;
  final bool imageOnly;

  const DigitalPassCardWidget({
    super.key,
    required this.item,
    required this.onTapCharge,
    this.imageOnly = true,
  });

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF0F172A),
      child: const Center(
        child: Icon(
          Icons.sports_esports,
          color: Color(0xFFF59E0B),
          size: 32,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double notchPositionFraction = 0.50;
    const double cornerRadius = 14.0;

    if (imageOnly) {
      return GestureDetector(
        onTap: onTapCharge,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: TicketPassShadowPainter(
            cornerRadius: cornerRadius,
            notchPositionFraction: notchPositionFraction,
            elevation: 4.0,
          ),
          child: CustomPaint(
            foregroundPainter: TicketPassBorderPainter(
              cornerRadius: cornerRadius,
              notchPositionFraction: notchPositionFraction,
              borderColor: Colors.white.withValues(alpha: 0.14),
              borderWidth: 1.0,
            ),
            child: ClipPath(
              clipper: TicketPassClipper(
                cornerRadius: cornerRadius,
                notchPositionFraction: notchPositionFraction,
              ),
              child: Container(
                color: const Color(0xFF0F172A),
                child: item.imageUrl.startsWith('assets/')
                    ? Image.asset(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
                      )
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTapCharge,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: TicketPassShadowPainter(
          cornerRadius: cornerRadius,
          notchPositionFraction: notchPositionFraction,
          elevation: 4.0,
        ),
        child: CustomPaint(
          foregroundPainter: TicketPassBorderPainter(
            cornerRadius: cornerRadius,
            notchPositionFraction: notchPositionFraction,
            borderColor: const Color(0xFF1E293B),
            borderWidth: 1.0,
          ),
          child: ClipPath(
            clipper: TicketPassClipper(
              cornerRadius: cornerRadius,
              notchPositionFraction: notchPositionFraction,
            ),
            child: Container(
              color: const Color(0xFF0F172A),
              child: Stack(
                children: [
            // 1. Full-Bleed Artwork Image
            Positioned.fill(
              child: item.imageUrl.startsWith('assets/')
                  ? Image.asset(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        color: const Color(0xFF0F172A),
                        child: const Center(
                          child: Icon(
                            Icons.sports_esports,
                            color: Color(0xFFF59E0B),
                            size: 32,
                          ),
                        ),
                      ),
                    )
                  : Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        color: const Color(0xFF0F172A),
                        child: const Center(
                          child: Icon(
                            Icons.sports_esports,
                            color: Color(0xFFF59E0B),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
            ),

            // 2. Cinematic Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF020617),
                      Color(0xCC0F172A),
                      Color(0x660F172A),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Foreground Content
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 9.0,
                vertical: 6.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // UPPER SECTION
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Row: Badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Status Badge: Plus Jakarta Sans / Space Mono
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: item.topBadgeBg,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.topBadgeIcon,
                                  size: 10,
                                  color: item.topBadgeIconCol,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  item.topBadgeText,
                                  style: AppTypography.fintechBadge(
                                    fontSize: 8.0,
                                    fontWeight: FontWeight.w900,
                                    color: item.topBadgeTextCol,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // TKT Code: Space Mono
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xE60F172A),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                              ),
                            ),
                            child: Text(
                              item.tktCode,
                              style: AppTypography.technicalCode(
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Game Title & Tag Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.arabicCardTitle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: item.secondaryTagBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: item.secondaryTagBorder,
                              ),
                            ),
                            child: Text(
                              item.secondaryTag,
                              style: AppTypography.technicalCode(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                color: item.secondaryTagTextCol,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Category Range: Cairo Arabic
                      Text(
                        item.categoryRange,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cairo(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),

                  // LOWER SECTION (Fare & Button together)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Perforated Dashed Line
                      CustomPaint(
                        painter: DashedLinePainter(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                        size: const Size(double.infinity, 1),
                      ),
                      const SizedBox(height: 5),

                      // Fare & Action Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Price & Fare Label
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.priceStarting,
                                style: AppTypography.price(
                                  fontSize: 13.5,
                                  color: const Color(0xFFFDE047),
                                ),
                              ),
                              Text(
                                "FARE / يبدأ من",
                                style: AppTypography.technicalCode(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),

                          // Compact Action Button
                          InkWell(
                            onTap: onTapCharge,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 28,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBBF24),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bolt,
                                    size: 13,
                                    color: Color(0xFF020617),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    item.buttonLabel,
                                    style: AppTypography.arabicButton(
                                      fontSize: 10.5,
                                      color: const Color(0xFF020617),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  ),
  );
}
}
