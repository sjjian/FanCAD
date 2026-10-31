import 'dart:io';

import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

class FakeRunner implements ProcessRunner {
  final List<String> calls = [];

  @override
  Future<ProcessOutcome> run(
    String executable,
    List<String> arguments, {
    bool detached = false,
  }) async {
    calls.add(
      '$executable ${arguments.join(' ')}${detached ? ' [detached]' : ''}',
    );
    return const ProcessOutcome(exitCode: 0);
  }
}

void main() {
  late Directory temp;
  late FakeRunner runner;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('fancad-executor-test');
    runner = FakeRunner();
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('opens the downloaded disk image', () async {
    const host = HostEnvironment(
      platform: UpdatePlatform.macos,
      arch: UpdateArch.arm64,
      executablePath: '/Applications/FanCAD.app/Contents/MacOS/fancad',
    );
    final plan = const InstallPlanner().plan(
      asset: ReleaseAsset(
        name: 'fancad-macos-arm64-0.6.0.dmg',
        url: Uri.parse('https://example.com/a.dmg'),
      ),
      artifact: File('/tmp/a.dmg'),
      host: host,
      workDirectory: Directory('/tmp/work'),
      processId: 1,
    );

    await InstallExecutor(host: host, runner: runner).run(plan);

    expect(runner.calls.single, '/usr/bin/open /tmp/a.dmg');
  });

  test('writes the Linux helper and starts it detached', () async {
    const host = HostEnvironment(
      platform: UpdatePlatform.linux,
      arch: UpdateArch.x64,
      executablePath: '/home/me/fan/FanCAD/fancad',
    );
    final plan = const InstallPlanner().plan(
      asset: ReleaseAsset(
        name: 'fancad-linux-x64-0.6.0.tar.gz',
        url: Uri.parse('https://example.com/a.tar.gz'),
      ),
      artifact: File('/tmp/a.tar.gz'),
      host: host,
      workDirectory: Directory('${temp.path}/work'),
      processId: 99,
    );

    await InstallExecutor(host: host, runner: runner).run(plan);

    final script = File(plan.helper!.path);
    expect(await script.exists(), isTrue);
    expect(await script.readAsString(), contains('tar -xzf'));
    expect(runner.calls.single, contains('[detached]'));
    expect(runner.calls.single, contains('fancad-install.sh'));
  });

  test('reveals the download instead of installing', () async {
    const host = HostEnvironment(
      platform: UpdatePlatform.macos,
      arch: UpdateArch.arm64,
      executablePath: '/Applications/FanCAD.app/Contents/MacOS/fancad',
    );
    final artifact = File('${temp.path}/fancad-macos-arm64-0.6.0.dmg');
    await artifact.writeAsBytes(const [0]);
    final plan = InstallPlan.reveal(
      path: artifact.path,
      reason: RevealReason.readOnly,
      summary: 'read only',
    );

    await InstallExecutor(host: host, runner: runner).run(plan);

    expect(runner.calls.single, 'open -R ${artifact.path}');
  });

  test('a missing download reveals its folder', () async {
    const host = HostEnvironment(
      platform: UpdatePlatform.macos,
      arch: UpdateArch.arm64,
      executablePath: '/Applications/FanCAD.app/Contents/MacOS/fancad',
    );
    final plan = InstallPlan.reveal(
      path: '${temp.path}/gone.dmg',
      reason: RevealReason.readOnly,
      summary: 'gone',
    );

    await InstallExecutor(host: host, runner: runner).run(plan);

    expect(runner.calls.single, 'open ${temp.path}');
  });

  test('starts a detached installer and returns immediately', () async {
    const host = HostEnvironment(
      platform: UpdatePlatform.windows,
      arch: UpdateArch.x64,
      executablePath: r'C:\Users\me\AppData\Local\Programs\FanCAD\fancad.exe',
    );
    final plan = const InstallPlanner().plan(
      asset: ReleaseAsset(
        name: 'fancad-windows-setup-x64-0.6.0.exe',
        url: Uri.parse('https://example.com/setup.exe'),
      ),
      artifact: File(r'C:\updates\setup.exe'),
      host: host,
      workDirectory: Directory(r'C:\updates'),
      processId: 1,
    );

    await InstallExecutor(host: host, runner: runner).run(plan);

    expect(runner.calls.single, contains('setup.exe'));
    expect(runner.calls.single, contains('[detached]'));
  });

  test('a plan with nothing to run is an error, not a silent no-op', () async {
    const host = HostEnvironment(
      platform: UpdatePlatform.linux,
      arch: UpdateArch.x64,
      executablePath: '/home/me/fan/FanCAD/fancad',
    );
    const plan = InstallPlan(mode: InstallMode.inPlace, summary: 'empty');

    await expectLater(
      InstallExecutor(host: host, runner: runner).run(plan),
      throwsA(isA<ProcessRunException>()),
    );
  });
}
