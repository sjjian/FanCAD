import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const view = CadViewport(center: Vec2.zero(), scale: 1, size: Size(800, 600));

  test('center and quadrant fire on a circle, not on its rim as nearest', () {
    final document = CadDocument()
      ..addEntity(const CircleEntity(id: 0, center: Vec2.zero(), radius: 10));

    final atCenter = SnapEngine(
      modes: {SnapMode.center},
    ).resolve(document, view, const Vec2(0.4, 0.3));
    expect(atCenter.marker!.kind, SnapMarkerKind.center);
    expect(atCenter.point.distanceTo(Vec2.zero()), closeTo(0, 1e-9));

    final atEast = SnapEngine(
      modes: {SnapMode.quadrant},
    ).resolve(document, view, const Vec2(10.2, 0.2));
    expect(atEast.marker!.kind, SnapMarkerKind.quadrant);
    expect(atEast.point.distanceTo(const Vec2(10, 0)), closeTo(0, 1e-6));
  });

  test('node, nearest and perpendicular land on the intended geometry', () {
    final document = CadDocument()
      ..addEntity(const PointEntity(id: 0, position: Vec2(3, 4)))
      ..addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );

    final node = SnapEngine(
      modes: {SnapMode.node},
    ).resolve(document, view, const Vec2(3.2, 4.1));
    expect(node.marker!.kind, SnapMarkerKind.node);
    expect(node.point.distanceTo(const Vec2(3, 4)), closeTo(0, 1e-9));

    final nearest = SnapEngine(
      modes: {SnapMode.nearest},
    ).resolve(document, view, const Vec2(4, 0.4));
    expect(nearest.marker!.kind, SnapMarkerKind.nearest);
    expect(nearest.point.distanceTo(const Vec2(4, 0)), closeTo(0, 1e-6));

    final perp = SnapEngine(
      modes: {SnapMode.perpendicular},
    ).resolve(document, view, const Vec2(4, 3));
    expect(perp.marker!.kind, SnapMarkerKind.perpendicular);
    expect(perp.point.distanceTo(const Vec2(4, 0)), closeTo(0, 1e-6));
  });

  test('tangent from outside a circle does not snap to the center', () {
    final document = CadDocument()
      ..addEntity(const CircleEntity(id: 0, center: Vec2.zero(), radius: 5));
    final hit = SnapEngine(
      modes: {SnapMode.tangent},
    ).resolve(document, view, const Vec2(8, 0.3));
    expect(hit.marker!.kind, SnapMarkerKind.tangent);
    expect(hit.point.length, closeTo(5, 1e-6));
    expect(hit.point.distanceTo(Vec2.zero()), closeTo(5, 1e-6));
  });
}
