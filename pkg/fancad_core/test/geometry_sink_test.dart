import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('TextGeometry', () {
    test('estimated bounds wrap, align and rotate without a font', () {
      const plain = TextGeometry(
        text: 'AB',
        origin: Vec2.zero(),
        height: 10,
        rotation: 0,
        styleName: 'Standard',
      );
      expect(plain.estimatedBounds(), const Bounds2(0, 0, 12.4, 12));

      const wrapped = TextGeometry(
        text: 'hello',
        origin: Vec2.zero(),
        height: 10,
        rotation: 0,
        styleName: 'Standard',
        rectangleWidth: 20,
        isMultiline: true,
      );
      expect(wrapped.estimatedBounds().width, closeTo(20, 1e-9));

      const stacked = TextGeometry(
        text: 'ab\ncd',
        origin: Vec2.zero(),
        height: 10,
        rotation: 0,
        styleName: 'Standard',
        isMultiline: true,
      );
      expect(stacked.estimatedBounds().height, closeTo(24, 1e-9));

      const centered = TextGeometry(
        text: 'X',
        origin: Vec2(10, 10),
        height: 10,
        rotation: 0,
        styleName: 'Standard',
        hAlign: TextHAlign.center,
        vAlign: TextVAlign.middle,
      );
      expect(centered.estimatedBounds().center.x, closeTo(10, 1e-9));
      expect(centered.estimatedBounds().center.y, closeTo(10, 1e-9));

      const rotated = TextGeometry(
        text: 'A',
        origin: Vec2.zero(),
        height: 10,
        rotation: math.pi / 2,
        styleName: 'Standard',
      );
      final box = rotated.estimatedBounds();
      expect(box.minX, closeTo(-12, 1e-9));
      expect(box.maxY, closeTo(6.2, 1e-9));
    });
  });

  group('EmitContext', () {
    test('apply, descend and local tolerance follow the block transform', () {
      const identity = EmitContext(tolerance: 0.1);
      final xy = Float64List.fromList([1, 2]);
      expect(identical(identity.applyBuffer(xy), xy), isTrue);
      expect(identity.apply(const Vec2(3, 4)), const Vec2(3, 4));

      const moved = EmitContext(
        tolerance: 0.1,
        transform: Mat3.translation(10, 20),
      );
      expect(moved.apply(const Vec2(1, 2)), const Vec2(11, 22));
      expect(moved.applyBuffer(xy), Float64List.fromList([11, 22]));
      expect(moved.localTolerance(const Mat3.scaling(2, 2)), closeTo(0.05, 1e-12));
      expect(moved.localTolerance(const Mat3.scaling(0, 0)), 0.1);

      final child = identity.descend(
        const Mat3.translation(1, 0),
        ResolvedStyle.fallback,
      );
      expect(child.depth, 1);
      expect(child.minExtent, 0);
      expect(child.apply(Vec2.zero()), const Vec2(1, 0));
      expect(
        const EmitContext(tolerance: 0.1, minExtent: 4).descend(
          const Mat3.scaling(2, 2),
          ResolvedStyle.fallback,
        ).minExtent,
        4,
      );
      expect(
        const EmitContext(tolerance: 0.1, minExtent: 4).isSubPixelWorld(
          const Bounds2(0, 0, 3, 3),
        ),
        isTrue,
      );
      expect(
        const EmitContext(tolerance: 0.1, minExtent: 4).isSubPixelWorld(
          const Bounds2(0, 0, 10, 1),
        ),
        isFalse,
      );
      expect(const EmitContext(tolerance: 0.1, depth: 31).canRecurse, isTrue);
      expect(const EmitContext(tolerance: 0.1, depth: 32).canRecurse, isFalse);
      expect(BlockLookup.empty.entityIdsOf('X'), isNull);
      expect(BlockLookup.empty.boundsOf('X').isEmpty, isTrue);
    });
  });

  group('sinks', () {
    test('BoundsSink unions every primitive a consumer can emit', () {
      final sink = BoundsSink();
      const style = ResolvedStyle.fallback;
      sink.polyline(Float64List.fromList([0, 0, 10, 0]), style);
      sink.fill(Float64List.fromList([0, 2, 4, 2, 4, 6]), style);
      sink.point(20, 5, style);
      sink.text(
        const TextGeometry(
          text: 'A',
          origin: Vec2(0, 10),
          height: 10,
          rotation: 0,
          styleName: 'Standard',
        ),
        style,
      );
      sink.image(
        const ImageGeometry(
          reference: 'sheet.png',
          origin: Vec2(30, 0),
          uVector: Vec2(4, 0),
          vVector: Vec2(0, 3),
        ),
        style,
      );
      expect(sink.bounds.minX, closeTo(0, 1e-9));
      expect(sink.bounds.maxX, closeTo(34, 1e-9));
      expect(sink.bounds.maxY, closeTo(22, 1e-9));
    });

    test('PolylineSink skips empty runs and records holes and image frames', () {
      final sink = PolylineSink();
      const style = ResolvedStyle.fallback;
      expect(sink.isEmpty, isTrue);
      sink.polyline(Float64List(0), style);
      expect(sink.isEmpty, isTrue);

      sink.fill(
        Float64List.fromList([0, 0, 10, 0, 10, 8, 0, 8]),
        style,
        holes: [Float64List.fromList([2, 2, 4, 2, 4, 4, 2, 4])],
      );
      expect(sink.fills, hasLength(1));
      expect(sink.polylines, hasLength(2));
      expect(sink.closedFlags, everyElement(isTrue));

      sink.image(
        const ImageGeometry(
          reference: 'a.png',
          origin: Vec2.zero(),
          uVector: Vec2(2, 0),
          vVector: Vec2(0, 1),
        ),
        style,
      );
      expect(sink.images.single.corners, const [
        Vec2.zero(),
        Vec2(2, 0),
        Vec2(2, 1),
        Vec2(0, 1),
      ]);
      expect(sink.isEmpty, isFalse);
    });
  });
}
