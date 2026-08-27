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
