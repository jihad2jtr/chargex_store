import 'package:flutter/material.dart';

/// نوع الرسم التعبيري المسطّح لكل قسم من أقسام لوحة الأدمن
enum AdminIllustrationKind {
  numProviders,
  numDictionary,
  numApps,
  numQuality,
  numManual,
  numLogs,
  storeProviders,
  storeApps,
  orders,
  paymentAccounts,
  shippingCodes,
  templates,
  banners,
  users,
  manualServices,
}

/// صورة رسومية تعبيرية مسطّحة (Flat Vector Illustration) بأسلوب نظيف
/// يجمع بين الرمادي الفاتح والكحلي الداكن واللون المميّز بدون إطار كرت.
class AdminSectionIllustration extends StatelessWidget {
  final AdminIllustrationKind kind;
  final Color accent;
  final double size;

  const AdminSectionIllustration({
    super.key,
    required this.kind,
    required this.accent,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IllustrationPainter(kind: kind, accent: accent),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  final AdminIllustrationKind kind;
  final Color accent;

  const _IllustrationPainter({required this.kind, required this.accent});

  static const Color _ink = Color(0xFF1E293B);
  static const Color _body = Color(0xFFE2E8F0);
  static const Color _bodyMid = Color(0xFFCBD5E1);
  static const Color _bodyDark = Color(0xFF94A3B8);
  static const Color _orange = Color(0xFFF59E0B);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final bodyPaint = Paint()..color = _body;
    final bodyMidPaint = Paint()..color = _bodyMid;
    final bodyDarkPaint = Paint()..color = _bodyDark;
    final inkPaint = Paint()..color = _ink;
    final accentPaint = Paint()..color = accent;
    final orangePaint = Paint()..color = _orange;
    final whitePaint = Paint()..color = Colors.white;

    // هالة خلفية ناعمة جداً تمنح الرسم عمقاً لطيفاً دون إطار كرت
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.52),
      w * 0.44,
      Paint()..color = accent.withValues(alpha: 0.10),
    );

    switch (kind) {
      case AdminIllustrationKind.numProviders:
        // برج خادم مع هوائي إشارة
        _rrect(canvas, w * 0.24, h * 0.22, w * 0.52, h * 0.62, 8, bodyPaint);
        _rrect(canvas, w * 0.30, h * 0.32, w * 0.40, h * 0.12, 3, inkPaint);
        _rrect(canvas, w * 0.30, h * 0.50, w * 0.40, h * 0.12, 3, bodyDarkPaint);
        _rrect(canvas, w * 0.30, h * 0.68, w * 0.24, h * 0.08, 3, bodyMidPaint);
        canvas.drawCircle(Offset(w * 0.64, h * 0.72), w * 0.05, accentPaint);
        canvas.drawCircle(Offset(w * 0.64, h * 0.38), w * 0.03, orangePaint);
        // هوائي علوي
        canvas.drawLine(
          Offset(w * 0.5, h * 0.22),
          Offset(w * 0.5, h * 0.10),
          Paint()
            ..color = _ink
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(Offset(w * 0.5, h * 0.10), w * 0.055, orangePaint);
        break;

      case AdminIllustrationKind.numDictionary:
        // كتاب معجم مفتوح مع شريط مرجعي
        _rrect(canvas, w * 0.16, h * 0.22, w * 0.68, h * 0.58, 7, inkPaint);
        _rrect(canvas, w * 0.20, h * 0.25, w * 0.28, h * 0.50, 4, bodyPaint);
        _rrect(canvas, w * 0.52, h * 0.25, w * 0.28, h * 0.50, 4, whitePaint);
        // أسطر نص داخل الكتاب
        _rrect(canvas, w * 0.24, h * 0.34, w * 0.19, h * 0.05, 2, bodyDarkPaint);
        _rrect(canvas, w * 0.24, h * 0.44, w * 0.16, h * 0.05, 2, bodyDarkPaint);
        _rrect(canvas, w * 0.56, h * 0.34, w * 0.19, h * 0.05, 2, bodyMidPaint);
        _rrect(canvas, w * 0.56, h * 0.44, w * 0.15, h * 0.05, 2, bodyMidPaint);
        // شريط مرجعي برتقالي
        _rrect(canvas, w * 0.64, h * 0.18, w * 0.10, h * 0.22, 2, orangePaint);
        break;

      case AdminIllustrationKind.numApps:
        // هاتف يعرض شبكة تطبيقات
        _rrect(canvas, w * 0.26, h * 0.14, w * 0.48, h * 0.74, 9, inkPaint);
        _rrect(canvas, w * 0.30, h * 0.21, w * 0.40, h * 0.56, 5, bodyPaint);
        _rrect(canvas, w * 0.34, h * 0.26, w * 0.14, h * 0.14, 4, accentPaint);
        _rrect(canvas, w * 0.52, h * 0.26, w * 0.14, h * 0.14, 4, orangePaint);
        _rrect(canvas, w * 0.34, h * 0.44, w * 0.14, h * 0.14, 4, bodyDarkPaint);
        _rrect(canvas, w * 0.52, h * 0.44, w * 0.14, h * 0.14, 4, inkPaint);
        canvas.drawCircle(Offset(w * 0.5, h * 0.82), w * 0.035, bodyMidPaint);
        break;

      case AdminIllustrationKind.numQuality:
        // شاشة قياس جودة ونبض
        _rrect(canvas, w * 0.16, h * 0.22, w * 0.68, h * 0.54, 9, bodyPaint);
        _rrect(canvas, w * 0.22, h * 0.28, w * 0.56, h * 0.42, 6, inkPaint);
        final pulse = Path()
          ..moveTo(w * 0.26, h * 0.50)
          ..lineTo(w * 0.37, h * 0.50)
          ..lineTo(w * 0.44, h * 0.36)
          ..lineTo(w * 0.52, h * 0.61)
          ..lineTo(w * 0.59, h * 0.44)
          ..lineTo(w * 0.64, h * 0.50)
          ..lineTo(w * 0.74, h * 0.50);
        canvas.drawPath(
          pulse,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawCircle(Offset(w * 0.70, h * 0.34), w * 0.045, orangePaint);
        break;

      case AdminIllustrationKind.numManual:
        // درع ضمان مع علامة صح
        final shield = Path()
          ..moveTo(w * 0.50, h * 0.14)
          ..lineTo(w * 0.78, h * 0.24)
          ..lineTo(w * 0.74, h * 0.56)
          ..quadraticBezierTo(w * 0.66, h * 0.76, w * 0.50, h * 0.86)
          ..quadraticBezierTo(w * 0.34, h * 0.76, w * 0.26, h * 0.56)
          ..lineTo(w * 0.22, h * 0.24)
          ..close();
        canvas.drawPath(shield, bodyPaint);
        final innerShield = Path()
          ..moveTo(w * 0.50, h * 0.21)
          ..lineTo(w * 0.71, h * 0.29)
          ..lineTo(w * 0.68, h * 0.54)
          ..quadraticBezierTo(w * 0.62, h * 0.70, w * 0.50, h * 0.78)
          ..quadraticBezierTo(w * 0.38, h * 0.70, w * 0.32, h * 0.54)
          ..lineTo(w * 0.29, h * 0.29)
          ..close();
        canvas.drawPath(innerShield, inkPaint);
        final check = Path()
          ..moveTo(w * 0.39, h * 0.49)
          ..lineTo(w * 0.47, h * 0.57)
          ..lineTo(w * 0.62, h * 0.40);
        canvas.drawPath(
          check,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        break;

      case AdminIllustrationKind.numLogs:
        // شريحة SIM مع رقاقة ذهبية
        final sim = Path()
          ..moveTo(w * 0.26, h * 0.18)
          ..lineTo(w * 0.62, h * 0.18)
          ..lineTo(w * 0.74, h * 0.30)
          ..lineTo(w * 0.74, h * 0.82)
          ..lineTo(w * 0.26, h * 0.82)
          ..close();
        canvas.drawPath(sim, bodyPaint);
        _rrect(canvas, w * 0.35, h * 0.44, w * 0.30, h * 0.26, 5, orangePaint);
        canvas.drawLine(
          Offset(w * 0.35, h * 0.57),
          Offset(w * 0.65, h * 0.57),
          Paint()
            ..color = _ink
            ..strokeWidth = 1.6,
        );
        canvas.drawLine(
          Offset(w * 0.50, h * 0.44),
          Offset(w * 0.50, h * 0.70),
          Paint()
            ..color = _ink
            ..strokeWidth = 1.6,
        );
        canvas.drawCircle(Offset(w * 0.40, h * 0.29), w * 0.04, inkPaint);
        break;

      case AdminIllustrationKind.storeProviders:
        // عقدة مزودين متصلة وشرارة
        final lineP = Paint()
          ..color = _bodyDark
          ..strokeWidth = 2.4;
        canvas.drawLine(Offset(w * 0.50, h * 0.50), Offset(w * 0.24, h * 0.28), lineP);
        canvas.drawLine(Offset(w * 0.50, h * 0.50), Offset(w * 0.76, h * 0.28), lineP);
        canvas.drawLine(Offset(w * 0.50, h * 0.50), Offset(w * 0.26, h * 0.74), lineP);
        canvas.drawLine(Offset(w * 0.50, h * 0.50), Offset(w * 0.74, h * 0.74), lineP);
        canvas.drawCircle(Offset(w * 0.24, h * 0.28), w * 0.09, bodyPaint);
        canvas.drawCircle(Offset(w * 0.76, h * 0.28), w * 0.09, orangePaint);
        canvas.drawCircle(Offset(w * 0.26, h * 0.74), w * 0.09, bodyMidPaint);
        canvas.drawCircle(Offset(w * 0.74, h * 0.74), w * 0.09, bodyPaint);
        canvas.drawCircle(Offset(w * 0.50, h * 0.50), w * 0.16, inkPaint);
        canvas.drawCircle(Offset(w * 0.50, h * 0.50), w * 0.07, accentPaint);
        break;

      case AdminIllustrationKind.storeApps:
        // 4 مكعبات منتجات وتطبيقات
        _rrect(canvas, w * 0.20, h * 0.20, w * 0.27, h * 0.27, 7, inkPaint);
        _rrect(canvas, w * 0.53, h * 0.20, w * 0.27, h * 0.27, 7, accentPaint);
        _rrect(canvas, w * 0.20, h * 0.53, w * 0.27, h * 0.27, 7, bodyPaint);
        _rrect(canvas, w * 0.53, h * 0.53, w * 0.27, h * 0.27, 7, orangePaint);
        canvas.drawCircle(Offset(w * 0.335, h * 0.335), w * 0.05, whitePaint);
        break;

      case AdminIllustrationKind.orders:
        // لوح مراجعة الطلبات مع قائمة وختم
        _rrect(canvas, w * 0.23, h * 0.22, w * 0.54, h * 0.62, 8, bodyPaint);
        _rrect(canvas, w * 0.38, h * 0.15, w * 0.24, h * 0.11, 4, inkPaint);
        _rrect(canvas, w * 0.31, h * 0.38, w * 0.38, h * 0.06, 3, bodyDarkPaint);
        _rrect(canvas, w * 0.31, h * 0.50, w * 0.28, h * 0.06, 3, bodyDarkPaint);
        _rrect(canvas, w * 0.31, h * 0.62, w * 0.34, h * 0.06, 3, bodyMidPaint);
        canvas.drawCircle(Offset(w * 0.69, h * 0.68), w * 0.13, accentPaint);
        final tick = Path()
          ..moveTo(w * 0.63, h * 0.68)
          ..lineTo(w * 0.68, h * 0.73)
          ..lineTo(w * 0.75, h * 0.63);
        canvas.drawPath(
          tick,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
        break;

      case AdminIllustrationKind.paymentAccounts:
        // محفظة وبطاقة دفع مع عملة
        _rrect(canvas, w * 0.18, h * 0.28, w * 0.64, h * 0.48, 9, inkPaint);
        _rrect(canvas, w * 0.24, h * 0.22, w * 0.44, h * 0.14, 5, bodyPaint);
        _rrect(canvas, w * 0.58, h * 0.44, w * 0.26, h * 0.16, 6, accentPaint);
        canvas.drawCircle(Offset(w * 0.66, h * 0.52), w * 0.04, whitePaint);
        canvas.drawCircle(Offset(w * 0.34, h * 0.54), w * 0.09, orangePaint);
        break;

      case AdminIllustrationKind.shippingCodes:
        // قسيمة شحن مثقبة مع خطوط باركود
        _rrect(canvas, w * 0.15, h * 0.30, w * 0.70, h * 0.42, 8, bodyPaint);
        _rrect(canvas, w * 0.62, h * 0.30, w * 0.23, h * 0.42, 8, orangePaint);
        // ثقبا التذكرة
        final bg = Paint()..color = const Color(0xFFF4F6F9);
        canvas.drawCircle(Offset(w * 0.62, h * 0.30), w * 0.05, bg);
        canvas.drawCircle(Offset(w * 0.62, h * 0.72), w * 0.05, bg);
        // خطوط الكود
        _rrect(canvas, w * 0.22, h * 0.42, w * 0.05, h * 0.18, 2, inkPaint);
        _rrect(canvas, w * 0.30, h * 0.42, w * 0.08, h * 0.18, 2, inkPaint);
        _rrect(canvas, w * 0.41, h * 0.42, w * 0.04, h * 0.18, 2, inkPaint);
        _rrect(canvas, w * 0.48, h * 0.42, w * 0.07, h * 0.18, 2, bodyDarkPaint);
        break;

      case AdminIllustrationKind.templates:
        // وثيقة قالب خدمة مع حقول إدخال
        _rrect(canvas, w * 0.23, h * 0.17, w * 0.54, h * 0.66, 8, bodyPaint);
        _rrect(canvas, w * 0.31, h * 0.27, w * 0.24, h * 0.07, 3, accentPaint);
        _rrect(canvas, w * 0.31, h * 0.40, w * 0.38, h * 0.11, 4, whitePaint);
        _rrect(canvas, w * 0.31, h * 0.56, w * 0.38, h * 0.11, 4, whitePaint);
        _rrect(canvas, w * 0.56, h * 0.71, w * 0.13, h * 0.06, 3, inkPaint);
        break;

      case AdminIllustrationKind.banners:
        // لوحة إعلانات مع شريط تمييز
        _rrect(canvas, w * 0.15, h * 0.24, w * 0.70, h * 0.48, 9, inkPaint);
        _rrect(canvas, w * 0.20, h * 0.29, w * 0.60, h * 0.38, 6, bodyPaint);
        _rrect(canvas, w * 0.26, h * 0.36, w * 0.34, h * 0.09, 3, orangePaint);
        _rrect(canvas, w * 0.26, h * 0.50, w * 0.46, h * 0.06, 3, bodyDarkPaint);
        // نقاط التصفح
        canvas.drawCircle(Offset(w * 0.43, h * 0.79), w * 0.035, orangePaint);
        canvas.drawCircle(Offset(w * 0.52, h * 0.79), w * 0.028, bodyDarkPaint);
        canvas.drawCircle(Offset(w * 0.60, h * 0.79), w * 0.028, bodyDarkPaint);
        break;

      case AdminIllustrationKind.users:
        // شخصيتان مبسطتان بأسلوب رسومي حديث
        canvas.drawCircle(Offset(w * 0.62, h * 0.35), w * 0.11, bodyDarkPaint);
        _rrect(canvas, w * 0.48, h * 0.50, w * 0.30, h * 0.26, 12, bodyPaint);
        canvas.drawCircle(Offset(w * 0.38, h * 0.36), w * 0.13, inkPaint);
        _rrect(canvas, w * 0.19, h * 0.53, w * 0.38, h * 0.27, 13, accentPaint);
        canvas.drawCircle(Offset(w * 0.74, h * 0.30), w * 0.05, orangePaint);
        break;

      case AdminIllustrationKind.manualServices:
        // سماعة دعم ومشرف خدمات يدوية
        final arcRect = Rect.fromLTWH(w * 0.24, h * 0.22, w * 0.52, h * 0.50);
        canvas.drawArc(
          arcRect,
          3.14,
          3.14,
          false,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.2
            ..strokeCap = StrokeCap.round,
        );
        _rrect(canvas, w * 0.18, h * 0.44, w * 0.14, h * 0.24, 6, accentPaint);
        _rrect(canvas, w * 0.68, h * 0.44, w * 0.14, h * 0.24, 6, bodyPaint);
        _rrect(canvas, w * 0.44, h * 0.72, w * 0.20, h * 0.08, 4, orangePaint);
        break;
    }
  }

  void _rrect(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    double r,
    Paint paint,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.accent != accent;
}
