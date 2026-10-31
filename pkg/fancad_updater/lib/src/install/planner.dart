import 'dart:io';

import '../host.dart';
import '../paths.dart';
import '../release.dart';
import 'helper_scripts.dart';
import 'plan.dart';

/// Chooses how this host can finish an update.
///
/// Pure: it only produces a plan and the text of a helper. Writing the script
/// and starting it is [InstallExecutor]'s job, which keeps every branch here
/// testable from one machine.
class InstallPlanner {
  const InstallPlanner();

  InstallPlan plan({
    required ReleaseAsset asset,
    required File artifact,
    required HostEnvironment host,
    required Directory workDirectory,
    required int processId,
    bool targetWritable = true,
  }) {
    return switch (host.platform) {
      UpdatePlatform.macos => _macOs(assetName: asset.name, artifact: artifact),
      UpdatePlatform.windows => _windows(
        assetName: asset.name,
        artifact: artifact,
        host: host,
        workDirectory: workDirectory,
      ),
      UpdatePlatform.linux => _linux(
        assetName: asset.name,
        artifact: artifact,
        host: host,
        workDirectory: workDirectory,
        processId: processId,
        targetWritable: targetWritable,
      ),
    };
  }

  InstallPlan _macOs({required String assetName, required File artifact}) {
    // macOS has no installer. The disk image already contains the app and an
    // alias to /Applications, so opening it is the whole installation UI: the
    // user drags FanCAD across, then opens the new version.
    return InstallPlan(
      mode: InstallMode.runInstaller,
      summary: 'Open $assetName; drag FanCAD to Applications',
      steps: [
        InstallStep('/usr/bin/open', [artifact.path]),
      ],
    );
  }

  InstallPlan _windows({
    required String assetName,
    required File artifact,
    required HostEnvironment host,
    required Directory workDirectory,
  }) {
    // The wizard keeps FanCAD's install mode: the updater passes /ALLUSERS for
    // a machine-wide copy, which makes Inno relaunch itself elevated, and the
    // user only sees the familiar mode page and UAC prompt. A per-user copy
    // stays per-user and needs no elevation.
    final logPath = joinPath(workDirectory.path, 'install.log');
    return InstallPlan(
      mode: InstallMode.runInstaller,
      summary: 'Open the $assetName wizard after this process exits',
      steps: [
        InstallStep(artifact.path, [
          '/LOG=$logPath',
          if (host.installedForAllUsers) '/ALLUSERS',
        ], detached: true),
      ],
    );
  }

  InstallPlan _linux({
    required String assetName,
    required File artifact,
    required HostEnvironment host,
    required Directory workDirectory,
    required int processId,
    required bool targetWritable,
  }) {
    final target = host.executableDirectory.path;
    if (!targetWritable) {
      return InstallPlan.reveal(
        path: artifact.path,
        reason: RevealReason.readOnly,
        summary: 'The install folder is not writable',
      );
    }
    final helperPath = joinPath(workDirectory.path, 'fancad-install.sh');
    final logPath = joinPath(workDirectory.path, 'install.log');
    return InstallPlan(
      mode: InstallMode.inPlace,
      summary: 'Unpack $assetName over $target after this process exits',
      helper: HelperScript(
        path: helperPath,
        contents: linuxInstallScript,
        executable: '/bin/sh',
        arguments: [
          helperPath,
          '$processId',
          artifact.path,
          target,
          host.executableName,
          logPath,
        ],
      ),
    );
  }
}
