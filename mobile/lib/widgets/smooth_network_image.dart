import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// صورة شبكة بتحميل ناعم وتدرّج ظهور (Fade-in) بدون قفزات بصرية،
/// مع تحديد أبعاد فكّ التشفير في الذاكرة لتقليل استهلاك الذاكرة وتحسين سلاسة التمرير.
class SmoothNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final int? cacheWidth;
  final int? cacheHeight;
  final WidgetBuilder? placeholderBuilder;
  final WidgetBuilder? errorBuilder;
  final Duration fadeDuration;

  const SmoothNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholderBuilder,
    this.errorBuilder,
    this.fadeDuration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: fadeDuration,
          switchInCurve: Curves.easeOut,
          child: frame != null
              ? child
              : (placeholderBuilder?.call(context) ??
                    const ColoredBox(color: AppColors.slate100)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (errorBuilder != null) return errorBuilder!(context);
        return const ColoredBox(
          color: AppColors.slate100,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 20,
              color: AppColors.slate400,
            ),
          ),
        );
      },
    );
  }
}
