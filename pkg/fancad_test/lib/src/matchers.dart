import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

/// A [Vec2] whose components lie within [epsilon] of [expected].
Matcher closeVec(Vec2 expected, {double epsilon = 1e-6}) {
  return predicate<Vec2>(
    (actual) =>
        (actual.x - expected.x).abs() <= epsilon &&
        (actual.y - expected.y).abs() <= epsilon,
    'Vec2 close to (${expected.x}, ${expected.y}) within $epsilon',
  );
}

/// Asserts [entity] is owned by [blockName] in [document].
void expectOwner(CadDocument document, CadEntity entity, String blockName) {
  expect(
    document.ownerOf(entity.id),
    blockName,
    reason: '${entity.kind.name}#${entity.id}',
  );
}
