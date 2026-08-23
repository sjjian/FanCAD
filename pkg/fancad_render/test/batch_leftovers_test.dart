import 'dart:typed_data';
import 'dart:ui';

import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'BatchKey toString keeps colour and width so a merge miss can be seen',
    () {
      const key = BatchKey(Color(0xFFFFFFFF), 1.5);
      expect(key.toString(), 'BatchKey(#ffffffff, 1.5)');
      expect(key, isNot(const BatchKey(Color(0xFFFFFFFF), 2)));
    },
  );

  test(
    'a point batch counts markers and stays empty until a vertex is added',
    () {
      final batch = PointBatch(const BatchKey(Color(0xFFFF0000), 3));
      expect(batch.isEmpty, isTrue);
      expect(batch.pointCount, 0);

      batch.vertices.add2(1, 2);
      batch.vertices.add2(3, 4);
      expect(batch.pointCount, 2);
      expect(batch.isEmpty, isFalse);
      expect(batch.vertices.view, Float32List.fromList([1, 2, 3, 4]));
    },
  );

  test('a two-point closed polyline does not invent a third segment', () {
    final batch = LineBatch(const BatchKey(Color(0xFF000000), 1));
    batch.addPolyline(Float32List.fromList([0, 0, 10, 0]), closed: true);
    expect(batch.segmentCount, 1);
  });
}
