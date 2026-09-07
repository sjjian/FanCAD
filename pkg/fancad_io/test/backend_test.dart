import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_io/src/sample_drawing.dart';
import 'package:test/test.dart';

void main() {
  test('capabilities list only the formats a backend can actually write', () {
    const none = BackendCapabilities(description: 'none');
    expect(none.canReadAnything, isFalse);
    expect(none.readableExtensions, isEmpty);
    expect(none.writableExtensions, isEmpty);
    expect(none.toString(), 'BackendCapabilities(none, read: , write: )');

    const dwgOnly = BackendCapabilities(
      readDwg: true,
      writeDwg: true,
      description: 'LibreDWG',
    );
    expect(dwgOnly.canReadAnything, isTrue);
    expect(dwgOnly.readableExtensions, ['dwg']);
    expect(dwgOnly.writableExtensions, ['dwg']);
    expect(
      dwgOnly.toString(),
      'BackendCapabilities(LibreDWG, read: dwg, write: dwg)',
    );

    const both = BackendCapabilities(
      readDwg: true,
      writeDwg: true,
      readDxf: true,
      writeDxf: true,
      description: 'memory',
    );
    expect(both.writableExtensions, ['dwg', 'dxf']);
    expect(both.toString(), contains('read: dwg/dxf'));
    expect(both.toString(), contains('write: dwg/dxf'));
  });

  test(
    'import result and exception keep path and cache off the default form',
    () {
      final result = ImportResult(
        document: CadDocument(),
        entityCount: 3,
        parseTime: const Duration(milliseconds: 4),
        decodeTime: const Duration(milliseconds: 6),
      );
      expect(result.totalTime, const Duration(milliseconds: 10));
      expect(
        result.toString(),
        'ImportResult(3 entities, parse 4ms, decode 6ms)',
      );

      expect(
        const ImportException('broken').toString(),
        'ImportException: broken',
      );
      expect(
        const ImportException('broken', path: '/tmp/a.dwg').toString(),
        'ImportException: broken (/tmp/a.dwg)',
      );
    },
  );

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
}
