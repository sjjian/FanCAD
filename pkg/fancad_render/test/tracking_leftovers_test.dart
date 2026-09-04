import 'dart:math' as math;
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const view = CadViewport(center: Vec2.zero(), scale: 1, size: Size(800, 600));

  test('polar tracking only magnets onto horizontal or vertical', () {
    final engine = SnapEngine(
      modes: {},
      tracking: const TrackingSettings(polar: true),
    );
    final empty = CadDocument();

    final axis = engine.resolve(
      empty,
      view,
      const Vec2(200, 5),
      basePoint: Vec2.zero(),
    );
    expect(axis.origin, SnapOrigin.tracking);
    expect(axis.trackingAngle, closeTo(0, 1e-9));
    expect(TrackingSettings.isCardinalAngle(axis.trackingAngle!), isTrue);

    // A 31° stretch is not on an axis, so it stays free and draws no ray.
    final offset = engine.resolve(
      empty,
      view,
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
      view,
      const Vec2(8, -200),
      basePoint: Vec2.zero(),
    );
    expect(offAxis.origin, SnapOrigin.free);
    expect(offAxis.point, const Vec2(8, -200));
  });

  test('the overlay ray is omitted unless the cursor is on an axis', () {
    final controller = ToolController(
      session: DocumentSession(id: 't', document: CadDocument()),
      viewportProvider: () => view,
      snapEngine: SnapEngine(
        modes: {},
        tracking: const TrackingSettings(polar: true),
      ),
    );
    addTearDown(controller.dispose);
    controller.push(
      PointPromptTool(message: 'Specify stretch point:', anchor: Vec2.zero()),
    );

    controller.onPointerMove(
      const Vec2(171, 103),
      const PointerMoveEvent(pointer: 1, position: Offset(171, 103)),
    );
    expect(
      controller.buildOverlay().shapes.whereType<OverlayTrackingLine>(),
      isEmpty,
    );

    controller.onPointerMove(
      const Vec2(200, 5),
      const PointerMoveEvent(pointer: 1, position: Offset(200, 5)),
    );
    final rays = controller
        .buildOverlay()
        .shapes
        .whereType<OverlayTrackingLine>()
        .toList();
    expect(rays, hasLength(1));
    expect(TrackingSettings.isCardinalAngle(rays.single.angle), isTrue);
  });

  test('additional angles and a zero increment cannot invent polar rays', () {
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
      view,
      const Vec2(10, 5.8),
      basePoint: Vec2.zero(),
    );
    expect(hit.origin, SnapOrigin.tracking);
    expect(math.atan2(hit.point.y, hit.point.x), closeTo(math.pi / 6, 1e-6));
  });
}
