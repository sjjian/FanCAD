import 'dart:io';

import '../host.dart';
import '../paths.dart';
import '../release.dart';
import 'plan.dart';
import 'process_runner.dart';

/// Writes the helper script and starts it, or reveals the download when the
/// app cannot replace itself.
class InstallExecutor {
  InstallExecutor({required this.host, ProcessRunner? runner})
    : _runner = runner ?? const IoProcessRunner();

  final HostEnvironment host;
  final ProcessRunner _runner;

  Future<void> run(InstallPlan plan) async {
    if (plan.mode == InstallMode.reveal) {
      await reveal(plan);
      return;
    }
    final helper = plan.helper;
    if (helper != null) {
      final script = File(helper.path);
      await script.parent.create(recursive: true);
      await script.writeAsString(helper.contents, flush: true);
      await _runner.run(helper.executable, helper.arguments, detached: true);
      return;
    }
    if (plan.steps.isEmpty) {
      throw const ProcessRunException(
        'The install plan has neither a helper nor steps',
      );
    }
    for (final step in plan.steps) {
      final outcome = await _runner.run(
        step.executable,
        step.arguments,
        detached: step.detached,
      );
      if (!outcome.isSuccess) {
        throw ProcessRunException(
          '${step.executable} exited with ${outcome.exitCode}',
        );
      }
    }
  }

  /// Shows the downloaded file, or the folder that holds it.
  Future<void> reveal(InstallPlan plan) async {
    final path = plan.revealPath;
    if (path == null) return;
    final exists = await File(path).exists();
    final directory = dirname(path);
    final arguments = switch (host.platform) {
      UpdatePlatform.macos => exists ? ['-R', path] : [directory],
      UpdatePlatform.windows => exists ? ['/select,$path'] : [directory],
      UpdatePlatform.linux => [directory],
    };
    final executable = switch (host.platform) {
      UpdatePlatform.macos => 'open',
      UpdatePlatform.windows => 'explorer',
      UpdatePlatform.linux => 'xdg-open',
    };
    await _runner.run(executable, arguments);
  }
}
