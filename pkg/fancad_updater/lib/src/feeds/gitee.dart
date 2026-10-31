import 'dart:convert';

import '../feed.dart';
import '../release.dart';
import '../source.dart';
import '../transport.dart';
import 'json.dart';

/// `GET /repos/:owner/:repo/releases/latest`, with a list fallback.
///
/// Gitee mirrors GitHub but its API differs in small ways and older
/// deployments do not expose the `latest` endpoint, so a 404 there is retried
/// against the list endpoint before the source is declared dead.
class GiteeReleaseFeed implements ReleaseFeed {
  GiteeReleaseFeed({required this.source, required this.transport});

  final UpdateSource source;
  final HttpTransport transport;

  @override
  String get sourceId => source.id;

  @override
  Future<ReleaseInfo?> latest() async {
    final response = await transport.get(
      source.latestReleaseUri,
      headers: source.headers,
      timeout: source.requestTimeout,
    );
    if (response.statusCode == 404) return _fromList();
    if (!response.isSuccess) {
      throw FeedException(
        'Gitee answered HTTP ${response.statusCode}',
        sourceId: source.id,
        statusCode: response.statusCode,
        uri: source.latestReleaseUri,
      );
    }
    final json = _decodeObject(response.text, source.latestReleaseUri);
    final release = _parse(json, source.latestReleaseUri);
    // A mirror can leave a prerelease as "latest"; the list endpoint is the
    // only place a final release is guaranteed to show up.
    if (release.prerelease) return _fromList();
    return release;
  }

  Future<ReleaseInfo?> _fromList() async {
    final uri = source.releaseListUri;
    final response = await transport.get(
      uri,
      headers: source.headers,
      timeout: source.requestTimeout,
    );
    if (response.statusCode == 404) return null;
    if (!response.isSuccess) {
      throw FeedException(
        'Gitee answered HTTP ${response.statusCode}',
        sourceId: source.id,
        statusCode: response.statusCode,
        uri: uri,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.text);
    } on FormatException {
      throw FeedException(
        'Gitee returned malformed JSON',
        sourceId: source.id,
        uri: uri,
      );
    }
    if (decoded is! List<Object?>) {
      throw FeedException(
        'Gitee returned an unexpected payload',
        sourceId: source.id,
        uri: uri,
      );
    }
    // Pick the highest stable version instead of trusting list order: the
    // query is a hint Gitee is free to ignore.
    ReleaseInfo? best;
    for (final item in decoded) {
      if (item is! Map<Object?, Object?>) continue;
      if (boolField(item, 'prerelease')) continue;
      final tag = stringField(item, 'tag_name');
      if (tag == null) continue;
      final release = _parse(item, uri);
      final version = release.semanticVersion;
      if (version == null) continue;
      final current = best?.semanticVersion;
      if (current == null || version > current) best = release;
    }
    return best;
  }

  Map<Object?, Object?> _decodeObject(String body, Uri uri) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw FeedException(
        'Gitee returned malformed JSON',
        sourceId: source.id,
        uri: uri,
      );
    }
    if (decoded is! Map<Object?, Object?>) {
      throw FeedException(
        'Gitee returned an unexpected payload',
        sourceId: source.id,
        uri: uri,
      );
    }
    return decoded;
  }

  ReleaseInfo _parse(Map<Object?, Object?> json, Uri uri) {
    final tag = stringField(json, 'tag_name');
    if (tag == null) {
      throw FeedException(
        'The release has no tag',
        sourceId: source.id,
        uri: uri,
      );
    }
    // Newer API versions use `assets`; some mirrors still return
    // `attach_files`. An empty `assets` array must not hide the latter.
    final assets = json['assets'];
    final rawAssets = assets is List<Object?> && assets.isNotEmpty
        ? assets
        : json['attach_files'];
    return ReleaseInfo(
      sourceId: source.id,
      version: normaliseTag(tag),
      notes: stringField(json, 'body') ?? '',
      publishedAt: dateField(json, 'created_at'),
      prerelease: boolField(json, 'prerelease'),
      assets: assetList(rawAssets),
    );
  }
}
