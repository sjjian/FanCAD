import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an insert draws the attribute value, not the attdef default', () {
    final document = CadDocument()
      ..putBlock(const BlockRecord(name: 'TITLE', entityIds: []));
    document.addEntity(
      const AttdefEntity(
        id: 0,
        position: Vec2(2, 3),
        tag: 'NO',
        defaultValue: 'A-00',
        height: 2.5,
      ),
      blockName: 'TITLE',
    );
    final insert = document.addEntity(
      const InsertEntity(
        id: 0,
        blockName: 'TITLE',
        position: Vec2.zero(),
        attributes: {'NO': 'A-01'},
      ),
    );

    final definition = PolylineSink();
    document.entity(document.attdefsOf('TITLE').single.id)!.emit(
      const EmitContext(tolerance: 0.1),
      definition,
    );
    expect(definition.texts.single.text, 'A-00');

    final placed = PolylineSink();
    insert.emit(document.emitContext(tolerance: 0.1), placed);
    expect(placed.texts.single.text, 'A-01');
    expect(placed.texts.single.origin, const Vec2(2, 3));
  });

  test('an invisible attdef stays silent on the insert', () {
    final document = CadDocument()
      ..putBlock(const BlockRecord(name: 'TITLE', entityIds: []));
    document.addEntity(
      const AttdefEntity(
        id: 0,
        position: Vec2.zero(),
        tag: 'HIDDEN',
        defaultValue: 'secret',
        invisible: true,
      ),
      blockName: 'TITLE',
    );
    final insert = document.addEntity(
      const InsertEntity(
        id: 0,
        blockName: 'TITLE',
        position: Vec2.zero(),
        attributes: {'HIDDEN': 'secret'},
      ),
    );
    final sink = PolylineSink();
    insert.emit(document.emitContext(tolerance: 0.1), sink);
    expect(sink.texts, isEmpty);
  });

  test('toAttrib copies the definition into a value', () {
    const def = AttdefEntity(
      id: 4,
      position: Vec2(1, 2),
      tag: 'REV',
      defaultValue: 'A',
      height: 3,
    );
    final attrib = def.toAttrib('B');
    expect(attrib.tag, 'REV');
    expect(attrib.value, 'B');
    expect(attrib.position, const Vec2(1, 2));
    expect(attrib.height, 3);
  });
}
