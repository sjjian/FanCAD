import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late UpdateManifest manifest;

  setUpAll(() async {
    manifest = UpdateManifest.parse(await fixtureBytes('manifest.json'));
  });

  test('reads the signed fixture', () {
    expect(manifest.version, '0.6.0');
    expect(manifest.notes, 'Test release');
    expect(manifest.publishedAt, DateTime.utc(2026, 10, 30, 9));
    expect(manifest.assets, hasLength(3));
    expect(manifest.semanticVersion, SemanticVersion.parse('0.6.0'));
  });

  test('selects the host asset by name and architecture', () {
    expect(
      manifest
          .assetFor(platform: UpdatePlatform.macos, arch: UpdateArch.arm64)
          ?.name,
      'fancad-macos-arm64-0.6.0.dmg',
    );
    expect(
      manifest
          .assetFor(platform: UpdatePlatform.linux, arch: UpdateArch.x64)
          ?.name,
      'fancad-linux-x64-0.6.0.tar.gz',
    );
    expect(manifest.assetNamed('fancad-windows-setup-x64-0.6.0.exe')?.size, 13);
  });

  test('returns null when the host has no asset', () {
    expect(
      manifest.assetFor(
        platform: UpdatePlatform.windows,
        arch: UpdateArch.arm64,
      ),
      isNull,
    );
  });

  test('rejects a malformed manifest', () {
    expect(
      () => UpdateManifest.parse('{'.codeUnits),
      throwsA(isA<ManifestException>()),
    );
    expect(
      () => UpdateManifest.parse('{"assets": []}'.codeUnits),
      throwsA(isA<ManifestException>()),
    );
  });

  test('rejects a bad digest and duplicate names', () {
    const body = '''
{"schema": 1, "version": "0.6.0", "assets": [
  {"name": "fancad-macos-arm64-0.6.0.dmg", "sha256": "not-a-digest"}
]}''';
    expect(
      () => UpdateManifest.parse(body.codeUnits),
      throwsA(isA<ManifestException>()),
    );

    final digest = 'a' * 64;
    final duplicated =
        '''
{"schema": 1, "version": "0.6.0", "assets": [
  {"name": "fancad-macos-arm64-0.6.0.dmg", "sha256": "$digest"},
  {"name": "fancad-macos-arm64-0.6.0.dmg", "sha256": "$digest"}
]}''';
    expect(
      () => UpdateManifest.parse(duplicated.codeUnits),
      throwsA(isA<ManifestException>()),
    );
  });

  test('rejects an unsupported schema', () {
    const body = '{"schema": 2, "version": "0.6.0", "assets": []}';
    expect(
      () => UpdateManifest.parse(body.codeUnits),
      throwsA(isA<ManifestException>()),
    );
  });
}
