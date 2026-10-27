// لوحة الوكيل: هيكل مضغوط — شريط هوية بدل الكرت العلوي، «ملخص العمليات» جدول
// صغير بهوية تذكرة، وسجل تحويلات ثنائي الاتجاه (وارد من الإدارة + صادر للعملاء).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/models/agent_user_model.dart';
import 'package:layan_chargex/models/user_model.dart';
import 'package:layan_chargex/providers/agent_provider.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/screens/agent/agent_dashboard_screen.dart';
import 'package:layan_chargex/widgets/digital_pass_card.dart';
import 'package:provider/provider.dart';

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

class _FakeAuth extends AuthProvider {
  _FakeAuth()
    : _user = UserModel(
        id: 'u-agent',
        userId: 'JGO123',
        name: 'وكيل الاختبار',
        email: 'agent@jgo.store',
        role: 'agent',
        balance: 120.0,
      );

  final UserModel _user;

  @override
  UserModel? get currentUser => _user;
}

/// مزوّد محلي بلا شبكة: بيانات ثابتة وسجل تحويلات من الاتجاهين
class _FakeAgent extends AgentProvider {
  _FakeAgent({
    List<AgentTransferRecord> records = const [],
    List<AgentUserModel> users = const [],
  }) : _records = records,
       _users = users;

  final List<AgentTransferRecord> _records;
  final List<AgentUserModel> _users;

  @override
  List<AgentTransferRecord> get transfers => _records;

  @override
  List<AgentUserModel> get subUsers => _users;

  @override
  AgentDashboardStats get stats => AgentDashboardStats(
    totalSubUsers: 4,
    activeSubUsers: 3,
    suspendedSubUsers: 1,
    totalTransferred: 60.0,
    transferCount: 1,
    agentBalance: 120.0,
    totalReceived: 200.0,
    receivedCount: 1,
  );

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> refreshAll({bool silent = false}) async {}
}

AgentTransferRecord _incomingRecord() => AgentTransferRecord(
  id: 't-in',
  amount: 200.0,
  createdAt: DateTime(2026, 10, 25, 10, 30),
  recipientName: 'الإدارة',
  recipientUserId: '',
  recipientEmail: '',
  description: 'شحن رصيد من الإدارة',
  isIncoming: true,
);

AgentTransferRecord _outgoingRecord() => AgentTransferRecord(
  id: 't-out',
  amount: 60.0,
  note: 'دفعة أولى',
  createdAt: DateTime(2026, 10, 24, 9, 5),
  recipientName: 'أحمد سيد',
  recipientUserId: 'JGO999',
  recipientEmail: 'ahmed@jgo.store',
  isIncoming: false,
);

AgentUserModel _activeClient() => AgentUserModel(
  id: 'c1',
  userId: 'JGO555',
  name: 'محمود حسن',
  email: 'mahmoud@jgo.store',
  phone: '0999888777',
  balance: 85.5,
  isActive: true,
);

AgentUserModel _suspendedClient() => AgentUserModel(
  id: 'c2',
  userId: 'JGO777',
  name: 'سامي علي',
  email: 'sami@jgo.store',
  balance: 0.0,
  isActive: false,
  deactivatedByAgent: true,
  agentDeactivationReason: 'رصيد مدين',
);

/// يصرّف أخطاء تحميل الخطوط (متوقّعة مع حظر الشبكة) ويجمّعها لفحص الطفو
final List<Object> _collected = <Object>[];

void _drain(WidgetTester w) {
  for (;;) {
    final Object? error = w.takeException();
    if (error == null) break;
    _collected.add(error);
  }
}

Future<void> _settle(WidgetTester w, {int ms = 400}) async {
  await w.pump();
  await w.pump(Duration(milliseconds: ms));
  await w.pump(Duration(milliseconds: ms));
  _drain(w);
}

/// يفرّغ الشجرة كي يُلغي منصّة الوكيل مؤقّت التحديث الدوري
Future<void> _dispose(WidgetTester w) async {
  await w.pumpWidget(const SizedBox.shrink());
  _drain(w);
}

Future<void> _pumpScreen(
  WidgetTester w, {
  double width = 420,
  List<AgentUserModel> users = const [],
}) async {
  w.view.physicalSize = Size(width, 900);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  final agent = _FakeAgent(
    records: [_incomingRecord(), _outgoingRecord()],
    users: users,
  );

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
        ChangeNotifierProvider<AgentProvider>.value(value: agent),
      ],
      child: MaterialApp(
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: AgentDashboardScreen(),
        ),
      ),
    ),
  );
  await _settle(w);
}

Finder _ticketShadows() => find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint && widget.painter is TicketPassShadowPainter,
);

/// قائمة إجراءات العميل وحدها (الرأس فيه PopupMenuButton بنفس النوع)
Finder _clientMenus() => find.byWidgetPredicate(
  (widget) =>
      widget is PopupMenuButton<String> && widget.tooltip == 'إجراءات العميل',
);

/// الدرع العائم فيه نبض متكرّر، لذا نستخدم نبضات محدّدة بدل pumpAndSettle
Future<void> _openTransfersTab(WidgetTester w) async {
  await w.tap(find.textContaining('التحويلات ('));
  await w.pump();
  await w.pump(const Duration(milliseconds: 450));
  await w.pump(const Duration(milliseconds: 450));
  _drain(w);
}

/// رقائق الاتجاه تمرير أفقي، فنُقرّب الرقاقة قبل لمسها
Future<void> _tapTransferChip(WidgetTester w, String label) async {
  final finder = find.text(label);
  await w.ensureVisible(finder);
  await w.pump();
  await w.tap(finder);
  await _settle(w, ms: 250);
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  setUp(() {
    _collected.clear();
  });

  testWidgets('الكرت العلوي أُزيل وحلّ محله شريط هوية مضغوط', (w) async {
    await _pumpScreen(w);

    // شريط الهوية: الاسم (في الهيدر أيضاً) + شارة الاعتماد + آيدي التذكرة
    expect(find.text('وكيل الاختبار'), findsNWidgets(2));
    expect(find.text('وكيل معتمد'), findsOneWidget);
    expect(find.text('TKT #JGO123'), findsOneWidget);
    expect(find.text('agent@jgo.store'), findsOneWidget);

    // الكرت الداكن القديم كان يحمل زر خروج — ذهب، والخروج بقي في قائمة الهيدر
    expect(find.byIcon(Icons.logout_rounded), findsNothing);
    // الرصيد يظهر في الهيدر وفي خلية «رصيد الوكيل» فقط
    expect(find.text('\$120.00'), findsNWidgets(2));

    await _dispose(w);
  });

  testWidgets('ملخص العمليات جدول تذكرة صغير يحمل القيم الست', (w) async {
    await _pumpScreen(w);

    expect(find.text('ملخص العمليات'), findsOneWidget);
    expect(find.text('OPS SUMMARY'), findsOneWidget);

    for (final label in [
      'رصيد الوكيل',
      'مستلم من الإدارة',
      'محوّل للعملاء',
      'العملاء',
      'نشط',
      'موقوف',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'خلية «$label»');
    }

    expect(find.text('\$120.00'), findsNWidgets(2)); // الهيدر + خلية الرصيد
    expect(find.text('\$200.00'), findsOneWidget);
    expect(find.text('\$60.00'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // تذكرة واحدة فوق التبويبات: الجدول — وارتفاعها مضغوط
    expect(_ticketShadows(), findsOneWidget);
    expect(w.getSize(_ticketShadows()).height, lessThan(170));

    await _dispose(w);
  });

  testWidgets('سجل التحويلات يعرض الوارد من الإدارة والصادر للعملاء', (
    w,
  ) async {
    await _pumpScreen(w);
    await _openTransfersTab(w);

    // الوارد من الإدارة
    expect(find.text('+\$200.00'), findsOneWidget);
    expect(find.text('IN // إدارة'), findsOneWidget);
    expect(find.text('من الإدارة'), findsOneWidget);

    // الصادر إلى عميل
    expect(find.text('-\$60.00'), findsOneWidget);
    expect(find.text('OUT // عميل'), findsOneWidget);
    expect(find.text('أحمد سيد'), findsOneWidget);
    expect(find.text('JGO999'), findsOneWidget);
    expect(find.text('ملاحظة: دفعة أولى'), findsOneWidget);

    // رقائق الاتجاه مع أعدادها
    expect(find.text('الكل (2)'), findsOneWidget);
    expect(find.text('من الإدارة (1)'), findsOneWidget);
    expect(find.text('إلى العملاء (1)'), findsOneWidget);

    await _dispose(w);
  });

  testWidgets('رقائق الاتجاه تصفّي السجل', (w) async {
    await _pumpScreen(w);
    await _openTransfersTab(w);

    await _tapTransferChip(w, 'من الإدارة (1)');
    expect(find.text('IN // إدارة'), findsOneWidget);
    expect(find.text('OUT // عميل'), findsNothing);

    await _tapTransferChip(w, 'إلى العملاء (1)');
    expect(find.text('OUT // عميل'), findsOneWidget);
    expect(find.text('IN // إدارة'), findsNothing);

    await _tapTransferChip(w, 'الكل (2)');
    expect(find.text('IN // إدارة'), findsOneWidget);
    expect(find.text('OUT // عميل'), findsOneWidget);

    await _dispose(w);
  });

  testWidgets('قائمة العملاء تُعرض كتذاكر صغيرة مضغوطة', (w) async {
    await _pumpScreen(w, users: [_activeClient(), _suspendedClient()]);

    expect(find.text('محمود حسن'), findsOneWidget);
    expect(find.text('سامي علي'), findsOneWidget);

    // شارة الحالة داخل التذكرة (المسمّيان نفساهما في جدول الملخص أيضاً)
    expect(find.text('نشط'), findsNWidgets(2));
    expect(find.text('موقوف'), findsNWidgets(2));

    // سطر الآيدي القابل للنسخ + جهة الاتصال (هاتف أو بريد)
    expect(find.text('JGO555'), findsOneWidget);
    expect(find.text('JGO777'), findsOneWidget);
    expect(find.text('0999888777'), findsOneWidget);
    expect(find.text('sami@jgo.store'), findsOneWidget);

    // الرصيد بهوية الكعب
    expect(find.text('CLIENT BALANCE'), findsNWidgets(2));
    expect(find.text('\$85.50'), findsOneWidget);
    expect(find.text('\$0.00'), findsOneWidget);

    // تذكرة الملخص + تذكرتان للعميلين
    expect(_ticketShadows(), findsNWidgets(3));
    // ارتفاع التذكرة النشطة مضغوط (أقل من نصف الكرت القديم)
    expect(w.getSize(_ticketShadows().at(1)).height, lessThan(130));

    // إجراءات الكعب: التحويل بارز، والإيقاف/التفعيل داخل قائمة ...
    expect(find.text('تحويل رصيد'), findsNWidgets(2));
    expect(find.text('إيقاف'), findsNothing);
    expect(find.text('تفعيل'), findsNothing);
    expect(_clientMenus(), findsNWidgets(2));

    await _dispose(w);
  });

  testWidgets('العميل المجمّد: سبب مختصر في سطر واحد بدل لافتة كبيرة', (
    w,
  ) async {
    await _pumpScreen(w, users: [_suspendedClient()]);

    expect(find.text('مجمّد: رصيد مدين'), findsOneWidget);
    expect(find.text('إيقاف'), findsNothing);

    // قائمة ... تحمل إجراء التفعيل بدل الزر البارز
    await w.tap(_clientMenus().first);
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));
    _drain(w);

    expect(find.text('إلغاء التجميد والتفعيل'), findsOneWidget);
    expect(find.text('إيقاف الحساب'), findsNothing);

    await _dispose(w);
  });

  testWidgets('الإيقاف اختفى من الكرت وعاد داخل قائمة ...', (w) async {
    await _pumpScreen(w, users: [_activeClient()]);

    expect(find.text('إيقاف'), findsNothing);
    expect(_ticketShadows(), findsNWidgets(2));

    await w.tap(_clientMenus().first);
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));
    _drain(w);

    expect(find.text('إيقاف الحساب '), findsOneWidget);
    expect(find.text('نسخ الآيدي'), findsOneWidget);

    await w.tap(find.text('إيقاف الحساب '));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));
    _drain(w);

    // نافذة التجميد انفتحت من القائمة
    expect(find.text('تجميد حساب العميل لمنع الاحتيال'), findsOneWidget);

    await _dispose(w);
  });

  testWidgets('الاسم الطويل يأخذ كامل العرض بعد نقل الشارة للكعب', (w) async {
    await _pumpScreen(
      w,
      width: 320,
      users: [
        AgentUserModel(
          id: 'c3',
          userId: 'JGO333',
          name: 'عبدالرحمن إبراهيم الكريطي',
          email: 'crm@jgo.store',
          balance: 10.0,
          isActive: true,
        ),
      ],
    );

    // شارة الحالة كانت تزاحم الاسم في صف واحد فتقطع أكثره
    final nameWidth = w.getRect(find.text('عبدالرحمن إبراهيم الكريطي')).width;
    expect(nameWidth, greaterThan(120));
    expect(find.text('نشط'), findsNWidgets(2));

    await _dispose(w);
  });

  testWidgets('على 320dp: الشاشتان بلا طفو تخطيط', (w) async {
    await _pumpScreen(
      w,
      width: 320,
      users: [_activeClient(), _suspendedClient()],
    );

    expect(find.text('ملخص العمليات'), findsOneWidget);
    expect(find.text('محمود حسن'), findsOneWidget);
    await _openTransfersTab(w);
    expect(find.text('OUT // عميل'), findsOneWidget);

    expect(
      _collected.where((e) => '$e'.contains('RenderFlex')),
      isEmpty,
      reason: _collected.map((e) => '$e').join('\n'),
    );

    await _dispose(w);
  });

  test('تصفية العملاء تقرأ من الواجهة العامة subUsers', () {
    final agent = _FakeAgent(
      records: [_incomingRecord(), _outgoingRecord()],
      users: [_activeClient(), _suspendedClient()],
    );

    expect(agent.filteredSubUsers, hasLength(2));

    agent.setFilter('active');
    expect(agent.filteredSubUsers.single.name, 'محمود حسن');

    agent.setFilter('suspended');
    expect(agent.filteredSubUsers.single.name, 'سامي علي');
  });

  test('تصفية السجل والعدّادات تقرأ من الواجهة العامة transfers', () {
    final agent = _FakeAgent(records: [_incomingRecord(), _outgoingRecord()]);

    expect(agent.filteredTransfers, hasLength(2));
    expect(agent.incomingTransferCount, 1);
    expect(agent.outgoingTransferCount, 1);

    agent.setTransferFilter('in');
    expect(agent.filteredTransfers.single.isIncoming, isTrue);

    agent.setTransferFilter('out');
    expect(agent.filteredTransfers.single.isIncoming, isFalse);

    agent.setTransferFilter('all');
    expect(agent.filteredTransfers, hasLength(2));
  });

  test('fromJson يقرأ الاتجاه والمقدار المطلق والطرف الآخر', () {
    final incoming = AgentTransferRecord.fromJson({
      '_id': 'x1',
      'createdAt': '2026-10-25T10:30:00.000Z',
      'direction': 'in',
      'amount': 200,
      'referenceType': 'Admin',
      'counterparty': {'name': 'الإدارة', 'userId': '', 'email': ''},
    });
    expect(incoming.isIncoming, isTrue);
    expect(incoming.amount, 200.0);
    expect(incoming.counterpartyName, 'الإدارة');

    // خادم قديم: مقدار سالب بلا direction
    final legacyOut = AgentTransferRecord.fromJson({
      '_id': 'x2',
      'amount': -60,
      'referenceType': 'AgentTransfer',
      'recipient': {
        'name': 'أحمد سيد',
        'userId': 'JGO999',
        'email': 'ahmed@jgo.store',
      },
    });
    expect(legacyOut.isIncoming, isFalse);
    expect(legacyOut.amount, 60.0);
    expect(legacyOut.recipientUserId, 'JGO999');

    // بلا طرف آخر معروف: تسمية احتياطية بحسب الاتجاه
    final bare = AgentTransferRecord.fromJson({'_id': 'x3', 'amount': -15});
    expect(bare.isIncoming, isFalse);
    expect(bare.amount, 15.0);
    expect(bare.counterpartyName, 'عميل تابع');
  });
}
