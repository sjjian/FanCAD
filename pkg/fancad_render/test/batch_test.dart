import 'dart:typed_data';
import 'dart:ui';

import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a line batch vertex buffer grows, exposes a filled view and can clear',
    () {
      final buffer = LineBatch(const BatchKey(Color(0xFF000000), 1)).vertices;
      expect(buffer.isEmpty, isTrue);
      buffer.add2(1, 2);
      buffer.add4(3, 4, 5, 6);
      expect(buffer.length, 6);
      expect(buffer.view, Float32List.fromList([1, 2, 3, 4, 5, 6]));
      buffer.clear();
      expect(buffer.isEmpty, isTrue);
      expect(buffer.length, 0);
    },
  );

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

  test('a sub-pixel stub keeps its projected length', () {
    final batch = LineBatch(const BatchKey(Color(0xFF00FF00), 0));
    batch.addPolyline(Float32List.fromList([10, 4, 10.2, 4]));
    expect(batch.segmentCount, 1);
    expect(batch.vertices.view[0], closeTo(10, 1e-5));
    expect(batch.vertices.view[2], closeTo(10.2, 1e-5));
  });

  test('vertices inside a pixel of the last one kept are merged', () {
    // A zoomed-out arc: ten vertices a fifth of a pixel apart, then a jump.
    final batch = LineBatch(const BatchKey(Color(0xFF00FF00), 0));
    batch.addPolyline(
      Float32List.fromList([
        for (var i = 0; i < 10; i++) ...[10 + i * 0.2, 4],
        40,
        4,
      ]),
    );
    expect(batch.segmentCount, 2);
    expect(batch.vertices.view.sublist(0, 2), [10, 4]);
    expect(batch.vertices.view.sublist(6, 8), [40, 4]);
  });

  test('a stub inside a pixel of the last kept vertex is dropped', () {
    final batch = LineBatch(const BatchKey(Color(0xFF00FF00), 0));
    batch.addPolyline(Float32List.fromList([10, 4, 40, 4, 40.4, 4]));
    expect(batch.segmentCount, 1);
    expect(batch.vertices.view.sublist(0, 4), [10, 4, 40, 4]);
  });

  test('a ring of sub-pixel vertices keeps one segment', () {
    final batch = LineBatch(const BatchKey(Color(0xFF00FF00), 0));
    batch.addPolyline(
      Float32List.fromList([5, 5, 5.3, 5, 5.3, 5.3, 5, 5.3]),
      closed: true,
    );
    expect(batch.segmentCount, 1);
  });

  test('overlapping segments are drawn once, either way round', () {
    final batch = LineBatch(const BatchKey(Color(0xFF00FF00), 0))
      ..vertices.add4(0, 0, 10, 0)
      ..vertices.add4(10, 0, 0, 0)
      ..vertices.add4(0.01, 0, 10, 0)
      ..vertices.add4(0, 1, 10, 1);
    batch.removeOverlaps();
    expect(batch.segmentCount, 2);
    expect(
      batch.vertices.view,
      Float32List.fromList([0, 0, 10, 0, 0, 1, 10, 1]),
    );
  });

  test('sub-pixel segments keep one per pixel', () {
    final batch = LineBatch(const BatchKey(Color(0xFF00FF00), 0))
      ..vertices.add4(3.1, 3.1, 3.3, 3.2)
      ..vertices.add4(3.6, 3.7, 3.8, 3.9)
      ..vertices.add4(4.2, 3.1, 4.4, 3.2)
      ..vertices.add4(3.0, 3.0, 9.0, 3.0);
    batch.removeOverlaps();
    expect(batch.segmentCount, 3);
  });

  test('a small batch is not cut into cells', () {
    final batch = LineBatch(const BatchKey(Color(0xFF00FF00), 0));
    for (var i = 0; i < 40; i++) {
      final y = 0.5 + i.toDouble();
      batch.vertices.add4(0, y, 12, y);
    }
    batch.removeOverlaps();
    expect(batch.bounds, const Rect.fromLTRB(0, 0.5, 12, 39.5));

    // Below the threshold the painter's segment scan is cheaper than a grid.
    batch.indexCells();
    expect(batch.hasCells, isFalse);
  });

  test('a large batch is cut into a grid and every segment lands once', () {
    final batch = LineBatch(const BatchKey(Color(0xFF00FF00), 0));
    for (var i = 0; i < 300; i++) {
      final x = 5.0 + (i % 20) * 1.5;
      final y = 5.0 + (i ~/ 20) * 1.5;
      batch.vertices.add4(x, y, x + 4, y);
    }
    for (var i = 0; i < 300; i++) {
      final x = 500.0 + (i % 20) * 1.5;
      final y = 500.0 + (i ~/ 20) * 1.5;
      batch.vertices.add4(x, y, x + 4, y);
    }
    // One segment spans the whole batch, so it belongs to no single cell.
    batch.vertices.add4(0, 0, 600, 600);

    batch.removeOverlaps();
    batch.indexCells();
    expect(batch.segmentCount, 601);
    expect(batch.hasCells, isTrue);

    final starts = batch.cellStarts!;
    const side = LineBatch.gridSide;
    expect(starts.length, side * side + 1);
    // The two clusters sit in opposite corners, and the spanning segment is
    // the tail, so nothing is lost and nothing is counted twice.
    expect(starts[1] - starts[0], 300);
    expect(starts[side * side] - starts[side * side - 1], 300);
    expect(starts[side * side], 600);
    expect(batch.wideBounds, const Rect.fromLTRB(0, 0, 600, 600));
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
