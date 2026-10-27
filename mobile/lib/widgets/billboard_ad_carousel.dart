import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../models/banner_model.dart';
import 'digital_pass_card.dart';

class BillboardAdCarousel extends StatefulWidget {
  final List<BannerModel> banners;

  const BillboardAdCarousel({super.key, required this.banners});

  @override
  State<BillboardAdCarousel> createState() => _BillboardAdCarouselState();
}

class _BillboardAdCarouselState extends State<BillboardAdCarousel> {
  late PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentPage = 0;

  // هوية التطبيق: شكل تذكرة بنصف دائرتين مقطوعتين من منتصف الجنبين
  static const double _ticketRadius = 18.0;
  static const double _notchRadius = 14.0;
  static const double _notchPositionFraction = 0.5;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _resetTimer();
  }

  @override
  void didUpdateWidget(covariant BillboardAdCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _resetTimer();
    }
  }

  void _resetTimer() {
    _autoPlayTimer?.cancel();
    if (widget.banners.length > 1) {
      _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!mounted || !_pageController.hasClients) return;
        final nextPage = (_currentPage + 1) % widget.banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// الضغط على الإعلان يفتح الرابط المرفق به (إن وجد) في المتصفح،
  /// وإذا كان الإعلان "بدون رابط" فلا يحدث أي إجراء.
  Future<void> _handleBannerTap(BannerModel banner) async {
    final raw = (banner.actionValue ?? '').trim();
    if (raw.isEmpty) return;

    var uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      if (!raw.contains('.')) return;
      uri = Uri.tryParse('https://$raw');
    }
    if (uri == null || uri.host.isEmpty) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // رابط غير صالح أو لا يوجد تطبيق يفتحه: نتجاهل بهدوء دون تعطيل اللوحة
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no banners from server, display the fallback default billboard
    if (widget.banners.isEmpty) {
      return _buildDefaultBillboard();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      height: 152,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return _buildBannerSlide(banner);
            },
          ),

          // Pagination Dots (if multiple banners)
          if (widget.banners.length > 1)
            Positioned(
              bottom: 8,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.banners.length,
                  (dotIndex) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == dotIndex ? 18 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _currentPage == dotIndex
                          ? AppColors.secondary
                          : AppColors.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBannerSlide(BannerModel banner) {
    // هوية التطبيق: الإعلان على شكل تذكرة بنصف دائرتين مقطوعتين من الجنبين
    return Padding(
      padding: const EdgeInsets.all(3),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleBannerTap(banner),
        child: CustomPaint(
          painter: TicketPassShadowPainter(
            cornerRadius: _ticketRadius,
            notchRadius: _notchRadius,
            notchPositionFraction: _notchPositionFraction,
            shadowColor: Colors.black,
            elevation: 6.0,
          ),
          child: ClipPath(
            clipper: TicketPassClipper(
              cornerRadius: _ticketRadius,
              notchRadius: _notchRadius,
              notchPositionFraction: _notchPositionFraction,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cropped Background Image
                _buildBannerImage(banner.imageUrl),

                // Gradient Overlay for text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.88),
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),

                // Banner Content (Title & Description)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              banner.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(
                                alpha: 0.25,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.secondary,
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'إعلان',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondaryBright,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (banner.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          banner.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: Colors.white.withValues(alpha: 0.88),
                            shadows: const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Fallback default billboard when no ads are added
  Widget _buildDefaultBillboard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      child: CustomPaint(
        painter: TicketPassShadowPainter(
          cornerRadius: _ticketRadius,
          notchRadius: _notchRadius,
          notchPositionFraction: _notchPositionFraction,
          shadowColor: Colors.black,
          elevation: 6.0,
        ),
        child: ClipPath(
          clipper: TicketPassClipper(
            cornerRadius: _ticketRadius,
            notchRadius: _notchRadius,
            notchPositionFraction: _notchPositionFraction,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppColors.surfaceContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'أسرع شحن رقمي موثوق ⚡',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Icon(Icons.verified, color: AppColors.secondary, size: 18),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  'شحن فوري للألعاب والبطاقات والتطبيقات بأفضل الأسعار بالدولار.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Content = imageUrl.split(',').last;
        final bytes = base64Decode(base64Content);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildImagePlaceholder(),
        );
      } catch (_) {
        return _buildImagePlaceholder();
      }
    } else if (imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.holographicCardGradient,
      ),
      child: const Center(
        child: Icon(
          Icons.campaign_outlined,
          size: 48,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}
