/// Client feature flags via `--dart-define`.
///
/// Keep defaults safe for production store builds (incomplete features off).
abstract final class FeatureFlags {
  /// Test-only scripted trip. Store/release builds keep it hidden unless the
  /// APK is explicitly assembled with ENABLE_DEMO_MODE=true.
  static const bool enableDemoMode = bool.fromEnvironment(
    'ENABLE_DEMO_MODE',
    defaultValue: false,
  );

  /// Gallery → server avatar upload. Off until backend accepts multipart avatar.
  static const bool enableAvatarUpload = bool.fromEnvironment(
    'ENABLE_AVATAR_UPLOAD',
    defaultValue: true,
  );
}
