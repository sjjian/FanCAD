import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('orders drawn text top to bottom, then left to right', () {
    final document = CadDocument();
    document.addEntity(
      const TextEntity(id: 1, position: Vec2(0, 0), content: 'LOW'),
    );
    document.addEntity(
      const TextEntity(id: 2, position: Vec2(0, 100), content: 'HIGH'),
    );
    document.addEntity(
      const TextEntity(id: 3, position: Vec2(40, 10), content: 'RIGHT'),
    );
    document.addEntity(
      const TextEntity(id: 4, position: Vec2(0, 10), content: 'LEFT'),
    );

    final hits = textSearchHits(document);
    expect(hits.map((hit) => hit.text), ['HIGH', 'LEFT', 'RIGHT', 'LOW']);
    expect(hits.first.selectId, 2);
    expect(hits.first.kind, TextSearchKind.text);
    expect(identical(textSearchHits(document), hits), isTrue);
  });

  test('an empty query matches nothing and case does not matter', () {
    final document = CadDocument()
      ..addEntity(
        const TextEntity(id: 1, position: Vec2.zero(), content: 'Note'),
      );
    final hits = textSearchHits(document);
    expect(filterTextSearchHits(hits, ''), isEmpty);
    expect(filterTextSearchHits(hits, '   '), isEmpty);
    expect(filterTextSearchHits(hits, 'note'), hasLength(1));
    expect(filterTextSearchHits(hits, 'NO'), hasLength(1));
    expect(filterTextSearchHits(hits, 'missing'), isEmpty);
  });

  test('mtext codes and a frozen layer are not what the user searches', () {
    final document = CadDocument()
      ..putLayer(const LayerDef(name: 'OFF', visible: false))
      ..addEntity(
        const MTextEntity(id: 1, position: Vec2.zero(), content: r'Line\PTwo'),
      )
      ..addEntity(
        const TextEntity(
          id: 2,
          position: Vec2(10, 0),
          content: 'hidden',
          props: EntityProps(layer: 'OFF'),
        ),
      )
      ..addEntity(
        const TextEntity(
          id: 3,
          position: Vec2(20, 0),
          content: 'gone',
          props: EntityProps(visible: false),
        ),
      );

    final hits = textSearchHits(document);
    expect(hits, hasLength(1));
    expect(hits.single.text, 'Line\nTwo');
    expect(hits.single.kind, TextSearchKind.mtext);
    expect(filterTextSearchHits(hits, 'Two'), hasLength(1));
  });

  test('an insert shows the attribute value, not the definition default', () {
    final document = CadDocument()
      ..addEntity(
        const AttdefEntity(
          id: 1,
          position: Vec2(5, 6),
          tag: 'ROOM',
          defaultValue: 'A',
          height: 10,
        ),
        blockName: 'TAG',
      )
      ..addEntity(
        const TextEntity(
          id: 4,
          position: Vec2(0, 0),
          content: 'STATIC',
          height: 4,
        ),
        blockName: 'TAG',
      )
      ..addEntity(
        const InsertEntity(
          id: 2,
          blockName: 'TAG',
          position: Vec2(100, 200),
          scale: Vec2(2, 2),
          attributes: {'ROOM': '客厅'},
        ),
      )
      ..addEntity(
        const InsertEntity(id: 3, blockName: 'TAG', position: Vec2(0, 0)),
      );

    final hits = textSearchHits(document);
    final room = hits.where((hit) => hit.tag == 'ROOM').toList();
    expect(room.map((hit) => hit.text), ['客厅', 'A']);
    expect(room.every((hit) => hit.kind == TextSearchKind.attribute), isTrue);
    expect(room.first.selectId, 2);
    expect(room.first.height, closeTo(20, 1e-9));
    expect(room.first.anchor.x, greaterThan(100));
    expect(room.first.anchor.y, greaterThan(200));
    expect(hits.where((hit) => hit.text == 'STATIC'), hasLength(2));
    expect(
      hits.where((hit) => hit.text == 'STATIC').map((hit) => hit.selectId),
      [2, 3],
    );
  });

  test('invisible attributes and other layouts stay out of the list', () {
    final document = CadDocument()
      ..addLayout(
        const Layout(name: 'Sheet', blockName: '*Paper_Space', tabOrder: 1),
      )
      ..addEntity(
        const AttdefEntity(
          id: 1,
          position: Vec2.zero(),
          tag: 'SECRET',
          defaultValue: 'hidden-attr',
          invisible: true,
        ),
        blockName: 'TAG',
      )
      ..addEntity(
        const InsertEntity(
          id: 2,
          blockName: 'TAG',
          position: Vec2.zero(),
          attributes: {'SECRET': 'hidden-attr'},
        ),
      )
      ..addEntity(
        const TextEntity(id: 3, position: Vec2.zero(), content: 'SHEET'),
        blockName: '*Paper_Space',
      )
      ..addEntity(
        const TextEntity(id: 4, position: Vec2.zero(), content: 'MODEL'),
      );

    expect(textSearchHits(document).map((hit) => hit.text), ['MODEL']);
  });

  test('editing a block searches that definition, not the layout', () {
    final document = CadDocument()
      ..addEntity(
        const AttdefEntity(
          id: 1,
          position: Vec2.zero(),
          tag: 'TITLE',
          defaultValue: '图框',
        ),
        blockName: 'FRAME',
      )
      ..addEntity(
        const TextEntity(id: 2, position: Vec2.zero(), content: 'MODEL'),
      );
    expect(document.setEditedBlock('FRAME'), isTrue);

    final hits = textSearchHits(document);
    expect(hits, hasLength(1));
    expect(hits.single.text, '图框');
    expect(hits.single.selectId, 1);
    expect(hits.single.tag, 'TITLE');
  });

  test('a dimension is the painted label, and a space override is absent', () {
    final document = CadDocument()
      ..addEntity(
        const TextEntity(id: 2, position: Vec2(1, 1), content: 'Ø10'),
        blockName: '*D1',
      )
      ..addEntity(
        const DimensionEntity(
          id: 1,
          blockName: '*D1',
          textPosition: Vec2(1, 1),
          measurement: 10,
          overrideText: 'R<>',
        ),
      )
      ..addEntity(
        const DimensionEntity(
          id: 3,
          textPosition: Vec2(30, 0),
          measurement: 5,
          overrideText: ' ',
        ),
      )
      ..addEntity(
        const DimensionEntity(id: 4, textPosition: Vec2(40, 0), measurement: 5),
      );

    final hits = textSearchHits(document);
    expect(hits.map((hit) => hit.text), containsAll(['Ø10', '5.00']));
    expect(hits.map((hit) => hit.text), isNot(contains('R<>')));
    expect(hits.where((hit) => hit.selectId == 1).single.text, 'Ø10');
    expect(
      hits.where((hit) => hit.selectId == 1).single.kind,
      TextSearchKind.dimension,
    );
    expect(hits.where((hit) => hit.selectId == 3), isEmpty);
    expect(hits.where((hit) => hit.text == 'Ø10'), hasLength(1));
  });

  test('a block that inserts itself does not recurse forever', () {
    final document = CadDocument()
      ..addEntity(
        const TextEntity(id: 1, position: Vec2.zero(), content: 'LOOP'),
        blockName: 'LOOP',
      )
      ..addEntity(
        const InsertEntity(id: 2, blockName: 'LOOP', position: Vec2(10, 10)),
        blockName: 'LOOP',
      )
      ..addEntity(
        const InsertEntity(id: 3, blockName: 'LOOP', position: Vec2.zero()),
      );

    final hits = textSearchHits(document);
    expect(hits.map((hit) => hit.text), ['LOOP']);
    expect(hits.single.selectId, 3);
  });

  test('a new entity shows up after the document changes', () {
    final document = CadDocument()
      ..addEntity(
        const TextEntity(id: 1, position: Vec2.zero(), content: 'OLD'),
      );
    final before = textSearchHits(document);
    document.addEntity(
      const TextEntity(id: 2, position: Vec2(0, 5), content: 'NEW'),
    );
    final after = textSearchHits(document);
    expect(after.map((hit) => hit.text), ['NEW', 'OLD']);
    expect(identical(before, after), isFalse);
  });
}
