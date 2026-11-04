import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// تنبيه التطبيق: خبرٌ عابر يظهر في أعلى الشاشة ثم ينصرف
///
/// كان كل خبر يصل المستخدم شريطاً أسفل الشاشة (SnackBar)، وهو موضع لا يقرأه
/// أحد أثناء الكتابة ولا يشبه وصول الإشعار. هنا يُعرض الخبر MaterialBanner في
/// أعلى الـ Scaffold — المكان الذي اعتاد المستخدم أن يرفع عينيه إليه — بنفس الأرضية
/// الملونة والرمز اللذين كان عليهما الشريط، ويطفو على المحتوى ولا يدفعه.
///
/// وجهان لخدمةٍ واحدة: [TopNotice.show] لمن يكتب خبره من الصفر عنواناً ومتناً،
/// و[TopSnackBarMessenger] لما بقي مكتوباً على عهدة ScaffoldMessenger؛ وهذا الأخير
/// هو الباب الواسع فالرسائل في الشاشات تزيد على المئة، وإعادة كتابتها واحداً
/// واحداً يُضيع ما فيها من صيغٍ وألوانٍ وأفعال.
class TopNotice {
  TopNotice._();

  /// يعرض [title] (وأخته [body] إن كانت) أعلى الشاشة على أرضية [tone] ورمز
  /// [icon]، وينصرف بعد [hold]. و[onAction] إن كان للخبر فعلٌ واحد كـ«عرض».
  static void show(
    BuildContext context, {
    required String title,
    String body = '',
    Color tone = AppColors.slate800,
    IconData icon = Icons.notifications_active_rounded,
    Color iconColor = Colors.white,
    Duration hold = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    // الإغلاق: فعلُ الخبر إن كان له فعل، وشفرةُ تنحيةٍ لا غير
    Widget closeOrAction(void Function() dismiss) {
      if (actionLabel == null) {
        return IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          tooltip: 'إغلاق',
          onPressed: dismiss,
        );
      }
      return TextButton(
        onPressed: () {
          dismiss();
          onAction?.call();
        },
        child: Text(
          actionLabel,
          style: AppTypography.cairo(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: iconColor,
          ),
        ),
      );
    }

    final Widget content = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTypography.cairo(
                    fontSize: 11.5,
                    color: Colors.white70,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    _TopBanner.present(
      ScaffoldMessenger.of(context),
      tone: tone,
      hold: hold,
      content: content,
      action: closeOrAction,
    );
  }
}

/// كل شريطٍ كتبته الشاشات في أسفلها يصعد إلى أعلاها
///
/// التبديلُ في اسم النداء وحده: `showSnackBar(bar)` تُستبدل
/// بـ`showTopSnackBar(bar)`، والنصُّ والأرضيةُ والفعلُ والمهلةُ كلّها تُقرأ من
/// الشريط نفسه فلا تُعاد صياغته.
extension TopSnackBarMessenger on ScaffoldMessengerState {
  /// يعرض [snackBar] في أعلى الشاشة بأرضيته وفعلِه ومدّته
  ///
  /// أما أشكالُ الشريط (behavior وmargin وshape) فلا تُنقل: الخبر أعلى
  /// الشاشة شريطٌ عرضه كامل، فلا تختلّ مواءمةُ التنبيهات بعضها ببعض.
  void showTopSnackBar(SnackBar snackBar) {
    final Color tone = snackBar.backgroundColor ?? AppColors.slate800;
    // أرضيةٌ داكنة تحتاج نصاً فاتحاً وفاتحةٌ عكسَها، وإلا ضاع الخبر عن القارئ
    final Color ink = tone.computeLuminance() < 0.5
        ? Colors.white
        : AppColors.slate900;

    Widget action(void Function() dismiss) {
      final SnackBarAction? act = snackBar.action;
      // MaterialBanner لا يقبل أفعالاً فارغة، فما لا فعلَ له يُنحّى بزرّ
      if (act == null) {
        return IconButton(
          icon: Icon(Icons.close_rounded, color: ink.withValues(alpha: 0.7)),
          tooltip: 'إغلاق',
          onPressed: dismiss,
        );
      }
      return TextButton(
        onPressed: () {
          dismiss();
          act.onPressed();
        },
        child: Text(
          act.label,
          style: AppTypography.cairo(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: act.textColor ?? ink,
          ),
        ),
      );
    }

    _TopBanner.present(
      this,
      tone: tone,
      // وبرسالةٍ تُستدام (persist) لا مهلةَ لها: تنتظر صاحبها حتى يقرأها
      hold: snackBar.persist ? null : snackBar.duration,
      contentTextStyle: AppTypography.cairo(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      content: snackBar.content,
      action: action,
      onVisible: snackBar.onVisible,
    );
  }
}

/// التنبيه الذي على الشاشة: عرضٌ في الأعلى لا يزدوج ولا يُغلق مرّتين
class _TopBanner {
  _TopBanner._();

  static void present(
    ScaffoldMessengerState messenger, {
    required Color tone,
    required Widget content,
    required Widget Function(void Function() dismiss) action,
    TextStyle? contentTextStyle,
    Duration? hold,
    VoidCallback? onVisible,
  }) {
    // التنبيهات لا تصطفّ انتظاراً: الذي يصل يحلُّ محلَّ سابقه في الحال
    messenger.clearMaterialBanners();

    late ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>
    controller;
    // التنبيه ينحى بمهلته أو بفعل صاحبه أو بخبرٍ بعده أو بزوال الشاشة، فلا يُغلق
    // مرّتين: إغلاقٌ والطابورُ فارغٌ يرمي Bad state
    bool gone = false;
    void dismiss() {
      if (gone) return;
      gone = true;
      controller.close();
    }

    controller = messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: tone,
        // رفعٌ عن السطح فالخبر يطفو على المحتوى ولا يزحزحه عن مكانه
        elevation: 6,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        contentTextStyle: contentTextStyle,
        // المهلةُ تسكن شجرةَ التنبيه نفسها، فتُلغى معه إذا رُفع من الشاشة
        content: hold == null
            ? content
            : _AutoDismiss(hold: hold, onExpire: dismiss, child: content),
        actions: [action(dismiss)],
        onVisible: onVisible,
      ),
    );

    // وإن أُغلق من خارجنا — بخبرٍ بعده أو بزوال الشاشة — فلا مؤقّتَ بعده يُنحى
    controller.closed.whenComplete(() => gone = true);
  }
}

/// مهلةٌ تسكن التنبيه: تنحّيه في أوانه، وتُبطل بإبطاله
///
/// المهلةُ التي تعيش خارج الشجرة تبقى تعمل بعد أن تُهدَم الشاشة في نهاية
/// الاختبار، فيسقط الاختبار بمؤقّتٍ لم ينقضِ.
class _AutoDismiss extends StatefulWidget {
  const _AutoDismiss({
    required this.hold,
    required this.onExpire,
    required this.child,
  });

  final Duration hold;
  final VoidCallback onExpire;
  final Widget child;

  @override
  State<_AutoDismiss> createState() => _AutoDismissState();
}

class _AutoDismissState extends State<_AutoDismiss> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.hold, widget.onExpire);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
