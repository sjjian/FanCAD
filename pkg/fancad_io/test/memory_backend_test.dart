import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_io/src/sample_drawing.dart';
import 'package:test/test.dart';

void main() {
  test('the memory backend stores FCB and throws on a missing path', () async {
    final document = SampleDrawings.mechanicalPart();
    final bytes = FcbWriter().write(document);
    final backend = MemoryDrawingBackend(files: {'/mem/a.dwg': bytes});
    expect(backend.paths, contains('/mem/a.dwg'));
    expect(backend.capabilities.canReadAnything, isTrue);
    expect(
      backend.capabilities.readableExtensions,
      containsAll(['dwg', 'dxf']),
    );

    final read = await backend.readToFcb('/mem/a.dwg');
    expect(read, bytes);

    await backend.writeFromFcb('/mem/b.dwg', Uint8List.fromList([1, 2, 3]));
    expect(
      await backend.readToFcb('/mem/b.dwg'),
      Uint8List.fromList([1, 2, 3]),
    );

    expect(
      () => backend.readToFcb('/mem/missing.dwg'),
      throwsA(
        isA<ImportException>().having(
          (error) => error.toString(),
          'toString',
          contains('/mem/missing.dwg'),
        ),
      ),
    );
  });

  test(
    'the importer opens a memory DWG and can reopen it from the FCB cache',
    () async {
      final temporary = Directory.systemTemp.createTempSync('fancad-mem');
      addTearDown(() => temporary.deleteSync(recursive: true));

      final document = SampleDrawings.mechanicalPart();
      final fcb = FcbWriter().write(document);
      final source = File('${temporary.path}/part.dwg')..writeAsBytesSync([0]);
      final backend = MemoryDrawingBackend(files: {source.path: fcb});
      final cache = FcbCache(directory: Directory('${temporary.path}/cache'));
      final importer = DrawingImporter(backend: backend, cache: cache);

      expect(importer.canOpen(source.path), isTrue);
      expect(importer.canOpen('notes.fcb'), isTrue);
      expect(importer.canOpen('   '), isFalse);

      final first = await importer.open(source.path);
      expect(first.fromCache, isFalse);
      expect(first.entityCount, document.entityCount);
      expect(first.totalTime, greaterThanOrEqualTo(Duration.zero));

      final second = await importer.open(source.path);
      expect(second.fromCache, isTrue);
      expect(second.entityCount, document.entityCount);
      expect(second.toString(), contains('from cache'));
    },
  );

  test('the importer writes and reopens its own FCB files', () async {
    final temporary = Directory.systemTemp.createTempSync('fancad-fcb-save');
    addTearDown(() => temporary.deleteSync(recursive: true));

    final document = CadDocument()
      ..addEntity(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)));
    final importer = DrawingImporter(backend: MemoryDrawingBackend());
    final path = '${temporary.path}/part.fcb';
    final outcome = await importer.save(path, document);
    expect(outcome.usedFallback, isFalse);
    expect(File(outcome.path).existsSync(), isTrue);

    final opened = await importer.open(path);
    expect(opened.document.entityCount, 1);
    expect(opened.document.entities.single, isA<LineEntity>());
  });
}
