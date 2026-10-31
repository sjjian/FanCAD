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

  /// The shape the app writes to its local release cache.
  Map<String, Object?> toJson() => {
    'name': name,
    'url': url.toString(),
    'size': size,
  };

  /// Reads a cache entry. A malformed entry is skipped, not fatal: the cache
  /// only saves the next network check, it is not an update source.
  static ReleaseAsset? tryFromJson(Object? raw) {
    if (raw is! Map<Object?, Object?>) return null;
    final name = raw['name'];
    final url = raw['url'];
    if (name is! String || url is! String) return null;
    final parsed = Uri.tryParse(url);
    if (parsed == null) return null;
    final size = raw['size'];
    return ReleaseAsset(
      name: name,
      url: parsed,
      size: size is num ? size.toInt() : null,
    );
  }

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

  /// The shape the app writes to its local release cache.
  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'version': version,
    'notes': notes,
    'publishedAt': publishedAt?.toIso8601String(),
    if (prerelease) 'prerelease': true,
    'assets': [for (final asset in assets) asset.toJson()],
  };

  /// Reads the cache written by [toJson].
  ///
  /// Returns null when the entry cannot describe a release: a corrupt cache
  /// must only cost the next network check, never a crash at startup.
  static ReleaseInfo? tryFromJson(Object? raw) {
    if (raw is! Map<Object?, Object?>) return null;
    final sourceId = raw['sourceId'];
    final version = raw['version'];
    if (sourceId is! String || version is! String) return null;
    if (SemanticVersion.tryParse(version) == null) return null;

    final assets = <ReleaseAsset>[];
    final rawAssets = raw['assets'];
    if (rawAssets is List<Object?>) {
      for (final item in rawAssets) {
        final asset = ReleaseAsset.tryFromJson(item);
        if (asset != null) assets.add(asset);
      }
    }

    final notes = raw['notes'];
    final publishedAt = raw['publishedAt'];
    return ReleaseInfo(
      sourceId: sourceId,
      version: version,
      notes: notes is String ? notes : '',
      publishedAt: publishedAt is String
          ? DateTime.tryParse(publishedAt)
          : null,
      prerelease: raw['prerelease'] == true,
      assets: List.unmodifiable(assets),
    );
  }

  @override
  String toString() => 'ReleaseInfo($version from $sourceId)';
}
