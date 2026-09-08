import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  test('an unknown entity without strokes cannot invent drawable geometry', () {
    expect(emit(UnknownEntity(id: 1, originalType: 'PROXY')).isEmpty, isTrue);
  });

  test('an unknown entity emits imported fallback strokes', () {
    final sink = emit(
      UnknownEntity(
        id: 2,
        originalType: 'REGION',
        strokes: Float64List.fromList([0, 0, 4, 0, 4, 3, 0, 3]),
        strokeCounts: const [4],
      ),
    );
    expect(sink.polylines, isNotEmpty);
    expect(sink.polylines.first.length, 8);
  });
}
