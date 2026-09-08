import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing loop or out-of-range grip cannot invent a vertex', () {
    const empty = HatchEntity(id: 1, loops: []);
    expect(empty.withGrip(0, const Vec2(1, 1)), same(empty));

    final hatch = HatchEntity(
      id: 2,
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 4, 0, 4, 3, 0, 3])),
      ],
    );
    expect(hatch.withGrip(99, const Vec2(1, 1)), same(hatch));
  });

  test('hatch bounds are the boundary loops, not the pattern strokes', () {
    final hatch = HatchEntity(
      id: 1,
      solid: false,
      patternName: 'ANSI31',
      patternScale: 0.5,
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 10, 0, 10])),
      ],
    );
    expect(hatch.computeBounds(), const Bounds2(0, 0, 20, 10));
  });

  test('copyWith keeps the loops and emit fills a solid', () {
    final hatch = HatchEntity(
      id: 1,
      solid: false,
      patternName: 'ANSI31',
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
      ],
    ).copyWith(patternName: 'STEEL', patternScale: 2);
    expect(hatch.patternName, 'STEEL');
    expect(hatch.patternScale, 2);
    expect(hatch.loops, hasLength(1));
    final sink = PolylineSink();
    HatchEntity(
      id: 1,
      solid: true,
      patternName: 'ANSI31',
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
      ],
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.fills, isNotEmpty);
  });

  test('a grip on the inner loop does not move the outer vertices', () {
    final hatch = HatchEntity(
      id: 1,
      solid: true,
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
        HatchLoop(
          vertices: Float64List.fromList([6, 6, 10, 6, 10, 10, 6, 10]),
          isOuter: false,
        ),
      ],
    );
    expect(hatch.grips(), hasLength(8));
    final edited = hatch.withGrip(5, const Vec2(12, 7));
    expect(edited.loops.first.vertices[0], 0);
    expect(edited.loops.last.vertices[2], closeTo(12, 1e-9));
    expect(edited.loops.last.vertices[3], closeTo(7, 1e-9));
    expect(hatch.withGrip(20, const Vec2.zero()), hatch);

    final sink = PolylineSink();
    edited.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.fills, hasLength(1));
    expect(sink.polylines, hasLength(2));
  });

  test('a solid with only an island still fills that ring', () {
    const empty = HatchEntity(id: 1, loops: []);
    final silent = PolylineSink();
    empty.emit(const EmitContext(tolerance: 0.1), silent);
    expect(silent.fills, isEmpty);

    final island = HatchEntity(
      id: 1,
      solid: true,
      loops: [
        HatchLoop(
          vertices: Float64List.fromList([0, 0, 4, 0, 4, 4, 0, 4]),
          isOuter: false,
        ),
      ],
    );
    final sink = PolylineSink();
    island.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.fills, hasLength(1));
    expect(sink.polylines, hasLength(1));
  });

  test('junk hatch loops cannot invent a boundary', () {
    final hatch =
        CadEntity.fromJson(const {
              'type': 'hatch',
              'loops': 'nope',
            })
            as HatchEntity;
    expect(hatch.loops, isEmpty);
    final sink = PolylineSink();
    hatch.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.isEmpty, isTrue);
  });

  test('resolved definition lines survive a JSON round trip', () {
    final hatch = HatchEntity(
      id: 7,
      solid: false,
      patternName: 'ANSI31',
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
      ],
      patternLines: const [
        HatchPatternLine(
          angle: 3.141592653589793,
          originX: 45236.355,
          originY: -40545.868,
          deltaY: -15.875,
          dashes: [2, -1],
        ),
      ],
    );

    final decoded = CadEntity.fromJson(hatch.toJson()) as HatchEntity;
    expect(decoded.patternLines, hasLength(1));
    expect(decoded.patternLines.single.angle, closeTo(math.pi, 1e-12));
    expect(decoded.patternLines.single.originY, closeTo(-40545.868, 1e-9));
    expect(decoded.patternLines.single.deltaY, closeTo(-15.875, 1e-12));
    expect(decoded.patternLines.single.dashes, [2, -1]);

    // A hatch that only names a pattern must not grow an empty list key.
    expect(
      HatchEntity(id: 8, loops: hatch.loops).toJson(),
      isNot(contains('patternLines')),
    );
  });

  test('a one-point loop cannot invent a hatch fill', () {
    final sink = PolylineSink();
    HatchEntity(
      id: 1,
      loops: [HatchLoop(vertices: Float64List.fromList([0, 0]))],
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.fills, isEmpty);
    expect(sink.polylines, isEmpty);
  });
}

