import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_core/src/io/dxf/reader.dart';
import 'package:fancad_core/src/io/dxf/writer.dart';
import 'package:test/test.dart';

void main() {
  test('a REGION writes as ACIS and reads back as a REGION', () {
    const circle = RegionConicArc(
      center: Vec2(50, 50),
      u: Vec2(5, 0),
      v: Vec2(0, 5),
      startParameter: 0,
      sweep: math.pi * 2,
    );
    final source = CadDocument()
      ..addEntity(
        RegionEntity(
          id: 1,
          components: [
            RegionComponent(
              outer: RegionLoop(const [
                RegionLine(start: Vec2(0, 0), end: Vec2(100, 0)),
                RegionLine(start: Vec2(100, 0), end: Vec2(100, 100)),
                RegionLine(start: Vec2(100, 100), end: Vec2(0, 100)),
                RegionLine(start: Vec2(0, 100), end: Vec2(0, 0)),
              ]),
              holes: [
                RegionLoop([circle]),
              ],
            ),
          ],
        ),
      );
    final text = const DxfWriter().writeString(source);
    expect(text, contains('AcDbModelerGeometry'));
    final opened = const DxfReader().readString(text);
    final region = opened.entities.whereType<RegionEntity>().single;
    expect(region.signedArea, closeTo(10000 - math.pi * 25, 1.0));
    expect(region.components, hasLength(1));
    expect(region.components.single.holes, hasLength(1));
    expect(region.approximated, isFalse);
  });

  test('a flattened REGION keeps its approximate marker through DXF', () {
    final spline = RegionSpline(
      controlPoints: Float64List.fromList([10, 0, 10, 2, 12, 2, 10, 2]),
      knots: const [0, 0, 0, 0, 1, 1, 1, 1],
      weights: const [],
      degree: 3,
      closed: false,
    );
    final source = CadDocument()
      ..addEntity(
        RegionEntity(
          id: 1,
          components: [
            RegionComponent(
              outer: RegionLoop([
                spline,
                const RegionLine(start: Vec2(10, 2), end: Vec2(0, 2)),
                const RegionLine(start: Vec2(0, 2), end: Vec2(0, 0)),
                const RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
              ]),
            ),
          ],
        ),
      );
    final text = const DxfWriter().writeString(source);
    expect(text, contains('FanCAD REGION APPROXIMATED'));
    expect(text, contains('FanCAD_APPROX'));
    final opened = const DxfReader().readString(text);
    final region = opened.entities.whereType<RegionEntity>().single;
    expect(region.approximated, isTrue);
  });
}
