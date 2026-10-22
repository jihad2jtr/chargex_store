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
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true);

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

class VerticalDashedLinePainter extends CustomPainter {
  final Color color;
  final double dashHeight;
  final double dashSpace;

  VerticalDashedLinePainter({
    this.color = const Color(0x33FFFFFF),
    this.dashHeight = 4.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
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

  /// Helper to resolve card image from server URL (app.iconUrl)
  static String resolveCardImage(String name, {String? fallbackUrl}) {
    if (fallbackUrl != null && fallbackUrl.trim().isNotEmpty) {
      return fallbackUrl.trim();
    }
    return '';
  }

  /// Construct a dynamic digital pass item strictly using data from the server/admin panel
  factory DigitalPassItem.fromApp(AppItemModel app) {
    // Generate clean code for ticket badge (e.g., TKT #PUBG, TKT #FREE)
    final String cleanCode = app.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final String tktCode = cleanCode.isNotEmpty
        ? "TKT #${cleanCode.length > 5 ? cleanCode.substring(0, 5).toUpperCase() : cleanCode.toUpperCase()}"
        : "TKT #${app.name.split(' ').first.toUpperCase()}";

    final resolvedImg = resolveCardImage(app.name, fallbackUrl: app.iconUrl);

    // Determine badge and tag based on app category/type dynamically
    String badgeText = "فوري";
    IconData badgeIcon = Icons.bolt;
    Color badgeTextCol = const Color(0xFF065F46);
    Color badgeIconCol = const Color(0xFF059669);

    if (app.appType == 'game' || (app.category != null && app.category!.contains('ألعاب'))) {
      badgeText = "شحن فوري";
      badgeIcon = Icons.sports_esports;
    } else if (app.appType == 'service') {
      badgeText = "خدمة رقمية";
      badgeIcon = Icons.verified;
      badgeTextCol = const Color(0xFF075985);
      badgeIconCol = const Color(0xFF0284C7);
    } else if (app.category != null && app.category!.isNotEmpty) {
      badgeText = app.category!;
    }

    return DigitalPassItem(
      id: app.id,
      tktCode: tktCode,
      title: app.name,
      categoryRange: (app.description != null && app.description!.trim().isNotEmpty)
          ? app.description!
          : (app.category ?? "شحن فوري 24/7"),
      priceStarting: "باقات متعددة",
      topBadgeText: badgeText,
      topBadgeIcon: badgeIcon,
      topBadgeBg: const Color(0xF2FFFFFF),
      topBadgeTextCol: badgeTextCol,
      topBadgeIconCol: badgeIconCol,
      secondaryTag: app.appType.toUpperCase(),
      secondaryTagBg: const Color(0xCC082F49),
      secondaryTagBorder: const Color(0x660284C7),
      secondaryTagTextCol: const Color(0xFF7DD3FC),
      buttonLabel: "عرض الباقات",
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
    final String cleanCode = product.name.replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '',
    );
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
      categoryRange:
          product.description != null && product.description!.isNotEmpty
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
        child: Icon(Icons.sports_esports, color: Color(0xFFF59E0B), size: 32),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.20,
                                      ),
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
                                          color: Colors.black.withValues(
                                            alpha: 0.25,
                                          ),
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

// -----------------------------------------------------------------------------
// 5. HORIZONTAL RECTANGULAR DIGITAL PASS CARD WIDGET (كروت الباقات المستطيلة)
// -----------------------------------------------------------------------------

class HorizontalDigitalPassCardWidget extends StatelessWidget {
  final DigitalPassItem item;
  final ProductModel product;
  final VoidCallback onTapCharge;
  final double displayPrice;
  final String? marginText;

  const HorizontalDigitalPassCardWidget({
    super.key,
    required this.item,
    required this.product,
    required this.onTapCharge,
    required this.displayPrice,
    this.marginText,
  });

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF0F172A),
      child: const Center(
        child: Icon(Icons.sports_esports, color: Color(0xFFF59E0B), size: 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double notchPositionFraction = 0.50;
    const double cornerRadius = 14.0;
    const double cardHeight = 104.0;

    return Container(
      height: cardHeight,
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTapCharge,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: TicketPassShadowPainter(
            cornerRadius: cornerRadius,
            notchPositionFraction: notchPositionFraction,
            notchRadius: 8.0,
            elevation: 4.0,
          ),
          child: CustomPaint(
            foregroundPainter: TicketPassBorderPainter(
              cornerRadius: cornerRadius,
              notchPositionFraction: notchPositionFraction,
              notchRadius: 8.0,
              borderColor: Colors.white.withValues(alpha: 0.16),
              borderWidth: 1.0,
            ),
            child: ClipPath(
              clipper: TicketPassClipper(
                cornerRadius: cornerRadius,
                notchPositionFraction: notchPositionFraction,
                notchRadius: 8.0,
              ),
              child: Container(
                color: const Color(0xFF0F172A),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Full-Bleed Artwork Image
                    Positioned.fill(
                      child: item.imageUrl.startsWith('assets/')
                          ? Image.asset(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) =>
                                  _buildPlaceholder(),
                            )
                          : Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) =>
                                  _buildPlaceholder(),
                            ),
                    ),

                    // 2. Cinematic Gradient Overlay (Darkens toward the price side)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFF020617),
                              Color(0xF00F172A),
                              Color(0x990F172A),
                            ],
                            stops: [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // 3. Foreground Content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 9.0,
                      ),
                      child: Row(
                        children: [
                          // RIGHT SECTION (In RTL: Package Info)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top Badges Row
                                Row(
                                  children: [
                                    // Status Badge (Fast-Pass / كود رقمي / شحن ID)
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
                                    const SizedBox(width: 6),

                                    // TKT Code
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xE60F172A),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.20,
                                          ),
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
                                    const SizedBox(width: 6),

                                    // Secondary Tag (Codes / Direct / Manual)
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

                                // Package Title
                                Text(
                                  product.name,
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.arabicCardTitle(
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),

                                // Bottom Row: Category / Description & Reseller Margin
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.categoryRange,
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.cairo(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                    ),
                                    if (marginText != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0x3310B981),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: const Color(0x6610B981),
                                          ),
                                        ),
                                        child: Text(
                                          marginText!,
                                          style: AppTypography.cairo(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF34D399),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Vertical Perforated Dashed Line
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: CustomPaint(
                              painter: VerticalDashedLinePainter(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                              size: const Size(1, 68),
                            ),
                          ),

                          // LEFT SECTION (In RTL: Yellow Gradient Price Container)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFFEE82), // Soft bright yellow
                                  Color(0xFFFBBF24), // Vibrant warm yellow
                                  Color(0xFFF59E0B), // Golden amber
                                ],
                              ),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: const Color(0xFFFFFBEB),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (product.hasPriceChanged &&
                                    product.previousPrice != null)
                                  Text(
                                    '\$${product.previousPrice!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.lineThrough,
                                      height: 1.0,
                                    ),
                                  ),
                                Text(
                                  '\$${displayPrice.toStringAsFixed(2)}',
                                  style: AppTypography.price(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.bolt,
                                        size: 11,
                                        color: Color(0xFFFBBF24),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        item.buttonLabel,
                                        style: AppTypography.arabicButton(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
