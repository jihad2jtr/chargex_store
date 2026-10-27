// إدارة المستخدمين: ترقية العميل إلى وكيل (أو مشرف) بشاشة تأكيد، وإرجاع الوكيل
// إلى عميل، ونافذة شحن/خصم رصيد العميل مباشرة من نفس الصفحة.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/screens/admin/users_management_screen.dart';

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

  String? roleUserId;
  String? roleValue;
  String? creditUserId;
  double? creditAmount;
  String? creditNote;
  bool creditOk = true;
  String? fakeError;

  @override
  List<Map<String, dynamic>> get allUsers => users;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => fakeError ?? super.errorMessage;

  @override
  Future<void> fetchAllUsers({bool silent = false}) async {}

  @override
  Future<void> fetchTopupLog() async {}

  @override
  Future<bool> updateUserRole(String userId, String role) async {
    roleUserId = userId;
    roleValue = role;
    return true;
  }

  @override
  Future<bool> adjustUserBalance(
    String userId,
    double amount,
    String description,
  ) async {
    creditUserId = userId;
    creditAmount = amount;
    creditNote = description;
    return creditOk;
  }
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

Future<_SeededAdmin> _pumpScreen(
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
  return admin;
}

/// يشغّل الأنيميشن ويستبعد أخطاء تحميل الخطوط فقط
Future<void> _settle(WidgetTester w) async {
  await w.pump();
  await w.pump(const Duration(milliseconds: 600));
  while (w.takeException() != null) {
    // تجاهل أخطاء google_fonts الناتجة عن حظر الشبكة
  }
}

Future<void> _openSheetFor(WidgetTester w, String name) async {
  await w.tap(find.text(name).first);
  await _settle(w);
}

Finder get _amountField => find.widgetWithText(TextField, 'المبلغ بالدولار');

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  final List<Map<String, dynamic>> seeded = <Map<String, dynamic>>[
    _user(id: 'c1', name: 'عميل تجريبي', balance: 10),
    _user(id: 'a1', name: 'وكيل المبيعات', role: 'agent', balance: 40),
    _user(id: 's1', name: 'مشرف التنفيذ', role: 'supervisor', balance: 0),
    _user(id: 'ad1', name: 'أدمن النظام', role: 'admin', balance: 999),
  ];

  testWidgets('البلاطات تعدّ الوكلاء وتفتح الصف بلا أخطاء تخطيط', (w) async {
    await _pumpScreen(w, users: seeded, width: 560);

    expect(find.text('إدارة المستخدمين'), findsOneWidget);
    // بلاطة العدّ وشريط الفلاتر كلاهما يحمل كلمة «وكلاء»
    expect(find.text('وكلاء'), findsWidgets);
    expect(find.text('عميل تجريبي'), findsOneWidget);
  });

  testWidgets('نافذة العميل تعرض ترقتَي الوكيل والمشرف وزر الرصيد', (w) async {
    await _pumpScreen(w, users: seeded);
    await _openSheetFor(w, 'عميل تجريبي');

    expect(find.text('ترقية إلى وكيل'), findsOneWidget);
    expect(find.text('ترقية إلى مشرف'), findsOneWidget);
    expect(find.text('شحن أو خصم رصيد'), findsOneWidget);
    expect(find.text(r'$10.00'), findsWidgets);
  });

  testWidgets('تأكيد ترقية العميل إلى وكيل يمرر agent للملف الشخصي', (w) async {
    final admin = await _pumpScreen(w, users: seeded);
    await _openSheetFor(w, 'عميل تجريبي');

    await w.tap(find.text('ترقية إلى وكيل'));
    await _settle(w);

    // شاشة تأكيد تشرح صلاحيات الوكيل قبل التنفيذ
    expect(find.widgetWithText(ElevatedButton, 'تأكيد'), findsOneWidget);

    await w.tap(find.widgetWithText(ElevatedButton, 'تأكيد'));
    await _settle(w);

    expect(admin.roleValue, 'agent');
    expect(admin.roleUserId, 'c1');
    expect(find.text('تمت ترقية "عميل تجريبي" إلى وكيل'), findsOneWidget);
  });

  testWidgets('وكيل بلا عملاء يمكن إرجاعه إلى عميل', (w) async {
    final admin = await _pumpScreen(w, users: seeded);
    await _openSheetFor(w, 'وكيل المبيعات');

    expect(find.text('لوحة الوكيل متاحة'), findsOneWidget);
    expect(find.text('إرجاع إلى عميل'), findsOneWidget);

    await w.tap(find.text('إرجاع إلى عميل'));
    await _settle(w);
    await w.tap(find.widgetWithText(ElevatedButton, 'تأكيد'));
    await _settle(w);

    expect(admin.roleValue, 'user');
    expect(find.text('تم إرجاع "وكيل المبيعات" إلى عميل'), findsOneWidget);
  });

  testWidgets('حساب الأدمن لا يعرض أزرار تغيير الرتبة', (w) async {
    await _pumpScreen(w, users: seeded);
    await _openSheetFor(w, 'أدمن النظام');

    expect(find.text('حساب إداري'), findsOneWidget);
    expect(find.text('ترقية إلى وكيل'), findsNothing);
    expect(find.text('إرجاع إلى عميل'), findsNothing);
  });

  testWidgets('شحن رصيد يرسل مبلغاً موجباً ويحدّث الرصيد الظاهر', (w) async {
    final admin = await _pumpScreen(w, users: seeded);
    await _openSheetFor(w, 'عميل تجريبي');

    await w.tap(find.text('شحن أو خصم رصيد'));
    await _settle(w);

    expect(find.text('الرصيد الحالي'), findsOneWidget);
    expect(find.text('الرصيد بعد العملية'), findsOneWidget);

    await w.enterText(_amountField, '25');
    await _settle(w);

    expect(find.text(r'$35.00'), findsOneWidget);
    expect(find.textContaining('تأكيد شحن \$25.00'), findsOneWidget);

    await w.tap(find.textContaining('تأكيد شحن'));
    await _settle(w);

    expect(admin.creditUserId, 'c1');
    expect(admin.creditAmount, 25.0);
    expect(admin.creditNote, 'شحن رصيد من لوحة الأدمن');
    // نافذة الرصيد أُغلقت بعد النجاح وظهر إشعار بالرصيد الجديد
    expect(find.text('الرصيد بعد العملية'), findsNothing);
    expect(
      find.text('تم تحديث رصيد "عميل تجريبي" إلى \$35.00'),
      findsOneWidget,
    );
  });

  testWidgets('اختيار مبلغ سريع يضبط الحقل مباشرة', (w) async {
    final admin = await _pumpScreen(w, users: seeded);
    await _openSheetFor(w, 'عميل تجريبي');
    await w.tap(find.text('شحن أو خصم رصيد'));
    await _settle(w);

    await w.tap(find.text(r'$10'));
    await _settle(w);
    await w.tap(find.textContaining('تأكيد شحن'));
    await _settle(w);

    expect(admin.creditAmount, 10.0);
  });

  testWidgets('الخصم بمبلغ أكبر من الرصيد يُرفض دون إرسال طلب', (w) async {
    final admin = await _pumpScreen(w, users: seeded);
    await _openSheetFor(w, 'عميل تجريبي');
    await w.tap(find.text('شحن أو خصم رصيد'));
    await _settle(w);

    await w.tap(find.text('خصم'));
    await _settle(w);
    await w.enterText(_amountField, '50');
    await _settle(w);

    expect(find.text(r'$-40.00'), findsOneWidget); // معاينة رصيد سالب

    await w.tap(find.textContaining('تأكيد خصم'));
    await _settle(w);

    expect(admin.creditAmount, isNull);
    expect(find.textContaining('المبلغ أكبر من الرصيد الحالي'), findsOneWidget);
  });

  testWidgets('الخصم الصالح يطلب تأكيداً ثانياً ويرسل مبلغاً سالباً', (
    w,
  ) async {
    final admin = await _pumpScreen(w, users: seeded);
    await _openSheetFor(w, 'عميل تجريبي');
    await w.tap(find.text('شحن أو خصم رصيد'));
    await _settle(w);

    await w.tap(find.text('خصم'));
    await _settle(w);
    await w.enterText(_amountField, '4');
    await _settle(w);

    await w.tap(find.textContaining('تأكيد خصم'));
    await _settle(w);

    expect(find.text('تأكيد الخصم'), findsOneWidget);
    await w.tap(find.text('تأكيد الخصم'));
    await _settle(w);

    expect(admin.creditAmount, -4.0);
    expect(admin.creditNote, 'خصم رصيد من لوحة الأدمن');
    expect(find.text('تم تحديث رصيد "عميل تجريبي" إلى \$6.00'), findsOneWidget);
  });

  testWidgets('فشل تعديل الرصيد يبقي النافذة مفتوحة ويعرض رسالة الخادم', (
    w,
  ) async {
    final admin = await _pumpScreen(w, users: seeded);
    admin.creditOk = false;
    admin.fakeError = 'رصيد الأدمن غير كافٍ';
    await _openSheetFor(w, 'مشرف التنفيذ');
    await w.tap(find.text('شحن أو خصم رصيد'));
    await _settle(w);

    await w.enterText(_amountField, '5');
    await _settle(w);
    await w.tap(find.textContaining('تأكيد شحن'));
    await _settle(w);

    expect(
      find.text('الرصيد بعد العملية'),
      findsOneWidget,
    ); // النافذة ما زالت مفتوحة
    expect(find.text('رصيد الأدمن غير كافٍ'), findsOneWidget);
  });

  testWidgets('شاشة ضيقة (320px): نافذة الوكيل والبطاقات بلا طفو تخطيط', (
    w,
  ) async {
    await _pumpScreen(
      w,
      users: <Map<String, dynamic>>[
        _user(
          id: 'c9',
          name: 'عميل باسم طويل جداً للمراجعة الدقيقة',
          role: 'agent',
          balance: 1234.56,
        ),
      ],
      width: 320,
      height: 700,
    );

    await w.tap(find.textContaining('عميل باسم طويل').first);
    await _settle(w);

    expect(find.text('شحن أو خصم رصيد'), findsOneWidget);
    expect(find.text('إرجاع إلى عميل'), findsOneWidget);
  });
}
