import 'semver.dart';

/// Version metadata baked into a build by `--dart-define`.
///
/// `flutter build` does not expose the pubspec version to Dart, so the release
/// workflow passes it explicitly. A local `flutter run` has no defines and
/// reports [devVersion]; the UI uses that to hide the update controls rather
/// than offering an upgrade from a version nobody published.
class BuildInfo {
  const BuildInfo({
    required this.version,
    this.buildNumber = 0,
    this.channel = 'stable',
    this.commit = '',
    this.builtAt,
  });

  final String version;
  final int buildNumber;
  final String channel;
  final String commit;
  final DateTime? builtAt;

  static const String devVersion = '0.0.0-dev';

  static const String versionKey = 'FANCAD_VERSION';
  static const String buildNumberKey = 'FANCAD_BUILD_NUMBER';
  static const String channelKey = 'FANCAD_CHANNEL';
  static const String commitKey = 'FANCAD_COMMIT';
  static const String builtAtKey = 'FANCAD_BUILD_TIME';

  /// The values the release workflow passes to `flutter build`.
  factory BuildInfo.fromEnvironment() {
    const rawVersion = String.fromEnvironment(
      versionKey,
      defaultValue: devVersion,
    );
    const rawBuildNumber = String.fromEnvironment(buildNumberKey);
    const rawChannel = String.fromEnvironment(
      channelKey,
      defaultValue: 'stable',
    );
    const rawCommit = String.fromEnvironment(commitKey);
    const rawBuiltAt = String.fromEnvironment(builtAtKey);
    final buildNumber = int.tryParse(rawBuildNumber);
    final builtAt = DateTime.tryParse(rawBuiltAt);
    return BuildInfo(
      version: rawVersion.trim().isEmpty ? devVersion : rawVersion.trim(),
      buildNumber: buildNumber ?? 0,
      channel: rawChannel.trim().isEmpty ? 'stable' : rawChannel.trim(),
      commit: rawCommit.trim(),
      builtAt: builtAt,
    );
  }

  SemanticVersion? get semantic => SemanticVersion.tryParse(version);

  bool get isDevelopment => version == devVersion || semantic == null;

  String get display => buildNumber > 0 ? '$version ($buildNumber)' : version;

  String get shortCommit => commit.length > 7 ? commit.substring(0, 7) : commit;
}
