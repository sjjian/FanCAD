import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('leftover parameter kinds cannot invent the wrong JSON type', () {
    expect(
      const ParamSpec(name: 'payload', type: ParamType.json).toJsonSchema()['type'],
      'object',
    );
    expect(
      const ParamSpec(name: 'points', type: ParamType.points).toJsonSchema()['type'],
      'array',
    );
    expect(
      const ParamSpec(name: 'cell', type: ParamType.block).toJsonSchema()['type'],
      'string',
    );
    expect(
      const ParamSpec(name: 'id', type: ParamType.entity).toJsonSchema()['type'],
      'integer',
    );
    expect(
      const ParamSpec(
        name: 'opt',
        type: ParamType.text,
        required: false,
      ).toString(),
      contains('?'),
    );
  });
}
