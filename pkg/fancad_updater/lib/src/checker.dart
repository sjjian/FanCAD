import 'build_info.dart';
import 'feed.dart';
import 'feeds/factory.dart';
import 'manifest.dart';
import 'release.dart';
import 'source.dart';
import 'transport.dart';

/// Overall result of one check.
enum CheckStatus {
  /// A newer version exists and the UI should offer it.
  available,

  /// The first source that answered is current; later sources are not asked.
  upToDate,

  /// No source produced a usable answer.
  failed,

  /// A `flutter run` build has no version to compare.
  unsupported,
}

/// What one source did, kept for the diagnostics line in the about page.
enum AttemptOutcome { answered, noRelease, failed }

class SourceAttempt {
  const SourceAttempt({
    required this.sourceId,
    required this.outcome,
    this.version,
    this.error,
    this.elapsed = Duration.zero,
  });

  final String sourceId;
  final AttemptOutcome outcome;
  final String? version;
  final String? error;
  final Duration elapsed;
}

class CheckResult {
  const CheckResult({
    required this.status,
    this.release,
    this.attempts = const [],
    this.error,
  });

  final CheckStatus status;

  /// The release that answered, even when it is not newer than the build.
  final ReleaseInfo? release;
  final List<SourceAttempt> attempts;
  final String? error;

  bool get hasUpdate => status == CheckStatus.available;

  bool get canRetry => status == CheckStatus.failed;

  /// One line naming every source that was tried, for support screenshots.
  String get diagnostic {
    if (attempts.isEmpty) return error ?? '';
    return attempts
        .map((attempt) {
          final suffix = switch (attempt.outcome) {
            AttemptOutcome.answered => 'OK ${attempt.version ?? ''}'.trim(),
            AttemptOutcome.noRelease => 'no release',
            AttemptOutcome.failed => attempt.error ?? 'failed',
          };
          return '${attempt.sourceId}: $suffix';
        })
        .join(' · ');
  }
}

/// Queries sources in priority order and stops at the first answer.
///
/// The first source that returns a release decides, even when it says the app
/// is current: asking the fallback "just in case" would turn a fallback into a
/// second opinion and double every check.
class UpdateChecker {
  UpdateChecker({
    required List<UpdateSource> sources,
    required this.build,
    required HttpTransport transport,
    ReleaseFeed Function(UpdateSource source)? feedFactory,
  }) : sources = List.unmodifiable(sources),
       _feedFactory = feedFactory ?? ((source) => feedFor(source, transport));

  final List<UpdateSource> sources;
  final BuildInfo build;
  final ReleaseFeed Function(UpdateSource source) _feedFactory;

  Future<CheckResult> check() async {
    if (build.isDevelopment) {
      return const CheckResult(status: CheckStatus.unsupported);
    }
    final current = build.semantic!;
    final ordered = sources.where((source) => source.enabled).toList()
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
      });
    if (ordered.isEmpty) {
      return const CheckResult(
        status: CheckStatus.failed,
        error: 'No update source is enabled',
      );
    }

    final attempts = <SourceAttempt>[];
    for (final source in ordered) {
      final stopwatch = Stopwatch()..start();
      try {
        final release = await _feedFactory(source).latest();
        stopwatch.stop();
        if (release == null) {
          attempts.add(
            SourceAttempt(
              sourceId: source.id,
              outcome: AttemptOutcome.noRelease,
              elapsed: stopwatch.elapsed,
            ),
          );
          continue;
        }
        final version = release.semanticVersion;
        if (version == null) {
          attempts.add(
            SourceAttempt(
              sourceId: source.id,
              outcome: AttemptOutcome.failed,
              version: release.version,
              error: 'Unreadable version ${release.version}',
              elapsed: stopwatch.elapsed,
            ),
          );
          continue;
        }
        if (release.assetNamed(manifestFileName) == null ||
            release.assetNamed(manifestSignatureFileName) == null) {
          attempts.add(
            SourceAttempt(
              sourceId: source.id,
              outcome: AttemptOutcome.failed,
              version: release.version,
              error: 'No signed manifest',
              elapsed: stopwatch.elapsed,
            ),
          );
          continue;
        }
        attempts.add(
          SourceAttempt(
            sourceId: source.id,
            outcome: AttemptOutcome.answered,
            version: release.version,
            elapsed: stopwatch.elapsed,
          ),
        );
        return CheckResult(
          status: version > current
              ? CheckStatus.available
              : CheckStatus.upToDate,
          release: release,
          attempts: List.unmodifiable(attempts),
        );
      } on FeedException catch (error) {
        stopwatch.stop();
        attempts.add(
          SourceAttempt(
            sourceId: source.id,
            outcome: AttemptOutcome.failed,
            error: error.message,
            elapsed: stopwatch.elapsed,
          ),
        );
      } on UpdateTransportException catch (error) {
        stopwatch.stop();
        attempts.add(
          SourceAttempt(
            sourceId: source.id,
            outcome: AttemptOutcome.failed,
            error: error.message,
            elapsed: stopwatch.elapsed,
          ),
        );
      } catch (error) {
        stopwatch.stop();
        attempts.add(
          SourceAttempt(
            sourceId: source.id,
            outcome: AttemptOutcome.failed,
            error: '$error',
            elapsed: stopwatch.elapsed,
          ),
        );
      }
    }

    return CheckResult(
      status: CheckStatus.failed,
      attempts: List.unmodifiable(attempts),
      error: 'No update source could be read',
    );
  }
}
