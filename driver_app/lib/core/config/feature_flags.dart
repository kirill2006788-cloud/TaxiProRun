abstract final class FeatureFlags {
  static const bool enableDemoMode = bool.fromEnvironment(
    'ENABLE_DEMO_MODE',
    defaultValue: false,
  );
}
