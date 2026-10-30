// فرز أقسام لوحة الأدمن حسب المهمة: تبويبات (الكل/إدارة الأرقام/المتجر/
// المالية/المستخدمون) + عناوين مجموعات فوق الأقسام في عرض «الكل».
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/user_model.dart';
import 'package:layan_chargex/core/services/cache_service.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/virtual_numbers_provider.dart';
import 'package:layan_chargex/screens/admin/admin_dashboard_screen.dart';

/// الشبكة معطّلة: أي طلب حقيقي يفشل فوراً والشاشات تبقى على حالتها الفارغة
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
  @override
  UserModel? get currentUser => UserModel(
    id: 'a1',
    userId: 'JGOADMIN0001',
    name: 'الأدمن',
    email: 'admin@example.com',
    role: 'admin',
    balance: 0,
  );
}

Future<void> _pumpDashboard(WidgetTester w) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await CacheService.instance.clearAll();

  w.view.physicalSize = const Size(760, 2200);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<AdminProvider>(create: (_) => AdminProvider()),
        ChangeNotifierProvider<VirtualNumbersProvider>(
          create: (_) => VirtualNumbersProvider(),
        ),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const AdminDashboardScreen(),
        ),
      ),
    ),
  );
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
  while (w.takeException() != null) {
    // تجاهل أخطاء google_fonts الناتجة عن حظر الشبكة
  }
}

/// تمرير التبويب إلى الظهور ثم النقر عليه عبر زرّالـ InkWell الخاص بالتبويب
/// (نفس نصّ التبويب يظهر كعنوان مجموعة، فالتبويب هو أول مطابقة)
Future<void> _tapTab(WidgetTester w, String label) async {
  final chip = find.ancestor(
    of: find.text(label),
    matching: find.byType(InkWell),
  );
  await w.ensureVisible(chip.first);
  await w.tap(chip.first);
  await w.pump();
  await w.pump(const Duration(milliseconds: 350));
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('عرض «الكل» يظهر عناوين المجموعات مع أقسامها', (w) async {
    await _pumpDashboard(w);

    // عناوين التجميع حسب المهمة (بعضها يتكرر كنص تبويب بنفس الاسم)
    expect(find.text('إدارة الأرقام الوهمية'), findsOneWidget);
    expect(find.text('المتجر والمنتجات'), findsWidgets);
    expect(find.text('المالية والطلبات'), findsWidgets);
    expect(find.text('المستخدمون والإشراف'), findsWidgets);

    // الأقسام ما زالت كلها ظاهرة
    expect(find.text('الأرقام الوهمية'), findsOneWidget);
    expect(find.text('إدارة تطبيقات الأرقام'), findsOneWidget);
    expect(find.text('مزودو الأرقام الوهمية'), findsOneWidget);
    // خدمات التفعيل المضمون معزولة كبطاقة مستقلة ضمن إدارة الأرقام
    expect(find.text('خدمات التفعيل المضمون'), findsOneWidget);
    expect(find.text('إدارة المزودين'), findsOneWidget);
    expect(find.text('أكواد الشحن'), findsOneWidget);
    expect(find.text('إدارة المستخدمين'), findsOneWidget);
  });

  testWidgets('تبويب «إدارة الأرقام» يُبقي أقسام الأرقام فقط', (w) async {
    await _pumpDashboard(w);
    await _tapTab(w, 'إدارة الأرقام');

    expect(find.text('الأرقام الوهمية'), findsOneWidget);
    // صفحة انتقاء التطبيقات معزولة كقسم مستقل ضمن إدارة الأرقام
    expect(find.text('إدارة تطبيقات الأرقام'), findsOneWidget);
    expect(find.text('مزودو الأرقام الوهمية'), findsOneWidget);
    // بطاقة التفعيل المضمون تبقى ضمن تبويب إدارة الأرقام
    expect(find.text('خدمات التفعيل المضمون'), findsOneWidget);
    // خارج المهمة اختفت
    expect(find.text('إدارة المزودين'), findsNothing);
    expect(find.text('أكواد الشحن'), findsNothing);
    expect(find.text('إدارة المستخدمين'), findsNothing);
    // عنوان مجموعة الأرقام يختفي: التبويب يُبقي الشبكة بلا عناوين مجموعات
    // (نص «المالية والطلبات» يبقى طبيعيًا في شريط التبويبات)
    expect(find.text('إدارة الأرقام الوهمية'), findsNothing);
  });

  testWidgets('تبويب «المالية والطلبات» يعرض الطلبات والحسابات والأكواد', (
    w,
  ) async {
    await _pumpDashboard(w);
    await _tapTab(w, 'المالية والطلبات');

    expect(find.text('الطلبات والمراجعة'), findsOneWidget);
    expect(find.text('حسابات الدفع'), findsOneWidget);
    expect(find.text('أكواد الشحن'), findsOneWidget);
    expect(find.text('الأرقام الوهمية'), findsNothing);
    expect(find.text('التطبيقات والمنتجات'), findsNothing);
  });

  testWidgets('تبويب «المتجر والمنتجات» يضم المزودين والتطبيقات والقوالب', (
    w,
  ) async {
    await _pumpDashboard(w);
    await _tapTab(w, 'المتجر والمنتجات');

    expect(find.text('إدارة المزودين'), findsOneWidget);
    expect(find.text('التطبيقات والمنتجات'), findsOneWidget);
    expect(find.text('أنواع قوالب الخدمة'), findsOneWidget);
    expect(find.text('لوحة الإعلانات'), findsOneWidget);
    expect(find.text('حسابات الدفع'), findsNothing);
  });

  testWidgets('تبويب «المستخدمون والإشراف» يضم المستخدمين والمشرفين', (
    w,
  ) async {
    await _pumpDashboard(w);
    await _tapTab(w, 'المستخدمون والإشراف');

    expect(find.text('إدارة المستخدمين'), findsOneWidget);
    expect(find.text('الخدمات اليدوية والمشرفين'), findsOneWidget);
    expect(find.text('الطلبات والمراجعة'), findsNothing);
  });
}
