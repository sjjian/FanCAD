import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  test('an empty or over-nested insert cannot invent block cells', () {
    const insert = InsertEntity(id: 1, blockName: '', position: Vec2.zero());
    expect(emit(insert).isEmpty, isTrue);

    const nested = InsertEntity(id: 2, blockName: 'CELL', position: Vec2.zero());
    final sink = PolylineSink();
    nested.emit(const EmitContext(tolerance: 0.1, depth: 32), sink);
    expect(sink.isEmpty, isTrue);
  });

  test('an insert grip stays on the insertion', () {
    const insert = InsertEntity(id: 1, blockName: 'B', position: Vec2.zero());
    expect(
      insert.withGrip(0, const Vec2(4, 5)).position,
      const Vec2(4, 5),
    );
  });

  test('an insert array emits each cell and a clip miss stays silent', () {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
        blockName: 'CELL',
      );
    const insert = InsertEntity(
      id: 2,
      blockName: 'CELL',
      position: Vec2(10, 0),
      columnCount: 2,
      columnSpacing: 20,
    );
    final sink = PolylineSink();
    insert.emit(EmitContext(tolerance: 0.1, blocks: document), sink);
    expect(sink.polylines, hasLength(2));
    expect(insert.computeBounds(blocks: document).width, greaterThan(4));

    final clipped = PolylineSink();
    insert.emit(
      EmitContext(
        tolerance: 0.1,
        blocks: document,
        clip: const Bounds2(-2, -2, -1, -1),
      ),
      clipped,
    );
    expect(clipped.polylines, isEmpty);
  });

  test('a sub-pixel insert collapses to a point instead of its members', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
      blockName: 'CELL',
    );
    document.putBlock(const BlockRecord(name: 'CELL', entityIds: [1]));
    const insert = InsertEntity(
      id: 2,
      blockName: 'CELL',
      position: Vec2.zero(),
    );
    final full = PolylineSink();
    insert.emit(EmitContext(tolerance: 0.1, blocks: document), full);
    expect(full.polylines, hasLength(1));
    expect(full.points, isEmpty);

    final lod = PolylineSink();
    insert.emit(
      EmitContext(tolerance: 0.1, blocks: document, minExtent: 10),
      lod,
    );
    expect(lod.polylines, isEmpty);
    expect(lod.points, hasLength(1));
  });

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
}
