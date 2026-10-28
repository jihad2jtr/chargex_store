// صفحة حسابات الدفع في الإدارة: رقم الحساب الطويل لا يجب أن يفيض خارج البطاقة
// أو يتداخل مع التسمية وأزرار الإجراءات، على أضيق عرض شاشة.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/payment_account_model.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/screens/admin/payment_accounts_screen.dart';

/// الشبكة معطّلة: لا نريد أي طلب حقيقي أثناء اختبار التخطيط
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

/// بيانات محلية جاهزة: بطاقات حسابات الدفع تظهر دون شبكة
class _SeededAdmin extends AdminProvider {
  _SeededAdmin(this._items);

  final List<PaymentAccountModel> _items;
  int toggleCalls = 0;

  @override
  List<PaymentAccountModel> get paymentAccounts => _items;

  @override
  bool get isLoading => false;

  @override
  Future<void> fetchPaymentAccounts() async {}

  @override
  Future<void> togglePaymentAccount(String id) async {
    toggleCalls++;
  }
}

/// رقم حساب طويل جداً (24 خانة) — الحالة التي كسرت التخطيط
const String longShamId = '099988877766655544433322';
const String binanceId = '1234567890123456';

PaymentAccountModel _account({
  required String id,
  required String type,
  required String name,
  required String accountId,
  bool isActive = true,
}) {
  return PaymentAccountModel(
    id: id,
    type: type,
    accountName: name,
    accountId: accountId,
    barcodeUrl: '', // بلا صورة كي لا نحمّل شبكة في الاختبار
    isActive: isActive,
  );
}

List<PaymentAccountModel> _accounts() => [
  _account(
    id: 'a1',
    type: 'sham_cash',
    name: 'حساب شام كاش الرئيسي للتحويلات',
    accountId: longShamId,
  ),
  _account(
    id: 'a2',
    type: 'binance',
    name: 'Binance Pay Main',
    accountId: binanceId,
    isActive: false,
  ),
];

Future<List<Object>> _pumpScreen(
  WidgetTester w, {
  double width = 360,
  required _SeededAdmin admin,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  w.view.physicalSize = Size(width, 900);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    ChangeNotifierProvider<AdminProvider>(
      create: (_) => admin,
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: PaymentAccountsScreen(),
        ),
      ),
    ),
  );
  await w.pump(const Duration(milliseconds: 400));

  return _drainErrors(w);
}

// نستهلك أخطاء الشبكة/الخط ونُبقي أخطاء التخطيط (تداخل العناصر) فقط
List<Object> _drainErrors(WidgetTester w) {
  final List<Object> errors = [];
  Object? e = w.takeException();
  while (e != null) {
    errors.add(e);
    e = w.takeException();
  }
  return errors
      .where((err) => !err.toString().contains('google_fonts'))
      .toList();
}

void _expectNoOverflow(List<Object> errors, int width, String where) {
  final overflows = errors
      .where((e) => e.toString().contains('overflowed'))
      .toList();
  expect(
    overflows,
    isEmpty,
    reason: 'عناصر متداخلة (تجاوز أفقي) في $where عند عرض $width',
  );
}

/// ضمن حدود الشاشة أفقياً: التجاوز يدفع العنصر خارجها فيظهر متداخلاً
void _expectWithinScreen(
  WidgetTester w,
  Finder finder,
  double width,
  String label,
) {
  expect(finder, findsOneWidget, reason: '$label غير موجود');
  final box = finder.evaluate().single.renderObject! as RenderBox;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  expect(
    rect.left,
    greaterThanOrEqualTo(-0.5),
    reason: '$label خارج الشاشة من اليسار',
  );
  expect(
    rect.right,
    lessThanOrEqualTo(width + 0.5),
    reason: '$label خارج الشاشة من اليمين (تجاوز أفقي)',
  );
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  for (final width in <double>[320, 360, 400]) {
    testWidgets(
      'رقم الحساب الطويل يبقى داخل البطاقة عند عرض ${width.toInt()}',
      (w) async {
        final errors = await _pumpScreen(
          w,
          width: width,
          admin: _SeededAdmin(_accounts()),
        );
        _expectNoOverflow(errors, width.toInt(), 'تبويب شام كاش');

        expect(find.text(longShamId), findsOneWidget);
        expect(find.text('رقم الحساب'), findsOneWidget);
        _expectWithinScreen(w, find.text(longShamId), width, 'رقم الحساب');
        _expectWithinScreen(
          w,
          find.byTooltip('نسخ رقم الحساب'),
          width,
          'زر نسخ الرقم',
        );
        _expectWithinScreen(w, find.byTooltip('حذف'), width, 'زر الحذف');
        _expectWithinScreen(w, find.byTooltip('تعديل'), width, 'زر التعديل');

        // الرقم وزر النسخ لا يتراكبان مع بعضهما
        final id = w.getRect(find.text(longShamId));
        final copy = w.getRect(find.byTooltip('نسخ رقم الحساب'));
        expect(
          id.overlaps(copy),
          isFalse,
          reason: 'رقم الحساب يتراكب مع زر النسخ',
        );
      },
    );
  }

  testWidgets('تبويب Binance Pay لا يفيض عند عرض 320', (w) async {
    final admin = _SeededAdmin(_accounts());
    await _pumpScreen(w, width: 320, admin: admin);

    await w.tap(find.text('Binance Pay'));
    await w.pump(const Duration(milliseconds: 600));
    await w.pump(const Duration(milliseconds: 400));

    _expectNoOverflow(_drainErrors(w), 320, 'تبويب Binance Pay');

    expect(find.text('معرّف الدفع (Binance Pay ID)'), findsOneWidget);
    expect(find.text(binanceId), findsOneWidget);
    _expectWithinScreen(w, find.text(binanceId), 320, 'معرّف الدفع');
  });

  testWidgets('زر النسخ ينسخ الرقم دون كسر البطاقة', (w) async {
    final admin = _SeededAdmin(_accounts());
    await _pumpScreen(w, width: 320, admin: admin);

    await w.tap(find.byTooltip('نسخ رقم الحساب'));
    await w.pump(const Duration(milliseconds: 200));

    expect(find.text('تم نسخ رقم الحساب 📋'), findsOneWidget);
    _expectNoOverflow(_drainErrors(w), 320, 'بعد النسخ');

    // إنهاء مؤقت شريط التنبيه قبل انتهاء الاختبار
    await w.pumpWidget(const SizedBox.shrink());
    await w.pump(const Duration(seconds: 3));
  });
}
