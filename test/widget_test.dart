import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:koroli_dorog/features/auth/providers/auth_provider.dart';
import 'package:koroli_dorog/features/profile/providers/settings_provider.dart';
import 'package:koroli_dorog/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAppShell(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final settingsProvider = SettingsProvider();
    await settingsProvider.load();

    final authProvider = AuthProvider();
    await authProvider.load();

    await tester.pumpWidget(
      KoroliDorogApp(
        settingsProvider: settingsProvider,
        authProvider: authProvider,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('KoroliDorogApp shell mounts MaterialApp.router', (tester) async {
    await pumpAppShell(tester);

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('logged-out user lands on auth screen', (tester) async {
    await pumpAppShell(tester);

    expect(find.text('Вход по номеру телефона'), findsOneWidget);
    expect(find.text('Получить код'), findsOneWidget);
    expect(find.textContaining('политикой конфиденциальности'), findsWidgets);
  });
}
