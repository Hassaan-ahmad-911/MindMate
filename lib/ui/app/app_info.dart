/// About the app build.
class AppInfo {
  const AppInfo._();

  /// The `version` in pubspec.yaml (without the build number). A test keeps
  /// the two in step; there is no package for reading it at run time.
  static const String version = '1.0.0';
}
