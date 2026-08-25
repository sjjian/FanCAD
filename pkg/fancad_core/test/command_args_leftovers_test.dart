import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a maybe keyword cannot invent a boolean', () {
    final args = CommandArgs({
      'flag': 'maybe',
      'count': 'nope',
      'scale': true,
    });
    expect(args.boolean('flag'), isNull);
    expect(args.integer('count'), isNull);
    expect(args.number('scale'), isNull);
    expect(args.boolean('missing'), isNull);
  });

  test('a broken point or id list cannot invent a pick', () {
    final args = CommandArgs({
      'at': '1,',
      'ids': 'nope',
      'payload': [1, 2],
    });
    expect(args.point('at'), isNull);
    expect(args.ids('ids'), isNull);
    expect(args.object('payload'), isNull);
    expect(CommandArgs.parsePoint({'x': 1}), isNull);
    expect(CommandArgs.parsePoint([1]), isNull);
  });

  test('leftover point lists still parse as vertices', () {
    expect(
      CommandArgs.parsePoints('[[0,0],[10,0],[10,10]]'),
      const [Vec2.zero(), Vec2(10, 0), Vec2(10, 10)],
    );
    expect(
      CommandArgs.parsePoints({
        'vertices': [
          {'x': 0, 'y': 0},
          {'x': 4, 'y': 1},
        ],
      }),
      const [Vec2.zero(), Vec2(4, 1)],
    );
    expect(
      CommandArgs.parsePoints({'0': [0, 0], '1': [2, 3]}),
      const [Vec2.zero(), Vec2(2, 3)],
    );
    expect(
      CommandArgs.parsePoints([0, 0, 8, 0, 8, 4]),
      const [Vec2.zero(), Vec2(8, 0), Vec2(8, 4)],
    );
    expect(CommandArgs.parsePoints({'leftover': true}), isEmpty);
    expect(
      CommandArgs({
        'vertices': [
          [1, 2],
          [3, 4],
        ],
      }).points('points'),
      const [Vec2(1, 2), Vec2(3, 4)],
    );
  });
}
