import '../model/document/drawing_data.dart';

/// The outcome of opening a drawing.
class OpenedDrawing {
  const OpenedDrawing({
    required this.document,
    this.diagnostics = const [],
    this.entityCount = 0,
    this.parseTime = Duration.zero,
    this.decodeTime = Duration.zero,
    this.bytesTransferred = 0,
  });

  final DrawingData document;

  /// Non-fatal problems: unsupported object types, approximated geometry,
  /// missing external references. Surfaced in the UI rather than swallowed.
  final List<String> diagnostics;
  final int entityCount;

  /// Time spent inside the DWG parser.
  final Duration parseTime;

  /// Time spent decoding the file into the document model.
  final Duration decodeTime;

  final int bytesTransferred;

  Duration get totalTime => parseTime + decodeTime;

  @override
  String toString() =>
      'OpenedDrawing($entityCount entities, parse ${parseTime.inMilliseconds}ms, '
      'decode ${decodeTime.inMilliseconds}ms)';
}

/// Raised when a drawing cannot be opened or saved.
class DrawingFileException implements Exception {
  const DrawingFileException(this.message, {this.path, this.status});

  final String message;
  final String? path;
  final int? status;

  @override
  String toString() =>
      'DrawingFileException: $message${path == null ? '' : ' ($path)'}';
}
