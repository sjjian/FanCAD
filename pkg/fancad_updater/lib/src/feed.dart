import 'release.dart';

/// Reads the latest release from one source.
abstract interface class ReleaseFeed {
  String get sourceId;

  /// Returns null when the repository has no release yet, which is different
  /// from a failure: the checker treats it as "nothing usable here" and moves
  /// to the next source either way.
  Future<ReleaseInfo?> latest();
}

/// A source answered, but not with a release the updater can use.
class FeedException implements Exception {
  const FeedException(
    this.message, {
    required this.sourceId,
    this.statusCode,
    this.uri,
  });

  final String message;
  final String sourceId;
  final int? statusCode;
  final Uri? uri;

  @override
  String toString() => message;
}
