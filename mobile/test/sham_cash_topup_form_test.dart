// شحن محفظة العميل عبر شام كاش: لا يُطلب رقم حساب المرسل — المبلغ مع صورة
// الإيصال يكفيان للتحقق، والبطاقة تعرض صورة كود الدفع في الأعلى ورقم الحساب
// تحتها، بكل ألوان شعار شام كاش نفسه.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:layan_chargex/models/payment_account_model.dart';
import 'package:layan_chargex/models/user_model.dart';
import 'package:layan_chargex/providers/auth_provider.dart';
import 'package:layan_chargex/providers/exchange_rate_provider.dart';
import 'package:layan_chargex/providers/wallet_provider.dart';
import 'package:layan_chargex/screens/user/topup_screen.dart';

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

  @override
  Future<void> refreshProfile() async {}
}

/// wallet وهمي: حساب شام كاش جاهز، والشحن يسجّل ما أُرسل فعلاً
class _FakeWallet extends WalletProvider {
  final List<PaymentAccountModel> shamAccounts = <PaymentAccountModel>[
    PaymentAccountModel(
      id: 'a1',
      type: 'sham_cash',
      accountName: 'حساب المتجر الرسمي',
      accountId: '09991112233',
      barcodeUrl: '',
    ),
  ];

  int submitCalls = 0;
  String? submittedType;
  double? submittedAmount;
  Map<String, dynamic>? submittedDetails;

  final List<PaymentAccountModel> binanceSeed = <PaymentAccountModel>[
    PaymentAccountModel(
      id: 'b1',
      type: 'binance',
      accountName: 'حساب المتجر على Binance Pay',
      accountId: '36639414',
      barcodeUrl: '',
    ),
  ];

  @override
  List<PaymentAccountModel> get shamCashAccounts => shamAccounts;

  @override
  List<PaymentAccountModel> get binanceAccounts => binanceSeed;

  @override
  Future<void> fetchPaymentAccounts() async {}

  @override
  Future<void> fetchMyTopupRequests() async {}

  @override
  Future<void> fetchBalance() async {}

  @override
  Future<String?> uploadReceiptImage(String base64Data) async => null;

  @override
  Future<bool> submitTopupRequest({
    required String type,
    required double amount,
    required Map<String, dynamic> details,
    String? receiptImageUrl,
  }) async {
    submitCalls++;
    submittedType = type;
    submittedAmount = amount;
    submittedDetails = details;
    return true;
  }
}

Future<_FakeWallet> _pumpTopup(
  WidgetTester w, {
  double width = 460,
  double height = 1400,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final wallet = _FakeWallet();

  w.view.physicalSize = Size(width, height);
  w.view.devicePixelRatio = 1.0;
  addTearDown(w.view.resetPhysicalSize);
  addTearDown(w.view.resetDevicePixelRatio);

  await w.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<WalletProvider>(create: (_) => wallet),
        ChangeNotifierProvider<ExchangeRateProvider>(
          create: (_) => ExchangeRateProvider(),
        ),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const TopupScreen(),
        ),
      ),
    ),
  );
  await _settle(w);
  return wallet;
}

/// يشغّل الأنيميشن ويستبعد أخطاء الخطوط/الشبكة المحجوبة
Future<void> _settle(WidgetTester w) async {
  await w.pump();
  await w.pump(const Duration(milliseconds: 600));
  while (true) {
    final Object? error = w.takeException();
    if (error == null) break;
    // تُسجَّل لتُفحص لاحقاً: طفو التخطيط وحده يُعتبر فشلاً
    _collected.add(error);
  }
}

Future<void> _openShamSheet(WidgetTester w) async {
  await w.tap(find.text('شام كاش').first);
  await w.pump();
  await w.pump(const Duration(milliseconds: 500));
  await _settle(w);
}

Finder get _shamAmountField =>
    find.widgetWithText(TextField, 'المبلغ المحول بالدولار (\$ USD)');

/// أخطاء التخطيط المُسجَّلة أثناء التثبيت (الخطوط/الشبكة تُستثنى عند الفحص)
final List<Object> _collected = <Object>[];

void _expectNoOverflow(int width) {
  final overflow = _collected
      .where((e) => e.toString().contains('RenderFlex overflowed'))
      .toList();
  expect(overflow, isEmpty, reason: 'طفو تخطيط على ${width}dp: $overflow');
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('نموذج شام كاش بلا حقل رقم الحساب المحوّل منه', (w) async {
    await _pumpTopup(w);
    await _openShamSheet(w);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(_shamAmountField, findsOneWidget);
    // الحقل القديم أُلغي تماماً من طريقة شام كاش
    expect(find.text('رقم حسابك المحول منه أو رقم المعاملة'), findsNothing);
    // صورة الإيصال ما زالت مطلوبة كدليل على التحويل
    expect(find.textContaining('إيصال'), findsWidgets);
  });

  testWidgets('المبلغ وحده يكفي لإرسال طلب الشحن بتفاصيل فارغة', (w) async {
    final wallet = await _pumpTopup(w);
    await _openShamSheet(w);

    await w.enterText(_shamAmountField, '10');
    await w.pump();
    await w.tap(find.textContaining('تأكيد وإرسال طلب الشحن'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 500));
    await _settle(w);

    expect(wallet.submitCalls, 1);
    expect(wallet.submittedType, 'sham_cash');
    expect(wallet.submittedAmount, 10.0);
    expect(wallet.submittedDetails, isEmpty);
    expect(
      find.text('تم إرسال طلب الشحن بنجاح، جاري المراجعة ✅'),
      findsOneWidget,
    );
    // النافذة أُغلقت بعد النجاح فلا يبقى حقل المبلغ معروضاً
    expect(_shamAmountField, findsNothing);
  });

  testWidgets('بلا مبلغ: يبقى الطلب محجوباً ولا يُرسل شيء', (w) async {
    final wallet = await _pumpTopup(w);
    await _openShamSheet(w);

    await w.tap(find.textContaining('تأكيد وإرسال طلب الشحن'));
    await w.pump();
    await _settle(w);

    expect(wallet.submitCalls, 0);
    expect(find.text('يرجى إدخال مبلغ صحيح بالدولار (\$)'), findsOneWidget);
    // إشعار النافذة يختفي مؤقّتاً (4 ثوان) — يجب تصريفه قبل نهاية الاختبار
    await w.pump(const Duration(seconds: 5));
    await w.pump();
  });

  testWidgets('رقم العملية ما زال مطلوباً في Binance Pay', (w) async {
    await _pumpTopup(w);

    await w.tap(find.text('Binance').first);
    await w.pump();
    await w.pump(const Duration(milliseconds: 500));
    await _settle(w);

    expect(find.byType(BottomSheet), findsOneWidget);
    // الوسيلة الأخرى لم تتغيّر: ما زالت تطلب معرّف الدفع للتحقق
    expect(
      find.widgetWithText(TextField, 'معرف الدفع الخاص بك (Pay ID أو TxID)'),
      findsOneWidget,
    );
  });

  testWidgets(
    'بطاقة الحساب: الصورة في الأعلى ورقم الحساب تحتها بألوان الشعار',
    (w) async {
      _collected.clear();
      await _pumpTopup(w, width: 380, height: 2400);
      await _openShamSheet(w);

      // رقم الحساب الكامل واسم الحساب يظهران بلا اقتطاع
      expect(find.text('09991112233'), findsOneWidget);
      expect(find.text('حساب المتجر الرسمي'), findsOneWidget);

      // الترتيب الرأسي المطلوب: صورة كود الدفع أعلى ورقم الحساب تحتها
      final Rect code = w.getRect(find.byType(QrImageView).first);
      final Rect idLine = w.getRect(find.text('09991112233'));
      expect(code.bottom, lessThan(idLine.top));

      // ألوان الشعار: رقم الحساب بلون أزرق الشعار لا الأزرق العام السابق
      final SelectableText idField = w
          .widgetList<SelectableText>(find.byType(SelectableText))
          .single;
      expect(idField.data, '09991112233');
      expect(idField.style?.color, const Color(0xFF4E67C3));

      // الضغط لم يمس الصورة: بقيت بمقاسها، ومحتوى البطاقة صار أقصر من 250
      expect(code.width, greaterThan(130));
      final Rect hint = w.getRect(
        find.text('حول إلى هذا الحساب ثم اضغط الصورة للتكبير'),
      );
      expect(hint.bottom - code.top, lessThan(250));
      _expectNoOverflow(380);
    },
  );

  testWidgets('البطاقة الجديدة بلا طفو على عرض 320', (w) async {
    _collected.clear();
    await _pumpTopup(w, width: 320, height: 2400);
    await _openShamSheet(w);

    expect(find.text('09991112233'), findsOneWidget);
    expect(find.text('نسخ'), findsOneWidget);
    _expectNoOverflow(320);
  });
}
