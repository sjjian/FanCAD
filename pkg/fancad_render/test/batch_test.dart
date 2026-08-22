import 'dart:typed_data';
import 'dart:ui';

import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a line batch vertex buffer grows, exposes a filled view and can clear', () {
    final buffer = LineBatch(const BatchKey(Color(0xFF000000), 1)).vertices;
    expect(buffer.isEmpty, isTrue);
    buffer.add2(1, 2);
    buffer.add4(3, 4, 5, 6);
    expect(buffer.length, 6);
    expect(buffer.view, Float32List.fromList([1, 2, 3, 4, 5, 6]));
    buffer.clear();
    expect(buffer.isEmpty, isTrue);
    expect(buffer.length, 0);
  });

  test('a line batch skips short runs and closes a ring', () {
    const key = BatchKey(Color(0xFFFFFFFF), 1);
    expect(key, const BatchKey(Color(0xFFFFFFFF), 1));
    expect({key}.contains(const BatchKey(Color(0xFFFFFFFF), 1)), isTrue);

    final batch = LineBatch(key);
    batch.addPolyline(Float32List.fromList([0, 0]));
    expect(batch.isEmpty, isTrue);

    batch.addPolyline(Float32List.fromList([0, 0, 10, 0, 10, 4]), closed: true);
    expect(batch.segmentCount, 3);
    expect(batch.vertices.view[8], 10);
    expect(batch.vertices.view[9], 4);
    expect(batch.vertices.view[10], 0);
    expect(batch.vertices.view[11], 0);
  });

  test('a fill batch ignores a two-point ring', () {
    final batch = FillBatch(const BatchKey(Color(0xFF00FF00), 0));
    batch.addRing(Float32List.fromList([0, 0, 1, 0]));
    expect(batch.isEmpty, isTrue);
    batch.addRing(Float32List.fromList([0, 0, 4, 0, 4, 3, 0, 3]));
    expect(batch.ringCount, 1);
    expect(batch.isEmpty, isFalse);
  });
}
