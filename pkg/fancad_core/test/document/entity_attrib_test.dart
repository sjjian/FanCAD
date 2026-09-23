import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

/// Collects the analytic snap points an entity reports.
class _SnapSink implements ObjectSnapSink {
  final List<Vec2> nodes = [];

  @override
  void endpoint(Vec2 point) {}

  @override
  void midpoint(Vec2 point) {}

  @override
  void center(Vec2 point) {}

  @override
  void quadrant(Vec2 point) {}

  @override
  void node(Vec2 point) => nodes.add(point);

  @override
  void segment(Vec2 start, Vec2 end) {}

  @override
  void circle(Vec2 center, double radius) {}
}

void main() {
  const sample = AttribEntity(
    id: 17,
    position: Vec2(4, 5),
    tag: 'NO',
    value: 'A-01',
    height: 3.5,
    rotation: 0.25,
    styleName: 'Notes',
    widthFactor: 0.8,
    obliqueAngle: 0.1,
    hAlign: TextHAlign.center,
    vAlign: TextVAlign.middle,
  );

  test('kind, display id and grip describe the value', () {
    expect(sample.kind, EntityKind.attrib);
    expect(sample.displayId, 'ATTRIB#11');
    expect(sample.grips(), const [Vec2(4, 5)]);

    // A grip drag moves the insertion; the tag and value stay put.
    final moved = sample.withGrip(0, const Vec2(9, 9));
    expect(moved.position, const Vec2(9, 9));
    expect(moved.tag, 'NO');
    expect(moved.value, 'A-01');
  });

  test('an invisible or empty value paints nothing', () {
    expect(emit(sample).texts, hasLength(1));

    const hidden = AttribEntity(
      id: 1,
      position: Vec2.zero(),
      tag: 'NO',
      value: 'A-01',
      invisible: true,
    );
    expect(emit(hidden).isEmpty, isTrue);
    expect(emit(sample.withValue('')).isEmpty, isTrue);
  });

  test('the value is painted at the insertion with its own metrics', () {
    final text = emit(sample).texts.single;
    expect(text.text, 'A-01');
    expect(text.origin, const Vec2(4, 5));
    expect(text.height, closeTo(3.5, 1e-9));
    expect(text.rotation, closeTo(0.25, 1e-9));
    expect(text.styleName, 'Notes');
    expect(text.hAlign, TextHAlign.center);
    expect(text.vAlign, TextVAlign.middle);
  });

  test('a STYLE entry folds into the emitted value', () {
    final document = drawing(
      textStyles: const [
        TextStyleDef(name: 'Notes', widthFactor: 0.5, obliqueAngle: 0.2),
      ],
    );
    final text = emit(sample, document: document).texts.single;
    expect(text.widthFactor, closeTo(0.4, 1e-9));
    expect(text.obliqueAngle, closeTo(0.3, 1e-9));
  });

  test('percent codes in the value expand before layout', () {
    final text = emit(sample.withValue('%%c10 %%d')).texts.single;
    expect(text.text, 'Ø10 °');
  });

  test('a transform scales the height and adds the rotation', () {
    final scaled = sample.transformed(Mat3.scaling(2, 2));
    expect(scaled.position, const Vec2(8, 10));
    expect(scaled.height, closeTo(7, 1e-9));
    expect(scaled.rotation, closeTo(0.25, 1e-9));

    final rotated = sample.transformed(Mat3.rotation(math.pi / 2));
    expect(rotated.rotation, closeTo(0.25 + math.pi / 2, 1e-9));
  });

  test('object snaps report the insertion as a node', () {
    final sink = _SnapSink();
    sample.emitObjectSnaps(sink);
    expect(sink.nodes, const [Vec2(4, 5)]);
  });

  test('id and props copies keep the geometry', () {
    final renumbered = sample.withId(3);
    expect(renumbered.id, 3);
    expect(renumbered.tag, 'NO');
    expect(renumbered.position, const Vec2(4, 5));

    final hidden = sample.withProps(const EntityProps(visible: false));
    expect(hidden.props.visible, isFalse);
    expect(hidden.value, 'A-01');
  });

  test('JSON round-trips the value and its alignment', () {
    final restored = CadEntity.fromJson(sample.toJson());
    expect(restored, isA<AttribEntity>());
    final attrib = restored as AttribEntity;
    expect(attrib.position, const Vec2(4, 5));
    expect(attrib.tag, 'NO');
    expect(attrib.value, 'A-01');
    expect(attrib.height, closeTo(3.5, 1e-9));
    expect(attrib.rotation, closeTo(0.25, 1e-9));
    expect(attrib.styleName, 'Notes');
    expect(attrib.widthFactor, closeTo(0.8, 1e-9));
    expect(attrib.obliqueAngle, closeTo(0.1, 1e-9));
    expect(attrib.hAlign, TextHAlign.center);
    expect(attrib.vAlign, TextVAlign.middle);
    expect(attrib.invisible, isFalse);

    const hidden = AttribEntity(
      id: 2,
      position: Vec2.zero(),
      tag: 'X',
      value: 'Y',
      invisible: true,
    );
    final round = CadEntity.fromJson(hidden.toJson()) as AttribEntity;
    expect(round.invisible, isTrue);
  });
}
