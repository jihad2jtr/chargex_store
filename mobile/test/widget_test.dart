import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/main.dart';

void main() {
  testWidgets('JGOApp builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JGOApp());
    expect(find.byType(JGOApp), findsOneWidget);
  });
}
