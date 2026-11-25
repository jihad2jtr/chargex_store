import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:layan_chargex/models/provider_model.dart';
import 'package:layan_chargex/providers/admin_provider.dart';
import 'package:layan_chargex/screens/admin/provider_products_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  setUpAll(() => HttpOverrides.global = _BlockedHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('فتح ProviderProductsScreen عبر Navigator لا يطلق setState/notifyListeners أثناء البناء', (
    WidgetTester w,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final provider = ProviderModel(
      id: 'pr1',
      name: 'Test Provider',
      baseUrl: '',
      apiKey: '',
    );

    await w.pumpWidget(
      ChangeNotifierProvider<AdminProvider>(
        create: (_) => AdminProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ProviderProductsScreen(provider: provider),
                      ),
                    );
                  },
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await w.tap(find.text('فتح'));
    await w.pump();
    await w.pump(const Duration(milliseconds: 400));

    Object? error;
    final List<String> buildErrors = <String>[];
    while ((error = w.takeException()) != null) {
      final text = error.toString();
      if (text.contains('called during build') ||
          text.contains('markNeedsBuild')) {
        buildErrors.add(text);
      }
    }
    expect(buildErrors, isEmpty);
  });
}
