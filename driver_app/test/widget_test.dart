import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driver_app/core/api/api_config.dart';
import 'package:driver_app/core/api/app_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppServices initializes with live API by default', () async {
    SharedPreferences.setMockInitialValues({});
    AppServices.reset();

    final services = await AppServices.initialize();

    expect(ApiConfig.useMock, isFalse);
    expect(services.orders, isNotNull);
    expect(services.profile, isNotNull);
  });
}
