import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a non-positive text height cannot invent a leader note', () {
    expect(
      Construct.leader(
        const [Vec2.zero(), Vec2(10, 5)],
        annotation: 'NOTE',
        textHeight: 0,
      ),
      isNull,
    );
    expect(
      Construct.leader(
        const [Vec2.zero(), Vec2(10, 5)],
        annotation: 'NOTE',
        textHeight: -2,
      ),
      isNull,
    );
  });

  test('duplicate vertices cannot invent a second landing point', () {
    expect(Construct.leader(const [Vec2.zero()]), isNull);
    expect(
      Construct.leader(const [Vec2.zero(), Vec2.zero(), Vec2.zero()]),
      isNull,
    );

    final created = Construct.leader(const [
      Vec2.zero(),
      Vec2(10, 0),
      Vec2(10, 0),
    ]);
    expect(created, isNotNull);
    final leader = created!.single as LeaderEntity;
    expect(leader.grips(), const [Vec2.zero(), Vec2(10, 0)]);
  });
}
