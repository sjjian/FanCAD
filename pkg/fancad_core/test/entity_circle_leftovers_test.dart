import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an inward offset that reaches the centre cannot invent a circle', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
    expect(circle.offsetBy(5, const Vec2.zero()), isNull);
    expect(circle.offsetBy(9, const Vec2.zero()), isNull);
  });

  test('a window miss cannot invent a circle stretch', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
    expect(
      circle.stretchBy(const Bounds2(100, 100, 101, 101), const Vec2(2, 0)),
      isNull,
    );
  });

  test('a vanished circle cannot invent a stroke', () {
    final sink = PolylineSink();
    const CircleEntity(
      id: 1,
      center: Vec2.zero(),
      radius: 0,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.isEmpty, isTrue);
  });
}
