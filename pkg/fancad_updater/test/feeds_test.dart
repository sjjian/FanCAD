import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

import 'support/fake_transport.dart';

const _github = UpdateSource(
  id: 'github',
  kind: SourceKind.github,
  owner: 'sjjian',
  repo: 'FanCAD',
);

const _gitee = UpdateSource(
  id: 'gitee',
  kind: SourceKind.gitee,
  owner: 'sjjian',
  repo: 'FanCAD',
  priority: 1,
);

void main() {
  group('GitHub', () {
    test('normalises tag, notes and assets', () async {
      final transport = FakeTransport(
        responses: {
          _github.latestReleaseUri.toString(): HttpResponseData(
            statusCode: 200,
            body: utf8Bytes('''
{
  "tag_name": "v0.6.0",
  "body": "Fixes",
  "published_at": "2026-10-30T09:00:00Z",
  "prerelease": false,
  "assets": [
    {
      "name": "fancad-macos-arm64-0.6.0.dmg",
      "browser_download_url": "https://example.com/a.dmg",
      "size": 42
    },
    {"name": "SHA256SUMS", "browser_download_url": "https://example.com/SHA256SUMS"}
  ]
}
'''),
          ),
        },
      );
      final release = await GithubReleaseFeed(
        source: _github,
        transport: transport,
      ).latest();
      expect(release, isNotNull);
      expect(release!.version, '0.6.0');
      expect(release.notes, 'Fixes');
      expect(release.publishedAt, DateTime.utc(2026, 10, 30, 9));
      expect(release.assets, hasLength(2));
      expect(
        release.assetNamed('fancad-macos-arm64-0.6.0.dmg')?.url.toString(),
        'https://example.com/a.dmg',
      );
      expect(release.assetNamed('SHA256SUMS')?.name, 'SHA256SUMS');
    });

    test('a 404 means no release, not a failure', () async {
      final transport = FakeTransport(
        responses: {
          _github.latestReleaseUri.toString(): HttpResponseData(
            statusCode: 404,
            body: utf8Bytes('{}'),
          ),
        },
      );
      expect(
        await GithubReleaseFeed(source: _github, transport: transport).latest(),
        isNull,
      );
    });

    test('a server error is a FeedException', () async {
      final transport = FakeTransport(
        responses: {
          _github.latestReleaseUri.toString(): HttpResponseData(
            statusCode: 500,
            body: utf8Bytes('boom'),
          ),
        },
      );
      expect(
        GithubReleaseFeed(source: _github, transport: transport).latest(),
        throwsA(isA<FeedException>()),
      );
    });
  });

  group('Gitee', () {
    test('parses the latest endpoint', () async {
      final transport = FakeTransport(
        responses: {
          _gitee.latestReleaseUri.toString(): HttpResponseData(
            statusCode: 200,
            body: utf8Bytes('''
{
  "tag_name": "0.6.0",
  "body": "镜像说明",
  "created_at": "2026-10-30T09:00:00Z",
  "prerelease": false,
  "assets": [
    {"name": "fancad-linux-x64-0.6.0.tar.gz", "browser_download_url": "https://gitee.com/a.tar.gz"}
  ]
}
'''),
          ),
        },
      );
      final release = await GiteeReleaseFeed(
        source: _gitee,
        transport: transport,
      ).latest();
      expect(release!.version, '0.6.0');
      expect(release.notes, '镜像说明');
      expect(transport.getRequests, hasLength(1));
    });

    test('falls back to attach_files when assets is empty', () async {
      final transport = FakeTransport(
        responses: {
          _gitee.latestReleaseUri.toString(): HttpResponseData(
            statusCode: 200,
            body: utf8Bytes('''
{
  "tag_name": "0.6.0",
  "assets": [],
  "attach_files": [
    {"name": "fancad-linux-x64-0.6.0.tar.gz", "browser_download_url": "https://gitee.com/a.tar.gz"}
  ]
}
'''),
          ),
        },
      );
      final release = await GiteeReleaseFeed(
        source: _gitee,
        transport: transport,
      ).latest();
      expect(release!.assets.single.name, 'fancad-linux-x64-0.6.0.tar.gz');
    });

    test('falls back to the list endpoint when latest is absent', () async {
      final transport = FakeTransport(
        responses: {
          _gitee.latestReleaseUri.toString(): HttpResponseData(
            statusCode: 404,
            body: utf8Bytes('{}'),
          ),
          _gitee.releaseListUri.toString(): HttpResponseData(
            statusCode: 200,
            body: utf8Bytes('''
[
  {"tag_name": "0.7.0-beta", "prerelease": true},
  {"tag_name": "v0.6.0", "body": "stable"}
]
'''),
          ),
        },
      );
      final release = await GiteeReleaseFeed(
        source: _gitee,
        transport: transport,
      ).latest();
      expect(release!.version, '0.6.0');
      expect(transport.getRequests, hasLength(2));
    });

    test('an empty list means no release', () async {
      final transport = FakeTransport(
        responses: {
          _gitee.latestReleaseUri.toString(): HttpResponseData(
            statusCode: 404,
            body: utf8Bytes('{}'),
          ),
          _gitee.releaseListUri.toString(): HttpResponseData(
            statusCode: 200,
            body: utf8Bytes('[]'),
          ),
        },
      );
      expect(
        await GiteeReleaseFeed(source: _gitee, transport: transport).latest(),
        isNull,
      );
    });

    test('picks the highest stable version whatever the list order', () async {
      final transport = FakeTransport(
        responses: {
          _gitee.latestReleaseUri.toString(): HttpResponseData(
            statusCode: 404,
            body: utf8Bytes('{}'),
          ),
          _gitee.releaseListUri.toString(): HttpResponseData(
            statusCode: 200,
            body: utf8Bytes(
              '[{"tag_name": "0.5.0"}, {"tag_name": "0.6.0"}, '
              '{"tag_name": "0.4.0"}]',
            ),
          ),
        },
      );
      final release = await GiteeReleaseFeed(
        source: _gitee,
        transport: transport,
      ).latest();
      expect(release!.version, '0.6.0');
    });

    test('a prerelease marked latest falls back to the list', () async {
      final transport = FakeTransport(
        responses: {
          _gitee.latestReleaseUri.toString(): HttpResponseData(
            statusCode: 200,
            body: utf8Bytes('{"tag_name": "0.7.0-beta", "prerelease": true}'),
          ),
          _gitee.releaseListUri.toString(): HttpResponseData(
            statusCode: 200,
            body: utf8Bytes(
              '[{"tag_name": "0.7.0-beta", "prerelease": true}, '
              '{"tag_name": "0.6.0", "prerelease": false}]',
            ),
          ),
        },
      );
      final release = await GiteeReleaseFeed(
        source: _gitee,
        transport: transport,
      ).latest();
      expect(release!.version, '0.6.0');
      expect(transport.getRequests, hasLength(2));
    });
  });
}
