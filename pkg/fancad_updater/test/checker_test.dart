import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

import 'support/fake_transport.dart';

const _sources = [
  UpdateSource(
    id: 'github',
    kind: SourceKind.github,
    owner: 'sjjian',
    repo: 'FanCAD',
  ),
  UpdateSource(
    id: 'gitee',
    kind: SourceKind.gitee,
    owner: 'sjjian',
    repo: 'FanCAD',
    priority: 1,
  ),
];

ReleaseInfo _release(
  String version, {
  String sourceId = 'github',
  bool withManifest = true,
}) => ReleaseInfo(
  sourceId: sourceId,
  version: version,
  assets: [
    if (withManifest) ...[
      ReleaseAsset(
        name: manifestFileName,
        url: Uri.parse('https://example.com/manifest.json'),
      ),
      ReleaseAsset(
        name: manifestSignatureFileName,
        url: Uri.parse('https://example.com/manifest.json.sig'),
      ),
    ],
  ],
);

UpdateChecker _checker(BuildInfo build, Map<String, FakeFeed> feeds) =>
    UpdateChecker(
      sources: _sources,
      build: build,
      transport: FakeTransport(),
      feedFactory: (source) => feeds[source.id]!,
    );

void main() {
  const current = BuildInfo(version: '0.5.0');

  test('a newer release is available and the fallback is not asked', () async {
    final github = FakeFeed(sourceId: 'github', release: _release('0.6.0'));
    final gitee = FakeFeed(sourceId: 'gitee', release: _release('0.6.0'));
    final result = await _checker(current, {
      'github': github,
      'gitee': gitee,
    }).check();
    expect(result.status, CheckStatus.available);
    expect(result.hasUpdate, isTrue);
    expect(result.release?.version, '0.6.0');
    expect(result.attempts, hasLength(1));
    expect(gitee.calls, 0);
  });

  test('when the first source is current, later sources are skipped', () async {
    final github = FakeFeed(sourceId: 'github', release: _release('0.5.0'));
    final gitee = FakeFeed(sourceId: 'gitee', release: _release('0.9.0'));
    final result = await _checker(current, {
      'github': github,
      'gitee': gitee,
    }).check();
    expect(result.status, CheckStatus.upToDate);
    expect(result.hasUpdate, isFalse);
    expect(gitee.calls, 0);
  });

  test('a failing primary falls through to the fallback', () async {
    final github = FakeFeed(
      sourceId: 'github',
      error: const FeedException('timeout', sourceId: 'github'),
    );
    final gitee = FakeFeed(
      sourceId: 'gitee',
      release: _release('0.6.0', sourceId: 'gitee'),
    );
    final result = await _checker(current, {
      'github': github,
      'gitee': gitee,
    }).check();
    expect(result.status, CheckStatus.available);
    expect(result.release?.sourceId, 'gitee');
    expect(result.attempts, hasLength(2));
    expect(result.attempts.first.outcome, AttemptOutcome.failed);
    expect(result.attempts.first.error, 'timeout');
    expect(result.attempts.last.outcome, AttemptOutcome.answered);
    expect(result.diagnostic, contains('github: timeout'));
  });

  test('a repository without a release counts as a miss', () async {
    final github = FakeFeed(sourceId: 'github');
    final gitee = FakeFeed(sourceId: 'gitee', release: _release('0.6.0'));
    final result = await _checker(current, {
      'github': github,
      'gitee': gitee,
    }).check();
    expect(result.status, CheckStatus.available);
    expect(result.attempts.first.outcome, AttemptOutcome.noRelease);
  });

  test('a release without a signed manifest is skipped', () async {
    final github = FakeFeed(
      sourceId: 'github',
      release: _release('0.6.0', withManifest: false),
    );
    final gitee = FakeFeed(
      sourceId: 'gitee',
      release: _release('0.6.0', sourceId: 'gitee'),
    );
    final result = await _checker(current, {
      'github': github,
      'gitee': gitee,
    }).check();
    expect(result.status, CheckStatus.available);
    expect(result.attempts.first.outcome, AttemptOutcome.failed);
    expect(result.attempts.first.error, 'No signed manifest');
    expect(result.release?.sourceId, 'gitee');
  });

  test('when every source fails the result says so', () async {
    final github = FakeFeed(
      sourceId: 'github',
      error: const FeedException('timeout', sourceId: 'github'),
    );
    final gitee = FakeFeed(
      sourceId: 'gitee',
      error: const FeedException('reset', sourceId: 'gitee'),
    );
    final result = await _checker(current, {
      'github': github,
      'gitee': gitee,
    }).check();
    expect(result.status, CheckStatus.failed);
    expect(result.release, isNull);
    expect(result.canRetry, isTrue);
    expect(result.diagnostic, 'github: timeout · gitee: reset');
  });

  test('a build without a version skips the network entirely', () async {
    final github = FakeFeed(sourceId: 'github', release: _release('0.6.0'));
    final result = await _checker(
      const BuildInfo(version: BuildInfo.devVersion),
      {'github': github, 'gitee': FakeFeed()},
    ).check();
    expect(result.status, CheckStatus.unsupported);
    expect(github.calls, 0);
  });

  test('an unreadable tag is treated as a source failure', () async {
    final github = FakeFeed(sourceId: 'github', release: _release('nightly'));
    final gitee = FakeFeed(
      sourceId: 'gitee',
      release: _release('0.6.0', sourceId: 'gitee'),
    );
    final result = await _checker(current, {
      'github': github,
      'gitee': gitee,
    }).check();
    expect(result.status, CheckStatus.available);
    expect(result.attempts.first.outcome, AttemptOutcome.failed);
    expect(result.release?.sourceId, 'gitee');
  });
}
