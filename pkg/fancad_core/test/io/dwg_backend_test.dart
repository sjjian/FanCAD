import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import 'support/sample_drawing.dart';

void main() {
  test('DWG capabilities describe only the replaceable DWG adapter', () {
    const none = DwgCapabilities(description: 'none');
    expect(none.canRead, isFalse);
    expect(none.canWrite, isFalse);
    expect(none.toString(), 'DwgCapabilities(none, read: false, write: false)');

    const dwgOnly = DwgCapabilities(
      canRead: true,
      canWrite: true,
      description: 'LibreDWG',
    );
    expect(
      dwgOnly.toString(),
      'DwgCapabilities(LibreDWG, read: true, write: true)',
    );

    const files = DrawingFileCapabilities(
      dwg: DwgCapabilities(canRead: true, description: 'memory'),
    );
    expect(files.readableExtensions, ['dwg', 'dxf']);
    expect(files.writableExtensions, ['dxf']);
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
    final backend = MemoryDwgBackend(files: {'/mem/a.dwg': bytes});
    expect(backend.paths, contains('/mem/a.dwg'));
    expect(backend.capabilities.canRead, isTrue);

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
