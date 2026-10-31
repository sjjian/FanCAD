import 'dart:io';

import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

const _mac = HostEnvironment(
  platform: UpdatePlatform.macos,
  arch: UpdateArch.arm64,
  executablePath: '/Applications/FanCAD.app/Contents/MacOS/fancad',
);

const _windows = HostEnvironment(
  platform: UpdatePlatform.windows,
  arch: UpdateArch.x64,
  executablePath: r'C:\Users\me\AppData\Local\Programs\FanCAD\fancad.exe',
);

const _linux = HostEnvironment(
  platform: UpdatePlatform.linux,
  arch: UpdateArch.x64,
  executablePath: '/home/me/fan/FanCAD/fancad',
);

const _planner = InstallPlanner();

InstallPlan _planFor(
  HostEnvironment host, {
  bool writable = true,
  String name = 'fancad-macos-arm64-0.6.0.dmg',
}) {
  return _planner.plan(
    asset: ReleaseAsset(
      name: name,
      url: Uri.parse('https://example.com/$name'),
    ),
    artifact: File('/tmp/$name'),
    host: host,
    workDirectory: Directory('/tmp/fancad-work'),
    processId: 4242,
    targetWritable: writable,
  );
}

void main() {
  group('macOS', () {
    test('opens the disk image and lets the user drag it across', () {
      final plan = _planFor(_mac);
      expect(plan.mode, InstallMode.runInstaller);
      expect(plan.canInstall, isTrue);
      expect(plan.canInstall, isTrue);
      expect(plan.helper, isNull);
      final step = plan.steps.single;
      expect(step.executable, '/usr/bin/open');
      expect(step.arguments, ['/tmp/fancad-macos-arm64-0.6.0.dmg']);
      expect(step.detached, isFalse);
    });
  });

  group('Windows', () {
    test('opens the installer wizard, which owns the restart', () {
      final plan = _planFor(
        _windows,
        name: 'fancad-windows-setup-x64-0.6.0.exe',
      );
      expect(plan.mode, InstallMode.runInstaller);
      expect(plan.helper, isNull);
      expect(plan.canInstall, isTrue);
      final step = plan.steps.single;
      expect(step.executable, '/tmp/fancad-windows-setup-x64-0.6.0.exe');
      expect(step.arguments, hasLength(1));
      expect(step.arguments.single, startsWith('/LOG='));
      expect(step.arguments, isNot(contains('/ALLUSERS')));
      expect(step.detached, isTrue);
    });

    test('an all-users install updates in place with /ALLUSERS', () {
      final plan = _planFor(
        const HostEnvironment(
          platform: UpdatePlatform.windows,
          arch: UpdateArch.x64,
          executablePath: r'C:\Program Files\FanCAD\fancad.exe',
        ),
        name: 'fancad-windows-setup-x64-0.6.0.exe',
      );
      expect(plan.mode, InstallMode.runInstaller);
      expect(plan.canInstall, isTrue);
      expect(plan.steps.single.arguments, contains('/ALLUSERS'));
      expect(plan.helper, isNull);
    });
  });

  group('Linux', () {
    test('unpacks the archive over the install folder', () {
      final plan = _planFor(_linux, name: 'fancad-linux-x64-0.6.0.tar.gz');
      expect(plan.mode, InstallMode.inPlace);
      expect(plan.canInstall, isTrue);
      final helper = plan.helper!;
      expect(helper.arguments, contains('/home/me/fan/FanCAD'));
      expect(helper.arguments, contains('fancad'));
      expect(helper.contents, contains('tar -xzf'));
      expect(helper.contents, contains('cp -a'));
      expect(helper.contents, contains(r'$target/$executable'));
    });

    test('a read-only folder falls back to reveal', () {
      final plan = _planFor(
        _linux,
        writable: false,
        name: 'fancad-linux-x64-0.6.0.tar.gz',
      );
      expect(plan.mode, InstallMode.reveal);
      expect(plan.revealReason, RevealReason.readOnly);
      // Nothing was installed, so the app must not quit.
      expect(plan.canInstall, isFalse);
    });
  });
}
