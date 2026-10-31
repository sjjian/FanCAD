import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_core/src/io/fcb/reader.dart';
import 'package:fancad_core/src/io/fcb/writer.dart';
import 'package:test/test.dart';

RegionEntity _region({
  AcisPayload? source,
  List<RegionCurve>? curves,
  Vec2 offset = const Vec2.zero(),
}) {
  final loop = curves == null
      ? RegionLoop([
          RegionLine(start: Vec2(0, 0) + offset, end: Vec2(10, 0) + offset),
          RegionLine(start: Vec2(10, 0) + offset, end: Vec2(10, 10) + offset),
          RegionLine(start: Vec2(10, 10) + offset, end: Vec2(0, 10) + offset),
          RegionLine(start: Vec2(0, 10) + offset, end: Vec2(0, 0) + offset),
        ])
      : RegionLoop([
          for (final curve in curves)
            curve.transformed(Mat3.translation(offset.x, offset.y)),
        ]);
  return RegionEntity(
    id: 1,
    components: [RegionComponent(outer: loop)],
    source: source,
  );
}

void main() {
  test('a REGION survives an FCB cache round trip', () {
    const circle = RegionConicArc(
      center: Vec2.zero(),
      u: Vec2(10, 0),
      v: Vec2(0, 10),
      startParameter: 0,
      sweep: math.pi * 2,
    );
    final document = CadDocument()
      ..addEntity(
        RegionEntity(
          id: 1,
          components: [
            RegionComponent(outer: RegionLoop([circle])),
          ],
        ),
      );

    final decoded = FcbReader(FcbWriter().write(document)).decode().document;
    final region = decoded.entities.whereType<RegionEntity>().single;
    expect(region.signedArea, closeTo(math.pi * 100, 0.6));
    expect(region.components, hasLength(1));
    expect(region.approximated, isFalse);
  });

  test('a flattened spline is flagged approximate through FCB', () {
    final spline = RegionSpline(
      controlPoints: Float64List.fromList([10, 0, 10, 2, 12, 2, 10, 2]),
      knots: const [0, 0, 0, 0, 1, 1, 1, 1],
      weights: const [],
      degree: 3,
      closed: false,
    );
    final document = CadDocument()
      ..addEntity(
        _region(
          curves: [
            spline,
            const RegionLine(start: Vec2(10, 2), end: Vec2(0, 2)),
            const RegionLine(start: Vec2(0, 2), end: Vec2(0, 0)),
            const RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
          ],
        ),
      );

    final decoded = FcbReader(FcbWriter().write(document)).decode().document;
    final region = decoded.entities.whereType<RegionEntity>().single;
    expect(region.approximated, isTrue);
    expect(
      region.components.single.outer.curves.whereType<RegionSpline>(),
      isEmpty,
    );
  });

  test('a parsed SAT source keeps its transform once', () {
    final local = RegionGeometry.fromLoops([
      RegionLoop(const [
        RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
        RegionLine(start: Vec2(10, 0), end: Vec2(10, 10)),
        RegionLine(start: Vec2(10, 10), end: Vec2(0, 10)),
        RegionLine(start: Vec2(0, 10), end: Vec2(0, 0)),
      ]),
    ]);
    final sat = const RegionSatWriter().write(local)!;
    final source = _region(
      offset: const Vec2(100, 20),
      source: AcisPayload(
        format: 'sat',
        bytes: Uint8List.fromList(utf8.encode(sat)),
        transform: Mat3.translation(100, 20),
      ),
    );
    final decoded = FcbReader(
      FcbWriter().write(CadDocument()..addEntity(source)),
    ).decode().document;
    final region = decoded.entities.whereType<RegionEntity>().single;
    expect(region.computeBounds().minX, closeTo(100, 1e-6));
    expect(region.computeBounds().minY, closeTo(20, 1e-6));
    expect(region.approximated, isFalse);
    expect(region.source, isNotNull);
  });

  test('malformed SAT falls back to world strokes without moving twice', () {
    final source = _region(
      offset: const Vec2(100, 20),
      source: AcisPayload(
        format: 'sat',
        bytes: Uint8List.fromList(utf8.encode('not sat')),
        transform: Mat3.translation(100, 20),
      ),
    );
    final decoded = FcbReader(
      FcbWriter().write(CadDocument()..addEntity(source)),
    ).decode().document;
    final region = decoded.entities.whereType<RegionEntity>().single;
    expect(region.computeBounds().minX, closeTo(100, 1e-6));
    expect(region.computeBounds().minY, closeTo(20, 1e-6));
    expect(region.approximated, isTrue);
    expect(region.source, isNull);
  });
}
