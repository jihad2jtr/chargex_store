import 'package:flutter/material.dart';

/// غلاف طيّ/فرد لتذاكر الأدمن: يعرض رأس التذكرة دائماً، ويفرد أسطرها
/// وأزرارها عند النقر. يُستعمل في سجل التفعيلات التلقائية وصفحة منتجات
/// الأرقام المضافة لئلا تطغى التفاصيل على الشاشة قبل أن يطلبها الأدمن
/// صراحة. تُبنى الحالة الداخلية لكل بطاقة على حدة، فتحفظ فتحها/طيّها عبر
/// إعادة البناء لأن أباؤها keyed بمكانها في ListView.
class CollapsibleTicket extends StatefulWidget {
  final Widget Function(BuildContext context, bool expanded) builder;

  const CollapsibleTicket({super.key, required this.builder});

  @override
  State<CollapsibleTicket> createState() => _CollapsibleTicketState();
}

class _CollapsibleTicketState extends State<CollapsibleTicket> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _open = !_open),
      child: widget.builder(context, _open),
    );
  }
}
