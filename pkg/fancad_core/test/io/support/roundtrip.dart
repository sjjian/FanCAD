import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_core/src/io/dxf/reader.dart';
import 'package:fancad_core/src/io/dxf/writer.dart';
import 'package:fancad_core/src/io/fcb/reader.dart';
import 'package:fancad_core/src/io/fcb/writer.dart';
import 'package:fancad_core/src/io/native/native_dwg_backend.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

/// Save then reopen a drawing through DWG, DXF, or FCB.
class Roundtrip {
  Roundtrip({DrawingFileService? importer})
    : importer = importer ?? DrawingFileService();

  final DrawingFileService importer;

  static const timeout = Timeout(Duration(minutes: 2));

  void requireDwg() {
    final dwg = NativeDwgBackend().capabilities;
    expect(
      dwg.canWrite && dwg.canRead,
      isTrue,
      reason:
          'Built without LibreDWG: ${dwg.description}. '
          'Set FANCAD_LIBREDWG_ROOT and rebuild.',
    );
  }

  Future<CadDocument> dwg(CadDocument source, {String name = 'round'}) async {
    final path = await writeDwg(source, name: name);
    return (await importer.open(path)).document;
  }

  /// Writes [source] and returns the temp path so callers can inspect bytes.
  Future<String> writeDwg(CadDocument source, {String name = 'round'}) async {
    final directory = tempDir(prefix: 'fancad-$name');
    final path = '${directory.path}/$name.dwg';
    await importer.save(path, source);
    return path;
  }

  CadDocument dxf(CadDocument source) {
    return const DxfReader().readString(const DxfWriter().writeString(source));
  }

  CadDocument fcb(CadDocument source) {
    return FcbReader(FcbWriter().write(source)).decode().document;
  }
}
