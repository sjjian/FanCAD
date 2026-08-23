import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  final leader = Construct.leader(const [
    Vec2(0, 0),
    Vec2(10, 5),
    Vec2(14, 5),
  ])!.single as LeaderEntity;

  test('a window stretch moves only the captured leader vertex', () {
    final stretched = Construct.stretch(
      leader,
      const Bounds2(-1, -1, 1, 1),
      const Vec2(0, 3),
    )! as LeaderEntity;

    expect(stretched.grips(), const [
      Vec2(0, 3),
      Vec2(10, 5),
      Vec2(14, 5),
    ]);
    expect(stretched.hasArrowHead, isTrue);
  });

  test('a window miss cannot drag a leader', () {
    expect(
      Construct.stretch(
        leader,
        const Bounds2(40, 40, 41, 41),
        const Vec2(0, 3),
      ),
      isNull,
    );
  });
}
