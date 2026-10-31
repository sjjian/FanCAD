import 'semver.dart';

/// Version metadata baked into a build.
///
/// Flutter writes `pubspec.yaml`'s version into the native bundle; the app
/// reads it back with `package_info_plus`. The `--dart-define` values are only
/// a fallback for tests and builds that cannot read the bundle.
class BuildInfo {
  const BuildInfo({required this.version, this.buildNumber = 0});

  final String version;
  final int buildNumber;

  static const String devVersion = '0.0.0-dev';

  static const String versionKey = 'FANCAD_VERSION';
  static const String buildNumberKey = 'FANCAD_BUILD_NUMBER';

  /// Fallback for tests and builds without a readable bundle.
  factory BuildInfo.fromEnvironment() {
    const rawVersion = String.fromEnvironment(
      versionKey,
      defaultValue: devVersion,
    );
    const rawBuildNumber = String.fromEnvironment(buildNumberKey);
    final buildNumber = int.tryParse(rawBuildNumber);
    return BuildInfo(
      version: rawVersion.trim().isEmpty ? devVersion : rawVersion.trim(),
      buildNumber: buildNumber ?? 0,
    );
  }

  SemanticVersion? get semantic => SemanticVersion.tryParse(version);

  bool get isDevelopment => version == devVersion || semantic == null;

  String get display => buildNumber > 0 ? '$version ($buildNumber)' : version;
}
