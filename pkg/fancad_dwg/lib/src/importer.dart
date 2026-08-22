import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';

import 'backend.dart';
import 'dxf/reader.dart';
import 'dxf/writer.dart';
import 'export/fidelity.dart';
import 'export/save_strategy.dart';
import 'fcb/format.dart';
import 'fcb/reader.dart';
import 'fcb/writer.dart';
import 'fcb_cache.dart';
import 'native_backend.dart';

/// Opens and saves drawings.
///
/// This is the only entry point the rest of the application uses to get a
/// [CadDocument] from disk. It owns the three-stage pipeline — cache lookup,
/// native parse on a worker isolate, FCB decode — so that no caller has to
/// know which stage produced the document it received.
class DrawingImporter {
  DrawingImporter({DrawingBackend? backend, FcbCache? cache})
    : backend = backend ?? NativeDrawingBackend(),
      _cache = cache;

  final DrawingBackend backend;
  final FcbCache? _cache;

  BackendCapabilities get capabilities {
    final native = backend.capabilities;
    return BackendCapabilities(
      readDwg: native.readDwg,
      writeDwg: native.writeDwg,
      readDxf: true,
      writeDxf: true,
      description: native.description,
    );
  }

  /// Whether [path] looks like something this importer can open.
  ///
  /// `.fcb` is FanCAD's own format and is always readable here, even when
  /// the native backend cannot open DWG.
  bool canOpen(String path) {
    final extension = _extensionOf(path.trim());
    return extension == 'fcb' ||
        capabilities.readableExtensions.contains(extension);
  }

  /// Opens a drawing.
  ///
  /// The native parse runs on a worker isolate so a slow or pathological file
  /// cannot freeze the UI. Decoding happens on the calling isolate because the
  /// resulting document graph would cost more to copy across the isolate
  /// boundary than it costs to build.
  Future<ImportResult> open(String path) async {
    final extension = _extensionOf(path);
    if (extension == 'fcb') {
      final bytes = await File(path).readAsBytes();
      return decode(Uint8List.fromList(bytes));
    }
    if (extension == 'dxf') {
      // ASCII DXF is decoded in Dart. The native shim only understands DWG;
      // routing `.dxf` through it would fail the moment LibreDWG is linked.
      final watch = Stopwatch()..start();
      final document = await const DxfReader().readFile(path);
      watch.stop();
      return ImportResult(
        document: document,
        entityCount: document.entityCount,
        decodeTime: watch.elapsed,
      );
    }
    final cache = _cache;
    String? cacheKey;
    if (cache != null && File(path).existsSync()) {
      try {
        cacheKey = FcbCache.keyFor(path, fcbVersion: fcbVersion);
        final cached = cache.read(cacheKey);
        if (cached != null) {
          final decoded = _decode(cached);
          return ImportResult(
            document: decoded.document,
            diagnostics: decoded.diagnostics,
            entityCount: decoded.entityCount,
            decodeTime: decoded.elapsed,
            bytesTransferred: cached.lengthInBytes,
            fromCache: true,
          );
        }
      } on FcbFormatException {
        // A stale or corrupt entry: fall through and re-parse.
        cache.clear();
      } on FileSystemException {
        cacheKey = null;
      }
    }

    final parseWatch = Stopwatch()..start();
    final fcb = await _readOnWorker(path);
    parseWatch.stop();

    if (cache != null && cacheKey != null) {
      cache.write(cacheKey, fcb);
    }

    final decoded = _decode(fcb);
    return ImportResult(
      document: decoded.document,
      diagnostics: decoded.diagnostics,
      entityCount: decoded.entityCount,
      parseTime: parseWatch.elapsed,
      decodeTime: decoded.elapsed,
      bytesTransferred: fcb.lengthInBytes,
    );
  }

  /// Saves [document] to [path], choosing a format the build can actually
  /// write. Returns the path that was written, which may be a fallback.
  Future<SaveOutcome> save(String path, CadDocument document) async {
    final plan = SaveStrategy(
      canWriteDwg: backend.capabilities.writeDwg,
      canWriteDxf: true,
    ).plan(path);
    switch (plan.format) {
      case SaveFormat.dxf:
        await const DxfWriter().writeFile(plan.targetPath, document);
      case SaveFormat.fcb:
        await File(plan.targetPath).writeAsBytes(encode(document));
      case SaveFormat.dwg:
        final dxf = '${plan.targetPath}.tmp.dxf';
        await const DxfWriter().writeFile(dxf, document);
        try {
          if (backend is NativeDrawingBackend) {
            await (backend as NativeDrawingBackend).exportDwgFromDxf(
              dxf,
              plan.targetPath,
              targetVersion: plan.dwgVersion,
            );
          } else {
            throw ImportException(
              'DWG export requires the native backend',
              path: plan.targetPath,
            );
          }
        } finally {
          final temp = File(dxf);
          if (temp.existsSync()) temp.deleteSync();
        }
    }
    return SaveOutcome(plan: plan, path: plan.targetPath);
  }

  /// Compares [source] to a freshly written-and-reread copy at [path].
  Future<FidelityReport> audit(String path, CadDocument source) async {
    final outcome = await save(path, source);
    final reopened = await open(outcome.path);
    return const FidelityAuditor().compare(source, reopened.document);
  }

  /// Encodes [document] as FCB, which is also FanCAD's own native file format.
  Uint8List encode(CadDocument document) => FcbWriter().write(document);

  /// Decodes an FCB buffer, for the native format and for tests.
  ImportResult decode(Uint8List fcb) {
    final decoded = _decode(fcb);
    return ImportResult(
      document: decoded.document,
      diagnostics: decoded.diagnostics,
      entityCount: decoded.entityCount,
      decodeTime: decoded.elapsed,
      bytesTransferred: fcb.lengthInBytes,
    );
  }

  FcbDecodeResult _decode(Uint8List fcb) => FcbReader(fcb).decode();

  Future<Uint8List> _readOnWorker(String path) async {
    final backend = this.backend;
    // A backend that holds no isolate-local state can be recreated on the
    // worker; anything else has to run in place.
    if (backend is! NativeDrawingBackend) {
      return backend.readToFcb(path);
    }
    return Isolate.run(() async {
      final bytes = await NativeDrawingBackend().readToFcb(path);
      return bytes;
    }, debugName: 'fancad-dwg-read');
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }
}
