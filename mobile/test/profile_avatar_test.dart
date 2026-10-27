// الصورة الشخصية في الملف الشخصي: تُعرض إن وُجدت، والحرف الأول عند غيابها،
// واللمس عليها يفتح قائمة (المعرض / الكاميرا / الإزالة).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/user_model.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/margin_provider.dart';
import 'package:layan_chargex/screens/user/profile_screen.dart';
import 'package:layan_chargex/widgets/user_avatar.dart';

/// الشبكة معطّلة: أي طلب يفشل فوراً بدل أن يعلّق الاختبار
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

/// مستخدم ثابت: الصفحة تقرأ منه فقط ولا تحتاج تسجيل دخول
class _FakeAuth extends AuthProvider {
  _FakeAuth(this._user);

  final UserModel _user;

  @override
  UserModel? get currentUser => _user;

  @override
  Future<void> refreshProfile() async {}
}

UserModel _user({String? avatar}) => UserModel(
  id: 'u1',
  userId: 'jgo26101512345',
  name: 'سامر',
  email: 'samer@example.com',
  role: 'user',
  balance: 12.5,
  avatar: avatar,
);

Future<void> _pumpProfile(WidgetTester w, UserModel user) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  w.view.physicalSize = const Size(420, 900);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth(user)),
        ChangeNotifierProvider<MarginProvider>(create: (_) => MarginProvider()),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const ProfileScreen(),
        ),
      ),
    ),
  );
  await w.pump(const Duration(milliseconds: 300));
}

bool _showsImage(WidgetTester w) =>
    w.widget<UserAvatar>(find.byType(UserAvatar)).hasImage;

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('الصورة المرفوعة تُعرض في بطاقة الجواز', (w) async {
    await _pumpProfile(
      w,
      _user(avatar: 'http://192.168.1.198:3000/uploads/a.jpg'),
    );

    expect(find.byType(UserAvatar), findsOneWidget);
    expect(_showsImage(w), isTrue);
  });

  testWidgets('بلا صورة يظهر الحرف الأول من الاسم', (w) async {
    await _pumpProfile(w, _user());

    expect(_showsImage(w), isFalse);
    expect(find.text('س'), findsWidgets);
  });

  testWidgets('اللمس على الصورة يفتح قائمة التعديل', (w) async {
    await _pumpProfile(w, _user(avatar: '/uploads/a.png'));

    await w.tap(find.byType(UserAvatar));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('الاختيار من المعرض'), findsOneWidget);
    expect(find.text('التقاط صورة بالكاميرا'), findsOneWidget);
    // صورة موجودة مسبقاً => خيار الإزالة ظاهر
    expect(find.text('إزالة الصورة الحالية'), findsOneWidget);
  });

  testWidgets('قائمة بلا صورة لا تعرض خيار الإزالة', (w) async {
    await _pumpProfile(w, _user());

    await w.tap(find.byType(UserAvatar));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('إزالة الصورة الحالية'), findsNothing);
  });

  testWidgets('إزالة الصورة تفشل بلطف عند تعذر الاتصال', (w) async {
    await _pumpProfile(
      w,
      _user(avatar: 'http://192.168.1.198:3000/uploads/a.jpg'),
    );

    await w.tap(find.byType(UserAvatar));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));
    await w.tap(find.text('إزالة الصورة الحالية'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    // الشبكة معطّلة في الاختبار => لا نافذة مفتوحة ورسالة خطأ واضحة
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('تعذر إزالة الصورة'), findsOneWidget);
  });
}
