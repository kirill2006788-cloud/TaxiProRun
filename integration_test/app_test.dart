// Integration test skeleton — КОРОЛИ ДОРОГ (passenger).
//
// Full flow (requires emulator/device + integration_test driver):
//   1. Launch app with USE_MOCK_API=true (default).
//   2. Complete onboarding if shown.
//   3. Enter test phone on auth screen → tap «Получить код».
//   4. Mock OTP verify (demo code from MockUserRepository) → home shell.
//   5. Assert route/home tab visible («Откуда» / bottom nav).
//
// Run locally:
//   flutter test integration_test/app_test.dart
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login mock → home', () {
    testWidgets(
      'placeholder — enable when running on device',
      (tester) async {
        // TODO: pump KoroliDorogApp, mock SharedPreferences session,
        // drive auth with MockUserRepository OTP, expect /home shell.
      },
      skip: true,
    );
  });
}
