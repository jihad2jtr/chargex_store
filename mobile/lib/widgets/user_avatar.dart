import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// صورة المستخدم الشخصية: تعرض الصورة المرفوعة إن وُجدت، وإلا أول حرف من الاسم.
/// تُستخدم في الملف الشخصي وهيدر التطبيق الموحّد.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.url,
    this.initial = 'U',
    this.size = 40,
    this.circular = true,
    this.backgroundColor = AppColors.slate800,
    this.foregroundColor = Colors.white,
  });

  final String? url;
  final String initial;
  final double size;
  final bool circular;
  final Color backgroundColor;
  final Color foregroundColor;

  bool get hasImage => (url ?? '').trim().isNotEmpty;

  Widget _letter() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(size * 0.26),
      ),
      child: Text(
        initial,
        style: AppTypography.plusJakartaSans(
          fontSize: size * 0.44,
          fontWeight: FontWeight.w900,
          color: foregroundColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!hasImage) return _letter();

    final String src = url!.trim();
    // مسار محلي من /uploads يُكمَّل برابط الخادم الأساسي
    final String absolute = src.startsWith('/')
        ? '${ApiConstants.baseUrl.replaceFirst('/api', '')}$src'
        : src;

    return SizedBox(
      width: size,
      height: size,
      child: circular
          ? ClipOval(child: _image(absolute))
          : ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.26),
              child: _image(absolute),
            ),
    );
  }

  Widget _image(String src) {
    return Image.network(
      src,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      // أثناء التحميل أو عند فشلها: الحرف الأول بدل مساحة فارغة
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _letter(),
      errorBuilder: (_, _, _) => _letter(),
    );
  }
}
