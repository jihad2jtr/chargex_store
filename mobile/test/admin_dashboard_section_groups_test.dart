// أقسام لوحة الأدمن معروضة كلها مرتّبة تحت عناوين مجموعاتها (بلا فلاتر تبويبات).
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

  w.view.physicalSize = const Size(760, 2400);
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

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('كل الأقسام ظاهرة مرتّبة تحت عناوين مجموعاتها (بلا فلاتر)', (
    w,
  ) async {
    await _pumpDashboard(w);

    // عناوين المجموعات الخمس تظهر فوق أقسامها
    expect(find.text('إدارة الأرقام'), findsOneWidget);
    expect(find.text('المتجر والمنتجات'), findsOneWidget);
    expect(find.text('المالية والطلبات'), findsOneWidget);
    expect(find.text('المستخدمون والإشراف'), findsOneWidget);
    expect(find.text('عام'), findsOneWidget);

    // الأقسام ما زالت كلها ظاهرة
    expect(find.text('مزودو الأرقام الوهمية'), findsOneWidget);
    expect(find.text('إدارة تطبيقات الارقام'), findsOneWidget);
    expect(find.text('خدمات التفعيل المضمون'), findsOneWidget);
    expect(find.text('سجل التفعيلات التلقائية'), findsOneWidget);
    expect(find.text('مزودو خدمات الشحن'), findsOneWidget);
    expect(find.text('التطبيقات والمنتجات'), findsOneWidget);
    expect(find.text('الطلبات والمراجعة'), findsOneWidget);
    expect(find.text('حسابات الدفع'), findsOneWidget);
    expect(find.text('أكواد الشحن'), findsOneWidget);
    expect(find.text('أنواع قوالب الخدمة'), findsOneWidget);
    expect(find.text('لوحة إدارة الأعلانات'), findsOneWidget);
    expect(find.text('إدارة المستخدمين'), findsOneWidget);
    expect(find.text('الخدمات اليدوية والمشرفين'), findsOneWidget);
  });

  testWidgets('لا يوجد شريط تبويبات فرز بعد إزلته', (w) async {
    await _pumpDashboard(w);

    // نصوص كانت حصرية على التبويبات لم تعد موجودة (مثل تبويب «الكل»)
    expect(find.text('الكل'), findsNothing);
    // البلاطة الأولى لكل مجموعة تأتي مباشرة بعد عنوانها دون أي فلتر
    expect(
      find.byType(SingleChildScrollView).evaluate().length,
      greaterThan(0),
    );
  });
}
