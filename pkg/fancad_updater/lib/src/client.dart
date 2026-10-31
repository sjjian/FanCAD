import 'dart:io';

import 'build_info.dart';
import 'checker.dart';
import 'downloader.dart';
import 'feed.dart';
import 'host.dart';
import 'install/executor.dart';
import 'install/plan.dart';
import 'install/planner.dart';
import 'install/process_runner.dart';
import 'paths.dart';
import 'release.dart';
import 'signature.dart';
import 'source.dart';
import 'transport.dart';

/// Everything the app needs: one object wired to the real network, the real
/// host and the real process runner.
///
/// Each part is also usable on its own; this facade only exists so call sites
/// do not repeat the wiring.
class UpdateClient {
  UpdateClient({
    required List<UpdateSource> sources,
    required this.build,
    HostEnvironment? host,
    HttpTransport? transport,
    ReleaseFeed Function(UpdateSource source)? feedFactory,
    ProcessRunner? processRunner,
    this.planner = const InstallPlanner(),
    this.manifestVerifier,
  }) : host = host ?? HostEnvironment.detect(),
       transport = transport ?? IoHttpTransport() {
    checker = UpdateChecker(
      sources: sources,
      build: build,
      transport: this.transport,
      feedFactory: feedFactory,
    );
    downloader = ReleaseDownloader(
      sources: sources,
      transport: this.transport,
      verifier: manifestVerifier,
      feedFactory: feedFactory,
    );
    executor = InstallExecutor(host: this.host, runner: processRunner);
  }

  final BuildInfo build;
  final HostEnvironment host;
  final HttpTransport transport;
  final InstallPlanner planner;

  /// The pinned RSA key. Null disables downloads: the updater never installs
  /// bytes it cannot verify.
  final ManifestVerifier? manifestVerifier;

  bool get canVerifyUpdates => manifestVerifier != null;

  late final UpdateChecker checker;
  late final ReleaseDownloader downloader;
  late final InstallExecutor executor;

  Future<CheckResult> check() => checker.check();

  Future<DownloadResult> download(
    ReleaseInfo release, {
    required Directory directory,
    void Function(DownloadProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final current = build.semantic;
    final target = release.semanticVersion;
    if (current != null && target != null && !target.isNewerThan(current)) {
      throw DownloadException(
        '${release.version} is not newer than ${build.version}',
      );
    }
    return downloader.download(
      release,
      directory: directory,
      platform: host.platform,
      arch: host.arch,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }

  /// Works out how this host installs [download]. The write probe is skipped
  /// when the caller already knows the answer (tests, or a pre-check).
  Future<InstallPlan> planInstall({
    required DownloadResult download,
    required Directory workDirectory,
    required int processId,
    bool? targetWritable,
  }) async {
    final writable =
        targetWritable ??
        (host.platform == UpdatePlatform.linux
            ? await isDirectoryWritable(host.executableDirectory)
            : true);
    return planner.plan(
      asset: download.asset,
      artifact: download.file,
      host: host,
      workDirectory: workDirectory,
      processId: processId,
      targetWritable: writable,
    );
  }

  /// Starts the plan.
  ///
  /// The caller quits afterwards when [InstallPlan.canInstall] is true. A
  /// reveal plan leaves the app running and just shows the download.
  Future<void> install(InstallPlan plan) => executor.run(plan);

  void dispose() => transport.close();
}
