import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  LineEntity line(double x1, double y1, double x2, double y2) => LineEntity(
    id: 1,
    start: Vec2(x1, y1),
    end: Vec2(x2, y2),
  );

  test('four lines that meet become the rectangle that encloses the pick', () {
    final loops = Construct.boundaryFromPick(
      [
        line(0, 0, 10, 0),
        line(10, 0, 10, 10),
        line(10, 10, 0, 10),
        line(0, 10, 0, 0),
      ],
      const Vec2(5, 5),
    );
    expect(loops, hasLength(1));
    expect(loops.first.isOuter, isTrue);
    expect(Intersect.polygonContains(loops.first.vertices, const Vec2(5, 5)), isTrue);
    expect(Construct.areaOf(HatchEntity(id: 0, loops: loops)), closeTo(100, 1e-6));
  });

  test('a circle inside that rectangle becomes an island', () {
    final loops = Construct.boundaryFromPick(
      [
        line(0, 0, 10, 0),
        line(10, 0, 10, 10),
        line(10, 10, 0, 10),
        line(0, 10, 0, 0),
        const CircleEntity(id: 2, center: Vec2(5, 5), radius: 2),
      ],
      const Vec2(1, 1),
    );
    expect(loops.length, 2);
    final outer = loops.firstWhere((loop) => loop.isOuter);
    final hole = loops.firstWhere((loop) => !loop.isOuter);
    expect(Intersect.polygonContains(outer.vertices, const Vec2(1, 1)), isTrue);
    expect(Intersect.polygonContains(hole.vertices, const Vec2(1, 1)), isFalse);
    expect(Intersect.polygonContains(hole.vertices, const Vec2(5, 5)), isTrue);
  });

  test('a pick inside the island takes the island, not the room', () {
    final loops = Construct.boundaryFromPick(
      [
        line(0, 0, 10, 0),
        line(10, 0, 10, 10),
        line(10, 10, 0, 10),
        line(0, 10, 0, 0),
        const CircleEntity(id: 2, center: Vec2(5, 5), radius: 2),
      ],
      const Vec2(5, 5),
    );
    expect(loops, hasLength(1));
    expect(
      Construct.areaOf(HatchEntity(id: 0, loops: loops)),
      closeTo(math.pi * 4, 0.5),
    );
  });

  test('a collinear overlap still closes the room around the pick', () {
    final loops = Construct.boundaryFromPick(
      [
        line(0, 0, 10, 0),
        line(3, 0, 7, 0),
        line(10, 0, 10, 10),
        line(10, 10, 0, 10),
        line(0, 10, 0, 0),
      ],
      const Vec2(5, 5),
    );
    expect(loops, hasLength(1));
    expect(Construct.areaOf(HatchEntity(id: 0, loops: loops)), closeTo(100, 1e-6));
  });

  test('a pick outside every loop finds nothing', () {
    expect(
      Construct.boundaryFromPick(
        [line(0, 0, 10, 0), line(10, 0, 10, 10)],
        const Vec2(50, 50),
      ),
      isEmpty,
    );
  });
}
