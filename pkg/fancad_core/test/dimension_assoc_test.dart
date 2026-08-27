import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('transforming a source regenerates the associated dimension', () {
    final document = CadDocument();
    final transaction = Transaction(document, label: 'draw');
    final lineId = transaction.add(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    final dimId = transaction.add(
      Construct.linearDimension(
        const Vec2.zero(),
        const Vec2(10, 0),
        const Vec2(5, 3),
        sourceIds: [lineId],
      )!,
    );
    transaction.commit();

    final moved = Transaction(document, label: 'Move');
    expect(moved.transform(lineId, const Mat3.translation(0, 4)), isTrue);
    moved.commit();

    final dim = document.entity(dimId)! as DimensionEntity;
    expect(dim.measurement, closeTo(10, 1e-9));
    expect(dim.definitionPoints[0], const Vec2(0, 4));
    expect(dim.definitionPoints[1], const Vec2(10, 4));
    expect(dim.definitionPoints[2].y, closeTo(7, 1e-9));
  });

  test('stretching a source updates the measurement', () {
    final document = CadDocument();
    final transaction = Transaction(document, label: 'draw');
    final lineId = transaction.add(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    final dimId = transaction.add(
      Construct.linearDimension(
        const Vec2.zero(),
        const Vec2(10, 0),
        const Vec2(5, 3),
        sourceIds: [lineId],
      )!,
    );
    transaction.commit();

    final stretch = Transaction(document, label: 'Stretch');
    stretch.modify(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(16, 0))
          .withId(lineId),
    );
    stretch.commit();

    final dim = document.entity(dimId)! as DimensionEntity;
    expect(dim.measurement, closeTo(16, 1e-9));
    expect(dim.sourceIds, [lineId]);
  });
}
