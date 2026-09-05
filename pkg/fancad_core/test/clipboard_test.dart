import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('extract carries an insert and its block definition', () {
    final document = CadDocument();
    final build = Transaction(document, label: 'build');
    build.putBlock(const BlockRecord(name: 'MARK', entityIds: []));
    build.add(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(2, 0)),
      blockName: 'MARK',
    );
    final insertId = build.add(
      const InsertEntity(id: 0, blockName: 'MARK', position: Vec2(5, 5)),
    );
    build.commit();

    final clip = DrawingClip.extract(document, [
      insertId,
    ], basePoint: const Vec2(5, 5))!;
    expect(clip.entities, hasLength(1));
    expect(clip.blocks.keys, contains('MARK'));
    expect(clip.blockEntities, hasLength(1));
    expect(clip.blockEntities.values.single, isA<LineEntity>());
  });

  test('paste translates by insertion minus the stored base', () {
    final source = CadDocument();
    final lineId = Transaction(source, label: 'draw')
      ..add(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)))
      ..commit();
    final id = lineId.change.added.single;
    final clip = DrawingClip.extract(source, [
      id,
    ], basePoint: const Vec2.zero())!;

    final target = CadDocument();
    final paste = Transaction(target, label: 'Paste');
    final placed = clip.paste(paste, insertion: const Vec2(3, 4));
    paste.commit();

    final copy = target.entity(placed.single)! as LineEntity;
    expect(copy.start, const Vec2(3, 4));
    expect(copy.end, const Vec2(13, 4));
  });

  test('paste at the base point keeps original coordinates', () {
    final source = CadDocument();
    final drawn = Transaction(source, label: 'draw')
      ..add(const LineEntity(id: 0, start: Vec2(8, 2), end: Vec2(12, 2)))
      ..commit();
    final clip = DrawingClip.extract(
      source,
      drawn.change.added,
      basePoint: const Vec2(8, 2),
    )!;

    final target = CadDocument();
    final paste = Transaction(target, label: 'Paste');
    final placed = clip.paste(paste, insertion: clip.basePoint);
    paste.commit();

    final copy = target.entity(placed.single)! as LineEntity;
    expect(copy.start, const Vec2(8, 2));
    expect(copy.end, const Vec2(12, 2));
  });

  test('a layer that already exists in the target is not overwritten', () {
    final source = CadDocument()
      ..putLayer(const LayerDef(name: 'WALL', color: CadColor.indexed(1)));
    final drawn = Transaction(source, label: 'draw')
      ..add(
        const LineEntity(
          id: 0,
          props: EntityProps(layer: 'WALL'),
          start: Vec2.zero(),
          end: Vec2(4, 0),
        ),
      )
      ..commit();
    final clip = DrawingClip.extract(
      source,
      drawn.change.added,
      basePoint: const Vec2.zero(),
    )!;

    final target = CadDocument()
      ..putLayer(const LayerDef(name: 'WALL', color: CadColor.indexed(3)));
    final paste = Transaction(target, label: 'Paste');
    clip.paste(paste, insertion: const Vec2.zero());
    paste.commit();

    expect(target.layer('WALL')!.color, const CadColor.indexed(3));
    expect(target.entities.whereType<LineEntity>().single.props.layer, 'WALL');
  });

  test('anonymous dimension blocks get a new name on each paste', () {
    final source = CadDocument();
    final build = Transaction(source, label: 'build');
    build.putBlock(
      const BlockRecord(name: '*D1', isAnonymous: true, entityIds: []),
    );
    build.add(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(1, 0)),
      blockName: '*D1',
    );
    final dimId = build.add(
      const DimensionEntity(
        id: 0,
        blockName: '*D1',
        definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 3)],
        measurement: 10,
      ),
    );
    build.commit();
    final clip = DrawingClip.extract(source, [
      dimId,
    ], basePoint: const Vec2.zero())!;

    final target = CadDocument();
    Transaction(target, label: 'seed')
      ..putBlock(
        const BlockRecord(name: '*D1', isAnonymous: true, entityIds: []),
      )
      ..commit();

    final paste = Transaction(target, label: 'Paste');
    final placed = clip.paste(paste, insertion: const Vec2.zero());
    paste.commit();

    final dim = target.entity(placed.single)! as DimensionEntity;
    expect(dim.blockName, isNot('*D1'));
    expect(dim.blockName, startsWith('*D'));
    expect(target.blocks[dim.blockName], isNotNull);
    expect(target.blocks[dim.blockName]!.isAnonymous, isTrue);
  });

  test('paste as block wraps the clip in one insert', () {
    final source = CadDocument();
    final drawn = Transaction(source, label: 'draw')
      ..add(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)))
      ..add(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(0, 6)))
      ..commit();
    final clip = DrawingClip.extract(
      source,
      drawn.change.added,
      basePoint: const Vec2.zero(),
    )!;

    final target = CadDocument();
    final paste = Transaction(target, label: 'Paste as Block');
    final placed = clip.paste(
      paste,
      insertion: const Vec2(2, 3),
      asBlock: true,
    );
    paste.commit();

    expect(placed, hasLength(1));
    final insert = target.entity(placed.single)! as InsertEntity;
    expect(insert.position, const Vec2(2, 3));
    expect(insert.blockName, startsWith(r'A$C'));
    final block = target.blocks[insert.blockName]!;
    expect(block.isAnonymous, isTrue);
    expect(block.entityIds, hasLength(2));
  });

  test('COPYCLIP lower-left is the selection extents minimum', () {
    final document = CadDocument();
    final drawn = Transaction(document, label: 'draw')
      ..add(const LineEntity(id: 0, start: Vec2(4, 1), end: Vec2(10, 7)))
      ..commit();
    expect(
      DrawingClip.lowerLeftOf(document, drawn.change.added),
      const Vec2(4, 1),
    );
  });
}
