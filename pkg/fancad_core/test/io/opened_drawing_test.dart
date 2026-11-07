import 'package:fancad_core/src/core.dart';
import 'package:test/test.dart';

void main() {
  test('open result and exception keep path and timing in their output', () {
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
  });
}
