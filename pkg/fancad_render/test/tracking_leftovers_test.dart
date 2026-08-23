import 'dart:math' as math;
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const view = CadViewport(center: Vec2.zero(), scale: 1, size: Size(800, 600));

  test('polar tracking is a magnet; a 6° miss stays free', () {
    final engine = SnapEngine(
      modes: {},
      tracking: const TrackingSettings(polar: true),
    );
    final empty = CadDocument();

    final diagonal = engine.resolve(
      empty,
      view,
      const Vec2(10, 10.2),
      basePoint: Vec2.zero(),
    );
    expect(diagonal.origin, SnapOrigin.tracking);
    expect(diagonal.point.x, closeTo(diagonal.point.y, 1e-6));
    expect(diagonal.trackingLabel, contains('45.0'));

    final missed = engine.resolve(
      empty,
      view,
      const Vec2(10, 1),
      basePoint: Vec2.zero(),
    );
    expect(missed.origin, SnapOrigin.free);
    expect(missed.point, const Vec2(10, 1));
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
