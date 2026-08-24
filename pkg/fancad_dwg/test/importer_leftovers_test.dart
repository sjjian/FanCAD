import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:test/test.dart';

class _DxfOnlyBackend implements DrawingBackend {
  @override
  BackendCapabilities get capabilities =>
      const BackendCapabilities(description: 'dxf-only');

  @override
  Future<Uint8List> readToFcb(String path) async =>
      throw UnsupportedError(path);

  @override
  Future<void> writeFromFcb(
    String path,
    Uint8List fcb, {
    int targetVersion = 0,
  }) async {}
}

void main() {
  test('open refuses a path the importer cannot read', () {
    final importer = DrawingImporter(backend: _DxfOnlyBackend());
    expect(importer.canOpen('notes.txt'), isFalse);
    expect(importer.canOpen('part.dwg'), isFalse);
    expect(importer.canOpen('part.dxf'), isTrue);
    expect(importer.canOpen('part.fcb'), isTrue);
    expect(importer.canOpen('/tmp/SOAS---3.0弧板/part.dxf'), isTrue);
    expect(importer.canOpen('/tmp/SOAS---3.0弧板/notes'), isFalse);

    expect(
      () => importer.open('notes.txt'),
      throwsA(
        isA<ImportException>().having(
          (error) => error.path,
          'path',
          'notes.txt',
        ),
      ),
    );
    expect(
      () => importer.open('part.dwg'),
      throwsA(
        isA<ImportException>().having(
          (error) => error.message,
          'message',
          contains('no DWG backend'),
        ),
      ),
    );
    expect(
      () => importer.open('   '),
      throwsA(
        isA<ImportException>().having((error) => error.path, 'path', '   '),
      ),
    );
  });

  test(
    'a DWG save falls back to a sibling DXF the backend can actually write',
    () async {
      final dir = Directory.systemTemp.createTempSync('fancad-import-');
      addTearDown(() => dir.deleteSync(recursive: true));

      final document = CadDocument()
        ..addEntity(
          const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
        );
      final importer = DrawingImporter(backend: _DxfOnlyBackend());
      final outcome = await importer.save('${dir.path}/sheet.dwg', document);

      expect(outcome.usedFallback, isTrue);
      expect(outcome.path, '${dir.path}/sheet.dxf');
      expect(File(outcome.path).existsSync(), isTrue);
      expect(File('${dir.path}/sheet.dwg').existsSync(), isFalse);

      final opened = await importer.open(outcome.path);
      expect(opened.document.entities.whereType<LineEntity>(), hasLength(1));
    },
  );

  test('an unknown extension is written as FCB rather than dropped', () async {
    final dir = Directory.systemTemp.createTempSync('fancad-import-fcb-');
    addTearDown(() => dir.deleteSync(recursive: true));

    final document = CadDocument()
      ..addEntity(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)));
    final importer = DrawingImporter(backend: _DxfOnlyBackend());
    final outcome = await importer.save('${dir.path}/notes.txt', document);

    expect(outcome.usedFallback, isTrue);
    expect(outcome.path, '${dir.path}/notes.fcb');
    expect(File(outcome.path).existsSync(), isTrue);

    final opened = await importer.open(outcome.path);
    expect(opened.document.entityCount, 1);
  });
}
