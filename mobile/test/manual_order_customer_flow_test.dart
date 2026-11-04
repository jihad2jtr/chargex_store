// جانب العميل في الخدمة اليدوية بعد إعادة التدفق:
// — تسليم النتيجة يُبقي للعميل «طلب تعديل» و«فتح اعتراض» فقط؛
//   زر تأكيد الاستلام أُزيل لأن مقدّم الخدمة هو من يؤكد الإنهاء ويغلق الطلب
// — بعد اكتمال الطلب تُقفل الدردشة في وجه العميل، وتبقى للموظف توثيقاً
// — خيارات تثبيت الرسالة لا تظهر للعميل أبداً، حتى لو حمل حسابه رتبة وظيفية
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:layan_chargex/models/order_model.dart';
import 'package:layan_chargex/models/user_model.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/manual_services_provider.dart';
import 'package:layan_chargex/screens/user/manual_order_details_screen.dart';

/// الشبكة معطّلة: أي استدعاء حقيقي يفشل فوراً ويبقى الهيكل ظاهراً
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
  _FakeAuth(this._user);

  final UserModel _user;

  @override
  UserModel? get currentUser => _user;

  // getters الصلاحية في AuthProvider تقرأ الحقل الخاص لا currentUser
  // المُتجاوز، فتجاوزها هنا إلزامي حتى يرى الموظف خيار التثبيت
  @override
  bool get isAdmin => _user.isAdmin;

  @override
  bool get isSupervisor => _user.isSupervisor;

  @override
  bool get isAgent => _user.isAgent;

  @override
  bool get isAuthenticated => true;
}

/// المزوّد محلي: المحادثة فارغة والتحديث الصامت يعيد نفس الطلب المختَم
class _FakeManual extends ManualServicesProvider {
  _FakeManual(this._order);

  final OrderModel _order;

  @override
  Future<List<OrderChatMessageModel>> fetchOrderMessages(
    String orderId,
  ) async => <OrderChatMessageModel>[];

  @override
  Future<OrderModel?> fetchOrderById(String orderId) async => _order;

  @override
  Future<Map<String, dynamic>?> fetchDecryptedCredentials(
    String orderId,
  ) async => null;

  @override
  String? get errorMessage => null;
}

final DateTime _now = DateTime(2026, 11, 3, 10, 0);

OrderModel _order({required String status, String? supervisorId}) {
  return OrderModel(
    id: 'o-9',
    orderNumber: 'ORD-4471',
    userId: 'c-1',
    userName: 'أحمد سيد',
    appId: 'app-1',
    appName: 'Chargex',
    productId: 's1',
    productName: 'تعبئة رصيد فري فاير 1000 جمة',
    type: 'manual',
    amount: 24.75,
    status: status,
    createdAt: _now,
    assignedSupervisorId: supervisorId,
    estimatedMinutes: 45,
  );
}

UserModel _user({String id = 'c-1', String role = 'user'}) {
  return UserModel(
    id: id,
    name: 'مستخدم الاختبار',
    email: '$id@jgo.store',
    role: role,
    balance: 0.0,
  );
}

Future<void> _pump(
  WidgetTester w, {
  required OrderModel order,
  required UserModel user,
}) async {
  // الارتفاع ضخم: شريط الإدخال أسفل منطقة المحادثة الموسّعة،
  // والرؤى خارج الشاشة لا يلتقطها finder في الاختبارات
  w.view.physicalSize = const Size(400, 2600);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth(user)),
        ChangeNotifierProvider<ManualServicesProvider>(
          create: (_) => _FakeManual(order),
        ),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ManualOrderDetailsScreen(order: order),
        ),
      ),
    ),
  );
  await w.pump();
  await w.pump(const Duration(milliseconds: 400));
  await w.pump();
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('تسليم النتيجة: للعميل تعديل/اعتراض فقط — لا زر تأكيد استلام', (
    w,
  ) async {
    await _pump(
      w,
      order: _order(status: 'delivered'),
      user: _user(),
    );

    expect(find.textContaining('تأكيد الاستلام'), findsNothing);
    expect(find.text('طلب تعديل'), findsOneWidget);
    expect(find.text('فتح اعتراض'), findsOneWidget);
  });

  testWidgets('الطلب المكتمل يقفل الدردشة في وجه العميل', (w) async {
    await _pump(
      w,
      order: _order(status: 'completed'),
      user: _user(),
    );

    expect(
      find.text('انتهى الطلب وأغلقه مقدّم الخدمة — الدردشة مغلقة.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('اكتب رسالة...'), findsNothing);
  });

  testWidgets('الموظف غير صاحب الطلب: دردشة مفتوحة وخيارات التثبيت ظاهرة', (
    w,
  ) async {
    await _pump(
      w,
      order: _order(status: 'completed', supervisorId: 'u-ad'),
      user: _user(id: 'u-ad', role: 'admin'),
    );

    // حقل الكتابة باقٍ للتوثيق، ورقائق التثبيت تظهر للموظف المسند
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('رسالة عادية'), findsOneWidget);
    expect(find.text('كود تحقق'), findsOneWidget);
    expect(
      find.text('انتهى الطلب وأغلقه مقدّم الخدمة — الدردشة مغلقة.'),
      findsNothing,
    );
  });

  testWidgets('صاحب الطلب لا تُمنحه رتبته الوظيفية خيار التثبيت', (w) async {
    await _pump(
      w,
      order: _order(status: 'delivered'),
      // نفس الهوية c-1 تملك الطلب وتحمل رتبة أدمن متفقداً: التثبيت يُحجب
      user: _user(id: 'c-1', role: 'admin'),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('رسالة عادية'), findsNothing);
    expect(find.text('كود تحقق'), findsNothing);
    // أزرار المراجعة الخاصة بالعميل باقية
    expect(find.text('طلب تعديل'), findsOneWidget);
  });

  testWidgets('موظف غير مسند بالطلب لا يرى التثبيت ولا أزرار العميل', (
    w,
  ) async {
    await _pump(
      w,
      order: _order(status: 'delivered', supervisorId: 'sup-other'),
      user: _user(id: 'u-sv', role: 'supervisor'),
    );

    expect(find.text('رسالة عادية'), findsNothing);
    expect(find.text('طلب تعديل'), findsNothing);
    expect(find.text('فتح اعتراض'), findsNothing);
  });
}
