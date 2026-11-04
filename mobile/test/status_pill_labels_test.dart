// شارات حالة الطلب: لا تبقى حالة إنجليزية في «طلباتي» ولا في شاشات الإدارة.
// الحالة تمر إلى StatusPill بلا label كما يفعل التاريخ والتفاصيل ومشرف الطلبات،
// فالتسمية العربية يجب أن تكون داخل الشارة نفسها.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/widgets/status_pill.dart';

Widget _pills(List<Widget> children) => MaterialApp(
  home: Scaffold(
    body: Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(spacing: 4, runSpacing: 4, children: children),
    ),
  ),
);

void main() {
  testWidgets('كل حالة طلب لها وصف عربي والمرجوعة «مسترد»', (
    WidgetTester w,
  ) async {
    const Map<String, String> labels = <String, String>{
      'pending': 'قيد الانتظار',
      'assigned': 'تم الإسناد',
      'accepted': 'تم القبول',
      'in_progress': 'قيد التنفيذ',
      'info_requested': 'بانتظار بياناتك',
      'delivered': 'تم التسليم',
      'revision_requested': 'طلب تعديل',
      'disputed': 'اعتراض',
      'completed': 'مكتمل',
      'rejected': 'مرفوض',
      'refunded': 'مسترد',
      'cancelled': 'ملغى',
      'failed': 'فشل',
      'closed': 'مغلق',
      'expired': 'انتهت المهلة',
    };

    await w.pumpWidget(
      _pills(<Widget>[
        for (final String status in labels.keys) StatusPill(status: status),
      ]),
    );

    for (final MapEntry<String, String> entry in labels.entries) {
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: 'حالة ${entry.key} يجب أن تُعرّب',
      );
    }
    // ولا حالة بقيت نصّها الخام كما يرسله الخادم
    for (final String status in labels.keys) {
      expect(find.text(status), findsNothing);
    }
  });

  testWidgets('الشارة لا تفرّق بين أحرف الحالة المسترجعة', (
    WidgetTester w,
  ) async {
    await w.pumpWidget(
      _pills(<Widget>[
        const StatusPill(status: 'refunded'),
        const StatusPill(status: 'REFUNDED'),
      ]),
    );

    expect(find.text('مسترد'), findsNWidgets(2));
  });

  testWidgets('التسمية الممرّرة أولى من الوصف الافتراضي', (
    WidgetTester w,
  ) async {
    await w.pumpWidget(
      _pills(<Widget>[
        const StatusPill(status: 'refunded', label: 'تم إرجاع المبلغ'),
      ]),
    );

    expect(find.text('تم إرجاع المبلغ'), findsOneWidget);
    expect(find.text('مسترد'), findsNothing);
  });
}
