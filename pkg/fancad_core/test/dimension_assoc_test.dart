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

  test('a grip on the source regenerates the associated dimension', () {
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

    final grip = Transaction(document, label: 'Grip');
    expect(grip.moveGrip(lineId, 2, const Vec2(16, 0)), isTrue);
    grip.commit();

    final dim = document.entity(dimId)! as DimensionEntity;
    expect(dim.measurement, closeTo(16, 1e-9));
    expect(dim.sourceIds, [lineId]);
  });

  test('moving only the dimension keeps origins on the source', () {
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

    final moved = Transaction(document, label: 'Move dim');
    expect(moved.transform(dimId, const Mat3.translation(0, 4)), isTrue);
    moved.commit();

    final dim = document.entity(dimId)! as DimensionEntity;
    expect(dim.measurement, closeTo(10, 1e-9));
    expect(dim.definitionPoints[0], const Vec2.zero());
    expect(dim.definitionPoints[1], const Vec2(10, 0));
    expect(dim.definitionPoints[2].y, closeTo(7, 1e-9));
  });

  test('erasing the source keeps the last measurement', () {
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

    final erase = Transaction(document, label: 'Erase');
    expect(erase.erase(lineId), isTrue);
    erase.commit();

    final dim = document.entity(dimId)! as DimensionEntity;
    expect(dim.measurement, closeTo(10, 1e-9));
    expect(dim.sourceIds, isEmpty);
  });

  test('copying a source and its dimension remaps the association', () {
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

    final copy = Transaction(document, label: 'Copy');
    final created = copy.duplicate([lineId, dimId], const Mat3.translation(0, 5));
    copy.commit();

    expect(created, hasLength(2));
    final copiedDim = document.entity(created[1])! as DimensionEntity;
    expect(copiedDim.sourceIds, [created[0]]);
    expect(copiedDim.measurement, closeTo(10, 1e-9));

    final original = document.entity(dimId)! as DimensionEntity;
    expect(original.sourceIds, [lineId]);
  });

  test('transforming a radius source updates the measurement', () {
    final document = CadDocument();
    final transaction = Transaction(document, label: 'draw');
    final circleId = transaction.add(
      const CircleEntity(id: 0, center: Vec2.zero(), radius: 5),
    );
    final dimId = transaction.add(
      Construct.radiusDimension(
        document.entity(circleId)!,
        const Vec2(8, 0),
      )!,
    );
    transaction.commit();

    final scaled = Transaction(document, label: 'Scale');
    expect(scaled.transform(circleId, const Mat3.scaling(2, 2)), isTrue);
    scaled.commit();

    final dim = document.entity(dimId)! as DimensionEntity;
    expect(dim.measurement, closeTo(10, 1e-9));
    expect(dim.sourceIds, [circleId]);
  });
}
