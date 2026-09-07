import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

/// Save then reopen a drawing through DWG, DXF, or FCB.
class Roundtrip {
  Roundtrip({DrawingImporter? importer})
    : importer = importer ?? DrawingImporter();

  final DrawingImporter importer;

  static const timeout = Timeout(Duration(minutes: 2));

  void requireDwg() {
    expect(
      importer.capabilities.writeDwg && importer.capabilities.readDwg,
      isTrue,
      reason:
          'Built without LibreDWG: ${importer.capabilities.description}. '
          'Set FANCAD_LIBREDWG_ROOT and rebuild.',
    );
  }

  Future<CadDocument> dwg(
    CadDocument source, {
    String name = 'round',
  }) async {
    final path = await writeDwg(source, name: name);
    return (await importer.open(path)).document;
  }

  /// Writes [source] and returns the temp path so callers can inspect bytes.
  Future<String> writeDwg(
    CadDocument source, {
    String name = 'round',
  }) async {
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
