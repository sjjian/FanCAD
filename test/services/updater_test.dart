import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:fancad_updater/fancad_updater.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const release = ReleaseInfo(sourceId: 'github', version: '0.6.0');

  test('a new version is promptable until it is prompted or skipped', () {
    const state = UpdateStateModel(
      phase: UpdatePhase.available,
      release: release,
    );
    expect(state.canPrompt, isTrue);
    expect(state.copyWith(promptedVersion: '0.6.0').canPrompt, isFalse);
    expect(state.copyWith(skippedVersion: '0.6.0').canPrompt, isFalse);
    expect(state.copyWith(phase: UpdatePhase.ready).canPrompt, isFalse);
  });

  test('a skipped version reports itself and can be unskipped', () {
    const state = UpdateStateModel(
      phase: UpdatePhase.available,
      release: release,
      skippedVersion: '0.6.0',
    );
    expect(state.isSkipped, isTrue);
    expect(state.copyWith(skippedVersion: '').isSkipped, isFalse);
  });

  test('busy covers the phases that must not start another action', () {
    for (final phase in [
      UpdatePhase.checking,
      UpdatePhase.downloading,
      UpdatePhase.installing,
    ]) {
      expect(UpdateStateModel(phase: phase).busy, isTrue);
    }
    expect(const UpdateStateModel().busy, isFalse);
    expect(const UpdateStateModel(phase: UpdatePhase.available).busy, isFalse);
  });

  test('a failed check does not use up the daily automatic check', () async {
    final harness = _NotifierHarness(
      const CheckResult(status: CheckStatus.failed, error: 'offline'),
    );
    addTearDown(harness.dispose);

    await harness.notifier.check(manual: true);

    expect(harness.state.phase, UpdatePhase.failed);
    expect(harness.savedLastCheckedAt, isNull);
  });

  test('a successful check records when it happened', () async {
    final harness = _NotifierHarness(
      const CheckResult(
        status: CheckStatus.upToDate,
        release: ReleaseInfo(sourceId: 'github', version: '0.5.0'),
      ),
    );
    addTearDown(harness.dispose);

    await harness.notifier.check(manual: true);

    expect(harness.state.phase, UpdatePhase.upToDate);
    expect(harness.savedLastCheckedAt, isNotNull);
  });
}

class _NotifierHarness {
  _NotifierHarness(CheckResult result) : _directory = _tempDirectory() {
    _store = SettingsStore.inMemory();
    _container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWithValue(_store),
        updatesDirectoryProvider.overrideWithValue(_directory.path),
        buildInfoProvider.overrideWithValue(const BuildInfo(version: '0.5.0')),
        updateClientProvider.overrideWithValue(_FakeUpdateClient(result)),
      ],
    );
  }

  final Directory _directory;
  late final SettingsStore _store;
  late final ProviderContainer _container;

  UpdateNotifier get notifier =>
      _container.read(updateNotifierProvider.notifier);

  UpdateStateModel get state => _container.read(updateNotifierProvider);

  DateTime? get savedLastCheckedAt =>
      UpdatesSettings(_store).load().lastCheckedAt;

  void dispose() {
    _container.dispose();
    _directory.deleteSync(recursive: true);
  }

  static Directory _tempDirectory() =>
      Directory.systemTemp.createTempSync('fancad-updater-test');
}

class _FakeUpdateClient extends UpdateClient {
  _FakeUpdateClient(this.result)
    : super(
        sources: const [],
        build: const BuildInfo(version: '0.5.0'),
        manifestVerifier: ManifestVerifier(
          RsaPublicKey(modulus: BigInt.from(3233)),
        ),
        transport: _NoopTransport(),
      );

  final CheckResult result;

  @override
  Future<CheckResult> check() async => result;
}

class _NoopTransport implements HttpTransport {
  @override
  Future<HttpResponseData> get(
    Uri url, {
    Map<String, String> headers = const {},
    Duration? timeout,
  }) => throw UnimplementedError();

  @override
  Future<int> download(
    Uri url, {
    required File destination,
    Map<String, String> headers = const {},
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration? timeout,
  }) => throw UnimplementedError();

  @override
  void close() {}
}
