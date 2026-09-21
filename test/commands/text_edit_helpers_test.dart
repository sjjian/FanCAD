import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad/commands/edit/helpers.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('TEXT / MTEXT / dim / attrib / mleader are edit targets', () {
    expect(
      isTextEditTarget(
        const TextEntity(id: 1, position: Vec2.zero(), content: 'A'),
      ),
      isTrue,
    );
    expect(
      isTextEditTarget(
        const LineEntity(id: 2, start: Vec2.zero(), end: Vec2(1, 0)),
      ),
      isFalse,
    );
  });

  test('MTEXT field value turns paragraph marks into newlines', () {
    const entity = MTextEntity(id: 1, position: Vec2.zero(), content: r'A\PB');
    expect(textEditFieldValue(entity), 'A\nB');
    expect(textEditCommitValue(entity, 'A\nC'), r'A\PC');
  });

  test('the edit field hides paragraph codes such as \\pxqc', () {
    const entity = MTextEntity(
      id: 1,
      position: Vec2.zero(),
      content: r'\pxqc;外墙',
    );
    expect(textEditFieldValue(entity), '外墙');
    expect(textEditCommitValue(entity, '内墙'), r'\pxqc;内墙');
  });

  test('a dimension field shows the measured value until overridden', () {
    const entity = DimensionEntity(id: 1, measurement: 6, overrideText: '');
    expect(editableTextOf(entity), isEmpty);
    expect(textEditFieldValue(entity), entity.displayText);
    final updated = entityWithEditedText(entity, '<> mm') as DimensionEntity;
    expect(updated.overrideText, '<> mm');
  });

  test(
    'a dimension field shows the *D note when the measurement disagrees',
    () {
      final document = CadDocument();
      document.addEntity(
        const TextEntity(
          id: 1,
          position: Vec2(5, 4),
          content: '114.6',
          height: 2.5,
        ),
        blockName: r'*D1',
      );
      final dim =
          document.addEntity(
                const DimensionEntity(
                  id: 2,
                  blockName: r'*D1',
                  textPosition: Vec2(5, 4),
                  measurement: 269.82,
                ),
              )
              as DimensionEntity;
      expect(textEditFieldValue(dim, document: document), '114.6');
      expect(textRotationOf(dim, document: document), 0);
      expect(
        (editedDimensionBlockLabel(document, dim, '120') as TextEntity).content,
        '120',
      );
      expect(
        (editedDimensionBlockLabel(
                  document,
                  dim,
                  '114.6',
                  rotationRadians: math.pi,
                )
                as TextEntity)
            .rotation,
        closeTo(math.pi, 1e-12),
      );
    },
  );

  test('entityWithEditedText keeps a dimension block name', () {
    const entity = DimensionEntity(
      id: 1,
      blockName: '*D1',
      overrideText: 'A',
      sourceIds: [3, 5],
    );
    final updated = entityWithEditedText(entity, 'B') as DimensionEntity;
    expect(updated.blockName, '*D1');
    expect(updated.sourceIds, [3, 5]);
    expect(updated.overrideText, 'B');
  });

  test('a locked layer is not a canvas edit target', () {
    final document = CadDocument()
      ..putLayer(const LayerDef(name: 'LOCK', locked: true));
    final text = document.addEntity(
      const TextEntity(
        id: 1,
        props: EntityProps(layer: 'LOCK'),
        position: Vec2.zero(),
        content: 'A',
      ),
    );
    expect(
      canvasTextEditTarget(
        document: document,
        entityId: text.id,
        commandRunning: false,
      ),
      isNull,
    );
  });

  test('a running command does not steal zoom for text', () {
    final document = CadDocument();
    final text = document.addEntity(
      const TextEntity(id: 1, position: Vec2.zero(), content: 'A'),
    );
    expect(
      canvasTextEditTarget(
        document: document,
        entityId: text.id,
        commandRunning: true,
      ),
      isNull,
    );
    expect(
      canvasTextEditTarget(
        document: document,
        entityId: text.id,
        commandRunning: false,
      ),
      text,
    );
  });

  test('an mleader note is rewritten in place', () {
    final entity = MLeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 10, 0]),
      content: 'NOTE',
    );
    expect(isTextEditTarget(entity), isTrue);
    expect(
      (entityWithEditedText(entity, 'TAG') as MLeaderEntity).content,
      'TAG',
    );
  });

  test('height changes in place without moving the insertion', () {
    const entity = TextEntity(
      id: 1,
      position: Vec2(4, 2),
      content: 'A',
      height: 2.5,
    );
    final updated = entityWithHeight(entity, 10) as TextEntity;
    expect(updated.height, 10);
    expect(updated.position, entity.position);
    expect(entityWithHeight(entity, 2.5), isNull);
    expect(textHeightOf(const DimensionEntity(id: 2)), isNull);
    expect(entityWithHeight(const DimensionEntity(id: 2), 5), isNull);
  });

  test('rotation turns the note about the insertion', () {
    const entity = TextEntity(
      id: 1,
      position: Vec2(4, 2),
      content: 'A',
      rotation: 0,
    );
    final updated = entityWithRotation(entity, math.pi / 2) as TextEntity;
    expect(updated.position, entity.position);
    expect(updated.rotation, closeTo(math.pi / 2, 1e-12));
    expect(entityWithRotation(entity, 0), isNull);
    expect(
      entityWithRotation(const DimensionEntity(id: 2), math.pi / 2),
      isNull,
    );
    final leader = MLeaderEntity(
      id: 3,
      vertices: Float64List.fromList([0, 0, 10, 0]),
      content: 'N',
      textPosition: const Vec2(10, 0),
    );
    final turned = entityWithRotation(leader, math.pi / 2) as MLeaderEntity;
    expect(turned.textPosition, const Vec2(10, 0));
    expect(turned.textRotation, closeTo(math.pi / 2, 1e-12));
    expect(turned.vertices, leader.vertices);
  });

  test('style, column width, width factor and oblique rewrite the object', () {
    const text = TextEntity(
      id: 1,
      position: Vec2(4, 2),
      content: 'A',
      styleName: 'Standard',
    );
    final styled = entityWithStyle(text, 'Notes') as TextEntity;
    expect(styled.styleName, 'Notes');
    expect(styled.position, text.position);
    expect(entityWithStyle(text, 'Standard'), isNull);

    final tall = entityWithStyle(text, 'Title', fixedHeight: 8) as TextEntity;
    expect(tall.styleName, 'Title');
    expect(tall.height, 8);

    const note = MTextEntity(
      id: 2,
      position: Vec2(10, 20),
      content: 'N',
      rectangleWidth: 40,
    );
    final wider = entityWithColumnWidth(note, 80) as MTextEntity;
    expect(wider.rectangleWidth, 80);
    expect(wider.position, note.position);
    expect(entityWithColumnWidth(note, 40), isNull);
    expect(entityWithColumnWidth(text, 80), isNull);

    final wide = entityWithWidthFactor(text, 1.2) as TextEntity;
    expect(wide.widthFactor, closeTo(1.2, 1e-12));
    expect(entityWithWidthFactor(text, 1), isNull);

    final slanted = entityWithOblique(text, math.pi / 12) as TextEntity;
    expect(slanted.obliqueAngle, closeTo(math.pi / 12, 1e-12));
    expect(entityWithOblique(text, 0), isNull);
  });

  test('editOutline ghosts a TEXT box when there are no strokes', () {
    final document = CadDocument();
    const entity = TextEntity(
      id: 1,
      position: Vec2.zero(),
      content: 'A',
      height: 10,
    );
    final ghost = editOutline(document, entity);
    final boxes = ghost.whereType<OverlayPolyline>().where(
      (shape) => shape.closed,
    );
    expect(boxes, isNotEmpty);
    expect(boxes.first.points, hasLength(4));
  });

  test('justify key maps baseline text onto the bottom row', () {
    const entity = TextEntity(id: 1, position: Vec2.zero(), content: 'A');
    expect(textJustifyKeyOf(entity), 'bl');
    final moved = entityWithJustify(entity, 'right') as TextEntity;
    expect(moved.hAlign, TextHAlign.right);
    expect(moved.position.x, greaterThan(0));
    expect(entityWithJustify(entity, 'left'), isNull);
  });

  test('height is readable on every text-like object except a dimension', () {
    expect(
      textHeightOf(
        const TextEntity(id: 1, position: Vec2.zero(), content: 'A', height: 3),
      ),
      3,
    );
    expect(
      textHeightOf(
        const MTextEntity(
          id: 2,
          position: Vec2.zero(),
          content: 'A',
          height: 4,
        ),
      ),
      4,
    );
    expect(
      textHeightOf(
        const AttribEntity(
          id: 3,
          position: Vec2.zero(),
          tag: 'T',
          value: 'A',
          height: 5,
        ),
      ),
      5,
    );
    expect(
      textHeightOf(
        const AttdefEntity(
          id: 4,
          position: Vec2.zero(),
          tag: 'T',
          defaultValue: 'A',
          height: 6,
        ),
      ),
      6,
    );
    expect(
      textHeightOf(
        MLeaderEntity(
          id: 5,
          vertices: Float64List.fromList([0, 0, 1, 0]),
          textHeight: 7,
        ),
      ),
      7,
    );
    expect(textHeightOf(const DimensionEntity(id: 6)), isNull);
    expect(
      textHeightOf(
        const LineEntity(id: 7, start: Vec2.zero(), end: Vec2(1, 0)),
      ),
      isNull,
    );
  });

  test('entityWithHeight keeps insertion, style and flags', () {
    const mtext = MTextEntity(
      id: 1,
      position: Vec2(1, 2),
      content: 'Hi',
      height: 2.5,
      rotation: 0.5,
      styleName: 'Notes',
      rectangleWidth: 40,
      attachment: 3,
    );
    final taller = entityWithHeight(mtext, 8) as MTextEntity;
    expect(taller.height, 8);
    expect(taller.position, mtext.position);
    expect(taller.rotation, 0.5);
    expect(taller.styleName, 'Notes');
    expect(taller.rectangleWidth, 40);
    expect(taller.attachment, 3);

    const attrib = AttribEntity(
      id: 2,
      position: Vec2(3, 4),
      tag: 'T',
      value: 'A',
      height: 2.5,
      invisible: true,
    );
    expect((entityWithHeight(attrib, 9) as AttribEntity).invisible, isTrue);
    expect(
      (entityWithHeight(attrib, 9) as AttribEntity).position,
      attrib.position,
    );

    const def = AttdefEntity(
      id: 3,
      position: Vec2.zero(),
      tag: 'NO',
      defaultValue: 'A',
      height: 2.5,
      constant: true,
      preset: true,
    );
    final raised = entityWithHeight(def, 11) as AttdefEntity;
    expect(raised.height, 11);
    expect(raised.constant, isTrue);
    expect(raised.preset, isTrue);

    final leader = MLeaderEntity(
      id: 4,
      vertices: Float64List.fromList([0, 0, 4, 0]),
      content: 'N',
      textPosition: const Vec2(4, 1),
      textHeight: 2.5,
      attachment: 6,
    );
    final note = entityWithHeight(leader, 12) as MLeaderEntity;
    expect(note.textHeight, 12);
    expect(note.textPosition, leader.textPosition);
    expect(note.attachment, 6);
    expect(note.vertices, leader.vertices);

    expect(entityWithHeight(mtext, 0), isNull);
    expect(entityWithHeight(mtext, -1), isNull);
  });

  test('justify keys follow the 1–9 attachment grid', () {
    expect(
      textJustifyKeyOf(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: 'A',
          attachment: 1,
        ),
      ),
      'tl',
    );
    expect(
      textJustifyKeyOf(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: 'A',
          attachment: 5,
        ),
      ),
      'mc',
    );
    expect(
      textJustifyKeyOf(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: 'A',
          attachment: 9,
        ),
      ),
      'br',
    );
    expect(
      textJustifyKeyOf(
        MLeaderEntity(
          id: 2,
          vertices: Float64List.fromList([0, 0, 1, 0]),
          attachment: 4,
        ),
      ),
      'ml',
    );
    expect(textAlignOf(const DimensionEntity(id: 3)), isNull);
    expect(textJustifyKeyOf(const DimensionEntity(id: 3)), isNull);
    expect(
      textAlignOf(const LineEntity(id: 4, start: Vec2.zero(), end: Vec2(1, 0))),
      isNull,
    );
  });

  test('entityWithJustify covers attrib, attdef, mtext and mleader', () {
    const attrib = AttribEntity(
      id: 1,
      position: Vec2.zero(),
      tag: 'T',
      value: 'ABC',
      height: 10,
    );
    final attribRight = entityWithJustify(attrib, 'right') as AttribEntity;
    expect(attribRight.hAlign, TextHAlign.right);
    expect(attribRight.tag, 'T');

    const def = AttdefEntity(
      id: 2,
      position: Vec2.zero(),
      tag: 'NO',
      defaultValue: 'ABC',
      height: 10,
    );
    expect(
      (entityWithJustify(def, 'tr') as AttdefEntity).vAlign,
      TextVAlign.top,
    );

    const mtext = MTextEntity(
      id: 3,
      position: Vec2.zero(),
      content: 'Hi',
      height: 10,
    );
    expect((entityWithJustify(mtext, 'tr') as MTextEntity).attachment, 3);

    final leader = MLeaderEntity(
      id: 4,
      vertices: Float64List.fromList([0, 0, 4, 0]),
      content: 'Hi',
      textHeight: 10,
      attachment: 4,
    );
    expect((entityWithJustify(leader, 'tr') as MLeaderEntity).attachment, 3);

    expect(entityWithJustify(const DimensionEntity(id: 5), 'right'), isNull);
    expect(
      entityWithJustify(
        const LineEntity(id: 6, start: Vec2.zero(), end: Vec2(1, 0)),
        'right',
      ),
      isNull,
    );
  });

  test('empty content is required only of TEXT, MTEXT and mleader notes', () {
    expect(
      textEditRequiresContent(
        const TextEntity(id: 1, position: Vec2.zero(), content: 'A'),
      ),
      isTrue,
    );
    expect(
      textEditRequiresContent(
        const MTextEntity(id: 2, position: Vec2.zero(), content: 'A'),
      ),
      isTrue,
    );
    expect(
      textEditRequiresContent(
        MLeaderEntity(
          id: 3,
          vertices: Float64List.fromList([0, 0, 1, 0]),
          content: 'A',
        ),
      ),
      isTrue,
    );
    expect(
      textEditRequiresContent(
        const AttribEntity(id: 4, position: Vec2.zero(), tag: 'T', value: 'A'),
      ),
      isFalse,
    );
    expect(
      textEditRequiresContent(
        const AttdefEntity(id: 5, position: Vec2.zero(), tag: 'T'),
      ),
      isFalse,
    );
    expect(textEditRequiresContent(const DimensionEntity(id: 6)), isFalse);
  });

  test('every text-like object is an edit target', () {
    expect(
      isTextEditTarget(
        const MTextEntity(id: 1, position: Vec2.zero(), content: 'A'),
      ),
      isTrue,
    );
    expect(isTextEditTarget(const DimensionEntity(id: 2)), isTrue);
    expect(
      isTextEditTarget(
        const AttribEntity(id: 3, position: Vec2.zero(), tag: 'T', value: 'A'),
      ),
      isTrue,
    );
    expect(
      isTextEditTarget(
        const AttdefEntity(id: 4, position: Vec2.zero(), tag: 'T'),
      ),
      isTrue,
    );
  });

  test('the same stored string is not rewritten', () {
    const text = TextEntity(id: 1, position: Vec2.zero(), content: 'A');
    expect(entityWithEditedText(text, 'A'), isNull);
    expect((entityWithEditedText(text, 'B') as TextEntity).content, 'B');

    const def = AttdefEntity(
      id: 2,
      position: Vec2.zero(),
      tag: 'NO',
      defaultValue: 'A',
    );
    expect(entityWithEditedText(def, 'A'), isNull);
    expect((entityWithEditedText(def, 'B') as AttdefEntity).tag, 'NO');
    expect((entityWithEditedText(def, 'B') as AttdefEntity).defaultValue, 'B');
  });

  test('a leader note turns field newlines into paragraph marks', () {
    final entity = MLeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 4, 0]),
      content: r'A\PB',
    );
    expect(textEditFieldValue(entity), 'A\nB');
    expect(textEditCommitValue(entity, 'A\nC'), r'A\PC');
  });

  test('placement follows the CAD insertion, not a guessed box', () {
    const text = TextEntity(
      id: 1,
      position: Vec2(4, 2),
      content: 'A',
      height: 3,
      rotation: 0.5,
    );
    final placed = textEditPlacementOf(text)!;
    expect(placed.origin, const Vec2(4, 2));
    expect(placed.multiline, isFalse);

    const mtext = MTextEntity(
      id: 2,
      position: Vec2(1, 2),
      content: 'Hi',
      height: 4,
      rectangleWidth: 40,
    );
    final paragraph = textEditPlacementOf(mtext)!;
    expect(paragraph.origin, mtext.position);
    expect(paragraph.multiline, isTrue);

    const dim = DimensionEntity(id: 3, textPosition: Vec2(8, 1));
    final dimPlace = textEditPlacementOf(dim)!;
    expect(dimPlace.origin, const Vec2(8, 1));
    expect(dimPlace.multiline, isFalse);

    const attrib = AttribEntity(
      id: 4,
      position: Vec2(3, 4),
      tag: 'T',
      value: 'A',
      height: 5,
    );
    expect(textEditPlacementOf(attrib)!.origin, attrib.position);

    const def = AttdefEntity(id: 5, position: Vec2(6, 7), tag: 'NO', height: 6);
    expect(textEditPlacementOf(def)!.origin, def.position);

    final leader = MLeaderEntity(
      id: 6,
      vertices: Float64List.fromList([0, 0, 4, 0]),
      textPosition: const Vec2(4, 1),
      textHeight: 7,
      textRotation: 0.25,
    );
    final note = textEditPlacementOf(leader)!;
    expect(note.origin, const Vec2(4, 1));
    expect(note.multiline, isTrue);

    expect(
      textEditPlacementOf(
        const LineEntity(id: 7, start: Vec2.zero(), end: Vec2(1, 0)),
      ),
      isNull,
    );
  });

  test('TEXT justify keys map baseline onto the bottom row', () {
    expect(
      textJustifyKeyOf(
        const TextEntity(
          id: 1,
          position: Vec2.zero(),
          content: 'A',
          hAlign: TextHAlign.center,
        ),
      ),
      'bc',
    );
    expect(
      textJustifyKeyOf(
        const TextEntity(
          id: 2,
          position: Vec2.zero(),
          content: 'A',
          hAlign: TextHAlign.right,
          vAlign: TextVAlign.top,
        ),
      ),
      'tr',
    );
    expect(
      textAlignOf(
        const MTextEntity(
          id: 3,
          position: Vec2.zero(),
          content: 'A',
          attachment: 3,
        ),
      ),
      (h: TextHAlign.right, v: TextVAlign.top),
    );
  });

  test('entityWithJustify ignores unknown or unchanged codes', () {
    const text = TextEntity(id: 1, position: Vec2.zero(), content: 'A');
    expect(entityWithJustify(text, 'align'), isNull);
    expect(entityWithJustify(text, 'fit'), isNull);
    expect(entityWithJustify(text, 'nope'), isNull);
    expect(entityWithJustify(text, 'left'), isNull);
  });

  test('a missing or non-text pick is not a canvas edit target', () {
    final document = CadDocument()
      ..addEntity(const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)));
    expect(
      canvasTextEditTarget(
        document: document,
        entityId: null,
        commandRunning: false,
      ),
      isNull,
    );
    expect(
      canvasTextEditTarget(
        document: document,
        entityId: 1,
        commandRunning: false,
      ),
      isNull,
    );
    expect(
      canvasTextEditTarget(
        document: document,
        entityId: 99,
        commandRunning: false,
      ),
      isNull,
    );
  });

  test('a live preview updates height and colour from the original', () {
    const entity = TextEntity(
      id: 1,
      position: Vec2.zero(),
      content: 'A',
      height: 2.5,
    );
    final taller =
        textEditPreviewOf(entity, const TextEditCommit(field: 'A', height: 10))
            as TextEntity;
    expect(taller.height, 10);
    expect(taller.content, 'A');

    final coloured =
        textEditPreviewOf(
              entity,
              const TextEditCommit(field: 'A', color: CadColor.indexed(1)),
            )
            as TextEntity;
    expect(coloured.props.color, const CadColor.indexed(1));
    expect(coloured.height, 2.5);
  });

  test('an unchanged live preview leaves the original entity', () {
    const entity = TextEntity(
      id: 1,
      position: Vec2.zero(),
      content: 'A',
      height: 2.5,
    );
    expect(
      textEditPreviewOf(
        entity,
        const TextEditCommit(field: 'A', height: 2.5, justify: 'bl'),
      ),
      isNull,
    );
  });

  test('a second preview does not stack rotation on the original', () {
    const entity = TextEntity(id: 1, position: Vec2.zero(), content: 'A');
    final once =
        textEditPreviewOf(
              entity,
              const TextEditCommit(field: 'A', rotation: 90),
            )
            as TextEntity;
    final twice =
        textEditPreviewOf(
              entity,
              const TextEditCommit(field: 'A', rotation: 90),
            )
            as TextEntity;
    expect(twice.rotation, once.rotation);
  });
}
