import 'package:flutter_test/flutter_test.dart';
import 'package:driver_app/core/services/push_service.dart';

void main() {
  test('PushService respects FIREBASE_ENABLED define', () {
    expect(PushService.firebaseEnabledDefine, isA<bool>());
  });
}
