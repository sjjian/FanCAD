import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'preview shapes keep rubber-band defaults until a command overrides them',
    () {
      const line = OverlayLine(Vec2.zero(), Vec2(4, 0));
      expect(line.dashed, isTrue);
      expect(line, isA<OverlayShape>());

      const poly = OverlayPolyline([Vec2.zero(), Vec2(1, 0), Vec2(1, 1)]);
      expect(poly.closed, isFalse);
      expect(poly.dashed, isFalse);

      const arc = OverlayArc(center: Vec2.zero(), radius: 5);
      expect(arc.startAngle, 0);
      expect(arc.sweep, math.pi * 2);

      const window = OverlayRect(Vec2.zero(), Vec2(10, 4));
      expect(window.crossing, isFalse);
      expect(
        const OverlayRect(Vec2(10, 4), Vec2.zero(), crossing: true).crossing,
        isTrue,
      );

      const track = OverlayTrackingLine(Vec2.zero(), math.pi / 2, label: '90');
      expect(track.label, '90');
      expect(track.angle, math.pi / 2);

      const mark = OverlayPoint(Vec2(2, 3));
      expect(mark.at, const Vec2(2, 3));
    },
  );

  test('preview shapes translate without changing style flags', () {
    const delta = Vec2(10, 4);
    final line = const OverlayLine(Vec2.zero(), Vec2(4, 0)).translated(delta);
    expect(line.from, const Vec2(10, 4));
    expect(line.to, const Vec2(14, 4));
    expect(line.dashed, isTrue);

    final poly = const OverlayPolyline([
      Vec2.zero(),
      Vec2(1, 0),
    ], closed: true).translated(delta);
    expect(poly.points, const [Vec2(10, 4), Vec2(11, 4)]);
    expect(poly.closed, isTrue);

    final arc = const OverlayArc(
      center: Vec2(1, 1),
      radius: 5,
    ).translated(delta);
    expect(arc.center, const Vec2(11, 5));
    expect(arc.radius, 5);

    final window = const OverlayRect(
      Vec2.zero(),
      Vec2(2, 1),
      crossing: true,
    ).translated(delta);
    expect(window.from, const Vec2(10, 4));
    expect(window.to, const Vec2(12, 5));
    expect(window.crossing, isTrue);

    expect(
      const OverlayPoint(Vec2(2, 3)).translated(delta).at,
      const Vec2(12, 7),
    );
    expect(
      const OverlayTrackingLine(
        Vec2.zero(),
        1,
        label: '90',
      ).translated(delta).origin,
      const Vec2(10, 4),
    );
  });

  test('preview shapes follow a matrix so a rotate still shows objects', () {
    const poly = OverlayPolyline([Vec2(1, 0), Vec2(2, 0)]);
    final rotated = poly.transformed(Mat3.rotation(math.pi / 2));
    expect(rotated.points.first.x, closeTo(0, 1e-9));
    expect(rotated.points.first.y, closeTo(1, 1e-9));
    expect(rotated.points.last.x, closeTo(0, 1e-9));
    expect(rotated.points.last.y, closeTo(2, 1e-9));

    final moved = poly.transformed(const Mat3.translation(3, 4));
    expect(moved.points, const [Vec2(4, 4), Vec2(5, 4)]);
  });

  test(
    'snap marker labels stay distinct so a glyph cannot steal another name',
    () {
      expect(
        {
          for (final kind in SnapMarkerKind.values)
            kind: SnapMarker(kind: kind, point: const Vec2.zero()).label,
        },
        {
          SnapMarkerKind.endpoint: 'Endpoint',
          SnapMarkerKind.midpoint: 'Midpoint',
          SnapMarkerKind.center: 'Center',
          SnapMarkerKind.quadrant: 'Quadrant',
          SnapMarkerKind.intersection: 'Intersection',
          SnapMarkerKind.perpendicular: 'Perpendicular',
          SnapMarkerKind.tangent: 'Tangent',
          SnapMarkerKind.nearest: 'Nearest',
          SnapMarkerKind.node: 'Node',
          SnapMarkerKind.extension: 'Extension',
          SnapMarkerKind.grid: 'Grid',
        },
      );
    },
  );
}
