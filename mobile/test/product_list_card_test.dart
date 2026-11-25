import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/core/theme/app_colors.dart';
import 'package:layan_chargex/models/product_model.dart';
import 'package:layan_chargex/widgets/digital_pass_card.dart';
import 'package:layan_chargex/widgets/product_list_card.dart';

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

ProductModel _makeProduct({
  required String id,
  required String name,
  String type = 'direct_api',
  double salePrice = 4.50,
  double? previousPrice,
  bool hasPriceChanged = false,
  String? description,
  int availableCodesCount = 0,
}) {
  return ProductModel(
    id: id,
    appId: 'app1',
    name: name,
    type: type,
    costPrice: salePrice * 0.8,
    profitMarginType: 'percentage',
    profitMarginValue: 20,
    salePrice: salePrice,
    previousPrice: previousPrice,
    hasPriceChanged: hasPriceChanged,
    description: description,
    availableCodesCount: availableCodesCount,
  );
}

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('ProductListCard يعرض حالات الشحن والكود واليدوي مع السعر دون overflow على 320dp', (
    WidgetTester w,
  ) async {
    w.view.physicalSize = const Size(320, 900);
    w.view.devicePixelRatio = 1.0;
    addTearDown(w.view.resetPhysicalSize);
    addTearDown(w.view.resetDevicePixelRatio);

    await w.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                ProductListCard(
                  product: _makeProduct(
                    id: 'p1',
                    name: '60 شدة ببجي موبايل شحن فوري',
                    salePrice: 0.99,
                    previousPrice: 1.25,
                    hasPriceChanged: true,
                  ),
                  displayPrice: 1.10,
                  costPrice: 0.99,
                  marginText: '+10% للزبون',
                  sypPriceText: '≈ 14,500 ل.س',
                  balance: 5.0,
                  appName: 'ببجي موبايل',
                  appIconUrl: 'assets/cards/pubg-mobile.png',
                  onTap: () {},
                ),
                ProductListCard(
                  product: _makeProduct(
                    id: 'p2',
                    name: 'بطاقة كود رقمي 10 دولار',
                    type: 'codes',
                    salePrice: 10.0,
                    availableCodesCount: 15,
                  ),
                  displayPrice: 10.0,
                  balance: 2.0,
                  onTap: () {},
                ),
                ProductListCard(
                  product: _makeProduct(
                    id: 'p3',
                    name: 'تفعيل باقة يدوية خاصة',
                    type: 'manual',
                    salePrice: 3.50,
                    description: 'تُسلَّم عبر الدردشة مع المشرف',
                  ),
                  displayPrice: 3.50,
                  balance: 10.0,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await w.pump();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is ClipPath && widget.clipper is TicketPassClipper,
      ),
      findsNWidgets(3),
    );
    expect(find.text('فوري آلي'), findsOneWidget);
    expect(find.text('كود رقمي'), findsOneWidget);
    expect(find.text('تنفيذ يدوي'), findsOneWidget);
    expect(find.text('سعر مخفّض'), findsOneWidget);
    expect(find.text('+10% للزبون'), findsOneWidget);
    expect(find.text('شحن'), findsNWidgets(2));
    expect(find.text('رصيد ناقص'), findsOneWidget);

    Object? error;
    final List<String> overflows = <String>[];
    while ((error = w.takeException()) != null) {
      final text = error.toString();
      if (!text.contains('google_fonts') &&
          (text.contains('overflow') || text.contains('OVERFLOW'))) {
        overflows.add(text);
      }
    }
    expect(overflows, isEmpty);
  });
}
