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

  test('a pasted named insert does not translate its members', () {
    final source = CadDocument();
    final build = Transaction(source, label: 'build');
    build.putBlock(const BlockRecord(name: 'MARK', entityIds: []));
    build.add(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(2, 0)),
      blockName: 'MARK',
    );
    final insertId = build.add(
      const InsertEntity(id: 0, blockName: 'MARK', position: Vec2(5, 5)),
    );
    build.commit();
    final clip = DrawingClip.extract(source, [
      insertId,
    ], basePoint: const Vec2(5, 5))!;

    final target = CadDocument();
    final paste = Transaction(target, label: 'Paste');
    final placed = clip.paste(paste, insertion: const Vec2(100, 40));
    paste.commit();

    final insert = target.entity(placed.single)! as InsertEntity;
    expect(insert.position, const Vec2(100, 40));
    expect(insert.blockName, 'MARK');
    final member = target.entitiesOf('MARK').whereType<LineEntity>().single;
    expect(member.start, Vec2.zero());
    expect(member.end, const Vec2(2, 0));
  });

  test('a pasted named insert keeps nested *D in the block', () {
    // 角码1-style: the ticks live in *D, the measured edges live in MARK.
    // Shifting only *D by the paste delta leaves the ticks behind.
    final source = CadDocument();
    final build = Transaction(source, label: 'build');
    build.putBlock(
      const BlockRecord(name: '*D1', isAnonymous: true, entityIds: []),
    );
    build.add(
      const LineEntity(id: 0, start: Vec2(100, 0), end: Vec2(110, 0)),
      blockName: '*D1',
    );
    build.putBlock(const BlockRecord(name: 'MARK', entityIds: []));
    build.add(
      const LineEntity(id: 0, start: Vec2(100, 0), end: Vec2(110, 0)),
      blockName: 'MARK',
    );
    build.add(
      const DimensionEntity(
        id: 0,
        blockName: '*D1',
        definitionPoints: [Vec2(100, 0), Vec2(110, 0), Vec2(105, 5)],
        textPosition: Vec2(105, 5),
        measurement: 10,
      ),
      blockName: 'MARK',
    );
    final insertId = build.add(
      const InsertEntity(id: 0, blockName: 'MARK', position: Vec2(5, 5)),
    );
    build.commit();
    final clip = DrawingClip.extract(source, [
      insertId,
    ], basePoint: const Vec2.zero())!;

    final target = CadDocument();
    final paste = Transaction(target, label: 'Paste');
    final placed = clip.paste(paste, insertion: const Vec2(20, 10));
    paste.commit();

    final insert = target.entity(placed.single)! as InsertEntity;
    expect(insert.position, const Vec2(25, 15));
    final member = target.entitiesOf('MARK').whereType<LineEntity>().single;
    expect(member.start, const Vec2(100, 0));
    final dim = target.entitiesOf('MARK').whereType<DimensionEntity>().single;
    final tick = target.entitiesOf(dim.blockName).whereType<LineEntity>().single;
    expect(tick.start, const Vec2(100, 0));
    expect(tick.end, const Vec2(110, 0));
  });

  test('a pasted *U insert does not translate its members', () {
    final source = CadDocument();
    final build = Transaction(source, label: 'build');
    build.putBlock(
      const BlockRecord(name: '*U1', isAnonymous: true, entityIds: []),
    );
    build.add(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      blockName: '*U1',
    );
    final insertId = build.add(
      const InsertEntity(id: 0, blockName: '*U1', position: Vec2(5, 5)),
    );
    build.commit();
    final clip = DrawingClip.extract(source, [
      insertId,
    ], basePoint: const Vec2(5, 5))!;

    final target = CadDocument();
    final paste = Transaction(target, label: 'Paste');
    final placed = clip.paste(paste, insertion: const Vec2(100, 40));
    paste.commit();

    final insert = target.entity(placed.single)! as InsertEntity;
    expect(insert.position, const Vec2(100, 40));
    expect(insert.blockName, startsWith('*U'));
    final member = target
        .entitiesOf(insert.blockName)
        .whereType<LineEntity>()
        .single;
    expect(member.start, Vec2.zero());
    expect(member.end, const Vec2(10, 0));
    expect(target.boundsOfEntity(insert), const Bounds2(100, 40, 110, 40));
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

  test('a second paste that imports a new layer still draws the first paste', () {
    DrawingClip clipWithLayer(String layer, Vec2 start) {
      final source = CadDocument()
        ..putLayer(LayerDef(name: layer, color: const CadColor.indexed(1)));
      final drawn = Transaction(source, label: 'draw')
        ..add(
          LineEntity(
            id: 0,
            props: EntityProps(layer: layer),
            start: start,
            end: start + const Vec2(4, 0),
          ),
        )
        ..commit();
      return DrawingClip.extract(
        source,
        drawn.change.added,
        basePoint: start,
      )!;
    }

    final target = CadDocument();
    final first = Transaction(target, label: 'Paste');
    final firstIds = clipWithLayer('WALL', Vec2.zero()).paste(
      first,
      insertion: Vec2.zero(),
    );
    first.commit();
    expect(target.queryVisible(const Bounds2(-1, -1, 5, 1)), firstIds);

    final second = Transaction(target, label: 'Paste');
    final secondIds = clipWithLayer('ROOF', const Vec2(10, 0)).paste(
      second,
      insertion: const Vec2(10, 0),
    );
    second.commit();

    expect(target.activeEntities, hasLength(2));
    expect(
      target.queryVisible(const Bounds2(-1, -1, 15, 1)),
      unorderedEquals([...firstIds, ...secondIds]),
    );
  });

  test('a pasted *D note keeps height and rotation after the translation', () {
    const raw = r'{\F宋体|c134;型材1}';
    final source = CadDocument();
    final build = Transaction(source, label: 'build');
    build.putBlock(
      const BlockRecord(name: '*D1', isAnonymous: true, entityIds: []),
    );
    build.add(
      const MTextEntity(
        id: 0,
        position: Vec2(5, 3),
        content: raw,
        height: 40,
        rotation: 1.5707963267948966,
        attachment: 5,
      ),
      blockName: '*D1',
    );
    final dimId = build.add(
      const DimensionEntity(
        id: 0,
        blockName: '*D1',
        definitionPoints: [Vec2.zero(), Vec2(0, -10)],
        textPosition: Vec2(5, 3),
        measurement: 10,
        overrideText: raw,
        dimensionType: 161,
      ),
    );
    build.commit();
    final clip = DrawingClip.extract(source, [
      dimId,
    ], basePoint: const Vec2.zero())!;

    final target = CadDocument();
    final paste = Transaction(target, label: 'Paste');
    final placed = clip.paste(paste, insertion: const Vec2(100, 40));
    paste.commit();

    final dim = target.entity(placed.single)! as DimensionEntity;
    expect(dim.blockName, isNotEmpty);
    expect(dim.textPosition, const Vec2(105, 43));
    final note = target
        .entitiesOf(dim.blockName)
        .whereType<MTextEntity>()
        .single;
    expect(note.position, const Vec2(105, 43));
    expect(note.height, 40);
    expect(note.rotation, closeTo(1.5707963267948966, 1e-12));

    final sink = PolylineSink();
    dim.emit(target.emitContext(tolerance: 0.1), sink);
    expect(sink.texts, isNotEmpty);
    expect(sink.texts.every((item) => item.height == 40), isTrue);
    expect(
      sink.texts.every(
        (item) => (item.rotation - 1.5707963267948966).abs() < 1e-9,
      ),
      isTrue,
    );
    expect(sink.texts.every((item) => !item.text.contains(r'\F')), isTrue);
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
