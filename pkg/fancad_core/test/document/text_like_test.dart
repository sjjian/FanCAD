import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

/// Each `with` on a [TextLike] changes its one property and nothing else.
///
/// Every field is set away from its default so a copy that drops one shows
/// up as a missing or changed JSON key.
void main() {
  const props = EntityProps(layer: 'NOTES', color: CadColor.indexed(3));
  final notes = <TextLike>[
    const TextEntity(
      id: 11,
      props: props,
      position: Vec2(1, 2),
      content: 'TEXT',
      height: 3.5,
      rotation: 0.3,
      styleName: 'Notes',
      widthFactor: 0.8,
      obliqueAngle: 0.2,
      hAlign: TextHAlign.center,
      vAlign: TextVAlign.top,
    ),
    const MTextEntity(
      id: 12,
      props: props,
      position: Vec2(3, 4),
      content: r'{\fArial;MTEXT}\Pline',
      height: 4,
      rotation: 0.4,
      styleName: 'Notes',
      rectangleWidth: 30,
      attachment: 5,
    ),
    const AttribEntity(
      id: 13,
      props: props,
      position: Vec2(5, 6),
      tag: 'NO',
      value: 'A-01',
      height: 2,
      rotation: 0.5,
      styleName: 'Notes',
      widthFactor: 0.7,
      obliqueAngle: 0.1,
      hAlign: TextHAlign.right,
      vAlign: TextVAlign.bottom,
      invisible: true,
    ),
    const AttdefEntity(
      id: 14,
      props: props,
      position: Vec2(7, 8),
      tag: 'NO',
      prompt: 'Number',
      defaultValue: 'A-00',
      height: 2.2,
      rotation: 0.6,
      styleName: 'Notes',
      widthFactor: 0.9,
      obliqueAngle: 0.15,
      hAlign: TextHAlign.middle,
      vAlign: TextVAlign.middle,
      invisible: true,
      constant: true,
      verify: true,
      preset: true,
    ),
    MLeaderEntity(
      id: 15,
      props: props,
      vertices: Float64List.fromList([0, 0, 5, 5, 9, 5]),
      pathLengths: const [3],
      hasArrowHead: false,
      content: 'NOTE',
      textPosition: const Vec2(9, 5),
      textHeight: 3,
      textRotation: 0.7,
      styleName: 'Notes',
      attachment: 6,
    ),
  ];

  Map<String, Object?> changedKeys(CadEntity before, CadEntity after) {
    final a = before.toJson();
    final b = after.toJson();
    return {
      for (final key in {...a.keys, ...b.keys})
        if ('${a[key]}' != '${b[key]}') key: b[key],
    };
  }

  for (final note in notes) {
    group(note.kind.name, () {
      test('copyWith with nothing is the same object on disk', () {
        expect(changedKeys(note, note.withId(note.id)), isEmpty);
        expect(changedKeys(note, note.withProps(note.props)), isEmpty);
      });

      test('withContent reads back', () {
        expect(note.withContent('changed').content, 'changed');
      });

      final edits = <String, TextLike? Function()>{
        'text': () => note.withContent('changed'),
        'height': () => note.withHeight(9.25),
        'rotation': () => note.withRotation(1.25),
        'style': () => note.withStyleName('Other'),
        'widthFactor': () => note.withWidthFactor(1.75),
        'oblique': () => note.withObliqueAngle(0.35),
        'rectangleWidth': () => note.withColumnWidth(44),
      };
      for (final MapEntry(key: key, value: edit) in edits.entries) {
        test('with $key changes $key and nothing else', () {
          final next = edit();
          final supported = switch (key) {
            'widthFactor' => note.widthFactor != null,
            'oblique' => note.obliqueAngle != null,
            'rectangleWidth' => note.columnWidth != null,
            _ => true,
          };
          if (!supported) {
            expect(next, isNull);
            return;
          }
          expect(next, isNotNull);
          final before = note.geometryToJson();
          final after = next!.geometryToJson();
          final changed = {
            for (final k in {...before.keys, ...after.keys})
              if ('${before[k]}' != '${after[k]}') k,
          };
          expect(changed, {key});
          expect(next.id, note.id);
          expect(next.props, note.props);
        });
      }
    });
  }

  test('reads match the stored fields', () {
    final mleader = notes.last as MLeaderEntity;
    expect(mleader.position, mleader.textPosition);
    expect(mleader.height, mleader.textHeight);
    expect(mleader.rotation, mleader.textRotation);
    final attrib = notes[2] as AttribEntity;
    expect(attrib.content, attrib.value);
    final attdef = notes[3] as AttdefEntity;
    expect(attdef.content, attdef.defaultValue);
    final mtext = notes[1] as MTextEntity;
    expect(mtext.columnWidth, mtext.rectangleWidth);
  });
}
