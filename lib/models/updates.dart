import 'package:fancad_updater/fancad_updater.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'updates.freezed.dart';

/// Where the update flow is right now.
enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  ready,
  installing,
  failed,
  unsupported,
  unconfigured,
  reveal,
}

/// Everything the About page and the startup prompt need.
@freezed
abstract class UpdateStateModel with _$UpdateStateModel {
  const UpdateStateModel._();

  const factory UpdateStateModel({
    @Default(UpdatePhase.idle) UpdatePhase phase,
    @Default(true) bool autoCheck,
    @Default('') String promptedVersion,
    @Default('') String skippedVersion,
    DateTime? lastCheckedAt,
    ReleaseInfo? release,
    DownloadResult? download,
    DownloadProgress? progress,
    String? error,
    @Default(<SourceAttempt>[]) List<SourceAttempt> attempts,
  }) = _UpdateStateModel;

  bool get busy =>
      phase == UpdatePhase.checking ||
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.installing;

  bool get isSkipped => release != null && skippedVersion == release!.version;

  bool get canPrompt {
    final release = this.release;
    if (release == null || phase != UpdatePhase.available) return false;
    return release.version != promptedVersion &&
        release.version != skippedVersion;
  }
}
