import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/main.dart';

void main() {
  testWidgets('ChargeXApp builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChargeXApp());
    expect(find.byType(ChargeXApp), findsOneWidget);
  });
}
