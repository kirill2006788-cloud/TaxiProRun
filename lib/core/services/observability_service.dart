/// Crash / error reporting stubs gated by dart-define.
///
/// - [SENTRY_DSN]: when non-empty, ready for `sentry_flutter` (ops adds package).
/// - [CRASHLYTICS_ENABLED]: when true **and** Firebase platform files exist,
///   ready for `firebase_crashlytics`.
///
/// Without packages / DSN this service is a safe no-op so CI and local builds
/// do not require secrets.
library;

import 'package:flutter/foundation.dart';

class ObservabilityService {
  ObservabilityService._();

  static final ObservabilityService instance = ObservabilityService._();

  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  static const String sentryEnvironment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: 'production',
  );

  static const bool crashlyticsEnabled = bool.fromEnvironment(
    'CRASHLYTICS_ENABLED',
    defaultValue: false,
  );

  static const bool firebaseEnabled = bool.fromEnvironment(
    'FIREBASE_ENABLED',
    defaultValue: false,
  );

  bool _ready = false;
  bool get isReady => _ready;
  bool get sentryConfigured => sentryDsn.trim().isNotEmpty;
  bool get crashlyticsConfigured =>
      crashlyticsEnabled && firebaseEnabled;

  /// Call once from [main] before [runApp].
  Future<void> init() async {
    if (_ready) return;

    if (sentryConfigured) {
      // Ops: `flutter pub add sentry_flutter` then:
      // await SentryFlutter.init((o) { o.dsn = sentryDsn; o.environment = sentryEnvironment; }, appRunner: () {});
      debugPrint(
        'ObservabilityService: SENTRY_DSN set — add sentry_flutter to enable reporting '
        '(env=$sentryEnvironment). Stub active.',
      );
    }

    if (crashlyticsConfigured) {
      // Ops: `flutter pub add firebase_crashlytics` + Firebase Console.
      // FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      debugPrint(
        'ObservabilityService: CRASHLYTICS_ENABLED + FIREBASE_ENABLED — '
        'add firebase_crashlytics to enable. Stub active.',
      );
    }

    _ready = true;
  }

  /// Non-fatal breadcrumb / message (no-op until SDK wired).
  void captureMessage(String message, {Map<String, Object?>? extras}) {
    if (!sentryConfigured && !crashlyticsConfigured) return;
    debugPrint('ObservabilityService.message: $message ${extras ?? {}}');
  }

  /// Record error (no-op until SDK wired).
  void captureException(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?>? extras,
  }) {
    if (!sentryConfigured && !crashlyticsConfigured) {
      if (kDebugMode) {
        debugPrint('ObservabilityService.exception: $error');
      }
      return;
    }
    debugPrint(
      'ObservabilityService.exception: $error\n$stackTrace\n${extras ?? {}}',
    );
  }
}
