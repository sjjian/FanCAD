import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  RegionGeometry square(double x0, double y0, double x1, double y1) =>
      RegionGeometry.fromLoops([
        RegionLoop([
          RegionLine(start: Vec2(x0, y0), end: Vec2(x1, y0)),
          RegionLine(start: Vec2(x1, y0), end: Vec2(x1, y1)),
          RegionLine(start: Vec2(x1, y1), end: Vec2(x0, y1)),
          RegionLine(start: Vec2(x0, y1), end: Vec2(x0, y0)),
        ]),
      ]);

  const boolean = PolygonRegionBoolean();

  test('union, intersect, subtract and xor of overlapping squares', () {
    final a = square(0, 0, 10, 10);
    final b = square(5, 5, 15, 15);
    expect(
      boolean.apply(RegionOp.union, [a, b]).signedArea,
      closeTo(175, 0.01),
    );
    expect(
      boolean.apply(RegionOp.intersect, [a, b]).signedArea,
      closeTo(25, 0.01),
    );
    expect(
      boolean.apply(RegionOp.subtract, [a, b]).signedArea,
      closeTo(75, 0.01),
    );
    expect(boolean.apply(RegionOp.xor, [a, b]).signedArea, closeTo(150, 0.01));
  });

  test('a boolean result is marked approximated', () {
    final result = boolean.apply(RegionOp.union, [
      square(0, 0, 10, 10),
      square(5, 5, 15, 15),
    ]);
    expect(result.approximated, isTrue);
    expect(result.components, isNotEmpty);
  });

  test('disjoint squares stay two components in one result', () {
    final result = boolean.apply(RegionOp.union, [
      square(0, 0, 10, 10),
      square(20, 0, 30, 10),
    ]);
    expect(result.components, hasLength(2));
    expect(result.signedArea, closeTo(200, 0.01));
  });
}
