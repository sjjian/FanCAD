import 'package:fancad_core/src/core.dart';
import 'package:fancad_core/src/io/dxf/reader.dart';
import 'package:fancad_core/src/io/dxf/writer.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

/// Save then reopen a drawing through DWG or DXF.
class Roundtrip {
  Roundtrip({DrawingFileService? importer})
    : importer = importer ?? DrawingFileService();

  final DrawingFileService importer;

  static const timeout = Timeout(Duration(minutes: 2));

  void requireDwg() {
    // The pure-Dart reader is always compiled in; there is no optional
    // backend to probe before a round trip.
  }

  Future<CadDocument> dwg(CadDocument source, {String name = 'round'}) async {
    final path = await writeDwg(source, name: name);
    return CadDocument.fromData((await importer.open(path)).document);
  }

  /// Writes [source] and returns the temp path so callers can inspect bytes.
  Future<String> writeDwg(CadDocument source, {String name = 'round'}) async {
    final directory = tempDir(prefix: 'fancad-$name');
    final path = '${directory.path}/$name.dwg';
    await importer.save(path, source);
    return path;
  }

  CadDocument dxf(CadDocument source) {
    return CadDocument.fromData(
      const DxfReader().readString(const DxfWriter().writeString(source)),
    );
  }
}
