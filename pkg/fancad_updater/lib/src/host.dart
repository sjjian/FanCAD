import 'dart:ffi';
import 'dart:io';

import 'paths.dart';
import 'release.dart';

/// The machine the updater is running on.
///
/// Kept as data so the install planner can be tested for all three platforms
/// from one host.
class HostEnvironment {
  const HostEnvironment({
    required this.platform,
    required this.arch,
    required this.executablePath,
  });

  final UpdatePlatform platform;
  final UpdateArch arch;

  /// `Platform.resolvedExecutable`.
  final String executablePath;

  factory HostEnvironment.detect() {
    final platform = switch (Platform.operatingSystem) {
      'macos' => UpdatePlatform.macos,
      'windows' => UpdatePlatform.windows,
      'linux' => UpdatePlatform.linux,
      final other => throw UnsupportedError('No updater for $other'),
    };
    return HostEnvironment(
      platform: platform,
      arch: _archFromAbi(Abi.current()),
      executablePath: Platform.resolvedExecutable,
    );
  }

  /// The folder that holds the executable.
  ///
  /// On macOS this is inside the `.app`; the updater never writes there, it
  /// opens the disk image and lets the user install.
  Directory get executableDirectory => Directory(dirname(executablePath));

  String get executableName => basename(executablePath);

  /// A Windows install under Program Files is the machine-wide layout. Such a
  /// copy needs `/ALLUSERS` and an elevation prompt to update; a per-user copy
  /// does not.
  bool get installedForAllUsers {
    if (platform != UpdatePlatform.windows) return false;
    final directory = executableDirectory.path.toLowerCase();
    for (final key in const [
      'ProgramFiles',
      'ProgramFiles(x86)',
      'ProgramW6432',
    ]) {
      final root = Platform.environment[key]?.toLowerCase();
      if (root == null || root.isEmpty) continue;
      if (directory == root || directory.startsWith('$root\\')) return true;
    }
    return directory.startsWith(r'c:\program files');
  }

  static UpdateArch _archFromAbi(Abi abi) => switch (abi) {
    Abi.macosArm64 || Abi.linuxArm64 || Abi.windowsArm64 => UpdateArch.arm64,
    Abi.macosX64 ||
    Abi.linuxX64 ||
    Abi.windowsX64 ||
    Abi.androidX64 => UpdateArch.x64,
    _ => UpdateArch.x64,
  };
}
