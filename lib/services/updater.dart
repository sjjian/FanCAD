import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fancad_updater/fancad_updater.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/updates.dart';
import '../storage/settings.dart';
import 'providers.dart';
import 'update_key.dart';
import 'workspace.dart';

part 'updater.g.dart';

/// GitHub first, Gitee only when GitHub cannot answer.
const List<UpdateSource> fanCadUpdateSources = [
  UpdateSource(
    id: 'github',
    kind: SourceKind.github,
    owner: 'sjjian',
    repo: 'FanCAD',
  ),
  UpdateSource(
    id: 'gitee',
    kind: SourceKind.gitee,
    owner: 'sjjian',
    repo: 'FanCAD',
    priority: 1,
  ),
];

@Riverpod(keepAlive: true)
BuildInfo buildInfo(Ref ref) => BuildInfo.fromEnvironment();

/// How long the app waits after the first frame before checking. Tests set
/// this to zero so no timer outlives the widget tree.
@Riverpod(keepAlive: true)
Duration updateStartupDelay(Ref ref) => const Duration(milliseconds: 1500);

@Riverpod(keepAlive: true)
UpdateClient updateClient(Ref ref) {
  final client = UpdateClient(
    sources: fanCadUpdateSources,
    build: ref.watch(buildInfoProvider),
    manifestVerifier: createUpdateVerifier(),
  );
  ref.onDispose(client.dispose);
  return client;
}

/// `<support>/updates`. Empty for an in-memory store (tests).
@Riverpod(keepAlive: true)
String updatesDirectory(Ref ref) {
  final file = ref.watch(settingsProvider).file;
  if (file == null) return '';
  return p.join(file.parent.path, 'updates');
}

/// Checks, downloads and hands the update to the platform.
///
/// The feed is only a directory; the package refuses to download without a
/// signed manifest, so an unconfigured key leaves the UI in
/// [UpdatePhase.unconfigured] instead of offering an unsafe update.
@Riverpod(keepAlive: true)
class UpdateNotifier extends _$UpdateNotifier {
  static const Duration interval = Duration(hours: 24);

  var _closed = false;
  var _cancelDownload = false;

  UpdatesStore get _store => ref.read(appSettingsProvider).updates;
  UpdateClient get _client => ref.read(updateClientProvider);
  String get _dir => ref.read(updatesDirectoryProvider);

  @override
  UpdateStateModel build() {
    ref.onDispose(() => _closed = true);
    final saved = ref.watch(appSettingsProvider).updates.load();
    return UpdateStateModel(
      autoCheck: saved.autoCheck,
      promptedVersion: saved.promptedVersion,
      skippedVersion: saved.skippedVersion,
      lastCheckedAt: saved.lastCheckedAt,
    );
  }

  void _set(UpdateStateModel next) {
    if (_closed) return;
    state = next;
  }

  void setAutoCheck(bool value) {
    if (state.autoCheck == value) return;
    _save(autoCheck: value);
    _set(state.copyWith(autoCheck: value));
  }

  /// Loads the last release seen on disk, so a new version can be offered
  /// before the network check finishes.
  Future<void> restoreCache() async {
    if (!state.autoCheck) return;
    final file = _cacheFile;
    if (file == null || state.busy) return;
    // Without a pinned key the update cannot be installed, so do not offer it.
    if (!_client.canVerifyUpdates) return;
    if (state.phase != UpdatePhase.idle && state.phase != UpdatePhase.failed) {
      return;
    }
    try {
      if (!file.existsSync()) return;
      final release = ReleaseInfo.tryFromJson(
        jsonDecode(await file.readAsString()),
      );
      if (release == null) return;
      final current = ref.read(buildInfoProvider).semantic;
      final target = release.semanticVersion;
      if (current == null || target == null || !target.isNewerThan(current)) {
        return;
      }
      _set(
        state.copyWith(
          phase: UpdatePhase.available,
          release: release,
          error: null,
        ),
      );
    } on FormatException {
      // A corrupt cache only costs a network check.
    } on FileSystemException {
      // The updates directory may not exist on a fresh install.
    }
  }

  Future<void> check({bool manual = false}) async {
    if (state.busy) return;
    if (!manual) {
      if (!state.autoCheck) return;
      final last = state.lastCheckedAt;
      if (last != null && DateTime.now().difference(last) < interval) return;
    }
    if (_dir.isEmpty || !_client.canVerifyUpdates) {
      _set(state.copyWith(phase: UpdatePhase.unconfigured, error: null));
      return;
    }

    _set(state.copyWith(phase: UpdatePhase.checking, error: null));
    final CheckResult result;
    try {
      result = await _client.check();
    } catch (error) {
      _set(state.copyWith(phase: UpdatePhase.failed, error: '$error'));
      return;
    }

    switch (result.status) {
      case CheckStatus.available:
        final release = result.release;
        if (release == null) {
          _set(state.copyWith(phase: UpdatePhase.failed));
          return;
        }
        await _writeCache(release);
        _saveLastChecked();
        if (state.phase == UpdatePhase.ready &&
            state.release?.version == release.version) {
          _set(state.copyWith(attempts: result.attempts, error: null));
        } else {
          _set(
            state.copyWith(
              phase: UpdatePhase.available,
              release: release,
              download: null,
              attempts: result.attempts,
              error: null,
            ),
          );
        }
      case CheckStatus.upToDate:
        final release = result.release;
        if (release != null) await _writeCache(release);
        _saveLastChecked();
        _set(
          state.copyWith(
            phase: UpdatePhase.upToDate,
            release: release,
            download: null,
            attempts: result.attempts,
            error: null,
          ),
        );
      case CheckStatus.failed:
        // Do not record a failed check: the next launch should try again
        // instead of showing "not checked yet" for a whole day.
        final cached = state.release;
        if (cached != null && state.phase == UpdatePhase.available) {
          _set(
            state.copyWith(attempts: result.attempts, error: result.diagnostic),
          );
        } else {
          _set(
            state.copyWith(
              phase: UpdatePhase.failed,
              attempts: result.attempts,
              error: result.diagnostic,
            ),
          );
        }
      case CheckStatus.unsupported:
        _set(state.copyWith(phase: UpdatePhase.unsupported, error: null));
    }
  }

  Future<void> download() async {
    final release = state.release;
    if (release == null ||
        state.busy ||
        state.download != null ||
        _dir.isEmpty) {
      return;
    }
    if (!_client.canVerifyUpdates) {
      _set(state.copyWith(phase: UpdatePhase.unconfigured, error: null));
      return;
    }
    _cancelDownload = false;
    _set(
      state.copyWith(
        phase: UpdatePhase.downloading,
        progress: const DownloadProgress(received: 0),
        error: null,
      ),
    );
    try {
      final result = await _client.download(
        release,
        directory: Directory(p.join(_dir, release.version)),
        onProgress: (progress) {
          if (_closed || state.phase != UpdatePhase.downloading) return;
          _set(state.copyWith(progress: progress));
        },
        isCancelled: () => _cancelDownload,
      );
      _set(
        state.copyWith(
          phase: UpdatePhase.ready,
          download: result,
          progress: null,
          error: null,
        ),
      );
    } on UpdateCancelled {
      _set(state.copyWith(phase: UpdatePhase.available, progress: null));
    } on DownloadException catch (error) {
      _set(
        state.copyWith(
          phase: UpdatePhase.failed,
          progress: null,
          error: error.toString(),
        ),
      );
    } catch (error) {
      _set(
        state.copyWith(
          phase: UpdatePhase.failed,
          progress: null,
          error: '$error',
        ),
      );
    }
  }

  void cancelDownload() {
    _cancelDownload = true;
  }

  /// Closes the drawings, flushes settings and starts the platform plan.
  ///
  /// Returns true when the caller should quit the process now.
  Future<bool> install() async {
    final download = state.download;
    final release = state.release;
    if (download == null ||
        release == null ||
        state.phase == UpdatePhase.installing ||
        _dir.isEmpty) {
      return false;
    }

    try {
      final plan = await _client.planInstall(
        download: download,
        workDirectory: Directory(p.join(_dir, release.version)),
        processId: pid,
      );
      // A reveal plan only opens a folder or a disk image; closing the
      // drawings first would be destructive and pointless.
      if (!plan.canInstall) {
        await _client.install(plan);
        _set(state.copyWith(phase: UpdatePhase.reveal, error: null));
        return false;
      }

      final workspace = ref.read(workspaceNotifierProvider.notifier);
      if (!await workspace.closeAllTabs()) return false;
      await ref.read(settingsProvider).flush();

      _set(state.copyWith(phase: UpdatePhase.installing, error: null));
      await _client.install(plan);
      return true;
    } catch (error) {
      _set(state.copyWith(phase: UpdatePhase.failed, error: '$error'));
      return false;
    }
  }

  /// Marks the version as prompted and returns it, or null when it is not
  /// eligible. Called before the dialog is shown so a crash cannot prompt
  /// twice.
  ReleaseInfo? consumePrompt() {
    final release = state.release;
    if (release == null || !state.canPrompt) return null;
    _save(promptedVersion: release.version);
    _set(state.copyWith(promptedVersion: release.version));
    return release;
  }

  void skipVersion() {
    final release = state.release;
    if (release == null) return;
    _save(skippedVersion: release.version);
    _set(state.copyWith(skippedVersion: release.version));
  }

  void unskipVersion() {
    _save(skippedVersion: '');
    _set(state.copyWith(skippedVersion: ''));
  }

  void _save({
    bool? autoCheck,
    String? promptedVersion,
    String? skippedVersion,
  }) {
    final current = _store.load();
    _store.save(
      current.copyWith(
        autoCheck: autoCheck ?? current.autoCheck,
        promptedVersion: promptedVersion ?? current.promptedVersion,
        skippedVersion: skippedVersion ?? current.skippedVersion,
        lastCheckedAt: current.lastCheckedAt,
      ),
    );
  }

  void _saveLastChecked() {
    final now = DateTime.now();
    final current = _store.load();
    _store.save(current.copyWith(lastCheckedAt: now));
    _set(state.copyWith(lastCheckedAt: now));
  }

  File? get _cacheFile {
    final dir = _dir;
    if (dir.isEmpty) return null;
    return File(p.join(dir, 'latest.json'));
  }

  Future<void> _writeCache(ReleaseInfo release) async {
    final file = _cacheFile;
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(release.toJson()));
    } on FileSystemException {
      // A cache miss only costs a network check next launch.
    }
  }
}
