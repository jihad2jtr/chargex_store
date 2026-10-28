// شاشة «إدارة المستخدمين»: عدّادات الرتب الخمسة تجتمع في بطاقة تذكرة واحدة،
// والقائمة تذكرة بصفوف تفصلها خطوط مثقّبة وكعب لكل صف يعرض الرصيد.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/screens/admin/users_management_screen.dart';
import 'package:layan_chargex/widgets/digital_pass_card.dart';

/// الشبكة معطّلة: أي استدعاء فعلي يفشل فوراً ويبقى الهيكل ظاهراً
class _BlockedHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _BlockingHttpClient();
}

class _BlockingHttpClient implements HttpClient {
  @override
  noSuchMethod(Invocation invocation) =>
      throw const SocketException('network is blocked in widget tests');
}

class _SeededAdmin extends AdminProvider {
  _SeededAdmin(this.users);

  final List<Map<String, dynamic>> users;

  @override
  List<Map<String, dynamic>> get allUsers => users;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchAllUsers({bool silent = false}) async {}

  @override
  Future<void> fetchTopupLog() async {}
}

Map<String, dynamic> _user({
  required String id,
  required String name,
  String role = 'user',
  double balance = 10,
  bool isActive = true,
}) {
  return <String, dynamic>{
    '_id': id,
    'userId': 'jgo$id',
    'name': name,
    'email': '$id@example.com',
    'phone': '0900000000',
    'role': role,
    'balance': balance,
    'isActive': isActive,
    'createdAt': '2026-10-01T08:00:00.000Z',
  };
}

/// يجمّع أخطاء التخطيط (أخطاء الخطوط متوقّعة مع حظر الشبكة فلا تهمّ هنا)
final List<Object> _collected = <Object>[];

void _drain(WidgetTester w) {
  for (;;) {
    final Object? error = w.takeException();
    if (error == null) break;
    _collected.add(error);
  }
}

Future<void> _settle(WidgetTester w) async {
  await w.pump();
  await w.pump(const Duration(milliseconds: 600));
  _drain(w);
}

Future<void> _pump(
  WidgetTester w, {
  required List<Map<String, dynamic>> users,
  double width = 400,
  double height = 900,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final admin = _SeededAdmin(users);

  w.view.physicalSize = Size(width, height);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    ChangeNotifierProvider<AdminProvider>(
      create: (_) => admin,
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const UsersManagementScreen(),
        ),
      ),
    ),
  );
  await _settle(w);
}

Finder get _ticketClips => find.byWidgetPredicate(
  (widget) => widget is ClipPath && widget.clipper is TicketPassClipper,
);

List<CustomPaint> _paintersWhere(
  WidgetTester w,
  bool Function(CustomPaint) test,
) => w.widgetList<CustomPaint>(find.byType(CustomPaint)).where(test).toList();

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  setUp(() => _collected.clear());

  final seeded = <Map<String, dynamic>>[
    _user(id: 'c1', name: 'عميل تجريبي', balance: 10),
    _user(id: 'a1', name: 'وكيل المبيعات', role: 'agent', balance: 40),
    _user(id: 's1', name: 'مشرف التنفيذ', role: 'supervisor', balance: 0),
    _user(id: 'ad1', name: 'أدمن النظام', role: 'admin', balance: 999),
  ];

  testWidgets('الرتب الخمس تجتمع في بطاقة تذكرة واحدة بلا بطاقات منفصلة', (
    w,
  ) async {
    await _pump(w, users: seeded, width: 560);

    expect(find.text('عدّادات الحسابات'), findsOneWidget);
    expect(find.text('USERS LEDGER · 4'), findsOneWidget);
    expect(find.text('الإجمالي'), findsOneWidget);
    expect(find.text('موقوفون'), findsOneWidget);

    // كل التسميات داخل نفس الغلاف المثقّب: تذكرة للعدّادات وتذكرة للقائمة
    final ClipPath ledger = w.widget<ClipPath>(_ticketClips.first);
    expect(ledger.clipper, isA<TicketPassClipper>());
    for (final String label in <String>[
      'الإجمالي',
      'وكلاء',
      'مشرفون',
      'عملاء',
      'موقوفون',
    ]) {
      expect(
        find.descendant(of: _ticketClips.first, matching: find.text(label)),
        findsOneWidget,
        reason: '$label يجب أن يكون داخل بطاقة العدّادات الواحدة',
      );
    }
    expect(_ticketClips, findsNWidgets(2));

    // لا عدّاد خارج التذكرة: الرقم المرجعي للإجمالي يتيم على خانته
    expect(find.text('4'), findsOneWidget);
    expect(
      _collected.where((e) => '$e'.contains('RenderFlex')),
      isEmpty,
      reason: _collected.map((e) => '$e').join('\n'),
    );
  });

  testWidgets('القائمة تذكرة: رأس هوية وكعب رصيد وخطوط مثقّبة بلا Divider', (
    w,
  ) async {
    await _pump(w, users: seeded, width: 560);

    expect(find.text('المستخدمون'), findsOneWidget);
    expect(find.text('USERS · 4'), findsOneWidget);
    expect(find.text('الرصيد'), findsNWidgets(4));
    expect(find.text(r'$10.00'), findsOneWidget);

    // كعب الرصيد داخل تذكرة واحدة، ولا خطوط صلبة بين الصفوف
    expect(
      find.descendant(of: _ticketClips.last, matching: find.byType(Divider)),
      findsNothing,
    );

    final tears = _paintersWhere(
      w,
      (p) => p.painter is VerticalDashedLinePainter,
    );
    // أربعة فواصل خانات في العدّادات + أربعة كعوب صفوف
    expect(tears.length, greaterThanOrEqualTo(8));

    final dashes = _paintersWhere(w, (p) => p.painter is DashedLinePainter);
    // رأس العدّادات + رأس القائمة + ثلاثة فواصل بين أربعة صفوف
    expect(dashes.length, greaterThanOrEqualTo(5));

    // النمط الجديد لا يبتلع اللمس: النقر على الصف يفتح نافذته
    await w.tap(find.text('عميل تجريبي'));
    await _settle(w);
    expect(find.text('ترقية إلى وكيل'), findsOneWidget);
  });

  testWidgets('صف ضيّق 320px: أسماء طويلة وأرصدة كبيرة بلا أي طفو', (w) async {
    await _pump(
      w,
      width: 320,
      height: 760,
      users: <Map<String, dynamic>>[
        _user(
          id: 'c1',
          name: 'عميل باسم طويل جداً للمراجعة الدقيقة',
          balance: 1234.56,
        ),
        _user(
          id: 'a1',
          name: 'وكيل المبيعات الإقليمي',
          role: 'agent',
          balance: 999999.99,
        ),
        _user(
          id: 's1',
          name: 'مشرف التنفيذ',
          role: 'supervisor',
          balance: -12.5,
          isActive: false,
        ),
      ],
    );

    expect(find.text('الإجمالي'), findsOneWidget);
    expect(find.text(r'$-12.50'), findsOneWidget);
    expect(
      _collected.where((e) => '$e'.contains('RenderFlex')),
      isEmpty,
      reason: _collected.map((e) => '$e').join('\n'),
    );
  });
}
