import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

void main() {
  final release = ReleaseInfo(
    sourceId: 'github',
    version: '0.6.0',
    notes: 'Fixes and features',
    publishedAt: DateTime.utc(2026, 10, 30, 9),
    prerelease: true,
    assets: [
      ReleaseAsset(
        name: 'fancad-macos-0.6.0.dmg',
        url: Uri.parse('https://example.com/fancad-macos-0.6.0.dmg'),
        size: 42,
      ),
    ],
  );

  test('a release survives the cache round trip', () {
    final decoded = ReleaseInfo.tryFromJson(release.toJson());

    expect(decoded, isNotNull);
    expect(decoded!.sourceId, 'github');
    expect(decoded.version, '0.6.0');
    expect(decoded.notes, 'Fixes and features');
    expect(decoded.publishedAt, DateTime.utc(2026, 10, 30, 9));
    expect(decoded.prerelease, isTrue);
    expect(decoded.assets, hasLength(1));
    expect(decoded.assets.single.name, 'fancad-macos-0.6.0.dmg');
    expect(decoded.assets.single.url, release.assets.single.url);
    expect(decoded.assets.single.size, 42);
  });

  test('a missing prerelease flag is a final release', () {
    final decoded = ReleaseInfo.tryFromJson({
      'sourceId': 'gitee',
      'version': '0.6.0',
      'assets': const <Object?>[],
    });
    expect(decoded, isNotNull);
    expect(decoded!.prerelease, isFalse);
    expect(decoded.publishedAt, isNull);
    expect(decoded.notes, isEmpty);
  });

  test('an unusable cache entry is rejected instead of throwing', () {
    expect(ReleaseInfo.tryFromJson(null), isNull);
    expect(ReleaseInfo.tryFromJson('not a map'), isNull);
    expect(ReleaseInfo.tryFromJson({'version': '0.6.0'}), isNull);
    expect(
      ReleaseInfo.tryFromJson({'sourceId': 'github', 'version': 'nightly'}),
      isNull,
    );
  });

  test('malformed assets are skipped and the rest survive', () {
    final decoded = ReleaseInfo.tryFromJson({
      'sourceId': 'github',
      'version': '0.6.0',
      'notes': 7,
      'publishedAt': 'not a date',
      'assets': [
        null,
        {'name': 'no-url'},
        {
          'name': 'fancad-linux-0.6.0.tar.gz',
          'url': 'https://e/x',
          'size': 7.9,
        },
      ],
    });

    expect(decoded, isNotNull);
    expect(decoded!.notes, isEmpty);
    expect(decoded.publishedAt, isNull);
    expect(decoded.assets, hasLength(1));
    expect(decoded.assets.single.size, 7);
  });
}
