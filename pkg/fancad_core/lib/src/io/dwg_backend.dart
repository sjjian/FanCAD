import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../document/document.dart';

/// DWG capabilities supplied by the replaceable native adapter.
@immutable
class DwgCapabilities {
  const DwgCapabilities({
    this.canRead = false,
    this.canWrite = false,
    this.description = '',
  });

  final bool canRead;
  final bool canWrite;

  /// Human-readable backend identification, shown in the About dialog and
  /// included in bug reports.
  final String description;

  @override
  String toString() =>
      'DwgCapabilities($description, read: $canRead, write: $canWrite)';
}

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

/// Translates DWG files to and from the FCB transfer format.
///
/// `DrawingFileService` owns format routing. This seam only isolates the
/// replaceable DWG implementation from the Dart codecs.
abstract class DwgBackend {
  DwgCapabilities get capabilities;

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
/// Exists so tests of the file service need neither the native library nor a
/// real DWG file.
class MemoryDwgBackend implements DwgBackend {
  MemoryDwgBackend({Map<String, Uint8List>? files}) : _files = {...?files};

  final Map<String, Uint8List> _files;

  /// The paths currently held, for assertions.
  Iterable<String> get paths => _files.keys;

  @override
  DwgCapabilities get capabilities => const DwgCapabilities(
    canRead: true,
    canWrite: true,
    description: 'In-memory FCB backend',
  );

  @override
  Future<Uint8List> readToFcb(String path) async {
    final bytes = _files[path];
    if (bytes == null) {
      throw DrawingFileException('No such drawing in memory', path: path);
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
