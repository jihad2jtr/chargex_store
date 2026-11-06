import 'package:flutter/material.dart';

import '../core/constants/app_icon_assets.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import 'digital_pass_card.dart';

/// كرت خدمة بأسلوب التذكرة: صورة تملأ أعلى التذكرة، وفوق خطّ الفتحتين شريط
/// الاسم المتدرّج وأسفله تبويب السعر، مع وسم نوع في الزاوية. التصميم واحد
/// لصفحة الأرقام الوهمية وصفحة الخدمات والاشتراكات، فلا يقرأ العميل نمطين
/// مختلفين لتذكرة واحدة.
class ServiceTicketCard extends StatelessWidget {
  /// الاسم العربي الذي يملأ تبويب الاسم
  final String name;

  /// السعر أو وصف ما يعرضه الكرت في تبويبه الأسفل
  final String priceText;

  /// وسم الزاوية (نوع الخدمة) ولونه
  final String tag;
  final Color tagColor;

  /// الرمز الخام كما يخزّنه الأدمن: مسار أصل أو رابط خارجي
  final String iconRaw;

  /// بذور البحث عن الأيقونة بالاسم حين لا يكون الرمز المخزّن كافياً
  final List<String> iconSeeds;

  /// بذرة الحرف الذي يملأ أرض التذكرة حين لا صورة ولا اسم
  final String letterSeed;

  /// سطر أجنبي خافت فوق الاسم (يُرسم لتيكست الاتجاه ltr)
  final String foreign;

  /// سطر مساعد تحت السطر الأجنبي: دول أو وصف
  final String metaText;

  /// خدمة تطلب بيانات سرية: قفل صغير في الزاوية المقابلة
  final bool sensitive;

  final VoidCallback onTap;

  const ServiceTicketCard({
    super.key,
    required this.name,
    required this.priceText,
    required this.tag,
    required this.tagColor,
    required this.onTap,
    this.iconRaw = '',
    this.iconSeeds = const <String>[],
    this.letterSeed = '',
    this.foreign = '',
    this.metaText = '',
    this.sensitive = false,
  });

  /// رمز التطبيق الذي يملأ الكرت: الرمز المخزّن ثم الأسماء العربي والإنجليزي
  /// ورمز الخدمة
  String? _findIconAsset() {
    final cleanIcon = iconRaw.trim();
    if (cleanIcon.isNotEmpty) {
      if (cleanIcon.startsWith('assets/')) return cleanIcon;
      final direct = builtinIconAssetExact(cleanIcon);
      if (direct != null) return direct;
      final byQuery = builtinIconAssetForQuery(cleanIcon);
      if (byQuery != null) return byQuery;
    }
    for (final seed in iconSeeds) {
      if (seed.trim().isEmpty) continue;
      final found = iconAssetForApp(iconUrl: cleanIcon, name: seed.trim());
      if (found != null) return found;
    }
    return null;
  }

  /// رابط صورة خارجي اختاره الأدمن بدل رمز مخزّن
  String? get _networkCover {
    final raw = iconRaw.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return null;
  }

  // غلاف التذكرة: فتحتان على الحافتين وحوافة 14، والصورة تملأ الكرت إلى خطّ
  // تبويبي الاسم والسعر لا إلى آخره
  static const double _radius = 14;
  static const double _notch = 6;

  // تبويبا الكرت: شريط اسم وشريط سعر أسفل التذكرة، والفتحتان على خطّهما
  static const double _stubHeight = 22;
  static const double _nameHeight = 20;
  static const double _tabsHeight = _stubHeight + _nameHeight;

  /// ارتفاع التبويبين تحت الفتحتين: تعده الشبكة لتبقى الكروت أطول من عرضها
  static const double tabsHeight = _tabsHeight;

  @override
  Widget build(BuildContext context) {
    final String? iconAsset = _findIconAsset();
    final String? networkCover = iconAsset == null ? _networkCover : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // الفتحتان تنزلان إلى خطّ القصّ فوق تبويبي الاسم والسعر، فتنقسم
        // التذكرة إلى صورةٍ أعلى وجنبٍ مقصوصٍ أسفل لا إلى كرتٍ بفتحةٍ في وسطه
        final double height = constraints.maxHeight;
        final double ceiling = (height - _radius - _notch) / height;
        final double upper = ceiling > 0.55 ? ceiling : 0.55;
        final double notchFraction = ((height - _tabsHeight) / height)
            .clamp(0.55, upper)
            .toDouble();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: CustomPaint(
            painter: TicketPassShadowPainter(
              cornerRadius: _radius,
              notchRadius: _notch,
              notchPositionFraction: notchFraction,
              // ظلّ بلون النوع: أخضر خلف المضمون وكهرماني خلف الآلي
              shadowColor: tagColor,
              elevation: 5,
            ),
            child: CustomPaint(
              foregroundPainter: TicketPassBorderPainter(
                cornerRadius: _radius,
                notchRadius: _notch,
                notchPositionFraction: notchFraction,
                borderColor: Colors.white.withValues(alpha: 0.75),
                borderWidth: 1,
              ),
              child: ClipPath(
                clipper: TicketPassClipper(
                  cornerRadius: _radius,
                  notchRadius: _notch,
                  notchPositionFraction: notchFraction,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // أرض التذكرة: تدرّج وحرف، كي لا تترك البطاقةُ بلا رمز
                    // بياضاً على حوافها، ولكي يبقى تحت تبويبي الاسم والسعر ما يسده
                    _letterBackdrop(),
                    // الصورة وقدرُها ما فوق التبويبين: حدُّها السفلي خطُّ الاسم
                    // نفسه، فلا اسمَ ولا سعرَ يُقرأ فوق جزء منها
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      end: 0,
                      bottom: _tabsHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (iconAsset != null)
                            Positioned.fill(
                              child: Image.asset(
                                iconAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            )
                          else if (networkCover != null)
                            Positioned.fill(
                              child: Image.network(
                                networkCover,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          // تعتيم أسفل الصورة: الأسطر الصغيرة تُقرأ فوق أي رمز
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [0.0, 0.4, 0.7, 0.86],
                                    colors: [
                                      Color(0x00000000),
                                      Color(0x0D000000),
                                      Color(0x66000000),
                                      Color(0xB3000000),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // أعلى الصورة للقفل والشارة، وأسفلها الأسطر الصغيرة
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(7, 20, 7, 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // الاسم الأجنبي والسطر المساعد يبقيان على
                                  // الصورة، أما الاسم والسعر فلكلٍّ تبويبه
                                  if (foreign.isNotEmpty)
                                    _subLine(foreign, ltr: true),
                                  if (metaText.isNotEmpty) _subLine(metaText),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // تبويب الاسم فوق تبويب السعر: شريطاهما الآن على أرض التذكرة
                    // لا على الصورة
                    PositionedDirectional(
                      bottom: _stubHeight,
                      start: 0,
                      end: 0,
                      child: _nameTab(),
                    ),
                    // تبويب السعر أسفل الكرت: السعر وحده، أكبر وأبين من قبل
                    PositionedDirectional(
                      bottom: 0,
                      start: 0,
                      end: 0,
                      child: _priceStub(),
                    ),
                    // وسم النوع في زاوية الكرت: هو وحده ما يفرّق نوع الخدمة
                    PositionedDirectional(top: 4, start: 4, child: _typeTag()),
                    if (sensitive)
                      // قفل صغير في الزاوية المقابلة: الخدمة تطلب بيانات سرية
                      PositionedDirectional(
                        top: 4,
                        end: 4,
                        child: _sensitiveLock(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// سطر مساعد فوق الاسم: الاسم الأجنبي أو التفاصيل، بخطّ خافت صغير
  Widget _subLine(String text, {bool ltr = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        textDirection: ltr ? TextDirection.ltr : null,
        style: AppTypography.cairo(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
          height: 1.15,
        ),
      ),
    );
  }

  /// تبويب الاسم: شريط متدرّج رأسي من أسفل الكرت إلى أعلاه، الاسمُ فيه وحده
  /// بخطّ أبيض بائن، فلا يقرأه أحد فوق صورة داكنة
  Widget _nameTab() {
    return Container(
      height: _nameHeight,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        // التدرّج من أسفل الكرت إلى أعلاه: سواد عند تبويب السعر يفتح شيئاً
        // فشيئاً نحو الصورة، فالتبويبان طبقة واحدة لا شريطان بنفس اللون
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, AppColors.slate700],
        ),
        border: Border(top: BorderSide(color: Colors.white38, width: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.cairo(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.15,
          ),
        ),
      ),
    );
  }

  /// شريط أسفل التذكرة: أرضية داكنة مصمتة وخطّ كبير بلون التطبيق المميز،
  /// فالسعر أول ما تقرأه العين ولا ينافسه سطرُ الوصف ولا الاسم
  Widget _priceStub() {
    return Container(
      height: _stubHeight,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.slate900,
        // نفس الخيط الأبيض الرفيع الذي فوق تبويب الاسم: خطّان متماثلان
        // يفصلان الصورة عن الاسم عن السعر
        border: Border(top: BorderSide(color: Colors.white38, width: 0.8)),
      ),
      child: Text(
        priceText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppTypography.cairo(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: AppColors.ticketAmber,
          height: 1.15,
        ),
      ),
    );
  }

  /// قفل على زاوية كرت الخدمة التي تطلب بيانات سرية
  Widget _sensitiveLock() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Icon(
        Icons.lock_outline_rounded,
        size: 9,
        color: AppColors.rose,
      ),
    );
  }

  /// وسم صغير أعلى الكرت: يفرّق نوع الخدمة بلون واحد مع الظلّ
  Widget _typeTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: tagColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag,
        maxLines: 1,
        style: AppTypography.cairo(
          fontSize: 7,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    );
  }

  /// خلفية التذكرة: تدرّج بحرف كبير من اسم الخدمة، تُمدّ فوقها الصورة عند وجودها
  Widget _letterBackdrop() {
    final letter = name.isNotEmpty
        ? name.substring(0, 1)
        : (letterSeed.isEmpty ? '#' : letterSeed.substring(0, 1).toUpperCase());
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF475569)],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: AppTypography.fintechBadge(color: Colors.white, fontSize: 30),
        ),
      ),
    );
  }
}
