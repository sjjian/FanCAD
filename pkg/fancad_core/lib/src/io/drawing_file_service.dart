import 'dart:isolate';

import '../model/document/drawing_data.dart';
import 'dwg/dwg_codec.dart';
import 'dxf/reader.dart';
import 'dxf/writer.dart';
import 'fidelity.dart';
import 'opened_drawing.dart';
import 'save_strategy.dart';

/// The file that was actually written.
class SavedDrawing {
  const SavedDrawing({
    required this.path,
    this.usedFallback = false,
    this.reason = '',
  });

  final String path;
  final bool usedFallback;

  /// Empty when [path] is the path the caller asked for.
  final String reason;
}

/// Opens and saves drawings.
///
/// This is the only entry point the rest of the application uses to get a
/// [DrawingData] from disk. DWG and DXF are decoded directly into the document
/// model; no caller has to know which format produced the document it
/// received.
class DrawingFileService {
  /// Opens and saves drawings with the built-in codecs.
  const DrawingFileService();

  /// Whether [path] looks like something this service can open.
  bool canOpen(String path) {
    final target = path.trim();
    final extension = _extensionOf(target);
    return extension == 'dxf' ||
        (extension == 'dwg' && const DwgCodec().canRead(target));
  }

  /// Opens a drawing.
  ///
  /// DWG parsing and document construction are CPU-bound, so they run on a
  /// worker isolate: a large drawing would otherwise freeze the UI (and its
  /// opening indicator) for seconds. The document graph is copied back, but
  /// that copy costs far less than the parse the UI is spared.
  Future<OpenedDrawing> open(String path) async {
    final target = path.trim();
    if (!canOpen(target)) {
      throw DrawingFileException(
        _cannotOpenMessage(target),
        path: target.isEmpty ? path : target,
      );
    }
    final extension = _extensionOf(target);
    if (extension == 'dxf') {
      // ASCII DXF is decoded in Dart.
      final watch = Stopwatch()..start();
      final document = await const DxfReader().readFile(target);
      watch.stop();
      return OpenedDrawing(
        document: document,
        entityCount: document.entityCount,
        decodeTime: watch.elapsed,
      );
    }
    return _readDwgOnWorker(target);
  }

  /// Saves [document] to [path], choosing a format this build can actually
  /// write. Returns the path that was written, which may be a fallback.
  Future<SavedDrawing> save(String path, DrawingData document) async {
    final plan = SaveStrategy(
      canWriteDwg: const DwgCodec().canWrite(document),
      dwgFallbackReason:
          'This drawing contains objects the DWG writer cannot represent; '
          'saving DXF instead.',
    ).plan(path);
    switch (plan.format) {
      case SaveFormat.dxf:
        await const DxfWriter().writeFile(plan.targetPath, document);
      case SaveFormat.dwg:
        await const DwgCodec().write(plan.targetPath, document);
    }
    return SavedDrawing(
      path: plan.targetPath,
      usedFallback: plan.usedFallback,
      reason: plan.reason,
    );
  }

  /// Compares [source] to a freshly written-and-reread copy at [path].
  Future<FidelityReport> audit(String path, DrawingData source) async {
    final outcome = await save(path, source);
    final reopened = await open(outcome.path);
    return const FidelityAuditor().compare(source, reopened.document);
  }

  /// Runs the pure-Dart DWG read on a worker so the UI isolate stays free.
  ///
  /// [DwgCodec] holds no isolate-local state, so the worker constructs its
  /// own. Everything [OpenedDrawing] carries is plain data, which makes the
  /// result sendable without a hand-written transfer format.
  Future<OpenedDrawing> _readDwgOnWorker(String path) => Isolate.run(
    () => const DwgCodec().read(path),
    debugName: 'fancad-dwg-read',
  );

  String _cannotOpenMessage(String path) {
    final extension = _extensionOf(path);
    if (extension == 'fcb') {
      return 'FCB files are no longer supported by FanCAD.';
    }
    if (extension == 'dwg') {
      return 'This DWG version or layout is not supported by the Dart reader.';
    }
    return 'This file is not a drawing FanCAD can open.';
  }

  /// Extension of the last path segment, so a dotted parent folder is ignored.
  static String _extensionOf(String path) {
    final slash = path.lastIndexOf('/');
    final back = path.lastIndexOf(r'\');
    final sep = slash > back ? slash : back;
    final name = sep < 0 ? path : path.substring(sep + 1);
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}
