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
}
