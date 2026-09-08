import 'dart:math' as math;
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const view = CadViewport(
    center: Vec2(5, 0),
    scale: 1,
    size: Size(800, 600),
  );

  CadDocument lineDoc() {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    return document;
  }

  test('every snap mode has a label and parse is exact', () {
    for (final mode in SnapMode.values) {
      expect(mode.label, isNotEmpty);
      expect(SnapMode.parse(mode.name), mode);
    }
    expect(SnapMode.parse('nope'), isNull);
    expect(SnapMode.defaults, containsAll([SnapMode.endpoint, SnapMode.midpoint]));
  });

  test('an unusable viewport or a disabled engine leaves the cursor free', () {
    const dead = CadViewport(center: Vec2.zero(), scale: 1, size: Size.zero);
    final engine = SnapEngine();
    expect(
      engine.resolve(lineDoc(), dead, const Vec2(0.1, 0.1)).origin,
      SnapOrigin.free,
    );

    engine.enabled = false;
    final result = engine.resolve(lineDoc(), view, const Vec2(0.1, 0.1));
    expect(result.origin, SnapOrigin.free);
    expect(result.isSnapped, isFalse);
    expect(result.point, const Vec2(0.1, 0.1));
  });

  test('endpoint and midpoint fire only for the modes that are on', () {
    final document = lineDoc();
    final ends = SnapEngine(modes: {SnapMode.endpoint});
    final atStart = ends.resolve(document, view, const Vec2(0.2, 0.2));
    expect(atStart.origin, SnapOrigin.osnap);
    expect(atStart.marker!.kind, SnapMarkerKind.endpoint);
    expect(atStart.point.distanceTo(Vec2.zero()), closeTo(0, 1e-9));

    final mids = SnapEngine(modes: {SnapMode.midpoint});
    final atMid = mids.resolve(document, view, const Vec2(5, 0.3));
    expect(atMid.marker!.kind, SnapMarkerKind.midpoint);
    expect(atMid.point.distanceTo(const Vec2(5, 0)), closeTo(0, 1e-9));

    final skipped = ends.resolve(
      document,
      view,
      const Vec2(0.2, 0.2),
      excludedIds: {document.entities.single.id},
    );
    expect(skipped.isSnapped, isFalse);
  });

  test('GRID lock lands on the same intersections the canvas paints', () {
    final empty = CadDocument();
    final engine = SnapEngine(modes: {}, snapToGrid: true);
    final step = referenceGridStep(view);
    expect(step, greaterThan(0));

    final result = engine.resolve(empty, view, const Vec2(1.2, 0.4));
    expect(result.origin, SnapOrigin.grid);
    expect(result.marker!.kind, SnapMarkerKind.grid);
    expect(result.point.x % step, closeTo(0, 1e-9));
    expect(result.point.y % step, closeTo(0, 1e-9));

    engine.snapToGrid = false;
    final free = engine.resolve(empty, view, const Vec2(1.2, 0.4));
    expect(free.origin, SnapOrigin.free);
    expect(free.point, const Vec2(1.2, 0.4));
  });

  test('ortho tracking projects the cursor and intersection wins on a crossing', () {
    final empty = CadDocument();
    final ortho = SnapEngine(
      modes: {},
      tracking: const TrackingSettings(ortho: true),
    );
    final tracked = ortho.resolve(
      empty,
      view,
      const Vec2(8, 1),
      basePoint: Vec2.zero(),
    );
    expect(tracked.origin, SnapOrigin.tracking);
    expect(tracked.point.x, closeTo(8, 1e-6));
    expect(tracked.point.y, closeTo(0, 1e-6));
    expect(tracked.trackingLabel, contains('8.00'));

    final crossed = CadDocument()
      ..addEntity(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)))
      ..addEntity(const LineEntity(id: 0, start: Vec2(5, -5), end: Vec2(5, 5)));
    final hits = SnapEngine(modes: {SnapMode.intersection}).resolve(
      crossed,
      view,
      const Vec2(5.2, 0.2),
    );
    expect(hits.marker!.kind, SnapMarkerKind.intersection);
    expect(hits.point.distanceTo(const Vec2(5, 0)), closeTo(0, 1e-6));
  });

  test('center and quadrant fire on a circle, not on its rim as nearest', () {
    const origin = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(800, 600),
    );
    final document = CadDocument()
      ..addEntity(const CircleEntity(id: 0, center: Vec2.zero(), radius: 10));

    final atCenter = SnapEngine(
      modes: {SnapMode.center},
    ).resolve(document, origin, const Vec2(0.4, 0.3));
    expect(atCenter.marker!.kind, SnapMarkerKind.center);
    expect(atCenter.point.distanceTo(Vec2.zero()), closeTo(0, 1e-9));

    final atEast = SnapEngine(
      modes: {SnapMode.quadrant},
    ).resolve(document, origin, const Vec2(10.2, 0.2));
    expect(atEast.marker!.kind, SnapMarkerKind.quadrant);
    expect(atEast.point.distanceTo(const Vec2(10, 0)), closeTo(0, 1e-6));
  });

  test('node, nearest and perpendicular land on the intended geometry', () {
    const origin = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(800, 600),
    );
    final document = CadDocument()
      ..addEntity(const PointEntity(id: 0, position: Vec2(3, 4)))
      ..addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );

    final node = SnapEngine(
      modes: {SnapMode.node},
    ).resolve(document, origin, const Vec2(3.2, 4.1));
    expect(node.marker!.kind, SnapMarkerKind.node);
    expect(node.point.distanceTo(const Vec2(3, 4)), closeTo(0, 1e-9));

    final nearest = SnapEngine(
      modes: {SnapMode.nearest},
    ).resolve(document, origin, const Vec2(4, 0.4));
    expect(nearest.marker!.kind, SnapMarkerKind.nearest);
    expect(nearest.point.distanceTo(const Vec2(4, 0)), closeTo(0, 1e-6));

    final perp = SnapEngine(
      modes: {SnapMode.perpendicular},
    ).resolve(document, origin, const Vec2(4, 3));
    expect(perp.marker!.kind, SnapMarkerKind.perpendicular);
    expect(perp.point.distanceTo(const Vec2(4, 0)), closeTo(0, 1e-6));
  });

  test('tangent from outside a circle does not snap to the center', () {
    const origin = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(800, 600),
    );
    final document = CadDocument()
      ..addEntity(const CircleEntity(id: 0, center: Vec2.zero(), radius: 5));
    final hit = SnapEngine(
      modes: {SnapMode.tangent},
    ).resolve(document, origin, const Vec2(8, 0.3));
    expect(hit.marker!.kind, SnapMarkerKind.tangent);
    expect(hit.point.length, closeTo(5, 1e-6));
    expect(hit.point.distanceTo(Vec2.zero()), closeTo(5, 1e-6));
  });

  test('polar tracking only magnets onto horizontal or vertical', () {
    const origin = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(800, 600),
    );
    final engine = SnapEngine(
      modes: {},
      tracking: const TrackingSettings(polar: true),
    );
    final empty = CadDocument();

    final axis = engine.resolve(
      empty,
      origin,
      const Vec2(200, 5),
      basePoint: Vec2.zero(),
    );
    expect(axis.origin, SnapOrigin.tracking);
    expect(axis.trackingAngle, closeTo(0, 1e-9));
    expect(TrackingSettings.isCardinalAngle(axis.trackingAngle!), isTrue);

    // A 31° stretch is not on an axis, so it stays free and draws no ray.
    final offset = engine.resolve(
      empty,
      origin,
      const Vec2(171, 103),
      basePoint: Vec2.zero(),
    );
    expect(offset.origin, SnapOrigin.free);
    expect(offset.trackingAngle, isNull);
    expect(offset.point, const Vec2(171, 103));

    // A few pixels off vertical must stay free, otherwise a stretch can
    // only go straight down.
    final offAxis = engine.resolve(
      empty,
      origin,
      const Vec2(8, -200),
      basePoint: Vec2.zero(),
    );
    expect(offAxis.origin, SnapOrigin.free);
    expect(offAxis.point, const Vec2(8, -200));
  });

  test('additional angles and a zero increment cannot invent polar rays', () {
    const origin = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(800, 600),
    );
    const extra = TrackingSettings(additionalAngles: [math.pi / 6]);
    expect(extra.isActive, isTrue);
    expect(
      extra.candidateAngles(),
      containsAll([math.pi / 6, math.pi * 7 / 6]),
    );

    const deadPolar = TrackingSettings(polar: true, polarIncrement: 0);
    expect(deadPolar.candidateAngles(), isEmpty);
    expect(deadPolar.isActive, isTrue);

    final copied = extra.copyWith(polar: true, polarIncrement: math.pi / 2);
    expect(copied.polar, isTrue);
    expect(copied.candidateAngles(), contains(math.pi / 2));

    final engine = SnapEngine(modes: {}, tracking: extra);
    final hit = engine.resolve(
      CadDocument(),
      origin,
      const Vec2(10, 5.8),
      basePoint: Vec2.zero(),
    );
    expect(hit.origin, SnapOrigin.tracking);
    expect(math.atan2(hit.point.y, hit.point.x), closeTo(math.pi / 6, 1e-6));
  });
}
