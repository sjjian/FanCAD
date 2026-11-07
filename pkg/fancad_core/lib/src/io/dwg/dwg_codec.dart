import 'dart:io';

import '../../model/document/drawing_data.dart';
import '../opened_drawing.dart';
import 'dwg_document.dart';
import 'dwg_reader.dart';
import 'writer/cad_document_writer.dart';

/// Reads and writes DWG without any replaceable backend.
///
/// The reader supports R13-R2018. The writer emits R2000 and reports whether a
/// document is representable, so `DrawingFileService` can choose DXF instead.
final class DwgCodec {
  const DwgCodec();

  /// Whether this document can be stored without losing geometry.
  bool canWrite(DrawingData document) => canWriteR2000Document(document);

  Future<void> write(String path, DrawingData document) async {
    await File(path).writeAsBytes(writeR2000Document(document));
  }

  bool canRead(String path) => DwgReader.supportsFile(path);

  Future<OpenedDrawing> read(String path) async {
    final watch = Stopwatch()..start();
    final drawing = DwgReader.readFile(path);
    final document = dwgToDocument(drawing);
    watch.stop();
    final diagnostics = <String>[
      if (drawing.entities.length < drawing.objectCount)
        'The Dart reader skipped objects it does not decode yet '
            '(${drawing.entities.length} of ${drawing.objectCount}).',
      'The Dart backend reads R13-R2018 fixed types and most class types.',
    ];
    return OpenedDrawing(
      document: document,
      diagnostics: diagnostics,
      entityCount: document.entityCount,
      parseTime: watch.elapsed,
      bytesTransferred: File(path).lengthSync(),
    );
  }
}
