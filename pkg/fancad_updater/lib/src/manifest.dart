import 'dart:convert';

import 'asset_match.dart';
import 'release.dart';
import 'semver.dart';

/// Name of the signed release manifest inside a release.
const String manifestFileName = 'manifest.json';

/// Detached RSA signature over [manifestFileName], base64 encoded.
const String manifestSignatureFileName = 'manifest.json.sig';

/// The manifest is present but cannot be trusted or read.
class ManifestException implements Exception {
  const ManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ManifestAsset {
  const ManifestAsset({required this.name, required this.sha256, this.size});

  final String name;

  /// Lowercase hex SHA-256 of the asset.
  final String sha256;
  final int? size;

  @override
  String toString() => 'ManifestAsset($name)';
}

/// The signed description of one release.
///
/// This is the only source of hashes the downloader trusts: the release feed
/// supplies download URLs, but the bytes those URLs return must match this
/// document.
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    this.notes = '',
    this.publishedAt,
    this.assets = const [],
  });

  final String version;
  final String notes;
  final DateTime? publishedAt;
  final List<ManifestAsset> assets;

  SemanticVersion get semanticVersion => SemanticVersion.parse(version);

  ManifestAsset? assetNamed(String name) {
    for (final asset in assets) {
      if (asset.name == name) return asset;
    }
    return null;
  }

  /// The best artifact for this host, scored the same way as feed assets.
  ManifestAsset? assetFor({
    required UpdatePlatform platform,
    required UpdateArch arch,
  }) {
    ManifestAsset? best;
    var bestScore = -1;
    for (final asset in assets) {
      final score = scoreReleaseAsset(
        asset.name,
        platform: platform,
        arch: arch,
      );
      if (score == null) continue;
      if (score > bestScore) {
        best = asset;
        bestScore = score;
      }
    }
    return best;
  }

  /// Parses the exact bytes that were signed. Never re-serialise before
  /// verifying, or the signature will not match.
  static UpdateManifest parse(List<int> bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const ManifestException('The manifest is not UTF-8');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const ManifestException('The manifest is not valid JSON');
    }
    if (decoded is! Map<Object?, Object?>) {
      throw const ManifestException('The manifest is not an object');
    }

    final schema = decoded['schema'];
    if (schema != null && schema != 1) {
      throw ManifestException('Unsupported manifest schema $schema');
    }

    final version = _string(decoded['version']);
    if (version == null || SemanticVersion.tryParse(version) == null) {
      throw const ManifestException('The manifest has no readable version');
    }

    final rawAssets = decoded['assets'];
    if (rawAssets is! List<Object?>) {
      throw const ManifestException('The manifest has no asset list');
    }

    final assets = <ManifestAsset>[];
    for (final item in rawAssets) {
      if (item is! Map<Object?, Object?>) {
        throw const ManifestException('An asset entry is not an object');
      }
      final name = _string(item['name']);
      final digest = _string(item['sha256'])?.toLowerCase();
      if (name == null) {
        throw const ManifestException('An asset entry has no name');
      }
      if (digest == null || !_isSha256(digest)) {
        throw ManifestException('Asset $name has no valid sha256');
      }
      for (final existing in assets) {
        if (existing.name == name) {
          throw ManifestException('Asset $name is listed twice');
        }
      }
      final rawSize = item['size'];
      assets.add(
        ManifestAsset(
          name: name,
          sha256: digest,
          size: rawSize is num && rawSize >= 0 ? rawSize.toInt() : null,
        ),
      );
    }

    return UpdateManifest(
      version: version,
      notes: _string(decoded['notes']) ?? '',
      publishedAt: DateTime.tryParse(_string(decoded['publishedAt']) ?? ''),
      assets: List.unmodifiable(assets),
    );
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _isSha256(String value) {
    if (value.length != 64) return false;
    for (final unit in value.codeUnits) {
      final digit = unit >= 0x30 && unit <= 0x39;
      final lower = unit >= 0x61 && unit <= 0x66;
      if (!digit && !lower) return false;
    }
    return true;
  }
}
