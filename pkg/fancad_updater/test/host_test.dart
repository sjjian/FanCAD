import 'dart:io';

import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

void main() {
  group('dirname', () {
    test('handles POSIX paths', () {
      expect(
        dirname('/Applications/FanCAD.app/Contents/MacOS/fancad'),
        '/Applications/FanCAD.app/Contents/MacOS',
      );
      expect(dirname('/Applications'), '/');
      expect(dirname('/'), '/');
      expect(dirname('relative'), '.');
    });

    test('handles Windows paths and drive roots', () {
      expect(dirname(r'C:\Users\me\FanCAD\fancad.exe'), r'C:\Users\me\FanCAD');
      expect(dirname(r'C:\fancad.exe'), r'C:\');
      expect(dirname(r'C:/fancad.exe'), r'C:/');
    });
  });

  test('basename keeps the executable name', () {
    expect(basename(r'C:\Users\me\fancad.exe'), 'fancad.exe');
    expect(basename('/opt/fancad/fancad'), 'fancad');
  });

  test('joinPath keeps the separator style of the first part', () {
    expect(joinPath(r'C:\Users\me', 'log.txt'), r'C:\Users\me\log.txt');
    expect(joinPath('/tmp/work', 'log.txt'), '/tmp/work/log.txt');
  });

  test('safeFileName cannot escape the updates directory', () {
    expect(safeFileName('../../etc/passwd'), isNot(contains('/')));
    expect(safeFileName(r'..\..\windows\system32'), isNot(contains('\\')));
    expect(safeFileName(''), 'download');
  });

  test('isDirectoryWritable probes without leaving a file behind', () async {
    final directory = await Directory.systemTemp.createTemp('fancad-probe');
    addTearDown(() => directory.delete(recursive: true));

    expect(await isDirectoryWritable(directory), isTrue);
    expect(
      directory.listSync().where((entry) => entry.path.contains('probe')),
      isEmpty,
    );

    final missing = Directory('${directory.path}/nested/missing');
    expect(await isDirectoryWritable(missing), isFalse);
  });

  group('HostEnvironment', () {
    test('the install directory is the folder that holds the executable', () {
      const mac = HostEnvironment(
        platform: UpdatePlatform.macos,
        arch: UpdateArch.arm64,
        executablePath: '/Applications/FanCAD.app/Contents/MacOS/fancad',
      );
      expect(
        mac.executableDirectory.path,
        '/Applications/FanCAD.app/Contents/MacOS',
      );
      expect(mac.executableName, 'fancad');

      const linux = HostEnvironment(
        platform: UpdatePlatform.linux,
        arch: UpdateArch.x64,
        executablePath: '/home/me/fancad/fancad',
      );
      expect(linux.executableDirectory.path, '/home/me/fancad');
    });

    test('a Windows install under Program Files is machine-wide', () {
      const all = HostEnvironment(
        platform: UpdatePlatform.windows,
        arch: UpdateArch.x64,
        executablePath: r'C:\Program Files\FanCAD\fancad.exe',
      );
      const mine = HostEnvironment(
        platform: UpdatePlatform.windows,
        arch: UpdateArch.x64,
        executablePath: r'C:\Users\me\AppData\Local\Programs\FanCAD\fancad.exe',
      );
      expect(all.installedForAllUsers, isTrue);
      expect(mine.installedForAllUsers, isFalse);
    });
  });
}
