import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a point grip moves the node', () {
    const point = PointEntity(id: 2, position: Vec2(1, 2));
    expect(point.grips(), const [Vec2(1, 2)]);
    expect(
      point.withGrip(0, const Vec2(4, 5)).position,
      const Vec2(4, 5),
    );
  });

  test('a point marks a node unless PDMODE hides it', () {
    final sink = PolylineSink();
    const PointEntity(id: 1, position: Vec2(1, 2)).emit(
      const EmitContext(tolerance: 0.1),
      sink,
    );
    expect(sink.points, isNotEmpty);
    sink.points.clear();
    const PointEntity(id: 2, position: Vec2(3, 4)).emit(
      EmitContext(
        tolerance: 0.1,
        pointDisplay: PointDisplay.fromHeaders({r'$PDMODE': '0'}),
      ),
      sink,
    );
    expect(sink.points, isEmpty);
    const PointEntity(id: 3, position: Vec2(5, 6)).emit(
      EmitContext(
        tolerance: 0.1,
        pointDisplay: PointDisplay.fromHeaders({r'$PDMODE': '1'}),
      ),
      sink,
    );
    expect(sink.points, isEmpty);
    const PointEntity(id: 4, position: Vec2(7, 8)).emit(
      EmitContext(
        tolerance: 0.1,
        pointDisplay: PointDisplay.fromHeaders({r'$PDMODE': '3'}),
      ),
      sink,
    );
    expect(sink.points, isNotEmpty);
  });
}
