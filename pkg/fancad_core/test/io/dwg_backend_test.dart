import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_core/src/io/dwg_backend.dart';
import 'package:fancad_core/src/io/fcb/writer.dart';
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
  });

  test(
    'import result and exception keep path and cache off the default form',
    () {
      final result = OpenedDrawing(
        document: CadDocument(),
        entityCount: 3,
        parseTime: const Duration(milliseconds: 4),
        decodeTime: const Duration(milliseconds: 6),
      );
      expect(result.totalTime, const Duration(milliseconds: 10));
      expect(
        result.toString(),
        'OpenedDrawing(3 entities, parse 4ms, decode 6ms)',
      );

      expect(
        const DrawingFileException('broken').toString(),
        'DrawingFileException: broken',
      );
      expect(
        const DrawingFileException('broken', path: '/tmp/a.dwg').toString(),
        'DrawingFileException: broken (/tmp/a.dwg)',
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
        isA<DrawingFileException>().having(
          (error) => error.toString(),
          'toString',
          contains('/mem/missing.dwg'),
        ),
      ),
    );
  });
}
