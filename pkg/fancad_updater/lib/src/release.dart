import 'semver.dart';

/// The desktop systems the updater ships installers for.
enum UpdatePlatform { macos, windows, linux }

/// Artifact architectures. [universal] is a single binary that runs anywhere.
enum UpdateArch { x64, arm64, universal }

/// One downloadable file attached to a release.
///
/// Assets carry no hash of their own: the signed manifest is the only source
/// of digests the updater trusts.
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, this.size});

  final String name;
  final Uri url;
  final int? size;

  @override
  String toString() => 'ReleaseAsset($name)';
}

/// A published release, normalised across feeds.
class ReleaseInfo {
  const ReleaseInfo({
    required this.sourceId,
    required this.version,
    this.notes = '',
    this.publishedAt,
    this.prerelease = false,
    this.assets = const [],
  });

  /// Which [UpdateSource] this came from, so a failure can name it.
  final String sourceId;

  /// The tag without a leading `v`, e.g. `0.6.0`.
  final String version;

  /// Markdown changelog. The feed is not signed, so this is display text, not
  /// part of the verified update.
  final String notes;
  final DateTime? publishedAt;
  final bool prerelease;
  final List<ReleaseAsset> assets;

  SemanticVersion? get semanticVersion => SemanticVersion.tryParse(version);

  ReleaseAsset? assetNamed(String name) {
    for (final asset in assets) {
      if (asset.name == name) return asset;
    }
    return null;
  }

  @override
  String toString() => 'ReleaseInfo($version from $sourceId)';
}
