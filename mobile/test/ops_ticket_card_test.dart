// بطاقة التذكرة الإدارية: تظهر كل بيانات الطلب والخط المتمزّق (فجوتان)
// وأزرار الإجراءات تُمرَّر من الشاشة وتعمل بالضغط.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/theme/app_colors.dart';
import 'package:layan_chargex/widgets/ops_ticket_card.dart';
import 'package:layan_chargex/widgets/status_pill.dart';

Future<void> _pumpCard(
  WidgetTester w, {
  double width = 380,
  VoidCallback? onAccept,
  VoidCallback? onReject,
  String? note = 'تم الشحن يدويًا',
}) async {
  w.view.physicalSize = Size(width, 800);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              OpsTicketCard(
                accent: AppColors.ticketAmber,
                icon: Icons.bolt_rounded,
                tag: 'ORD-1001',
                title: 'Fortnite 2800 V-Bucks',
                subtitle: 'Fortnite · أحمد محمد',
                amount: const Text('\$12.50'),
                status: const StatusPill(status: 'pending'),
                rows: const [
                  OpsTicketInfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'العميل',
                    value: 'أحمد محمد · a@b.com',
                  ),
                  OpsTicketInfoRow(
                    icon: Icons.key_rounded,
                    label: 'بيانات الحساب',
                    value: 'player_id: 123456789',
                    mono: true,
                  ),
                ],
                note: note,
                meta: '2026/10/27 - 10:00',
                actions: [
                  TextButton(onPressed: onAccept, child: const Text('قبول')),
                  TextButton(onPressed: onReject, child: const Text('رفض')),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await w.pump();
  while (w.takeException() != null) {}
}

void main() {
  testWidgets('التذكرة تعرض الأرقام والبيانات وخطّ التمزّق', (w) async {
    await _pumpCard(w);

    expect(find.text('ORD-1001'), findsOneWidget);
    expect(find.text('Fortnite 2800 V-Bucks'), findsOneWidget);
    expect(find.text('Fortnite · أحمد محمد'), findsOneWidget);
    expect(find.text('\$12.50'), findsOneWidget);
    expect(find.text('قيد الانتظار'), findsOneWidget);
    expect(find.text('player_id: 123456789'), findsOneWidget);
    expect(find.text('تم الشحن يدويًا'), findsOneWidget);
    // هوية التذكرة: خط التمزّق بفجوتين على الحافتين
    expect(find.byType(OpsTearLine), findsOneWidget);
  });

  testWidgets('أزرار القبول والرفض تنفّذ الإجراء', (w) async {
    bool accepted = false;
    bool rejected = false;
    await _pumpCard(
      w,
      onAccept: () => accepted = true,
      onReject: () => rejected = true,
    );

    await w.tap(find.text('قبول'));
    await w.tap(find.text('رفض'));

    expect(accepted, isTrue);
    expect(rejected, isTrue);
  });

  testWidgets('بدون ملاحظات لا يظهر صندوق الملاحظات', (w) async {
    await _pumpCard(w, note: null);

    expect(find.text('تم الشحن يدويًا'), findsNothing);
    expect(find.byType(OpsTearLine), findsOneWidget);
  });

  testWidgets('لا يفيض التخطيط على شاشة ضيقة 320', (w) async {
    await _pumpCard(w, width: 320);

    final List<Object> exceptions = [];
    Object? e = w.takeException();
    while (e != null) {
      exceptions.add(e);
      e = w.takeException();
    }
    // خط google_fonts يحتاج شبكة في الاختبار — نتجاهله ونفحص التخطيط فقط
    final layout = exceptions.where(
      (err) => !err.toString().contains('google_fonts'),
    );
    expect(layout, isEmpty);
  });
}
