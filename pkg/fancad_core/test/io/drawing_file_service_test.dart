import 'dart:io';

import 'package:fancad_core/src/core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  test('open refuses a path the importer cannot read', () {
    const importer = DrawingFileService();
    expect(importer.canOpen('notes.txt'), isFalse);
    expect(importer.canOpen('part.dwg'), isFalse);
    expect(importer.canOpen('part.dxf'), isTrue);
    expect(importer.canOpen('part.fcb'), isFalse);
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
          contains('not supported'),
        ),
      ),
    );
    expect(
      () => importer.open('part.fcb'),
      throwsA(
        isA<DrawingFileException>().having(
          (error) => error.message,
          'message',
          contains('no longer supported'),
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

  test('a simple DWG save uses the Dart writer', () async {
    final dir = tempDir(prefix: 'fancad-import-');
    final document = drawing(
      entities: const [LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0))],
    );
    const importer = DrawingFileService();
    final outcome = await importer.save('${dir.path}/sheet.dwg', document);

    expect(outcome.usedFallback, isFalse);
    expect(outcome.path, '${dir.path}/sheet.dwg');
    expect(File(outcome.path).existsSync(), isTrue);
    expect(File('${dir.path}/sheet.dxf').existsSync(), isFalse);

    final opened = await importer.open(outcome.path);
    expect(opened.document.entities.whereType<LineEntity>(), hasLength(1));
  });

  test(
    'a DWG save with unsupported entities falls back to a sibling DXF',
    () async {
      final dir = tempDir(prefix: 'fancad-import-');
      final document = drawing(
        entities: const [
          InsertEntity(id: 0, blockName: 'B', position: Vec2.zero()),
        ],
      );
      const importer = DrawingFileService();
      final outcome = await importer.save('${dir.path}/sheet.dwg', document);

      expect(outcome.usedFallback, isTrue);
      expect(outcome.path, '${dir.path}/sheet.dxf');
      expect(File(outcome.path).existsSync(), isTrue);
      expect(File('${dir.path}/sheet.dwg').existsSync(), isFalse);
    },
  );

  test('an unknown extension is written as DXF rather than dropped', () async {
    final dir = tempDir(prefix: 'fancad-import-unknown-');
    final document = drawing(
      entities: const [LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0))],
    );
    const importer = DrawingFileService();
    final outcome = await importer.save('${dir.path}/notes.txt', document);

    expect(outcome.usedFallback, isTrue);
    expect(outcome.path, '${dir.path}/notes.dxf');
    expect(File(outcome.path).existsSync(), isTrue);

    final opened = await importer.open(outcome.path);
    expect(opened.document.entityCount, 1);
  });
}
