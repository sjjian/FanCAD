import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('add and erase invert each other at the same draw-order index', () {
    final document = CadDocument();
    const line = LineEntity(id: 7, start: Vec2.zero(), end: Vec2(3, 0));
    final add = AddEntityPatch(
      entity: line,
      blockName: document.modelSpaceBlockName,
    );
    final undoAdd = add.inverse(document);
    expect(add.describe(), contains('line'));
    add.applyTo(document);
    expect(document.entity(7), isNotNull);

    final erase = RemoveEntityPatch(
      entity: line,
      blockName: document.modelSpaceBlockName,
      index: document.entityIndexOf(7),
    );
    final undoErase = erase.inverse(document);
    erase.applyTo(document);
    expect(document.entity(7), isNull);
    undoErase.applyTo(document);
    expect(document.entity(7), isNotNull);
    undoAdd.applyTo(document);
    expect(document.entity(7), isNull);
  });

  test('modify, layer and dimstyle patches restore the previous table row', () {
    final document = CadDocument();
    final original = document.addEntity(
      const PointEntity(id: 0, position: Vec2.zero()),
    );
    final after = original.withProps(
      const EntityProps(layer: '0', visible: false),
    );
    final modify = ModifyEntityPatch(before: original, after: after);
    modify.applyTo(document);
    expect(document.entity(original.id)!.props.visible, isFalse);
    modify.inverse(document).applyTo(document);
    expect(document.entity(original.id)!.props.visible, isTrue);

    const layer = LayerDef(name: 'WALLS', locked: true);
    final putLayer = PutLayerPatch(layer);
    final undoLayer = putLayer.inverse(document);
    expect(undoLayer, isA<RemoveLayerPatch>());
    putLayer.applyTo(document);
    expect(document.layer('WALLS')?.locked, isTrue);
    undoLayer.applyTo(document);
    expect(document.layer('WALLS'), isNull);

    const style = DimStyleDef(name: 'ARCH', decimalPlaces: 0);
    final putStyle = PutDimStylePatch(style, null);
    final undoStyle = putStyle.inverse(document);
    expect(undoStyle, isA<RemoveDimStylePatch>());
    putStyle.applyTo(document);
    expect(document.namedDimStyle('ARCH')?.decimalPlaces, 0);
    undoStyle.applyTo(document);
    expect(document.namedDimStyle('ARCH'), isNull);
  });

  test(
    'header, current layer and layout patches undo without leftover tabs',
    () {
      final document = CadDocument();
      final header = HeaderVariablePatch('\$INSUNITS', '4', null);
      header.applyTo(document);
      expect(document.headerVariables['\$INSUNITS'], '4');
      header.inverse(document).applyTo(document);
      expect(document.headerVariables['\$INSUNITS'], '');

      document.putLayer(const LayerDef(name: 'WORK'));
      final layer = CurrentLayerPatch('WORK', '0');
      layer.applyTo(document);
      expect(document.currentLayer, 'WORK');
      layer.inverse(document).applyTo(document);
      expect(document.currentLayer, '0');

      const sheet = Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1);
      final put = PutLayoutPatch(sheet);
      final undoPut = put.inverse(document);
      expect(undoPut, isA<RemoveLayoutPatch>());
      put.applyTo(document);
      expect(document.layouts.map((l) => l.name), contains('A3'));
      final activate = ActiveLayoutPatch('A3', 'Model');
      activate.applyTo(document);
      expect(document.activeLayoutName, 'A3');
      activate.inverse(document).applyTo(document);
      expect(document.activeLayoutName, 'Model');
      undoPut.applyTo(document);
      expect(document.layouts.map((l) => l.name), isNot(contains('A3')));
    },
  );

  test('rename and restore a user block with its entities', () {
    final document = CadDocument();
    final line = document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(2, 0)),
      blockName: 'DOOR',
    );
    final rename = RenameBlockPatch('DOOR', 'LEAF');
    rename.applyTo(document);
    expect(document.blocks.containsKey('LEAF'), isTrue);
    rename.inverse(document).applyTo(document);
    expect(document.ownerOf(line.id), 'DOOR');

    final block = document.blocks['DOOR']!;
    final remove = RemoveBlockPatch(block.name, block, entities: [line]);
    final restore = remove.inverse(document);
    remove.applyTo(document);
    expect(document.entity(line.id), isNull);
    restore.applyTo(document);
    expect(document.entity(line.id), isNotNull);
    expect(
      PutLineTypePatch(LineTypeDef.dashed, null).describe(),
      contains('DASHED'),
    );
    expect(
      PutTextStylePatch(const TextStyleDef(name: 'Notes'), null).describe(),
      contains('Notes'),
    );
    expect(
      CurrentDimStylePatch('ARCH', 'Standard').describe(),
      contains('ARCH'),
    );
  });

  test('undoing a new block cannot invent a previous definition', () {
    final document = CadDocument();
    const block = BlockRecord(name: 'TEMP');
    final put = PutBlockPatch(block, null);
    final undo = put.inverse(document);

    expect(undo, isA<RemoveBlockPatch>());
    put.applyTo(document);
    expect(document.blocks.containsKey('TEMP'), isTrue);
    undo.applyTo(document);
    expect(document.blocks.containsKey('TEMP'), isFalse);
  });

  test('undoing a new text style cannot invent a previous font', () {
    final document = CadDocument();
    const style = TextStyleDef(name: 'Notes', fontFamily: 'Arial', height: 5);
    final put = PutTextStylePatch(style, null);
    final undo = put.inverse(document);

    put.applyTo(document);
    expect(document.textStyles['Notes']?.fontFamily, 'Arial');
    undo.applyTo(document);
    expect(document.textStyles['Notes']?.fontFamily, 'txt');
    expect(document.textStyles['Notes']?.height, 0);
  });

  test('undoing a new linetype cannot invent a previous dash pattern', () {
    final document = CadDocument();
    const lineType = LineTypeDef(
      name: 'CUSTOM',
      pattern: [12, -6],
      patternLength: 18,
    );
    final put = PutLineTypePatch(lineType, null);
    final undo = put.inverse(document);

    put.applyTo(document);
    expect(document.lineTypes['CUSTOM']?.pattern, [12, -6]);
    undo.applyTo(document);
    expect(document.lineTypes['CUSTOM']?.pattern, isEmpty);
    expect(document.lineTypes['CUSTOM']?.patternLength, 0);
  });
}
