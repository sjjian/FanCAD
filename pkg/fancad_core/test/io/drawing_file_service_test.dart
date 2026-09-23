import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_core/src/io/drawing_file_service.dart';
import 'package:fancad_core/src/io/dwg_backend.dart';
import 'package:fancad_core/src/io/fcb/reader.dart';
import 'package:fancad_core/src/io/fcb/writer.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import 'support/sample_drawing.dart';

class _DxfOnlyBackend implements DwgBackend {
  @override
  DwgCapabilities get capabilities =>
      const DwgCapabilities(description: 'dxf-only');

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

class _CaptureDwgBackend implements DwgBackend {
  Uint8List? fcb;
  String? path;
  int? version;

  @override
  DwgCapabilities get capabilities =>
      const DwgCapabilities(canWrite: true, description: 'capture-dwg');

  @override
  Future<Uint8List> readToFcb(String path) async =>
      throw UnsupportedError(path);

  @override
  Future<void> writeFromFcb(
    String path,
    Uint8List fcb, {
    int targetVersion = 0,
  }) async {
    this.path = path;
    this.fcb = fcb;
    version = targetVersion;
  }
}

void main() {
  test('open refuses a path the importer cannot read', () {
    final importer = drawingFilesWithBackend(_DxfOnlyBackend());
    expect(importer.canOpen('notes.txt'), isFalse);
    expect(importer.canOpen('part.dwg'), isFalse);
    expect(importer.canOpen('part.dxf'), isTrue);
    expect(importer.canOpen('part.fcb'), isTrue);
    expect(importer.canOpen('/tmp/SOAS---3.0弧板/part.dxf'), isTrue);
    expect(importer.canOpen('/tmp/SOAS---3.0弧板/notes'), isFalse);

    expect(
      () => importer.open('notes.txt'),
      throwsA(
        isA<DrawingFileException>()
            .having((error) => error.path, 'path', 'notes.txt')
            .having(
              (error) => error.message,
              'message',
              contains('not a drawing'),
            ),
      ),
    );
    expect(
      () => importer.open('part.dwg'),
      throwsA(
        isA<DrawingFileException>().having(
          (error) => error.message,
          'message',
          contains('no DWG backend'),
        ),
      ),
    );
    expect(
      () => importer.open('   '),
      throwsA(
        isA<DrawingFileException>().having(
          (error) => error.path,
          'path',
          '   ',
        ),
      ),
    );
  });

  test(
    'a DWG save falls back to a sibling DXF the backend can actually write',
    () async {
      final dir = tempDir(prefix: 'fancad-import-');
      final document = drawing(
        entities: const [
          LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
        ],
      );
      final importer = drawingFilesWithBackend(_DxfOnlyBackend());
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
    final dir = tempDir(prefix: 'fancad-import-fcb-');
    final document = drawing(
      entities: const [LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0))],
    );
    final importer = drawingFilesWithBackend(_DxfOnlyBackend());
    final outcome = await importer.save('${dir.path}/notes.txt', document);

    expect(outcome.usedFallback, isTrue);
    expect(outcome.path, '${dir.path}/notes.fcb');
    expect(File(outcome.path).existsSync(), isTrue);

    final opened = await importer.open(outcome.path);
    expect(opened.document.entityCount, 1);
  });

  test('a DWG save encodes FCB and hands it to the backend', () async {
    final backend = _CaptureDwgBackend();
    final importer = drawingFilesWithBackend(backend);
    final document = drawing(
      entities: const [LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0))],
    );

    final outcome = await importer.save('/tmp/Drawing1.dwg', document);

    expect(outcome.path, '/tmp/Drawing1.dwg');
    expect(backend.path, '/tmp/Drawing1.dwg');
    expect(backend.version, 2004);
    expect(backend.fcb, isNotNull);
    final restored = FcbReader(backend.fcb!).decode().document;
    expect(restored.entities.whereType<LineEntity>(), hasLength(1));
    expect(
      restored.entities.whereType<LineEntity>().single.end.x,
      closeTo(10, 1e-9),
    );
  });

  test('the importer opens a memory DWG', () async {
    final temporary = tempDir(prefix: 'fancad-mem');
    final document = SampleDrawings.mechanicalPart();
    final fcb = FcbWriter().write(document);
    final source = File('${temporary.path}/part.dwg')..writeAsBytesSync([0]);
    final importer = DrawingFileService.inMemory(files: {source.path: fcb});

    expect(importer.canOpen(source.path), isTrue);
    expect(importer.canOpen('notes.fcb'), isTrue);
    expect(importer.canOpen('   '), isFalse);

    final opened = await importer.open(source.path);
    expect(opened.entityCount, document.entityCount);
    expect(opened.totalTime, greaterThanOrEqualTo(Duration.zero));
  });

  test('the importer writes and reopens its own FCB files', () async {
    final temporary = tempDir(prefix: 'fancad-fcb-save');
    final document = drawing(
      entities: const [LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0))],
    );
    final importer = DrawingFileService.inMemory();
    final path = '${temporary.path}/part.fcb';
    final outcome = await importer.save(path, document);
    expect(outcome.usedFallback, isFalse);
    expect(File(outcome.path).existsSync(), isTrue);

    final opened = await importer.open(path);
    expect(opened.document.entityCount, 1);
    expect(opened.document.entities.single, isA<LineEntity>());
  });

  test('encodes and decodes FanCAD native files', () {
    final importer = drawingFilesWithBackend(_DxfOnlyBackend());
    final document = SampleDrawings.mechanicalPart();
    final result = importer.decode(importer.encode(document));
    expect(result.entityCount, document.entityCount);
  });
}
