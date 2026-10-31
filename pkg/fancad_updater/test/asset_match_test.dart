import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

void main() {
  group('scoreReleaseAsset', () {
    test('matches platform and architecture', () {
      expect(
        scoreReleaseAsset(
          'fancad-macos-arm64-0.6.0.dmg',
          platform: UpdatePlatform.macos,
          arch: UpdateArch.arm64,
        ),
        greaterThan(
          scoreReleaseAsset(
                'fancad-macos-x64-0.6.0.dmg',
                platform: UpdatePlatform.macos,
                arch: UpdateArch.arm64,
              ) ??
              -1,
        ),
      );
      expect(
        scoreReleaseAsset(
          'fancad-macos-arm64-0.6.0.dmg',
          platform: UpdatePlatform.macos,
          arch: UpdateArch.arm64,
        ),
        isNotNull,
      );
    });

    test('rejects another architecture', () {
      expect(
        scoreReleaseAsset(
          'fancad-macos-x64-0.6.0.dmg',
          platform: UpdatePlatform.macos,
          arch: UpdateArch.arm64,
        ),
        isNull,
      );
    });

    test('accepts a universal build for a concrete architecture', () {
      expect(
        scoreReleaseAsset(
          'fancad-macos-universal-0.6.0.dmg',
          platform: UpdatePlatform.macos,
          arch: UpdateArch.arm64,
        ),
        isNotNull,
      );
    });

    test('keeps legacy names without an architecture', () {
      expect(
        scoreReleaseAsset(
          'fancad-macos-0.5.0.dmg',
          platform: UpdatePlatform.macos,
          arch: UpdateArch.arm64,
        ),
        isNotNull,
      );
    });

    test('ignores other platforms and support files', () {
      expect(
        scoreReleaseAsset(
          'fancad-windows-setup-x64-0.6.0.exe',
          platform: UpdatePlatform.macos,
          arch: UpdateArch.arm64,
        ),
        isNull,
      );
      expect(
        scoreReleaseAsset(
          'SHA256SUMS',
          platform: UpdatePlatform.macos,
          arch: UpdateArch.arm64,
        ),
        isNull,
      );
      expect(
        scoreReleaseAsset(
          'fancad-macos-arm64-0.6.0.dmg.sig',
          platform: UpdatePlatform.macos,
          arch: UpdateArch.arm64,
        ),
        isNull,
      );
    });
  });
}
