import 'dart:convert';

import '../feed.dart';
import '../release.dart';
import '../source.dart';
import '../transport.dart';
import 'json.dart';

/// `GET /repos/:owner/:repo/releases/latest`.
class GithubReleaseFeed implements ReleaseFeed {
  GithubReleaseFeed({required this.source, required this.transport});

  final UpdateSource source;
  final HttpTransport transport;

  @override
  String get sourceId => source.id;

  @override
  Future<ReleaseInfo?> latest() async {
    final uri = source.latestReleaseUri;
    final response = await transport.get(
      uri,
      headers: source.headers,
      timeout: source.requestTimeout,
    );
    if (response.statusCode == 404) return null;
    if (!response.isSuccess) {
      throw FeedException(
        'GitHub answered HTTP ${response.statusCode}',
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
        'GitHub returned malformed JSON',
        sourceId: source.id,
        uri: uri,
      );
    }
    if (decoded is! Map<Object?, Object?>) {
      throw FeedException(
        'GitHub returned an unexpected payload',
        sourceId: source.id,
        uri: uri,
      );
    }
    return _parse(decoded, uri);
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
    return ReleaseInfo(
      sourceId: source.id,
      version: normaliseTag(tag),
      notes: stringField(json, 'body') ?? '',
      publishedAt:
          dateField(json, 'published_at') ?? dateField(json, 'created_at'),
      prerelease: boolField(json, 'prerelease'),
      assets: assetList(json['assets']),
    );
  }
}
