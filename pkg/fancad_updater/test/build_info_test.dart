import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

void main() {
  test('display carries the build number', () {
    expect(const BuildInfo(version: '0.5.0').display, '0.5.0');
    expect(
      const BuildInfo(version: '0.5.0', buildNumber: 3).display,
      '0.5.0 (3)',
    );
  });

  test('a missing or malformed version is a development build', () {
    expect(
      const BuildInfo(version: BuildInfo.devVersion).isDevelopment,
      isTrue,
    );
    expect(const BuildInfo(version: 'local').isDevelopment, isTrue);
    expect(const BuildInfo(version: '0.5.0').isDevelopment, isFalse);
  });

  test('tests run without dart defines and stay in development', () {
    final build = BuildInfo.fromEnvironment();
    expect(build.version, BuildInfo.devVersion);
    expect(build.isDevelopment, isTrue);
    expect(build.buildNumber, 0);
  });
}
