// القائمة السريعة التي تفتح من صورة المستخدم في الرأس: واجهة البطاقة الفاتحة
// المعتمدة في التطبيق بدل الأسود، مع لمسة التذكرة (فتحتا تثقيب + خط مثقَّب).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/core/theme/app_colors.dart';
import 'package:layan_chargex/models/user_model.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/widgets/unified_tactile_header.dart';

/// الشبكة معطّلة: أي طلب حقيقي يفشل فوراً ويبقى الهيكل ظاهراً
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
    id: 'u1',
    userId: 'JGO26102712345',
    name: 'سامر',
    email: 'samer@example.com',
    role: 'user',
    balance: 20,
  );
}

Future<void> _pumpHeader(WidgetTester w) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  w.view.physicalSize = const Size(460, 1400);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _FakeAuth(),
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const Scaffold(
            body: Column(children: [UnifiedTactileHeader(isDashboard: true)]),
          ),
        ),
      ),
    ),
  );
  await _settle(w);
}

Future<void> _settle(WidgetTester w) async {
  await w.pump();
  await w.pump(const Duration(milliseconds: 600));
  while (w.takeException() != null) {
    // تجاهل أخطاء google_fonts الناتجة عن حظر الشبكة
  }
}

Future<void> _openMenu(WidgetTester w) async {
  await w.tap(find.byType(PopupMenuButton<String>));
  await w.pump();
  await w.pump(const Duration(milliseconds: 500));
  await _settle(w);
}

/// Material الخاص بالقائمة: أعمق Material يغلّف عناوين الصفوف
Material _menuMaterial(WidgetTester w) => w.widget<Material>(
  find
      .ancestor(of: find.text('الملف الشخصي'), matching: find.byType(Material))
      .last,
);

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('القائمة تفتح من الصورة الشخصية وتعرض أوامرها الأربعة', (
    w,
  ) async {
    await _pumpHeader(w);
    await _openMenu(w);

    expect(find.text('الملف الشخصي'), findsOneWidget);
    expect(find.text('تحديد نسبة الربح'), findsOneWidget);
    expect(find.text('التحقق من التحديثات'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('سطح القائمة بطاقة فاتحة من باليتة التطبيق لا أسود', (w) async {
    await _pumpHeader(w);
    await _openMenu(w);

    final material = _menuMaterial(w);
    expect(material.color, AppColors.surfaceCard);
    // العنوان الداكن لازم على السطح الفاتح (كان أبيض على أسود)
    final title = w.widget<Text>(find.text('الملف الشخصي'));
    expect(title.style!.color, AppColors.slate900);
  });

  testWidgets('لمسة التذكرة: فتحة تثقيب في منتصف كل حافة جانبية', (w) async {
    await _pumpHeader(w);
    await _openMenu(w);

    final shape = _menuMaterial(w).shape!;
    const rect = Rect.fromLTRB(0, 0, 210, 168);
    final path = shape.getOuterPath(rect);

    // منتصف الحافة اليمنى/اليسرى مقتطوع، وفوقه داخل البطاقة مباشرة
    expect(path.contains(const Offset(207, 84)), isFalse);
    expect(path.contains(const Offset(3, 84)), isFalse);
    expect(path.contains(const Offset(207, 40)), isTrue);
    expect(path.contains(const Offset(3, 128)), isTrue);
    expect(shape, isNot(isA<RoundedRectangleBorder>()));
  });

  testWidgets('عدد الصفوف زوجي والحشو متماثل = التثقيب على حد صفين', (w) async {
    await _pumpHeader(w);
    await _openMenu(w);

    // أي فاصل إضافي أو صف فردي يُسقط خط التثقيب في منتصف العنوان
    final items = w
        .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
        .toList();
    expect(items, hasLength(4));
    expect(items.length % 2, 0);
  });
}
