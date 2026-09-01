import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:meta/meta.dart';

/// What a drawing backend can do.
@immutable
class BackendCapabilities {
  const BackendCapabilities({
    this.readDwg = false,
    this.writeDwg = false,
    this.readDxf = false,
    this.writeDxf = false,
    this.description = '',
  });

  final bool readDwg;
  final bool writeDwg;
  final bool readDxf;
  final bool writeDxf;

  /// Human-readable backend identification, shown in the About dialog and
  /// included in bug reports.
  final String description;

  bool get canReadAnything => readDwg || readDxf;

  /// File extensions this backend can open, without the leading dot.
  List<String> get readableExtensions => [
    if (readDwg) 'dwg',
    if (readDxf) 'dxf',
  ];

  List<String> get writableExtensions => [
    if (writeDwg) 'dwg',
    if (writeDxf) 'dxf',
  ];

  @override
  String toString() =>
      'BackendCapabilities($description, read: ${readableExtensions.join('/')}'
      ', write: ${writableExtensions.join('/')})';
}

/// The outcome of opening a drawing.
class ImportResult {
  const ImportResult({
    required this.document,
    this.diagnostics = const [],
    this.entityCount = 0,
    this.parseTime = Duration.zero,
    this.decodeTime = Duration.zero,
    this.bytesTransferred = 0,
  });

  final CadDocument document;

  /// Non-fatal problems: unsupported object types, approximated geometry,
  /// missing external references. Surfaced in the UI rather than swallowed.
  final List<String> diagnostics;
  final int entityCount;

  /// Time spent inside the native parser.
  final Duration parseTime;

  /// Time spent decoding FCB into the document model.
  final Duration decodeTime;

  final int bytesTransferred;

  Duration get totalTime => parseTime + decodeTime;

  @override
  String toString() =>
      'ImportResult($entityCount entities, parse ${parseTime.inMilliseconds}ms, '
      'decode ${decodeTime.inMilliseconds}ms)';
}

/// Raised when a drawing cannot be opened.
class ImportException implements Exception {
  const ImportException(this.message, {this.path, this.status});

  final String message;
  final String? path;
  final int? status;

  @override
  String toString() =>
      'ImportException: $message${path == null ? '' : ' ($path)'}';
}

/// Reads and writes drawing files.
///
/// The rest of the application depends on this interface, never on LibreDWG.
/// That is the seam that makes the DWG library replaceable: a different
/// parser, a DXF-only reader, or an out-of-process sidecar all satisfy the
/// same contract.
abstract class DrawingBackend {
  BackendCapabilities get capabilities;

  /// Reads a file into an FCB buffer. Returning the intermediate buffer rather
  /// than a document lets the caller cache it and lets decoding happen on
  /// whichever isolate it prefers.
  Future<Uint8List> readToFcb(String path);

  /// Writes an FCB buffer out as a drawing file.
  Future<void> writeFromFcb(
    String path,
    Uint8List fcb, {
    int targetVersion = 0,
  });
}

/// A backend that stores FCB buffers in memory.
///
/// Exists so that tests, and any headless use of the importer, need neither the
/// native library nor the filesystem. Anything the application can do with a
/// real drawing it can do against this, which keeps the test suite honest about
/// the seam rather than mocking around it.
class MemoryDrawingBackend implements DrawingBackend {
  MemoryDrawingBackend({Map<String, Uint8List>? files})
    : _files = {...?files};

  final Map<String, Uint8List> _files;

  /// The paths currently held, for assertions.
  Iterable<String> get paths => _files.keys;

  @override
  BackendCapabilities get capabilities => const BackendCapabilities(
    readDwg: true,
    writeDwg: true,
    readDxf: true,
    writeDxf: true,
    description: 'In-memory FCB backend',
  );

  @override
  Future<Uint8List> readToFcb(String path) async {
    final bytes = _files[path];
    if (bytes == null) {
      throw ImportException('No such drawing in memory', path: path);
    }
    return bytes;
  }

  @override
  Future<void> writeFromFcb(
    String path,
    Uint8List fcb, {
    int targetVersion = 0,
  }) async {
    _files[path] = fcb;
  }
}
