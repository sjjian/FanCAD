@Tags(['native'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

/// Guards the half of the build that CI can only exercise when LibreDWG is
/// actually present. Without these, a broken link step would look identical to
/// a deliberate backend-less build.
void main() {
  late NativeDrawingBackend backend;
  late DrawingImporter importer;

  setUpAll(() {
    backend = NativeDrawingBackend();
    importer = DrawingImporter(backend: backend);
  });

  test('the shim loads and reports a version', () {
    expect(backend.capabilities.description, isNotEmpty);
    expect(
      backend.capabilities.description,
      isNot(contains('unavailable')),
      reason: 'The code asset did not load',
    );
  });

  test('the DWG backend is linked', () {
    expect(
      backend.capabilities.readDwg,
      isTrue,
      reason:
          'Built without LibreDWG: ${backend.capabilities.description}. '
          'Set FANCAD_LIBREDWG_ROOT and rebuild.',
    );
    expect(backend.capabilities.writeDwg, isTrue);
  });

  test('an empty drawing saves as DWG and reopens', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-empty');
    addTearDown(() => directory.deleteSync(recursive: true));

    final dwgPath = '${directory.path}/Drawing1.dwg';
    final outcome = await importer.save(dwgPath, CadDocument());
    expect(outcome.path, dwgPath);
    expect(File(dwgPath).existsSync(), isTrue);
    expect(File(dwgPath).lengthSync(), greaterThan(0));

    final opened = await importer.open(dwgPath);
    expect(opened.document.modelSpaceBlockName.toUpperCase(), '*MODEL_SPACE');
  });

  test('a line survives FCB to DWG and back', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-libredwg');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument();
    final session = DocumentSession(id: 'native', document: document);
    session.edit('line', (transaction) {
      transaction.add(
        LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(100, 40)),
      );
    });

    final dwgPath = '${directory.path}/line.dwg';
    await importer.save(dwgPath, document);
    expect(File(dwgPath).existsSync(), isTrue);
    expect(File(dwgPath).lengthSync(), greaterThan(0));

    final opened = await importer.open(dwgPath);
    final lines = opened.document.entities.whereType<LineEntity>().toList();
    expect(lines, isNotEmpty);
    expect(lines.first.end.x, closeTo(100, 1e-6));
    expect(lines.first.end.y, closeTo(40, 1e-6));
  });

  test('the native FCB version matches the Dart reader', () {
    // A mismatch here means the C and Dart sides of the format have drifted,
    // which would surface as corrupt geometry rather than a clean error.
    expect(backend.nativeFcbVersion, fcbVersion);
  });

  test('DWG import keeps layout names and paper size', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-layout');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument();
    document.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        paperWidth: 420,
        paperHeight: 297,
      ),
    );
    document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      blockName: '*Paper_Space',
    );

    final dwgPath = '${directory.path}/sheet.dwg';
    await importer.save(dwgPath, document);

    final opened = await importer.open(dwgPath);
    final paperBlock = opened.document.blocks.keys.cast<String>().firstWhere(
      (name) => name.toUpperCase() == '*PAPER_SPACE',
      orElse: () => '',
    );
    expect(
      paperBlock,
      isNotEmpty,
      reason: 'the paper block should survive FCB to DWG',
    );
    expect(
      opened.document.entitiesOf(paperBlock).whereType<LineEntity>(),
      isNotEmpty,
      reason: 'paper-space geometry should stay out of model space',
    );
    expect(
      opened.document.layouts.where((item) => !item.isModelSpace),
      isNotEmpty,
      reason: 'a paper LAYOUT should survive DWG',
    );
    expect(
      opened.document.layouts.where((item) => item.name == 'A3'),
      isNotEmpty,
      reason: 'LAYOUT tab names should survive FCB to DWG',
    );
    expect(
      opened.document.layouts
          .where((item) => item.name == 'A3')
          .single
          .paperWidth,
      closeTo(420, 1e-3),
    );
    expect(
      opened.document.layouts
          .where((item) => item.name == 'A3')
          .single
          .paperHeight,
      closeTo(297, 1e-3),
    );
  });

  test(
    'BLOCK/ENDBLK stay out of the entity list and base points survive',
    () async {
      final directory = Directory.systemTemp.createTempSync('fancad-block');
      addTearDown(() => directory.deleteSync(recursive: true));

      final document = CadDocument()
        ..putBlock(const BlockRecord(name: 'TICK', basePoint: Vec2(100, 50)))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2(100, 50), end: Vec2(101, 50)),
          blockName: 'TICK',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'TICK',
            position: Vec2(10, 20),
            scale: Vec2(2, 3),
            rotation: 0.25,
          ),
        );

      final dwgPath = '${directory.path}/tick.dwg';
      await importer.save(dwgPath, document);

      final opened = await importer.open(dwgPath);
      expect(
        opened.document.entities.whereType<UnknownEntity>().map(
          (entity) => entity.originalType,
        ),
        isNot(anyOf(contains('BLOCK'), contains('ENDBLK'))),
      );
      expect(opened.document.blocks['TICK']?.basePoint, const Vec2(100, 50));
      expect(
        opened.document.entities.whereType<InsertEntity>(),
        isNotEmpty,
        reason: 'INSERT should land after the block is closed',
      );
      expect(
        opened.document.entitiesOf('TICK').whereType<LineEntity>(),
        isNotEmpty,
        reason: 'block members should stay inside the named block',
      );
      final insert = opened.document.entities.whereType<InsertEntity>().single;
      expect(insert.position.x, closeTo(10, 1e-6));
      expect(insert.position.y, closeTo(20, 1e-6));
      expect(insert.scale.x, closeTo(2, 1e-6));
      expect(insert.scale.y, closeTo(3, 1e-6));
      expect(insert.rotation, closeTo(0.25, 1e-6));
    },
  );

  test('INSERT still lands when the block name is not ASCII', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-cjk-insert');
    addTearDown(() => directory.deleteSync(recursive: true));

    const names = ['面板信息', 'GB12618-90-4×铆厚5_5', 'A\$C73572138'];
    final document = CadDocument();
    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      document
        ..putBlock(BlockRecord(name: name))
        ..addEntity(
          LineEntity(
            id: i * 2 + 1,
            start: Vec2(i.toDouble(), 0),
            end: Vec2(i.toDouble(), 1),
          ),
          blockName: name,
        )
        ..addEntity(
          InsertEntity(
            id: i * 2 + 2,
            blockName: name,
            position: Vec2(100.0 * (i + 1), 200.0 * (i + 1)),
            scale: const Vec2(1, 1),
          ),
        );
    }

    final dwgPath = '${directory.path}/cjk.dwg';
    await importer.save(dwgPath, document);

    final opened = await importer.open(dwgPath);
    final inserts = opened.document.entities.whereType<InsertEntity>().toList();
    expect(
      inserts,
      hasLength(3),
      reason: 'CJK / × / \$ block names must not drop INSERT',
    );
    final xs = inserts.map((item) => item.position.x).toList()..sort();
    expect(xs[0], closeTo(100, 1e-6));
    expect(xs[1], closeTo(200, 1e-6));
    expect(xs[2], closeTo(300, 1e-6));
    expect(
      opened.document.blocks.keys.toSet(),
      containsAll(names),
      reason: 'CJK / × block names must decode from MIF, not stay as \\U+XXXX',
    );
    expect(inserts.map((item) => item.blockName).toSet(), containsAll(names));
    expect(
      opened.document.blocks.values.where(
        (block) => opened.document
            .entitiesOf(block.name)
            .whereType<LineEntity>()
            .isNotEmpty,
      ),
      hasLength(3),
    );
  });

  test('an INSERT with attributes still points at its own block', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-attrib');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument()
      ..putBlock(BlockRecord(name: 'TITLE'))
      ..addEntity(
        LineEntity(id: 1, start: const Vec2(0, 0), end: const Vec2(10, 0)),
        blockName: 'TITLE',
      )
      ..addEntity(
        InsertEntity(
          id: 2,
          blockName: 'TITLE',
          position: const Vec2(500, 300),
          scale: const Vec2(1, 1),
          attributes: const {'SHEET': '01'},
        ),
      );

    final dwgPath = '${directory.path}/attrib.dwg';
    await importer.save(dwgPath, document);

    final opened = (await importer.open(dwgPath)).document;
    final insert = opened.entities.whereType<InsertEntity>().single;
    expect(
      insert.blockName,
      'TITLE',
      reason: 'Attributes must not repoint the INSERT at its own container',
    );
    expect(
      insert.computeBounds(blocks: opened).isFinite,
      isTrue,
      reason: 'A self-referencing INSERT gives unbounded extents',
    );
  });

  test('block members come back inside their block', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-owned');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument()..putBlock(BlockRecord(name: 'PART'));
    for (var i = 0; i < 6; i++) {
      document.addEntity(
        LineEntity(
          id: i + 1,
          start: Vec2(i.toDouble(), 0),
          end: Vec2(i.toDouble(), 5),
        ),
        blockName: 'PART',
      );
    }
    document.addEntity(
      InsertEntity(
        id: 99,
        blockName: 'PART',
        position: const Vec2(40, 40),
        scale: const Vec2(1, 1),
      ),
    );

    final dwgPath = '${directory.path}/owned.dwg';
    await importer.save(dwgPath, document);

    final opened = (await importer.open(dwgPath)).document;
    expect(
      opened.entitiesOf('PART').whereType<LineEntity>(),
      hasLength(6),
      reason: 'Members need entmode 0 so the file carries their ownerhandle',
    );
    expect(
      opened.entities.where(
        (e) => opened.ownerOf(e.id) == opened.modelSpaceBlockName,
      ),
      hasLength(1),
      reason: 'Only the INSERT belongs to model space',
    );
  });

  test('justified text and a lowercase ATTDEF tag survive', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-justify');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument()
      ..addEntity(
        TextEntity(
          id: 1,
          position: const Vec2(1200, 800),
          content: 'centered',
          height: 2.5,
          hAlign: TextHAlign.center,
          vAlign: TextVAlign.middle,
        ),
      )
      ..addEntity(
        AttdefEntity(
          id: 2,
          position: const Vec2(1300, 900),
          tag: 'Sheet no',
          prompt: 'Sheet',
          defaultValue: '01',
          height: 2.5,
        ),
      );

    final dwgPath = '${directory.path}/justify.dwg';
    await importer.save(dwgPath, document);

    final opened = (await importer.open(dwgPath)).document;
    final text = opened.entities.whereType<TextEntity>().single;
    expect(
      text.position.x,
      closeTo(1200, 1e-6),
      reason:
          'Justified text paints from alignment_pt, which r2000 omits '
          'when it equals ins_pt',
    );
    expect(text.position.y, closeTo(800, 1e-6));
    final attdef = opened.entities.whereType<AttdefEntity>().single;
    expect(
      attdef.tag,
      'Sheet no',
      reason: 'A tag with a space or lowercase must not drop the ATTDEF',
    );
    expect(attdef.position.x, closeTo(1300, 1e-6));
  });

  test('a polyline keeps vertex stride and bulge', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-pline');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument()
      ..addEntity(
        PolylineEntity(
          id: 0,
          vertices: Float64List.fromList([0, 0, 0.5, 10, 0, 0, 10, 10, 0]),
          closed: true,
        ),
      );

    final dwgPath = '${directory.path}/arc.dwg';
    await importer.save(dwgPath, document);

    final opened = await importer.open(dwgPath);
    final pline = opened.document.entities.whereType<PolylineEntity>().single;
    expect(pline.closed, isTrue);
    expect(pline.vertices.length, 9);
    expect(pline.vertices[0], closeTo(0, 1e-6));
    expect(pline.vertices[1], closeTo(0, 1e-6));
    expect(pline.vertices[2], closeTo(0.5, 1e-6));
    expect(pline.vertices[3], closeTo(10, 1e-6));
    expect(pline.vertices[4], closeTo(0, 1e-6));
    expect(pline.vertices[6], closeTo(10, 1e-6));
    expect(pline.vertices[7], closeTo(10, 1e-6));
  });

  test('a rotated ellipse keeps its major axis', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-ellipse');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument()
      ..addEntity(
        const EllipseEntity(
          id: 0,
          center: Vec2(5, 5),
          majorAxis: Vec2(0, 10),
          ratio: 0.4,
        ),
      );

    final dwgPath = '${directory.path}/ellipse.dwg';
    await importer.save(dwgPath, document);

    final opened = await importer.open(dwgPath);
    final ellipse = opened.document.entities.whereType<EllipseEntity>().single;
    expect(ellipse.center.x, closeTo(5, 1e-6));
    expect(ellipse.center.y, closeTo(5, 1e-6));
    expect(ellipse.majorAxis.x, closeTo(0, 1e-6));
    expect(ellipse.majorAxis.y, closeTo(10, 1e-6));
    expect(ellipse.ratio, closeTo(0.4, 1e-6));
  });

  test('a second paper tab does not share the first sheet block', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-sheets');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument();
    document.addLayout(
      const Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1),
    );
    document.addLayout(
      const Layout(name: 'A4', blockName: '*Paper_Space0', tabOrder: 2),
    );
    document.addEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
      blockName: '*Paper_Space',
    );
    document.addEntity(
      const LineEntity(id: 2, start: Vec2(0, 1), end: Vec2(20, 1)),
      blockName: '*Paper_Space0',
    );

    final dwgPath = '${directory.path}/sheets.dwg';
    await importer.save(dwgPath, document);

    final opened = await importer.open(dwgPath);
    String blockNamed(String want) =>
        opened.document.blocks.keys.cast<String>().firstWhere(
          (name) => name.toUpperCase() == want.toUpperCase(),
          orElse: () => '',
        );

    final first = blockNamed('*Paper_Space');
    final second = blockNamed('*Paper_Space0');
    expect(first, isNotEmpty);
    expect(second, isNotEmpty);
    expect(first.toUpperCase(), isNot(second.toUpperCase()));
    expect(
      opened.document.entitiesOf(first).whereType<LineEntity>(),
      isNotEmpty,
    );
    expect(
      opened.document.entitiesOf(second).whereType<LineEntity>(),
      isNotEmpty,
      reason: 'the second sheet must keep its own geometry',
    );
    expect(
      opened.document.entitiesOf(first).whereType<LineEntity>().first.end.x,
      closeTo(10, 1e-6),
    );
    expect(
      opened.document.entitiesOf(second).whereType<LineEntity>().first.end.x,
      closeTo(20, 1e-6),
    );
    expect(
      opened.document.layouts.where((item) => item.name == 'A3'),
      isNotEmpty,
    );
    expect(
      opened.document.layouts.where((item) => item.name == 'A4'),
      isNotEmpty,
      reason: 'extra paper tabs need their own LAYOUT object',
    );
  });

  test('circle, arc, point and text survive FCB to DWG', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-prims');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument()
      ..addEntity(const CircleEntity(id: 1, center: Vec2(3, 4), radius: 5))
      ..addEntity(
        const ArcEntity(
          id: 2,
          center: Vec2.zero(),
          radius: 10,
          startAngle: 0,
          endAngle: math.pi / 2,
        ),
      )
      ..addEntity(const PointEntity(id: 3, position: Vec2(7, 8)))
      ..addEntity(
        const TextEntity(
          id: 4,
          position: Vec2(1, 2),
          content: 'Hello',
          height: 3,
          rotation: 0.5,
          widthFactor: 0.8,
          obliqueAngle: 0.1,
        ),
      );

    final dwgPath = '${directory.path}/prims.dwg';
    await importer.save(dwgPath, document);

    final opened = await importer.open(dwgPath);
    final circle = opened.document.entities.whereType<CircleEntity>().single;
    expect(circle.center.x, closeTo(3, 1e-6));
    expect(circle.center.y, closeTo(4, 1e-6));
    expect(circle.radius, closeTo(5, 1e-6));

    final arc = opened.document.entities.whereType<ArcEntity>().single;
    expect(arc.radius, closeTo(10, 1e-6));
    expect(arc.startAngle, closeTo(0, 1e-6));
    expect(arc.endAngle, closeTo(math.pi / 2, 1e-6));

    final point = opened.document.entities.whereType<PointEntity>().single;
    expect(point.position.x, closeTo(7, 1e-6));
    expect(point.position.y, closeTo(8, 1e-6));

    final text = opened.document.entities.whereType<TextEntity>().single;
    expect(text.content, 'Hello');
    expect(text.height, closeTo(3, 1e-6));
    expect(text.rotation, closeTo(0.5, 1e-6));
    expect(text.widthFactor, closeTo(0.8, 1e-6));
    expect(text.obliqueAngle, closeTo(0.1, 1e-6));
  });

  test('a custom layer name survives FCB to DWG', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-layer');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument()
      ..putLayer(const LayerDef(name: 'WALLS'))
      ..addEntity(
        const LineEntity(
          id: 0,
          start: Vec2.zero(),
          end: Vec2(10, 0),
          props: EntityProps(layer: 'WALLS'),
        ),
      );

    final dwgPath = '${directory.path}/walls.dwg';
    await importer.save(dwgPath, document);

    final opened = await importer.open(dwgPath);
    expect(opened.document.layers.containsKey('WALLS'), isTrue);
    expect(
      opened.document.entities.whereType<LineEntity>().single.props.layer,
      'WALLS',
    );
  });

  test('a CJK layer name stays bound after DWG save', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-cjk-layer');
    addTearDown(() => directory.deleteSync(recursive: true));

    const layerName = '标注线';
    final document = CadDocument()
      ..putLayer(const LayerDef(name: layerName))
      ..addEntity(
        const LineEntity(
          id: 0,
          start: Vec2.zero(),
          end: Vec2(10, 0),
          props: EntityProps(layer: layerName),
        ),
      );

    final dwgPath = '${directory.path}/cjk-layer.dwg';
    await importer.save(dwgPath, document);

    final opened = await importer.open(dwgPath);
    expect(opened.document.layers.containsKey(layerName), isTrue);
    expect(
      opened.document.layers.keys.any((name) => name.contains(r'\U+')),
      isFalse,
      reason: 'LAYER table must decode MIF back to Unicode',
    );
    expect(
      opened.document.entities.whereType<LineEntity>().single.props.layer,
      layerName,
      reason: 'the entity must stay on 标注线, not fall onto 0',
    );
  });

  test('saving over an existing DWG replaces the previous drawing', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-overwrite');
    addTearDown(() => directory.deleteSync(recursive: true));

    final dwgPath = '${directory.path}/sheet.dwg';
    await importer.save(
      dwgPath,
      CadDocument()..addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(100, 0)),
      ),
    );
    await importer.save(
      dwgPath,
      CadDocument()..addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(1, 2)),
      ),
    );

    expect(File('$dwgPath.bak').existsSync(), isFalse);
    final opened = await importer.open(dwgPath);
    final line = opened.document.entities.whereType<LineEntity>().single;
    expect(line.end.x, closeTo(1, 1e-6));
    expect(line.end.y, closeTo(2, 1e-6));
  });

  test('every FanCAD entity kind survives FCB to DWG', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-kinds');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument()
      ..putBlock(const BlockRecord(name: 'TITLE', basePoint: Vec2.zero()))
      ..addEntity(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)))
      ..addEntity(
        HatchEntity(
          id: 1,
          loops: [
            HatchLoop(
              vertices: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10]),
            ),
          ],
        ),
      )
      ..addEntity(
        const MTextEntity(id: 2, position: Vec2(1, 1), content: 'multi'),
      )
      ..addEntity(
        SplineEntity(
          id: 3,
          controlPoints: Float64List.fromList([0, 0, 2, 4, 8, 4, 10, 0]),
        ),
      )
      ..addEntity(
        const DimensionEntity(
          id: 4,
          measurement: 10,
          definitionPoints: [Vec2.zero(), Vec2(10, 0)],
        ),
      )
      ..addEntity(
        LeaderEntity(
          id: 5,
          vertices: Float64List.fromList([0, 0, 5, 5, 10, 5]),
        ),
      )
      ..addEntity(
        const SolidEntity(
          id: 6,
          corners: [Vec2.zero(), Vec2(4, 0), Vec2(4, 3), Vec2(0, 3)],
        ),
      )
      ..addEntity(
        const RayEntity(id: 7, origin: Vec2(1, 2), direction: Vec2(1, 0)),
      )
      ..addEntity(
        const XLineEntity(id: 8, origin: Vec2(3, 4), direction: Vec2(0, 1)),
      )
      ..addEntity(
        const ImageEntity(
          id: 9,
          reference: 'pic.png',
          origin: Vec2(2, 3),
          uVector: Vec2(8, 0),
          vVector: Vec2(0, 6),
        ),
      )
      ..addEntity(
        AttdefEntity(
          id: 10,
          position: const Vec2(0, 0),
          tag: 'DWGNO',
          prompt: 'Drawing number',
          defaultValue: 'A-01',
        ),
        blockName: 'TITLE',
      )
      ..addEntity(
        const AttribEntity(
          id: 11,
          position: Vec2(6, 6),
          tag: 'REV',
          value: 'B',
        ),
      )
      ..addEntity(
        MLeaderEntity(
          id: 12,
          vertices: Float64List.fromList([0, 8, 4, 8]),
          content: 'callout',
          textPosition: const Vec2(5, 8),
          textHeight: 2.5,
        ),
      )
      ..addEntity(
        UnknownEntity(
          id: 13,
          originalType: 'REGION',
          strokes: Float64List.fromList([0, 0, 2, 0, 2, 2]),
          strokeCounts: const [3],
        ),
      );

    final dwgPath = '${directory.path}/kinds.dwg';
    await importer.save(dwgPath, document);

    final opened = await importer.open(dwgPath);
    final entities = opened.document.entities;
    expect(entities.whereType<LineEntity>(), hasLength(1));
    expect(entities.whereType<HatchEntity>(), isNotEmpty);
    expect(entities.whereType<MTextEntity>(), isNotEmpty);
    expect(entities.whereType<SplineEntity>(), isNotEmpty);
    expect(entities.whereType<DimensionEntity>(), isNotEmpty);
    expect(entities.whereType<LeaderEntity>(), isNotEmpty);
    expect(entities.whereType<SolidEntity>(), isNotEmpty);
    expect(entities.whereType<RayEntity>(), isNotEmpty);
    expect(entities.whereType<XLineEntity>(), isNotEmpty);
    expect(entities.whereType<ImageEntity>(), isNotEmpty);

    final hatch = entities.whereType<HatchEntity>().single;
    expect(hatch.loops, isNotEmpty);
    expect(hatch.loops.first.pointCount, 4);

    expect(
      entities.whereType<MTextEntity>().any((item) => item.content == 'multi'),
      isTrue,
    );

    final spline = entities.whereType<SplineEntity>().single;
    expect(spline.controlPointCount, greaterThanOrEqualTo(2));

    final dim = entities.whereType<DimensionEntity>().single;
    expect(dim.measurement, closeTo(10, 1e-3));

    final solid = entities.whereType<SolidEntity>().single;
    expect(solid.corners, hasLength(4));
    expect(solid.corners.first.x, closeTo(0, 1e-6));
    expect(solid.corners[2].x, closeTo(4, 1e-6));

    final ray = entities.whereType<RayEntity>().single;
    expect(ray.origin.x, closeTo(1, 1e-6));
    expect(ray.direction.x, closeTo(1, 1e-6));

    final xline = entities.whereType<XLineEntity>().single;
    expect(xline.origin.y, closeTo(4, 1e-6));

    final image = entities.whereType<ImageEntity>().single;
    expect(image.origin.x, closeTo(2, 1e-6));
    expect(image.origin.y, closeTo(3, 1e-6));
    expect(image.uVector.x, closeTo(8, 1e-3));
    expect(image.vVector.y, closeTo(6, 1e-3));

    final title = opened.document.blocks.keys.cast<String>().firstWhere(
      (name) => name == 'TITLE',
      orElse: () => '',
    );
    expect(title, isNotEmpty);
    expect(
      opened.document.entitiesOf(title).whereType<AttdefEntity>(),
      isNotEmpty,
    );

    expect(
      entities.whereType<TextEntity>().any((item) => item.content == 'B'),
      isTrue,
      reason: 'a standalone ATTRIB is stored as TEXT',
    );
    expect(
      entities.whereType<MLeaderEntity>(),
      isEmpty,
      reason: 'R2004 writes MULTILEADER as LEADER+MTEXT',
    );
    expect(
      entities.whereType<MTextEntity>().any(
        (item) => item.content.contains('callout'),
      ),
      isTrue,
      reason: 'the callout note must remain visible',
    );
    expect(
      entities.whereType<LeaderEntity>().length,
      greaterThanOrEqualTo(2),
      reason: 'the exploded MULTILEADER keeps a LEADER stem',
    );
    expect(
      entities.whereType<UnknownEntity>(),
      isNotEmpty,
      reason: 'REGION must round-trip as UNKNOWN, not LWPOLYLINE',
    );
  });

  test('a *D dimension is not rewritten as a ray from the origin', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-dimblock');
    addTearDown(() => directory.deleteSync(recursive: true));

    final document = CadDocument()
      ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
      ..addEntity(
        const LineEntity(id: 1, start: Vec2(50, 50), end: Vec2(60, 50)),
        blockName: '*D1',
      )
      ..addEntity(
        const DimensionEntity(
          id: 2,
          blockName: '*D1',
          measurement: 2300,
          textPosition: Vec2(1752, 3703),
          overrideText: 'AW',
        ),
      );

    final dwgPath = '${directory.path}/dim.dwg';
    await importer.save(dwgPath, document);

    final opened = await importer.open(dwgPath);
    final dim = opened.document.entities.whereType<DimensionEntity>().single;
    expect(dim.blockName.toUpperCase(), '*D1');
    expect(dim.overrideText, 'AW');
    for (final point in dim.definitionPoints) {
      expect(
        point.x.abs() + point.y.abs(),
        greaterThan(1),
        reason: 'definition points must not be origin-to-measurement rays',
      );
    }
    final dimBlock = opened.document.blocks.keys.cast<String>().firstWhere(
      (name) => name.toUpperCase() == '*D1',
      orElse: () => '',
    );
    expect(dimBlock, isNotEmpty);
    expect(
      opened.document.entitiesOf(dimBlock).whereType<LineEntity>(),
      isNotEmpty,
    );
  });

  test('a *D TEXT that kept MTEXT font codes still paints the note', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-dimcjk');
    addTearDown(() => directory.deleteSync(recursive: true));

    const raw = r'{\F宋体|c134;型材1}';
    final document = CadDocument()
      ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
      ..addEntity(
        const TextEntity(
          id: 1,
          position: Vec2(5, 3),
          content: raw,
          height: 2.5,
        ),
        blockName: '*D1',
      )
      ..addEntity(
        const DimensionEntity(
          id: 2,
          blockName: '*D1',
          measurement: 10,
          overrideText: raw,
          definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 3)],
          textPosition: Vec2(5, 3),
        ),
      );

    final dwgPath = '${directory.path}/note.dwg';
    await importer.save(dwgPath, document);
    final opened = (await importer.open(dwgPath)).document;
    final dim = opened.entities.whereType<DimensionEntity>().single;
    final sink = PolylineSink();
    dim.emit(opened.emitContext(tolerance: 0.1), sink);
    final painted = sink.texts.map((item) => item.text).join();
    expect(painted, contains('型材1'));
    expect(
      painted.contains(r'\F') || painted.contains('{'),
      isFalse,
      reason: 'a write-down to TEXT must still hide the font switch',
    );
  });

  test('CJK notes are stored as GBK in an R2004 DWG, not UTF-8', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-gbk');
    addTearDown(() => directory.deleteSync(recursive: true));

    const note = '型材1';
    final document = CadDocument()
      ..addEntity(
        const MTextEntity(
          id: 1,
          position: Vec2(0, 0),
          content: note,
          height: 2.5,
        ),
      );

    final dwgPath = '${directory.path}/cjk.dwg';
    await importer.save(dwgPath, document);
    final opened = (await importer.open(dwgPath)).document;
    expect(
      opened.entities.whereType<MTextEntity>().single.content,
      contains(note),
    );

    final bytes = File(dwgPath).readAsBytesSync();
    const utf8Note = [0xE5, 0x9E, 0x8B, 0xE6, 0x9D, 0x90, 0x31];
    const gbkNote = [0xD0, 0xCD, 0xB2, 0xC4, 0x31];
    expect(
      _containsBytes(bytes, utf8Note),
      isFalse,
      reason: 'raw UTF-8 in a pre-2007 TV string is what GstarCAD shows as ?',
    );
    expect(
      _containsBytes(bytes, gbkNote) ||
          _containsBytes(bytes, r'\U+578B'.codeUnits) ||
          opened.entities.whereType<MTextEntity>().single.content.contains(note),
      isTrue,
      reason: 'GstarCAD reads R2004 TV bytes as GBK; UTF-8 becomes ?',
    );
  });

  test('CJK TEXT on an empty-font style stays GBK, not question marks', () async {
    final directory = Directory.systemTemp.createTempSync('fancad-stylecjk');
    addTearDown(() => directory.deleteSync(recursive: true));

    const note = '绘图';
    final document = CadDocument()
      ..putTextStyle(
        const TextStyleDef(name: '样式 1', fontFamily: '', bigFontFamily: ''),
      )
      ..addEntity(
        const TextEntity(
          id: 1,
          position: Vec2(0, 0),
          content: note,
          styleName: '样式 1',
        ),
      );

    final dwgPath = '${directory.path}/label.dwg';
    await importer.save(dwgPath, document);
    final opened = (await importer.open(dwgPath)).document;
    expect(opened.entities.whereType<TextEntity>().single.content, note);
    expect(opened.textStyles['样式 1']!.fontFamily, isNot('txt'));

    final dumped = const DxfWriter().writeString(opened);
    const utf8Note = [0xE7, 0xBB, 0x98, 0xE5, 0x9B, 0xBE];
    expect(
      dumped.contains(note),
      isTrue,
      reason: 'FanCAD DXF is UTF-8; the note must still round-trip',
    );
    expect(_containsBytes(dumped.codeUnits, utf8Note), isTrue);
  });

  test('a missing file fails cleanly rather than crashing', () {
    expect(
      () => backend.readToFcb('/definitely/not-a-drawing.dwg'),
      throwsA(isA<ImportException>()),
    );
  });
}

bool _containsBytes(List<int> haystack, List<int> needle) {
  if (needle.isEmpty || haystack.length < needle.length) return false;
  final limit = haystack.length - needle.length;
  for (var i = 0; i <= limit; i++) {
    var matched = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}
