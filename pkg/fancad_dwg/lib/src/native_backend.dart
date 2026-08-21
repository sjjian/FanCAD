import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'backend.dart';
import 'ffi/bindings.dart' as native;

/// The LibreDWG-backed implementation.
///
/// Every native call is confined to this file, which is what keeps the
/// GPL-licensed parser at arm's length behind [DrawingBackend] and makes it
/// possible to move it into a separate process later without touching
/// anything else.
class NativeDrawingBackend implements DrawingBackend {
  NativeDrawingBackend();

  BackendCapabilities? _capabilities;

  @override
  BackendCapabilities get capabilities =>
      _capabilities ??= _probeCapabilities();

  static BackendCapabilities _probeCapabilities() {
    try {
      final bits = native.fcCapabilities();
      final description = native.fcBackendVersion().cast<Utf8>().toDartString();
      return BackendCapabilities(
        readDwg: bits & native.FcCapability.readDwg != 0,
        writeDwg: bits & native.FcCapability.writeDwg != 0,
        readDxf: bits & native.FcCapability.readDxf != 0,
        writeDxf: bits & native.FcCapability.writeDxf != 0,
        description: description,
      );
    } catch (error) {
      // The code asset may be missing entirely, for example in a unit test
      // that runs without the native build. Report no capabilities rather
      // than crashing the caller.
      return BackendCapabilities(
        description: 'DWG shim unavailable: $error',
      );
    }
  }

  /// The FCB format version the native side emits, for a compatibility check
  /// against the Dart reader.
  int get nativeFcbVersion {
    try {
      return native.fcFcbVersion();
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<Uint8List> readToFcb(String path) async {
    if (!File(path).existsSync()) {
      throw ImportException(
        'File does not exist',
        path: path,
        status: native.FcStatus.fileNotFound,
      );
    }
    if (!capabilities.canReadAnything) {
      throw ImportException(
        'This build has no DWG backend (${capabilities.description}). '
        'See pkg/fancad_dwg/README.md for how to enable it.',
        path: path,
        status: native.FcStatus.noBackend,
      );
    }

    final pathPointer = path.toNativeUtf8();
    final dataOut = calloc<Pointer<Uint8>>();
    final lengthOut = calloc<Uint64>();
    final countOut = calloc<Uint32>();
    try {
      final status = native.fcReadFile(
        pathPointer.cast<Char>(),
        dataOut,
        lengthOut,
        countOut,
      );
      if (status != native.FcStatus.ok) {
        throw ImportException(
          _lastError(fallback: native.FcStatus.describe(status)),
          path: path,
          status: status,
        );
      }
      final data = dataOut.value;
      final length = lengthOut.value;
      if (data == nullptr || length == 0) {
        throw ImportException(
          'The backend returned an empty drawing',
          path: path,
          status: native.FcStatus.parseError,
        );
      }
      try {
        // The native buffer is owned by C, so it must be copied before it is
        // released. This is the only copy of the drawing data on the import
        // path, and it is a single memcpy rather than per-entity marshalling.
        return Uint8List.fromList(data.asTypedList(length));
      } finally {
        native.fcFree(data);
      }
    } finally {
      calloc.free(pathPointer);
      calloc.free(dataOut);
      calloc.free(lengthOut);
      calloc.free(countOut);
    }
  }

  @override
  Future<void> writeFromFcb(
    String path,
    Uint8List fcb, {
    int targetVersion = 0,
  }) async {
    final pathPointer = path.toNativeUtf8();
    final buffer = calloc<Uint8>(fcb.length);
    try {
      buffer.asTypedList(fcb.length).setAll(0, fcb);
      final status = native.fcWriteFile(
        pathPointer.cast<Char>(),
        buffer,
        fcb.length,
        targetVersion,
      );
      if (status != native.FcStatus.ok) {
        throw ImportException(
          _lastError(fallback: native.FcStatus.describe(status)),
          path: path,
          status: status,
        );
      }
    } finally {
      calloc.free(pathPointer);
      calloc.free(buffer);
    }
  }

  /// Writes [dwgPath] as r2000 or r2004 from an already-written DXF file.
  Future<void> exportDwgFromDxf(
    String dxfPath,
    String dwgPath, {
    int targetVersion = 2000,
  }) async {
    if (!capabilities.writeDwg) {
      throw ImportException(
        'This build cannot write DWG (${capabilities.description})',
        path: dwgPath,
        status: native.FcStatus.noBackend,
      );
    }
    final dxfPointer = dxfPath.toNativeUtf8();
    final dwgPointer = dwgPath.toNativeUtf8();
    try {
      final status = native.fcDxfToDwg(
        dxfPointer.cast<Char>(),
        dwgPointer.cast<Char>(),
        targetVersion,
      );
      if (status != native.FcStatus.ok) {
        throw ImportException(
          _lastError(fallback: native.FcStatus.describe(status)),
          path: dwgPath,
          status: status,
        );
      }
    } finally {
      calloc.free(dxfPointer);
      calloc.free(dwgPointer);
    }
  }

  static String _lastError({required String fallback}) {
    const capacity = 512;
    final buffer = calloc<Char>(capacity);
    try {
      final written = native.fcLastError(buffer, capacity);
      if (written <= 0) return fallback;
      return buffer.cast<Utf8>().toDartString();
    } catch (_) {
      return fallback;
    } finally {
      calloc.free(buffer);
    }
  }
}
