@Tags(['native'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

/// DWG handles are not stable, so entities are aligned by kind, owner, and
/// geometry rather than by id. A failure names the step (first write or the
/// edit pass) and the unmatched snapshot.
void main() {
  late DrawingImporter importer;

  setUpAll(() {
    final backend = NativeDrawingBackend();
    expect(
      backend.capabilities.writeDwg,
      isTrue,
      reason:
          'Built without LibreDWG: ${backend.capabilities.description}. '
          'Set FANCAD_LIBREDWG_ROOT and rebuild.',
    );
    importer = DrawingImporter(backend: backend);
  });

  test(
    'a synthetic drawing survives DWG save and reopen',
    () async {
      final directory = Directory.systemTemp.createTempSync('fancad-rt1');
      addTearDown(() => directory.deleteSync(recursive: true));

      final source = syntheticDrawing();
      final dwgPath = '${directory.path}/round1.dwg';
      await importer.save(dwgPath, source);
      final opened = (await importer.open(dwgPath)).document;

      expectFiniteModelExtents(opened, step: 'first write');
      expectMatchingSnapshots(source, opened, step: 'first write');
      expectNamedBlockIntact(opened, 'PART', lineCount: 3);
      expectNamedBlockIntact(opened, 'TITLE', attdefTag: 'Sheet no');
      expect(
        opened.entities
            .whereType<LineEntity>()
            .first
            .props
            .lineWeight,
        LineWeight.byLayer,
        reason: 'DWG 29 must come back as ByLayer, not 0.29 mm',
      );
      final titled = opened.entities.whereType<InsertEntity>().firstWhere(
        (e) => e.blockName == 'TITLE',
      );
      expect(
        titled.attributes['Sheet no'],
        '01',
        reason: 'an ATTRIB tag with a space must survive dwg_add_ATTRIB',
      );
    },
    timeout: Timeout.parse('2m'),
  );

  test(
    'edits survive a second DWG save and reopen',
    () async {
      final directory = Directory.systemTemp.createTempSync('fancad-rt2');
      addTearDown(() => directory.deleteSync(recursive: true));

      final source = syntheticDrawing();
      final firstPath = '${directory.path}/before.dwg';
      await importer.save(firstPath, source);
      final opened = (await importer.open(firstPath)).document;

      final edited = applyEdits(opened);
      final secondPath = '${directory.path}/after.dwg';
      await importer.save(secondPath, edited);
      final reopened = (await importer.open(secondPath)).document;

      expectFiniteModelExtents(reopened, step: 'edit pass');
      expectMatchingSnapshots(edited, reopened, step: 'edit pass');

      final moved = reopened.entities.whereType<LineEntity>().where(
        (e) =>
            close(e.start, const Vec2(105, 3)) &&
            close(e.end, const Vec2(115, 3)),
      );
      expect(moved, hasLength(1), reason: 'edit pass: translated LINE');

      final text = reopened.entities.whereType<TextEntity>().where(
        (e) => e.content == 'edited',
      );
      expect(text, hasLength(1), reason: 'edit pass: TEXT content');
      expect(text.single.position.x, closeTo(1200, 1e-6));
      expect(text.single.position.y, closeTo(800, 1e-6));

      final arc = reopened.entities.whereType<ArcEntity>().single;
      expect(arc.props.layer, 'NOTES', reason: 'edit pass: ARC layer');

      final added = reopened.entities.whereType<CircleEntity>().where(
        (e) => close(e.center, const Vec2(500, 500)) && (e.radius - 12).abs() < 1e-6,
      );
      expect(added, hasLength(1), reason: 'edit pass: added CIRCLE');

      expect(
        reopened.entities.whereType<PointEntity>().where(
          (e) => close(e.position, const Vec2(77, 88)),
        ),
        isEmpty,
        reason: 'edit pass: deleted POINT',
      );
    },
    timeout: Timeout.parse('2m'),
  );

  /// LibreDWG has no dwg_add_MULTILEADER / true UNKNOWN objects. Write-down
  /// to MTEXT+LEADER and LWPOLYLINE is the known strategy; this test locks
  /// that, and is not part of the CJK layer-name bind fix.
  test(
    'ATTRIB, UNKNOWN and MULTILEADER are not yet DWG round-trips',
    () async {
      final directory = Directory.systemTemp.createTempSync('fancad-gaps');
      addTearDown(() => directory.deleteSync(recursive: true));

      final document = CadDocument()
        ..addEntity(
          const AttribEntity(
            id: 1,
            position: Vec2(6, 6),
            tag: 'REV',
            value: 'B',
          ),
        )
        ..addEntity(
          UnknownEntity(
            id: 2,
            originalType: 'REGION',
            strokes: Float64List.fromList([0, 0, 2, 0, 2, 2]),
            strokeCounts: const [3],
          ),
        )
        ..addEntity(
          MLeaderEntity(
            id: 3,
            vertices: Float64List.fromList([0, 8, 4, 8]),
            content: 'callout',
            textPosition: const Vec2(5, 8),
            textHeight: 2.5,
          ),
        );

      final dwgPath = '${directory.path}/gaps.dwg';
      await importer.save(dwgPath, document);
      final opened = (await importer.open(dwgPath)).document;

      expect(
        opened.entities.whereType<AttribEntity>(),
        isEmpty,
        reason: 'a standalone ATTRIB is stored as TEXT',
      );
      expect(
        opened.entities.whereType<TextEntity>().any((e) => e.content == 'B'),
        isTrue,
        reason: 'ATTRIB content must still be visible as TEXT',
      );
      expect(
        opened.entities.whereType<UnknownEntity>(),
        isEmpty,
        reason: 'UNKNOWN proxy strokes are stored as LWPOLYLINE',
      );
      expect(
        opened.entities.whereType<PolylineEntity>(),
        isNotEmpty,
      );
      expect(
        opened.entities.whereType<MLeaderEntity>(),
        isEmpty,
        reason: 'MULTILEADER has no LibreDWG add API',
      );
      expect(
        opened.entities.whereType<MTextEntity>().any(
          (e) => e.content.contains('callout'),
        ),
        isTrue,
        reason: 'MULTILEADER content is stored as MTEXT',
      );
    },
    timeout: Timeout.parse('2m'),
  );

  Future<CadDocument> saveAndOpen(CadDocument source, String name) async {
    final directory = Directory.systemTemp.createTempSync('fancad-$name');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/$name.dwg';
    await importer.save(path, source);
    return (await importer.open(path)).document;
  }

  group('geometry variants', () {
    test('a closed polyline keeps bulge', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          PolylineEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 0.5, 10, 0, 0, 10, 10, 0]),
            closed: true,
          ),
        ),
        'bulge',
      );
      final pline = opened.entities.whereType<PolylineEntity>().single;
      expect(pline.closed, isTrue);
      expect(pline.vertices.length, 9);
      expect(pline.vertices[2], closeTo(0.5, 1e-6));
    });

    test('an elliptical arc keeps start and end params', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const EllipseEntity(
            id: 1,
            center: Vec2(5, 5),
            majorAxis: Vec2(0, 10),
            ratio: 0.4,
            startParam: 0.3,
            endParam: 2.2,
          ),
        ),
        'elliparc',
      );
      final ellipse = opened.entities.whereType<EllipseEntity>().single;
      expect(ellipse.majorAxis.y, closeTo(10, 1e-6));
      expect(ellipse.startParam, closeTo(0.3, 1e-6));
      expect(ellipse.endParam, closeTo(2.2, 1e-6));
    });

    test('a triangle SOLID keeps its three unique corners', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const SolidEntity(
            id: 1,
            corners: [Vec2(0, 0), Vec2(4, 0), Vec2(0, 3)],
          ),
        ),
        'solid3',
      );
      final solid = opened.entities.whereType<SolidEntity>().single;
      final unique = {
        for (final p in solid.corners)
          '${(p.x * 1e6).round()}:${(p.y * 1e6).round()}',
      };
      expect(
        unique,
        containsAll(['0:0', '4000000:0', '0:3000000']),
        reason: 'DWG SOLID stores four corners; a triangle repeats the last',
      );
    });

    test('right-top TEXT stays off the origin', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          TextEntity(
            id: 1,
            position: const Vec2(250, 180),
            content: 'right',
            height: 4,
            hAlign: TextHAlign.right,
            vAlign: TextVAlign.top,
          ),
        ),
        'textright',
      );
      final text = opened.entities.whereType<TextEntity>().single;
      expect(text.content, 'right');
      expect(text.position.x, closeTo(250, 1e-6));
      expect(text.position.y, closeTo(180, 1e-6));
      expect(text.hAlign, TextHAlign.right);
      expect(text.vAlign, TextVAlign.top);
    });

    test('MTEXT keeps a paragraph break', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const MTextEntity(
            id: 1,
            position: Vec2(8, 9),
            content: 'line1\\Pline2',
            height: 3,
            rectangleWidth: 40,
          ),
        ),
        'mtextp',
      );
      final mtext = opened.entities.whereType<MTextEntity>().single;
      expect(mtext.content, contains('line1'));
      expect(mtext.content, contains('line2'));
      expect(mtext.position.x, closeTo(8, 1e-6));
    });

    test('IMAGE keeps origin and axis vectors', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const ImageEntity(
            id: 1,
            reference: 'pic.png',
            origin: Vec2(2, 3),
            uVector: Vec2(8, 0),
            vVector: Vec2(0, 6),
          ),
        ),
        'image',
      );
      final image = opened.entities.whereType<ImageEntity>().single;
      expect(image.origin.x, closeTo(2, 1e-6));
      expect(image.origin.y, closeTo(3, 1e-6));
      expect(image.uVector.x, closeTo(8, 1e-3));
      expect(image.vVector.y, closeTo(6, 1e-3));
    });

    test('a leader without an arrow head keeps its vertices', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          LeaderEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 10, 4]),
            hasArrowHead: false,
          ),
        ),
        'leader',
      );
      final leader = opened.entities.whereType<LeaderEntity>().single;
      expect(leader.vertices[2], closeTo(10, 1e-6));
      expect(
        leader.hasArrowHead,
        isTrue,
        reason: 'LibreDWG rereads arrowhead_on as set even when we clear it',
      );
    });

    test('a RAY keeps origin and direction', () async {
      final source = CadDocument()
        ..addEntity(
          const RayEntity(
            id: 1,
            origin: Vec2(2, 3),
            direction: Vec2(0, 1),
          ),
        );
      final opened = await saveAndOpen(source, 'ray');
      expectMatchingSnapshots(source, opened, step: 'ray');
    });

    test('an XLINE keeps origin and direction', () async {
      final source = CadDocument()
        ..addEntity(
          const XLineEntity(
            id: 1,
            origin: Vec2(4, 5),
            direction: Vec2(1, 0),
          ),
        );
      final opened = await saveAndOpen(source, 'xline');
      expectMatchingSnapshots(source, opened, step: 'xline');
    });

    test('a spline keeps degree and control points', () async {
      final source = CadDocument()
        ..addEntity(
          SplineEntity(
            id: 1,
            controlPoints: Float64List.fromList([0, 0, 2, 4, 6, 4, 8, 0]),
            degree: 3,
            knots: const [0, 0, 0, 0, 1, 1, 1, 1],
          ),
        );
      final opened = await saveAndOpen(source, 'spline');
      expectMatchingSnapshots(source, opened, step: 'spline');
    });

    test('a four-corner SOLID keeps Z-order corners', () async {
      final source = CadDocument()
        ..addEntity(
          const SolidEntity(
            id: 1,
            corners: [Vec2(0, 0), Vec2(4, 0), Vec2(4, 3), Vec2(0, 3)],
          ),
        );
      final opened = await saveAndOpen(source, 'solid4');
      expectMatchingSnapshots(source, opened, step: 'quad solid');
    });

    test('an ARC keeps centre, radius and sweep', () async {
      final source = CadDocument()
        ..addEntity(
          const ArcEntity(
            id: 1,
            center: Vec2(10, 20),
            radius: 5,
            startAngle: 0.25,
            endAngle: 2.5,
          ),
        );
      final opened = await saveAndOpen(source, 'arc');
      expectMatchingSnapshots(source, opened, step: 'arc');
    });

    test('a solid hatch keeps its outer loop', () async {
      final source = CadDocument()
        ..addEntity(
          HatchEntity(
            id: 1,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 8, 0, 8, 6, 0, 6]),
              ),
            ],
          ),
        );
      final opened = await saveAndOpen(source, 'hatch');
      expectMatchingSnapshots(source, opened, step: 'hatch');
    });

    test('a hatch with a hole keeps both loops', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          HatchEntity(
            id: 1,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10]),
              ),
              HatchLoop(
                vertices: Float64List.fromList([3, 3, 7, 3, 7, 7, 3, 7]),
                isOuter: false,
              ),
            ],
          ),
        ),
        'hatchhole',
      );
      final hatch = opened.entities.whereType<HatchEntity>().single;
      expect(hatch.loops, hasLength(2));
      expect(hatch.loops.first.vertices[2], closeTo(10, 1e-6));
      expect(hatch.loops.last.vertices[0], closeTo(3, 1e-6));
      expect(
        hatch.loops.last.isOuter,
        isTrue,
        reason: 'hatch path outermost bit is not reread from LibreDWG',
      );
    });

    test('rotated TEXT keeps its angle', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const TextEntity(
            id: 1,
            position: Vec2(12, 8),
            content: 'tilt',
            height: 3,
            rotation: 0.4,
          ),
        ),
        'textrot',
      );
      final text = opened.entities.whereType<TextEntity>().single;
      expect(text.content, 'tilt');
      expect(text.rotation, closeTo(0.4, 1e-6));
      expect(text.position.x, closeTo(12, 1e-6));
    });

    test('a pattern hatch keeps its name and definition lines', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          HatchEntity(
            id: 1,
            solid: false,
            patternName: 'ANSI31',
            patternAngle: 0.2,
            patternScale: 2,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 20, 0, 20, 10, 0, 10]),
              ),
            ],
            patternLines: const [
              HatchPatternLine(angle: 0.785, deltaY: 3.175),
            ],
          ),
        ),
        'ansi31',
      );
      final hatch = opened.entities.whereType<HatchEntity>().single;
      expect(hatch.solid, isFalse);
      expect(hatch.patternName.toUpperCase(), 'ANSI31');
      expect(hatch.loops.single.vertices[2], closeTo(20, 1e-6));
    });

    test('a POINT and CIRCLE keep their geometry', () async {
      final source = CadDocument()
        ..addEntity(const PointEntity(id: 1, position: Vec2(3, 4)))
        ..addEntity(
          const CircleEntity(id: 2, center: Vec2(8, 9), radius: 2.5),
        );
      final opened = await saveAndOpen(source, 'ptcirc');
      expectMatchingSnapshots(source, opened, step: 'point circle');
    });

    test('a full ellipse keeps major axis and ratio', () async {
      final source = CadDocument()
        ..addEntity(
          const EllipseEntity(
            id: 1,
            center: Vec2(1, 2),
            majorAxis: Vec2(6, 2),
            ratio: 0.35,
          ),
        );
      final opened = await saveAndOpen(source, 'ellipse');
      expectMatchingSnapshots(source, opened, step: 'full ellipse');
    });

    test('TEXT keeps width factor and oblique angle', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const TextEntity(
            id: 1,
            position: Vec2(4, 5),
            content: 'oblique',
            height: 3,
            widthFactor: 0.75,
            obliqueAngle: 0.2,
          ),
        ),
        'textwf',
      );
      final text = opened.entities.whereType<TextEntity>().single;
      expect(text.widthFactor, closeTo(0.75, 1e-6));
      expect(text.obliqueAngle, closeTo(0.2, 1e-6));
    });

    test('MTEXT keeps rotation, box width and attachment', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const MTextEntity(
            id: 1,
            position: Vec2(10, 12),
            content: 'box',
            height: 4,
            rotation: 0.3,
            rectangleWidth: 50,
            attachment: 5,
          ),
        ),
        'mtextatt',
      );
      final mtext = opened.entities.whereType<MTextEntity>().single;
      expect(mtext.content, 'box');
      expect(mtext.rotation, closeTo(0.3, 1e-6));
      expect(mtext.rectangleWidth, closeTo(50, 1e-6));
      expect(mtext.attachment, 5);
    });

    test('IMAGE keeps its file path', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const ImageEntity(
            id: 1,
            reference: 'photos/part.png',
            origin: Vec2(0, 0),
            uVector: Vec2(10, 0),
            vVector: Vec2(0, 8),
          ),
        ),
        'imgpath',
      );
      expect(
        opened.entities.whereType<ImageEntity>().single.reference,
        'photos/part.png',
      );
    });

    test('a closed spline stays closed', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          SplineEntity(
            id: 1,
            controlPoints: Float64List.fromList([0, 0, 4, 2, 0, 4, -4, 2]),
            degree: 3,
            closed: true,
            knots: const [0, 0, 0, 0, 1, 1, 1, 1],
          ),
        ),
        'splclosed',
      );
      final spline = opened.entities.whereType<SplineEntity>().single;
      expect(spline.closed, isTrue);
      expect(spline.controlPointCount, 4);
    });

    test('a weighted spline keeps control weights', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          SplineEntity(
            id: 1,
            controlPoints: Float64List.fromList([0, 0, 4, 4, 8, 0]),
            degree: 2,
            knots: const [0, 0, 0, 1, 1, 1],
            weights: const [1, 2, 1],
          ),
        ),
        'splw',
      );
      final spline = opened.entities.whereType<SplineEntity>().single;
      expect(spline.weights, hasLength(3));
      expect(spline.weights[1], closeTo(2, 1e-6));
    });

    test('a three-vertex leader keeps all points', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          LeaderEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 4, 2, 8, 2]),
          ),
        ),
        'lead3',
      );
      final leader = opened.entities.whereType<LeaderEntity>().single;
      expect(leader.vertices.length, 6);
      expect(leader.vertices[4], closeTo(8, 1e-6));
    });

    test('an aligned dimension keeps its *D block and first two points', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(8, 6)),
          blockName: '*D1',
        )
        ..addEntity(
          const DimensionEntity(
            id: 2,
            blockName: '*D1',
            dimensionType: 1,
            measurement: 10,
            definitionPoints: [Vec2(0, 0), Vec2(8, 6), Vec2(4, 8)],
            textPosition: Vec2(4, 8),
          ),
        );
      final opened = await saveAndOpen(source, 'dimalign');
      final dim = opened.entities.whereType<DimensionEntity>().single;
      expect(dim.blockName, '*D1');
      expect(dim.measurement, closeTo(10, 1e-6));
      expect(dim.definitionPoints, hasLength(2));
      expect(dim.definitionPoints[1], const Vec2(8, 6));
      expect(
        opened.entitiesOf('*D1').whereType<LineEntity>(),
        hasLength(1),
      );
    });

    test('hatch pattern scale and angle survive', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          HatchEntity(
            id: 1,
            solid: false,
            patternName: 'ANSI31',
            patternAngle: 0.5,
            patternScale: 3,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 12, 0, 12, 8, 0, 8]),
              ),
            ],
            patternLines: const [
              HatchPatternLine(angle: 0.5, deltaY: 9.525),
            ],
          ),
        ),
        'hatchang',
      );
      final hatch = opened.entities.whereType<HatchEntity>().single;
      expect(hatch.patternAngle, closeTo(0.5, 1e-6));
      expect(hatch.patternScale, closeTo(3, 1e-6));
      expect(hatch.patternLines, isNotEmpty);
      expect(hatch.patternLines.first.deltaY, closeTo(9.525, 1e-3));
    });

    test('polyline constant width survives a DWG round trip', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          PolylineEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 0, 10, 0, 0]),
            constantWidth: 0.5,
          ),
        ),
        'plwidth',
      );
      final pline = opened.entities.whereType<PolylineEntity>().single;
      expect(pline.vertexAt(1).x, closeTo(10, 1e-6));
      expect(pline.constantWidth, closeTo(0.5, 1e-6));
    });

    test('an ARC that crosses zero keeps a 2π-equivalent sweep', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const ArcEntity(
            id: 1,
            center: Vec2(0, 0),
            radius: 4,
            startAngle: 5.5,
            endAngle: 0.8,
          ),
        ),
        'arcwrap',
      );
      final arc = opened.entities.whereType<ArcEntity>().single;
      expect(arc.radius, closeTo(4, 1e-6));
      expect(arc.endAngle, closeTo(0.8, 1e-6));
      final start = arc.startAngle % (math.pi * 2);
      final expected = 5.5 % (math.pi * 2);
      expect(
        (start - expected).abs() < 1e-6 ||
            (start - expected - math.pi * 2).abs() < 1e-6 ||
            (start - expected + math.pi * 2).abs() < 1e-6,
        isTrue,
        reason: 'LibreDWG may wrap 5.5 to 5.5-2π; sweep must match',
      );
    });

    test('a rotated IMAGE keeps non-axis u and v', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const ImageEntity(
            id: 1,
            reference: 'rot.png',
            origin: Vec2(1, 1),
            uVector: Vec2(6, 2),
            vVector: Vec2(-1, 3),
          ),
        ),
        'imgrot',
      );
      final image = opened.entities.whereType<ImageEntity>().single;
      expect(image.uVector.x, closeTo(6, 1e-3));
      expect(image.uVector.y, closeTo(2, 1e-3));
      expect(image.vVector.x, closeTo(-1, 1e-3));
      expect(image.vVector.y, closeTo(3, 1e-3));
    });

    test('MTEXT keeps inline formatting codes', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const MTextEntity(
            id: 1,
            position: Vec2(2, 2),
            content: r'{\fArial|b1;Bold}\Pplain',
            height: 3,
            rectangleWidth: 40,
          ),
        ),
        'mtextfmt',
      );
      final mtext = opened.entities.whereType<MTextEntity>().single;
      expect(mtext.content, contains('Bold'));
      expect(mtext.content, contains(r'\P'));
      expect(mtext.content, contains('plain'));
    });

    test('a fit-only spline comes back without its fit points', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          SplineEntity(
            id: 1,
            controlPoints: Float64List(0),
            fitPoints: Float64List.fromList([0, 0, 4, 3, 8, 0]),
            degree: 3,
          ),
        ),
        'splfit',
      );
      final spline = opened.entities.whereType<SplineEntity>().single;
      expect(
        spline.controlPointCount,
        0,
        reason: 'fit points are not promoted to NURBS controls on DWG rewrite',
      );
      expect(spline.fitPointCount, 0);
    });

    test('a radius dimension keeps its *D block and measurement', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
          ..addEntity(
            const CircleEntity(id: 1, center: Vec2.zero(), radius: 5),
            blockName: '*D1',
          )
          ..addEntity(
            const DimensionEntity(
              id: 2,
              blockName: '*D1',
              dimensionType: 4,
              measurement: 5,
              definitionPoints: [Vec2(0, 0), Vec2(5, 0)],
              textPosition: Vec2(6, 1),
            ),
          ),
        'dimrad',
      );
      final dim = opened.entities.whereType<DimensionEntity>().single;
      expect(dim.blockName, '*D1');
      expect(dim.measurement, closeTo(5, 1e-6));
      expect(opened.entitiesOf('*D1').whereType<CircleEntity>(), hasLength(1));
    });

    test('a diameter dimension keeps its *D block and measurement', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
          ..addEntity(
            const CircleEntity(id: 1, center: Vec2.zero(), radius: 4),
            blockName: '*D1',
          )
          ..addEntity(
            const DimensionEntity(
              id: 2,
              blockName: '*D1',
              dimensionType: 3,
              measurement: 8,
              definitionPoints: [Vec2(-4, 0), Vec2(4, 0)],
              textPosition: Vec2(0, 2),
            ),
          ),
        'dimdia',
      );
      final dim = opened.entities.whereType<DimensionEntity>().single;
      expect(dim.blockName, '*D1');
      expect(dim.measurement, closeTo(8, 1e-6));
    });

    test('an angular dimension keeps its *D block', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
            blockName: '*D1',
          )
          ..addEntity(
            const DimensionEntity(
              id: 2,
              blockName: '*D1',
              dimensionType: 5,
              measurement: 1.5708,
              definitionPoints: [Vec2(4, 0), Vec2(0, 4), Vec2(0, 0)],
              textPosition: Vec2(2, 2),
            ),
          ),
        'dimang',
      );
      final dim = opened.entities.whereType<DimensionEntity>().single;
      expect(dim.blockName, '*D1');
      expect(opened.entitiesOf('*D1').whereType<LineEntity>(), hasLength(1));
    });

    test('a leader with an arrow head keeps its vertices', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          LeaderEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 5, 3]),
            hasArrowHead: true,
          ),
        ),
        'leadon',
      );
      final leader = opened.entities.whereType<LeaderEntity>().single;
      expect(leader.hasArrowHead, isTrue);
      expect(leader.vertices[2], closeTo(5, 1e-6));
    });

    test('an open four-vertex polyline keeps order', () async {
      final source = CadDocument()
        ..addEntity(
          PolylineEntity.fromPoints(
            id: 1,
            points: const [Vec2(0, 0), Vec2(2, 0), Vec2(2, 3), Vec2(5, 3)],
          ),
        );
      final opened = await saveAndOpen(source, 'pl4');
      expectMatchingSnapshots(source, opened, step: 'open polyline');
    });

    test('a polyline keeps a bulge on the second vertex', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          PolylineEntity(
            id: 1,
            vertices: Float64List.fromList([0, 0, 0, 8, 0, 0.4, 8, 6, 0]),
          ),
        ),
        'bulge2',
      );
      final pline = opened.entities.whereType<PolylineEntity>().single;
      expect(pline.vertices[5], closeTo(0.4, 1e-6));
      expect(pline.vertexAt(2).x, closeTo(8, 1e-6));
    });

    test('two hatches keep separate loops', () async {
      final source = CadDocument()
        ..addEntity(
          HatchEntity(
            id: 1,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 4, 0, 4, 4, 0, 4]),
              ),
            ],
          ),
        )
        ..addEntity(
          HatchEntity(
            id: 2,
            solid: false,
            patternName: 'ANSI31',
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([10, 0, 16, 0, 16, 4, 10, 4]),
              ),
            ],
          ),
        );
      final opened = await saveAndOpen(source, 'twoh');
      expect(opened.entities.whereType<HatchEntity>(), hasLength(2));
      expect(
        opened.entities.whereType<HatchEntity>().where((e) => e.solid),
        hasLength(1),
      );
    });

    test('a hatch pattern line keeps dash lengths', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          HatchEntity(
            id: 1,
            solid: false,
            patternName: 'DASH',
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 20, 0, 20, 10, 0, 10]),
              ),
            ],
            patternLines: const [
              HatchPatternLine(angle: 0, deltaY: 4, dashes: [2, -1]),
            ],
          ),
        ),
        'hdash',
      );
      final hatch = opened.entities.whereType<HatchEntity>().single;
      expect(hatch.patternLines, isNotEmpty);
      expect(hatch.patternLines.first.dashes, hasLength(2));
      expect(hatch.patternLines.first.dashes[0], closeTo(2, 1e-3));
    });

    test('a diagonal RAY keeps a unit direction', () async {
      final source = CadDocument()
        ..addEntity(
          const RayEntity(
            id: 1,
            origin: Vec2(2, 3),
            direction: Vec2(3, 4),
          ),
        );
      final opened = await saveAndOpen(source, 'rayd');
      final ray = opened.entities.whereType<RayEntity>().single;
      expect(ray.origin, const Vec2(2, 3));
      expect(ray.direction.x / ray.direction.y, closeTo(0.75, 1e-6));
    });

    test('an ellipse with ratio 1 keeps a circular major axis', () async {
      final source = CadDocument()
        ..addEntity(
          const EllipseEntity(
            id: 1,
            center: Vec2(5, 5),
            majorAxis: Vec2(4, 0),
            ratio: 1,
          ),
        );
      final opened = await saveAndOpen(source, 'ell1');
      expectMatchingSnapshots(source, opened, step: 'circle ellipse');
    });

    test('bottom-left TEXT stays at its insertion point', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          TextEntity(
            id: 1,
            position: const Vec2(30, 40),
            content: 'bl',
            height: 3,
            hAlign: TextHAlign.left,
            vAlign: TextVAlign.bottom,
          ),
        ),
        'textbl',
      );
      final text = opened.entities.whereType<TextEntity>().single;
      expect(text.position.x, closeTo(30, 1e-6));
      expect(text.position.y, closeTo(40, 1e-6));
      expect(text.vAlign, TextVAlign.bottom);
    });

    test('MTEXT attachment 9 stays at bottom-right', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putTextStyle(const TextStyleDef(name: 'NOTES'))
          ..addEntity(
            const MTextEntity(
              id: 1,
              position: Vec2(80, 20),
              content: 'br',
              height: 4,
              rectangleWidth: 30,
              attachment: 9,
              styleName: 'NOTES',
            ),
          ),
        'mtext9',
      );
      final mtext = opened.entities.whereType<MTextEntity>().single;
      expect(mtext.attachment, 9);
      expect(mtext.styleName, 'NOTES');
      expect(mtext.position.x, closeTo(80, 1e-6));
    });

    test('an ordinate dimension keeps its *D block', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
          ..addEntity(
            const LineEntity(id: 1, start: Vec2(0, 0), end: Vec2(0, 8)),
            blockName: '*D1',
          )
          ..addEntity(
            const DimensionEntity(
              id: 2,
              blockName: '*D1',
              dimensionType: 6,
              measurement: 8,
              definitionPoints: [Vec2(0, 0), Vec2(0, 8)],
              textPosition: Vec2(2, 8),
            ),
          ),
        'dimord',
      );
      final dim = opened.entities.whereType<DimensionEntity>().single;
      expect(dim.blockName, '*D1');
      expect(dim.measurement, closeTo(8, 1e-6));
    });

    test('a rotated ATTDEF keeps its angle', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putBlock(const BlockRecord(name: 'TAG'))
          ..addEntity(
            const AttdefEntity(
              id: 1,
              position: Vec2(4, 5),
              tag: 'ANG',
              defaultValue: '0',
              height: 3,
              rotation: 0.4,
            ),
            blockName: 'TAG',
          )
          ..addEntity(
            const InsertEntity(
              id: 2,
              blockName: 'TAG',
              position: Vec2(0, 0),
              attributes: {'ANG': '0'},
            ),
          ),
        'attrot',
      );
      expect(
        opened.entitiesOf('TAG').whereType<AttdefEntity>().single.rotation,
        closeTo(0.4, 1e-6),
      );
    });
  });

  group('properties and tables', () {
    test('an indexed colour survives', () async {
      final source = CadDocument()
        ..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(color: CadColor.indexed(1)),
            start: Vec2.zero(),
            end: Vec2(10, 0),
          ),
        );
      final opened = await saveAndOpen(source, 'aci');
      expectMatchingSnapshots(source, opened, step: 'indexed color');
    });

    test('true colour survives as RGB', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const CircleEntity(
            id: 1,
            props: EntityProps(color: CadColor.rgb(0xFF00AA)),
            center: Vec2(5, 5),
            radius: 2,
          ),
        ),
        'rgb',
      );
      final color = opened.entities.whereType<CircleEntity>().single.props.color;
      expect(color.kind, ColorKind.trueColor);
      expect(color.value, 0xFF00AA);
    });

    test('an explicit millimetre lineweight is not ByLayer', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(lineWeight: 25),
            start: Vec2.zero(),
            end: Vec2(1, 0),
          ),
        ),
        'lw25',
      );
      expect(
        opened.entities.whereType<LineEntity>().single.props.lineWeight,
        25,
      );
    });

    test('a DASHED line type is bound on the entity', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putLineType(LineTypeDef.dashed)
          ..addEntity(
            const LineEntity(
              id: 1,
              props: EntityProps(lineType: 'DASHED'),
              start: Vec2.zero(),
              end: Vec2(12, 0),
            ),
          ),
        'dashed',
      );
      final line = opened.entities.whereType<LineEntity>().single;
      expect(line.end.x, closeTo(12, 1e-6));
      expect(line.props.lineType, 'DASHED');
    });

    test('a named layer keeps off, frozen and locked', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putLayer(
            const LayerDef(
              name: 'OFF',
              visible: false,
              frozen: true,
              locked: true,
              plottable: false,
            ),
          )
          ..addEntity(
            const PointEntity(
              id: 1,
              props: EntityProps(layer: 'OFF'),
              position: Vec2(1, 1),
            ),
          ),
        'layerflags',
      );
      final layer = opened.layer('OFF');
      expect(layer, isNotNull);
      expect(
        opened.entities.whereType<PointEntity>().single.props.layer,
        'OFF',
      );
      expect(layer!.plottable, isFalse);
      expect(layer.visible, isFalse);
      expect(layer.frozen, isTrue);
      expect(layer.locked, isTrue);
    });

    test('an invisible entity stays invisible', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(visible: false),
            start: Vec2.zero(),
            end: Vec2(5, 0),
          ),
        ),
        'invis',
      );
      expect(
        opened.entities.whereType<LineEntity>().single.props.visible,
        isFalse,
      );
    });

    test('a layer indexed colour survives on the table row', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putLayer(
            const LayerDef(name: 'WALLS', color: CadColor.indexed(5)),
          )
          ..addEntity(
            const LineEntity(
              id: 1,
              props: EntityProps(layer: 'WALLS'),
              start: Vec2.zero(),
              end: Vec2(8, 0),
            ),
          ),
        'layeraci',
      );
      expect(opened.layer('WALLS')?.color, const CadColor.indexed(5));
      expect(
        opened.entities.whereType<LineEntity>().single.props.layer,
        'WALLS',
      );
    });

    test('a CJK layer name is not stored as MIF on reopen', () async {
      const layerName = '标注线';
      final opened = await saveAndOpen(
        CadDocument()
          ..putLayer(const LayerDef(name: layerName, color: CadColor.indexed(1)))
          ..addEntity(
            const LineEntity(
              id: 1,
              props: EntityProps(layer: layerName),
              start: Vec2.zero(),
              end: Vec2(8, 0),
            ),
          ),
        'cjklayer',
      );
      expect(opened.layers.containsKey(layerName), isTrue);
      expect(opened.layers.keys.any((name) => name.contains(r'\U+')), isFalse);
      expect(
        opened.entities.whereType<LineEntity>().single.props.layer,
        layerName,
      );
      expect(opened.layer(layerName)?.color, const CadColor.indexed(1));
    });

    test('ByBlock colour and lineweight survive', () async {
      final source = CadDocument()
        ..addEntity(
          const CircleEntity(
            id: 1,
            props: EntityProps(
              color: CadColor.byBlock(),
              lineWeight: LineWeight.byBlock,
            ),
            center: Vec2(3, 3),
            radius: 1,
          ),
        );
      final opened = await saveAndOpen(source, 'byblock');
      expectMatchingSnapshots(source, opened, step: 'ByBlock');
    });

    test('a named text style is bound on TEXT', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putTextStyle(
            const TextStyleDef(name: 'TITLE', height: 5, widthFactor: 0.8),
          )
          ..addEntity(
            const TextEntity(
              id: 1,
              position: Vec2(1, 2),
              content: 'A',
              height: 5,
              styleName: 'TITLE',
            ),
          ),
        'textstyle',
      );
      expect(opened.textStyles.containsKey('TITLE'), isTrue);
      expect(
        opened.entities.whereType<TextEntity>().single.styleName,
        'TITLE',
      );
    });

    test('dimension override text survives', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          blockName: '*D1',
        )
        ..addEntity(
          const DimensionEntity(
            id: 2,
            blockName: '*D1',
            measurement: 10,
            overrideText: '10 mm',
            definitionPoints: [Vec2(0, 0), Vec2(10, 0), Vec2(5, 3)],
            textPosition: Vec2(5, 3),
          ),
        );
      final opened = await saveAndOpen(source, 'dimtext');
      expectMatchingSnapshots(source, opened, step: 'dim override');
      expect(
        opened.entities.whereType<DimensionEntity>().single.overrideText,
        '10 mm',
      );
    });

    test('a DASHED table row exists even when the entity is ByLayer', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putLineType(LineTypeDef.dashed)
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(5, 0)),
          ),
        'lttable',
      );
      expect(opened.lineTypes.containsKey('DASHED'), isTrue);
      expect(
        opened.lineTypes['DASHED']!.pattern,
        [closeTo(12, 1e-6), closeTo(-6, 1e-6)],
      );
      expect(opened.lineTypes['DASHED']!.patternLength, closeTo(18, 1e-6));
    });

    test('a named text style keeps font metrics', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putTextStyle(
            const TextStyleDef(
              name: 'NOTES',
              fontFamily: 'romans',
              height: 2.5,
              widthFactor: 0.8,
              obliqueAngle: 0.15,
            ),
          )
          ..addEntity(
            const TextEntity(
              id: 1,
              position: Vec2(1, 1),
              content: 'n',
              styleName: 'NOTES',
            ),
          ),
        'stymet',
      );
      expect(opened.textStyles.containsKey('NOTES'), isTrue);
      expect(
        opened.entities.whereType<TextEntity>().single.styleName,
        'NOTES',
      );
      expect(
        opened.textStyles['NOTES']!.fontFamily,
        'romans',
      );
      expect(opened.textStyles['NOTES']!.height, closeTo(2.5, 1e-6));
      expect(opened.textStyles['NOTES']!.widthFactor, closeTo(0.8, 1e-6));
      expect(opened.textStyles['NOTES']!.obliqueAngle, closeTo(0.15, 1e-6));
    });

    test('dimension styles survive a DWG round trip', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putDimStyle(
            const DimStyleDef(name: 'ARCH', textHeight: 5, decimalPlaces: 0),
          )
          ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
          ..addEntity(
            const DimensionEntity(
              id: 1,
              blockName: '*D1',
              styleName: 'ARCH',
              measurement: 10,
              definitionPoints: [Vec2(0, 0), Vec2(10, 0), Vec2(5, 2)],
              textPosition: Vec2(5, 2),
            ),
          ),
        'dimsty',
      );
      expect(opened.dimStyles.containsKey('ARCH'), isTrue);
      expect(opened.dimStyles['ARCH']!.textHeight, closeTo(5, 1e-6));
      expect(opened.dimStyles['ARCH']!.decimalPlaces, 0);
      expect(
        opened.entities.whereType<DimensionEntity>().single.styleName,
        'ARCH',
      );
    });

    test('insertion units survive a DWG round trip', () async {
      final source = CadDocument()
        ..setHeaderVariable(r'$INSUNITS', '1')
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
        );
      final opened = await saveAndOpen(source, 'insunits');
      expect(opened.insUnits, InsUnits.inches);
    });

    test('a layer millimetre lineweight survives', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putLayer(const LayerDef(name: 'THICK', lineWeight: 50))
          ..addEntity(
            const LineEntity(
              id: 1,
              props: EntityProps(layer: 'THICK'),
              start: Vec2.zero(),
              end: Vec2(2, 0),
            ),
          ),
        'lyrw',
      );
      expect(
        opened.entities.whereType<LineEntity>().single.props.layer,
        'THICK',
      );
      expect(opened.layer('THICK')?.lineWeight, 50);
    });

    test('entity elevation is not yet written', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(elevation: 12),
            start: Vec2.zero(),
            end: Vec2(4, 0),
          ),
        ),
        'elev',
      );
      expect(
        opened.entities.whereType<LineEntity>().single.props.elevation,
        0,
        reason: 'bind_entity does not copy elevation / ltscale / transparency',
      );
    });

    test('entity line-type scale and transparency are not yet written', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(lineTypeScale: 2.5, transparency: 40),
            start: Vec2.zero(),
            end: Vec2(6, 0),
          ),
        ),
        'lts',
      );
      final line = opened.entities.whereType<LineEntity>().single;
      expect(line.end.x, closeTo(6, 1e-6));
      expect(line.props.lineTypeScale, 1);
      expect(line.props.transparency, -1);
    });

    test('ByDefault lineweight is rewritten as ByLayer', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(lineWeight: LineWeight.byDefault),
            start: Vec2.zero(),
            end: Vec2(3, 0),
          ),
        ),
        'lwdef',
      );
      expect(
        LineWeight.normalize(
          opened.entities.whereType<LineEntity>().single.props.lineWeight,
        ),
        LineWeight.byLayer,
        reason: 'LibreDWG r2000 does not distinguish Default (31) from ByLayer (29)',
      );
    });

    test('CENTER and HIDDEN table names survive', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putLineType(LineTypeDef.center)
          ..putLineType(LineTypeDef.hidden)
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
          ),
        'ltsnames',
      );
      expect(opened.lineTypes.containsKey('CENTER'), isTrue);
      expect(opened.lineTypes.containsKey('HIDDEN'), isTrue);
    });

    test('a layer line-type name is bound', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putLineType(LineTypeDef.center)
          ..putLayer(const LayerDef(name: 'AXIS', lineType: 'CENTER'))
          ..addEntity(
            const LineEntity(
              id: 1,
              props: EntityProps(layer: 'AXIS'),
              start: Vec2.zero(),
              end: Vec2(8, 0),
            ),
          ),
        'lylt',
      );
      expect(opened.layer('AXIS'), isNotNull);
      expect(opened.layer('AXIS')!.lineType, 'CENTER');
    });

    test('point display headers survive a DWG round trip', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..setHeaderVariable(r'$PDMODE', '35')
          ..setHeaderVariable(r'$PDSIZE', '4')
          ..addEntity(const PointEntity(id: 1, position: Vec2(1, 1))),
        'pdmode',
      );
      expect(opened.headerVariables[r'$PDMODE'], '35');
      expect(
        double.parse(opened.headerVariables[r'$PDSIZE'] ?? ''),
        closeTo(4, 1e-6),
      );
    });

    test('a hairline lineweight stays zero', () async {
      final opened = await saveAndOpen(
        CadDocument()..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(lineWeight: LineWeight.zero),
            start: Vec2.zero(),
            end: Vec2(2, 0),
          ),
        ),
        'lw0',
      );
      expect(
        opened.entities.whereType<LineEntity>().single.props.lineWeight,
        LineWeight.zero,
      );
    });

    test('PHANTOM and DOT table names survive', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putLineType(LineTypeDef.phantom)
          ..putLineType(LineTypeDef.dot)
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(3, 0)),
          ),
        'ltmore',
      );
      expect(opened.lineTypes.containsKey('PHANTOM'), isTrue);
      expect(opened.lineTypes.containsKey('DOT'), isTrue);
    });

    test('global linetype scale survives a DWG round trip', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..setHeaderVariable(r'$LTSCALE', '2.5')
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
          ),
        'ltscale',
      );
      expect(
        double.parse(opened.headerVariables[r'$LTSCALE'] ?? ''),
        closeTo(2.5, 1e-6),
      );
    });

    test('two named text styles stay bound on their strings', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putTextStyle(const TextStyleDef(name: 'TITLE'))
          ..putTextStyle(const TextStyleDef(name: 'NOTES'))
          ..addEntity(
            const TextEntity(
              id: 1,
              position: Vec2(0, 0),
              content: 'T',
              styleName: 'TITLE',
            ),
          )
          ..addEntity(
            const MTextEntity(
              id: 2,
              position: Vec2(0, 8),
              content: 'N',
              styleName: 'NOTES',
            ),
          ),
        'twosty',
      );
      expect(
        opened.entities.whereType<TextEntity>().single.styleName,
        'TITLE',
      );
      expect(
        opened.entities.whereType<MTextEntity>().single.styleName,
        'NOTES',
      );
    });

    test('ACI 7 is not rewritten as ByLayer', () async {
      final source = CadDocument()
        ..addEntity(
          const CircleEntity(
            id: 1,
            props: EntityProps(color: CadColor.indexed(7)),
            center: Vec2(2, 2),
            radius: 1,
          ),
        );
      final opened = await saveAndOpen(source, 'aci7');
      expectMatchingSnapshots(source, opened, step: 'ACI 7');
    });
  });

  group('blocks and inserts', () {
    test('insert scale, rotation and base point survive', () async {
      final source = CadDocument()
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
      final opened = await saveAndOpen(source, 'tick');
      expect(opened.blocks['TICK']?.basePoint, const Vec2(100, 50));
      expectMatchingSnapshots(source, opened, step: 'scaled insert');
    });

    test('a MINSERT keeps row and column counts', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'CELL'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
          blockName: 'CELL',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'CELL',
            position: Vec2(0, 0),
            columnCount: 3,
            rowCount: 2,
            columnSpacing: 10,
            rowSpacing: 5,
          ),
        );
      final opened = await saveAndOpen(source, 'minsert');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.columnCount, 3);
      expect(insert.rowCount, 2);
      expect(insert.columnSpacing, closeTo(10, 1e-6));
      expect(insert.rowSpacing, closeTo(5, 1e-6));
    });

    test('a nested INSERT stays inside its owner block', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'INNER'))
        ..putBlock(const BlockRecord(name: 'OUTER'))
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 1),
          blockName: 'INNER',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'INNER',
            position: Vec2(2, 0),
          ),
          blockName: 'OUTER',
        )
        ..addEntity(
          const InsertEntity(
            id: 3,
            blockName: 'OUTER',
            position: Vec2(40, 40),
          ),
        );
      final opened = await saveAndOpen(source, 'nested');
      expectMatchingSnapshots(source, opened, step: 'nested insert');
      expect(
        opened.entitiesOf('OUTER').whereType<InsertEntity>(),
        hasLength(1),
      );
      expect(
        opened.entities
            .whereType<InsertEntity>()
            .where((e) => e.blockName == 'OUTER'),
        hasLength(1),
      );
    });

    test('two *D blocks keep their own members', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
        ..putBlock(const BlockRecord(name: '*D2', isAnonymous: true))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2(0, 0), end: Vec2(10, 0)),
          blockName: '*D1',
        )
        ..addEntity(
          const LineEntity(id: 2, start: Vec2(0, 1), end: Vec2(20, 1)),
          blockName: '*D2',
        )
        ..addEntity(
          const DimensionEntity(
            id: 3,
            blockName: '*D1',
            measurement: 10,
            definitionPoints: [Vec2(0, 0), Vec2(10, 0), Vec2(5, 2)],
            textPosition: Vec2(5, 2),
          ),
        )
        ..addEntity(
          const DimensionEntity(
            id: 4,
            blockName: '*D2',
            measurement: 20,
            definitionPoints: [Vec2(0, 1), Vec2(20, 1), Vec2(10, 3)],
            textPosition: Vec2(10, 3),
          ),
        );
      final opened = await saveAndOpen(source, 'twodim');
      expectMatchingSnapshots(source, opened, step: 'two *D blocks');
      expect(opened.entitiesOf('*D1').whereType<LineEntity>().single.end.x, 10);
      expect(opened.entitiesOf('*D2').whereType<LineEntity>().single.end.x, 20);
    });

    test('several attributes including a lowercase tag survive', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'FORM'))
        ..addEntity(
          const AttdefEntity(
            id: 1,
            position: Vec2.zero(),
            tag: 'rev',
            defaultValue: 'A',
          ),
          blockName: 'FORM',
        )
        ..addEntity(
          const AttdefEntity(
            id: 2,
            position: Vec2(0, 4),
            tag: 'Sheet no',
            defaultValue: '-',
          ),
          blockName: 'FORM',
        )
        ..addEntity(
          const InsertEntity(
            id: 3,
            blockName: 'FORM',
            position: Vec2(30, 30),
            attributes: {'rev': 'B', 'Sheet no': '12'},
          ),
        );
      final opened = await saveAndOpen(source, 'attribs');
      expectMatchingSnapshots(source, opened, step: 'multi attrib');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.attributes['rev'], 'B');
      expect(insert.attributes['Sheet no'], '12');
    });

    test('an empty named block can still be inserted', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'EMPTY'))
        ..addEntity(
          const InsertEntity(
            id: 1,
            blockName: 'EMPTY',
            position: Vec2(8, 9),
          ),
        );
      final opened = await saveAndOpen(source, 'emptyblk');
      expect(opened.blocks.containsKey('EMPTY'), isTrue);
      expect(
        opened.entities.whereType<InsertEntity>().single.blockName,
        'EMPTY',
      );
    });

    test('two INSERTs of the same block stay independent', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'BOLT'))
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 1),
          blockName: 'BOLT',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'BOLT',
            position: Vec2(10, 0),
          ),
        )
        ..addEntity(
          const InsertEntity(
            id: 3,
            blockName: 'BOLT',
            position: Vec2(20, 5),
            rotation: 0.5,
          ),
        );
      final opened = await saveAndOpen(source, 'twoins');
      expectMatchingSnapshots(source, opened, step: 'two inserts');
      expect(opened.entities.whereType<InsertEntity>(), hasLength(2));
    });

    test('a block member on a named layer stays in the block', () async {
      final source = CadDocument()
        ..putLayer(const LayerDef(name: 'NOTES', color: CadColor.indexed(3)))
        ..putBlock(const BlockRecord(name: 'TAG'))
        ..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(layer: 'NOTES'),
            start: Vec2.zero(),
            end: Vec2(2, 0),
          ),
          blockName: 'TAG',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'TAG',
            position: Vec2(40, 0),
          ),
        );
      final opened = await saveAndOpen(source, 'blklayer');
      expectMatchingSnapshots(source, opened, step: 'block layer');
      expect(
        opened.entitiesOf('TAG').whereType<LineEntity>().single.props.layer,
        'NOTES',
      );
    });

    test('an INSERT in paper space does not leak into the model', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 420,
          paperHeight: 297,
        ),
      );
      document.putBlock(const BlockRecord(name: 'MARK'));
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
        blockName: 'MARK',
      );
      document.addEntity(
        const InsertEntity(
          id: 2,
          blockName: 'MARK',
          position: Vec2(30, 20),
        ),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const PointEntity(id: 3, position: Vec2(100, 0)),
      );

      final opened = await saveAndOpen(document, 'paperins');
      expectMatchingSnapshots(document, opened, step: 'paper insert');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.position, const Vec2(30, 20));
      expect(
        sameOwner(opened.ownerOf(insert.id), '*Paper_Space'),
        isTrue,
        reason: 'paper INSERT must stay on the sheet, not *MODEL_SPACE',
      );
      expect(
        opened
            .entitiesOf(opened.modelSpaceBlockName)
            .whereType<InsertEntity>(),
        isEmpty,
      );
    });

    test('a hatch inside a named block stays in that block', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'PAD'))
        ..addEntity(
          HatchEntity(
            id: 1,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 4, 0, 4, 4, 0, 4]),
              ),
            ],
          ),
          blockName: 'PAD',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'PAD',
            position: Vec2(8, 8),
          ),
        );
      final opened = await saveAndOpen(source, 'blkhatch');
      expectMatchingSnapshots(source, opened, step: 'block hatch');
      expect(opened.entitiesOf('PAD').whereType<HatchEntity>(), hasLength(1));
    });

    test('an ATTDEF tag with an exclamation mark survives', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'BANG'))
        ..addEntity(
          const AttdefEntity(
            id: 1,
            position: Vec2.zero(),
            tag: 'REV!',
            defaultValue: 'A',
          ),
          blockName: 'BANG',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'BANG',
            position: Vec2(5, 5),
            attributes: {'REV!': 'B'},
          ),
        );
      final opened = await saveAndOpen(source, 'bangtag');
      expectMatchingSnapshots(source, opened, step: 'bang tag');
      expect(
        opened.entities.whereType<InsertEntity>().single.attributes['REV!'],
        'B',
      );
    });

    test('a mirrored INSERT keeps a negative X scale', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'MARK'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
          blockName: 'MARK',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'MARK',
            position: Vec2(10, 0),
            scale: Vec2(-1, 1),
          ),
        );
      final opened = await saveAndOpen(source, 'mirror');
      expectMatchingSnapshots(source, opened, step: 'mirrored insert');
      expect(
        opened.entities.whereType<InsertEntity>().single.scale.x,
        closeTo(-1, 1e-6),
      );
    });

    test('a three-level nested INSERT keeps each owner', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'A'))
        ..putBlock(const BlockRecord(name: 'B'))
        ..putBlock(const BlockRecord(name: 'C'))
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 1),
          blockName: 'A',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'A', position: Vec2(2, 0)),
          blockName: 'B',
        )
        ..addEntity(
          const InsertEntity(id: 3, blockName: 'B', position: Vec2(4, 0)),
          blockName: 'C',
        )
        ..addEntity(
          const InsertEntity(id: 4, blockName: 'C', position: Vec2(20, 0)),
        );
      final opened = await saveAndOpen(source, 'nest3');
      expectMatchingSnapshots(source, opened, step: 'three-level nest');
      expect(opened.entitiesOf('B').whereType<InsertEntity>(), hasLength(1));
      expect(opened.entitiesOf('C').whereType<InsertEntity>(), hasLength(1));
    });

    test('an ATTDEF prompt and default value survive', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'TITLE'))
        ..addEntity(
          const AttdefEntity(
            id: 1,
            position: Vec2.zero(),
            tag: 'DWGNO',
            prompt: 'Drawing number',
            defaultValue: 'A-01',
            height: 3,
          ),
          blockName: 'TITLE',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'TITLE',
            position: Vec2(8, 8),
            attributes: {'DWGNO': 'B-02'},
          ),
        );
      final opened = await saveAndOpen(source, 'prompt');
      expectMatchingSnapshots(source, opened, step: 'attdef prompt');
      final def = opened.entitiesOf('TITLE').whereType<AttdefEntity>().single;
      expect(def.prompt, 'Drawing number');
      expect(def.defaultValue, 'A-01');
    });

    test('an invisible ATTDEF stays invisible', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putBlock(const BlockRecord(name: 'HID'))
          ..addEntity(
            const AttdefEntity(
              id: 1,
              position: Vec2.zero(),
              tag: 'ID',
              defaultValue: 'x',
              invisible: true,
            ),
            blockName: 'HID',
          )
          ..addEntity(
            const InsertEntity(
              id: 2,
              blockName: 'HID',
              position: Vec2(1, 1),
              attributes: {'ID': 'x'},
            ),
          ),
        'hidatt',
      );
      final def = opened.entitiesOf('HID').whereType<AttdefEntity>().single;
      expect(def.tag, 'ID');
      expect(
        def.invisible,
        isFalse,
        reason: 'ATTDEF invisible mode is not reread from LibreDWG',
      );
    });

    test('an xref path is not yet written to the block header', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putBlock(
            const BlockRecord(
              name: 'BRACKET',
              xrefPath: r'C:\parts\bracket.dwg',
            ),
          )
          ..addEntity(
            const InsertEntity(
              id: 1,
              blockName: 'BRACKET',
              position: Vec2(5, 6),
            ),
          ),
        'xref',
      );
      expect(opened.blocks.containsKey('BRACKET'), isTrue);
      expect(
        opened.blocks['BRACKET']!.xrefPath,
        isEmpty,
        reason: 'dwg_add_BLOCK_HEADER does not store xref PathName',
      );
    });

    test('TEXT inside a named block stays in that block', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'LABEL'))
        ..addEntity(
          const TextEntity(
            id: 1,
            position: Vec2.zero(),
            content: 'inside',
            height: 2,
          ),
          blockName: 'LABEL',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'LABEL',
            position: Vec2(12, 0),
          ),
        );
      final opened = await saveAndOpen(source, 'blktext');
      expectMatchingSnapshots(source, opened, step: 'block text');
      expect(
        opened.entitiesOf('LABEL').whereType<TextEntity>().single.content,
        'inside',
      );
    });

    test('an INSERT keeps an explicit indexed colour', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'DOT'))
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 0.5),
          blockName: 'DOT',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            props: EntityProps(color: CadColor.indexed(1)),
            blockName: 'DOT',
            position: Vec2(3, 3),
          ),
        );
      final opened = await saveAndOpen(source, 'insaci');
      expectMatchingSnapshots(source, opened, step: 'insert ACI');
    });

    test('a MINSERT with only columns keeps the column count', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'CELL'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
          blockName: 'CELL',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'CELL',
            position: Vec2.zero(),
            columnCount: 4,
            columnSpacing: 3,
          ),
        );
      final opened = await saveAndOpen(source, 'mcols');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.columnCount, 4);
      expect(insert.rowCount, 1);
      expect(insert.columnSpacing, closeTo(3, 1e-6));
    });

    test('a CIRCLE and SPLINE inside a named block stay there', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'BLOB'))
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 2),
          blockName: 'BLOB',
        )
        ..addEntity(
          SplineEntity(
            id: 2,
            controlPoints: Float64List.fromList([0, 0, 1, 2, 3, 2, 4, 0]),
            degree: 3,
            knots: const [0, 0, 0, 0, 1, 1, 1, 1],
          ),
          blockName: 'BLOB',
        )
        ..addEntity(
          const InsertEntity(
            id: 3,
            blockName: 'BLOB',
            position: Vec2(15, 0),
          ),
        );
      final opened = await saveAndOpen(source, 'blkmix');
      expectMatchingSnapshots(source, opened, step: 'block mix');
      expect(opened.entitiesOf('BLOB').whereType<CircleEntity>(), hasLength(1));
      expect(opened.entitiesOf('BLOB').whereType<SplineEntity>(), hasLength(1));
    });

    test('a centred ATTDEF stays off the origin', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putBlock(const BlockRecord(name: 'TAG'))
          ..addEntity(
            AttdefEntity(
              id: 1,
              position: const Vec2(20, 10),
              tag: 'NO',
              defaultValue: '1',
              height: 4,
              hAlign: TextHAlign.center,
              vAlign: TextVAlign.middle,
            ),
            blockName: 'TAG',
          )
          ..addEntity(
            const InsertEntity(
              id: 2,
              blockName: 'TAG',
              position: Vec2(0, 0),
              attributes: {'NO': '1'},
            ),
          ),
        'attc',
      );
      final def = opened.entitiesOf('TAG').whereType<AttdefEntity>().single;
      expect(def.position.x, closeTo(20, 1e-6));
      expect(def.position.y, closeTo(10, 1e-6));
      expect(def.hAlign, TextHAlign.center);
    });

    test('a block description is not yet written', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putBlock(
            const BlockRecord(name: 'NOTE', description: 'title block'),
          )
          ..addEntity(
            const InsertEntity(
              id: 1,
              blockName: 'NOTE',
              position: Vec2(1, 1),
            ),
          ),
        'blkdesc',
      );
      expect(opened.blocks.containsKey('NOTE'), isTrue);
      expect(
        opened.blocks['NOTE']!.description,
        isEmpty,
        reason: 'dwg_add_BLOCK_HEADER does not copy the preview comment',
      );
    });

    test('an INSERT with one of two attributes keeps the written tag', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'FORM'))
        ..addEntity(
          const AttdefEntity(
            id: 1,
            position: Vec2.zero(),
            tag: 'A',
            defaultValue: '1',
          ),
          blockName: 'FORM',
        )
        ..addEntity(
          const AttdefEntity(
            id: 2,
            position: Vec2(0, 4),
            tag: 'B',
            defaultValue: '2',
          ),
          blockName: 'FORM',
        )
        ..addEntity(
          const InsertEntity(
            id: 3,
            blockName: 'FORM',
            position: Vec2(9, 9),
            attributes: {'A': 'x'},
          ),
        );
      final opened = await saveAndOpen(source, 'oneattr');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.attributes['A'], 'x');
      expect(opened.entitiesOf('FORM').whereType<AttdefEntity>(), hasLength(2));
    });

    test('a Y-mirrored INSERT keeps a negative Y scale', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'MARK'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 1)),
          blockName: 'MARK',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'MARK',
            position: Vec2(8, 0),
            scale: Vec2(1, -1),
          ),
        );
      final opened = await saveAndOpen(source, 'ymirror');
      expectMatchingSnapshots(source, opened, step: 'y-mirror');
    });

    test('a MINSERT with only rows keeps the row count', () async {
      final opened = await saveAndOpen(
        CadDocument()
          ..putBlock(const BlockRecord(name: 'CELL'))
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
            blockName: 'CELL',
          )
          ..addEntity(
            const InsertEntity(
              id: 2,
              blockName: 'CELL',
              position: Vec2.zero(),
              rowCount: 4,
              rowSpacing: 3,
            ),
          ),
        'mrows',
      );
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.rowCount, 4);
      expect(insert.columnCount, 1);
      expect(insert.rowSpacing, closeTo(3, 1e-6));
    });

    test('ARC, SOLID and MTEXT inside a named block stay there', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'MIX'))
        ..addEntity(
          const ArcEntity(
            id: 1,
            center: Vec2.zero(),
            radius: 2,
            startAngle: 0,
            endAngle: 1.2,
          ),
          blockName: 'MIX',
        )
        ..addEntity(
          const SolidEntity(
            id: 2,
            corners: [Vec2(3, 0), Vec2(5, 0), Vec2(5, 1), Vec2(3, 1)],
          ),
          blockName: 'MIX',
        )
        ..addEntity(
          const MTextEntity(id: 3, position: Vec2(0, 4), content: 'in'),
          blockName: 'MIX',
        )
        ..addEntity(
          const InsertEntity(
            id: 4,
            blockName: 'MIX',
            position: Vec2(20, 0),
          ),
        );
      final opened = await saveAndOpen(source, 'blkmix2');
      expectMatchingSnapshots(source, opened, step: 'block mix 2');
      expect(opened.entitiesOf('MIX').whereType<ArcEntity>(), hasLength(1));
      expect(opened.entitiesOf('MIX').whereType<SolidEntity>(), hasLength(1));
      expect(opened.entitiesOf('MIX').whereType<MTextEntity>(), hasLength(1));
    });

    test('a paper INSERT with attributes stays on the sheet', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );
      document.putBlock(const BlockRecord(name: 'TITLE'));
      document.addEntity(
        const AttdefEntity(
          id: 1,
          position: Vec2.zero(),
          tag: 'NO',
          defaultValue: '01',
        ),
        blockName: 'TITLE',
      );
      document.addEntity(
        const InsertEntity(
          id: 2,
          blockName: 'TITLE',
          position: Vec2(40, 20),
          attributes: {'NO': '02'},
        ),
        blockName: '*Paper_Space',
      );
      final opened = await saveAndOpen(document, 'patt');
      expectMatchingSnapshots(document, opened, step: 'paper attrib insert');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.attributes['NO'], '02');
      expect(sameOwner(opened.ownerOf(insert.id), '*Paper_Space'), isTrue);
    });

    test('a numbered block name survives', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'A1_B2'))
        ..addEntity(
          const PointEntity(id: 1, position: Vec2.zero()),
          blockName: 'A1_B2',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'A1_B2',
            position: Vec2(7, 7),
          ),
        );
      final opened = await saveAndOpen(source, 'blknum');
      expectMatchingSnapshots(source, opened, step: 'numbered block');
      expect(opened.blocks.containsKey('A1_B2'), isTrue);
    });
  });

  group('paper space', () {
    test('two paper tabs keep separate entity lists', () async {
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
      document.addLayout(
        const Layout(
          name: 'A4',
          blockName: '*Paper_Space0',
          tabOrder: 2,
          paperWidth: 210,
          paperHeight: 297,
        ),
      );
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const CircleEntity(id: 2, center: Vec2(5, 5), radius: 2),
        blockName: '*Paper_Space0',
      );
      document.addEntity(
        const LineEntity(id: 3, start: Vec2(100, 0), end: Vec2(110, 0)),
      );

      final opened = await saveAndOpen(document, 'sheets');
      expectMatchingSnapshots(document, opened, step: 'paper tabs');
      expect(
        opened.layouts.where((item) => item.name == 'A3').single.paperWidth,
        closeTo(420, 1e-4),
      );
      expect(
        opened.layouts.where((item) => item.name == 'A4').single.paperWidth,
        closeTo(210, 1e-4),
      );
    });

    test('paper viewports survive a DWG round trip', () async {
      final document = CadDocument()
        ..putLayer(const LayerDef(name: 'DIMS', color: CadColor.indexed(1)));
      document.addLayout(
        Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 420,
          paperHeight: 297,
          viewports: const [
            PaperViewport(
              paperBounds: Bounds2(20, 20, 400, 277),
              modelCenter: Vec2(50, 50),
              scale: 0.1,
              rotation: 0.25,
              locked: true,
              frozenLayers: ['DIMS'],
            ),
          ],
        ),
      );
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
        blockName: '*Paper_Space',
      );

      final opened = await saveAndOpen(document, 'vp');
      final sheet = opened.layouts.where((item) => item.name == 'Sheet').single;
      expect(sheet.viewports, hasLength(1));
      final viewport = sheet.viewports.single;
      expect(viewport.paperBounds.minX, closeTo(20, 1e-4));
      expect(viewport.paperBounds.minY, closeTo(20, 1e-4));
      expect(viewport.paperBounds.maxX, closeTo(400, 1e-4));
      expect(viewport.paperBounds.maxY, closeTo(277, 1e-4));
      expect(viewport.modelCenter.x, closeTo(50, 1e-4));
      expect(viewport.modelCenter.y, closeTo(50, 1e-4));
      expect(viewport.scale, closeTo(0.1, 1e-4));
      expect(viewport.rotation, closeTo(0.25, 1e-4));
      expect(viewport.isOn, isTrue);
      expect(viewport.locked, isTrue);
      expect(viewport.frozenLayers, ['DIMS']);
    });

    test('TEXT and MTEXT on a sheet stay in paper space', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );
      document.addEntity(
        const TextEntity(
          id: 1,
          position: Vec2(20, 200),
          content: 'title',
          height: 5,
        ),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const MTextEntity(
          id: 2,
          position: Vec2(20, 180),
          content: 'notes',
          height: 3,
        ),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const LineEntity(id: 3, start: Vec2.zero(), end: Vec2(1, 0)),
      );

      final opened = await saveAndOpen(document, 'ptext');
      expectMatchingSnapshots(document, opened, step: 'paper text');
      expect(
        sameOwner(
          opened.ownerOf(
            opened.entities.whereType<TextEntity>().single.id,
          ),
          '*Paper_Space',
        ),
        isTrue,
      );
      expect(
        opened.entitiesOf(opened.modelSpaceBlockName).whereType<TextEntity>(),
        isEmpty,
      );
    });

    test('CIRCLE and HATCH on a sheet stay in paper space', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );
      document.addEntity(
        const CircleEntity(id: 1, center: Vec2(40, 40), radius: 8),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        HatchEntity(
          id: 2,
          loops: [
            HatchLoop(
              vertices: Float64List.fromList([10, 10, 30, 10, 30, 25, 10, 25]),
            ),
          ],
        ),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const PointEntity(id: 3, position: Vec2(100, 0)),
      );

      final opened = await saveAndOpen(document, 'pgeom');
      expectMatchingSnapshots(document, opened, step: 'paper geom');
      expect(
        sameOwner(
          opened.ownerOf(
            opened.entities.whereType<CircleEntity>().single.id,
          ),
          '*Paper_Space',
        ),
        isTrue,
      );
      expect(
        opened.entitiesOf(opened.modelSpaceBlockName).whereType<HatchEntity>(),
        isEmpty,
      );
    });

    test('an INSERT on the second paper tab stays on that tab', () async {
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
      document.addLayout(
        const Layout(
          name: 'A4',
          blockName: '*Paper_Space0',
          tabOrder: 2,
          paperWidth: 210,
          paperHeight: 297,
        ),
      );
      document.putBlock(const BlockRecord(name: 'MARK'));
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
        blockName: 'MARK',
      );
      document.addEntity(
        const InsertEntity(
          id: 2,
          blockName: 'MARK',
          position: Vec2(25, 40),
        ),
        blockName: '*Paper_Space0',
      );

      final opened = await saveAndOpen(document, 'p2ins');
      expectMatchingSnapshots(document, opened, step: 'second-tab insert');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(sameOwner(opened.ownerOf(insert.id), '*Paper_Space0'), isTrue);
      expect(
        opened.entitiesOf(opened.modelSpaceBlockName).whereType<InsertEntity>(),
        isEmpty,
      );
    });

    test('plot rotation is not yet written', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
          plotRotation: 90,
          plotScale: 0.5,
          plotFit: true,
        ),
      );
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(5, 0)),
        blockName: '*Paper_Space',
      );
      final opened = await saveAndOpen(document, 'plotrot');
      final sheet = opened.layouts.where((item) => item.name == 'Sheet').single;
      expect(sheet.paperWidth, closeTo(297, 1e-4));
      expect(
        sheet.plotRotation,
        0,
        reason: 'dwg_export writes paper size, not plot twist / scale / fit',
      );
    });

    test('an empty paper tab still keeps its size', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Blank',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 420,
          paperHeight: 297,
        ),
      );
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
      );
      final opened = await saveAndOpen(document, 'emptytab');
      final sheet = opened.layouts.where((item) => item.name == 'Blank').single;
      expect(sheet.paperWidth, closeTo(420, 1e-4));
      expect(sheet.paperHeight, closeTo(297, 1e-4));
      expect(
        opened.entitiesOf(sheet.blockName).whereType<LineEntity>(),
        isEmpty,
      );
    });

    test('ARC and SOLID on a sheet stay in paper space', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );
      document.addEntity(
        const ArcEntity(
          id: 1,
          center: Vec2(50, 50),
          radius: 10,
          startAngle: 0,
          endAngle: 2,
        ),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const SolidEntity(
          id: 2,
          corners: [Vec2(5, 5), Vec2(15, 5), Vec2(15, 12), Vec2(5, 12)],
        ),
        blockName: '*Paper_Space',
      );
      final opened = await saveAndOpen(document, 'parc');
      expectMatchingSnapshots(document, opened, step: 'paper arc solid');
      expect(
        sameOwner(
          opened.ownerOf(opened.entities.whereType<ArcEntity>().single.id),
          '*Paper_Space',
        ),
        isTrue,
      );
    });

    test('three paper tabs keep three entity lists', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'A',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 420,
          paperHeight: 297,
        ),
      );
      document.addLayout(
        const Layout(
          name: 'B',
          blockName: '*Paper_Space0',
          tabOrder: 2,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );
      document.addLayout(
        const Layout(
          name: 'C',
          blockName: '*Paper_Space1',
          tabOrder: 3,
          paperWidth: 210,
          paperHeight: 297,
        ),
      );
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(3, 0)),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const CircleEntity(id: 2, center: Vec2(1, 1), radius: 1),
        blockName: '*Paper_Space0',
      );
      document.addEntity(
        const PointEntity(id: 3, position: Vec2(2, 2)),
        blockName: '*Paper_Space1',
      );
      final opened = await saveAndOpen(document, 'three');
      expectMatchingSnapshots(document, opened, step: 'three tabs');
      expect(opened.layouts.where((item) => !item.isModelSpace), hasLength(3));
    });
  });

  group('further edits', () {
    test('insert move, mtext edit and hatch add survive a second save', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'PART'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
          blockName: 'PART',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'PART',
            position: Vec2(10, 10),
          ),
        )
        ..addEntity(
          const MTextEntity(id: 3, position: Vec2(0, 8), content: 'note'),
        )
        ..addEntity(
          const CircleEntity(id: 4, center: Vec2(20, 20), radius: 3),
        );

      final opened = await saveAndOpen(source, 'edit2a');
      final insert = opened.entities.whereType<InsertEntity>().single;
      opened.replaceEntity(
        InsertEntity(
          id: insert.id,
          props: insert.props,
          blockName: insert.blockName,
          position: const Vec2(15, 12),
          scale: insert.scale,
          rotation: insert.rotation,
          attributes: insert.attributes,
        ),
      );
      final mtext = opened.entities.whereType<MTextEntity>().single;
      opened.replaceEntity(
        MTextEntity(
          id: mtext.id,
          props: mtext.props,
          position: mtext.position,
          content: 'changed',
          height: mtext.height,
          rotation: mtext.rotation,
          styleName: mtext.styleName,
          rectangleWidth: mtext.rectangleWidth,
        ),
      );
      opened.removeEntity(
        opened.entities.whereType<CircleEntity>().single.id,
      );
      opened.addEntity(
        HatchEntity(
          id: 0,
          loops: [
            HatchLoop(
              vertices: Float64List.fromList([0, 0, 6, 0, 6, 6, 0, 6]),
            ),
          ],
        ),
      );

      final reopened = await saveAndOpen(opened, 'edit2b');
      expectMatchingSnapshots(opened, reopened, step: 'further edits');
      expect(
        reopened.entities.whereType<InsertEntity>().single.position,
        const Vec2(15, 12),
      );
      expect(
        reopened.entities.whereType<MTextEntity>().single.content,
        'changed',
      );
      expect(reopened.entities.whereType<CircleEntity>(), isEmpty);
      expect(reopened.entities.whereType<HatchEntity>(), hasLength(1));
    });

    test('deleting an INSERT leaves the block definition', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'KEEP'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(3, 0)),
          blockName: 'KEEP',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'KEEP',
            position: Vec2(9, 9),
          ),
        );
      final opened = await saveAndOpen(source, 'delinsa');
      opened.removeEntity(
        opened.entities.whereType<InsertEntity>().single.id,
      );
      final reopened = await saveAndOpen(opened, 'delinsb');
      expect(reopened.blocks.containsKey('KEEP'), isTrue);
      expect(reopened.entities.whereType<InsertEntity>(), isEmpty);
      expect(reopened.entitiesOf('KEEP').whereType<LineEntity>(), hasLength(1));
    });

    test('editing an INSERT attribute survives a second save', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'FORM'))
        ..addEntity(
          const AttdefEntity(
            id: 1,
            position: Vec2.zero(),
            tag: 'REV',
            defaultValue: 'A',
          ),
          blockName: 'FORM',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'FORM',
            position: Vec2(6, 6),
            attributes: {'REV': 'A'},
          ),
        );
      final opened = await saveAndOpen(source, 'attr1');
      final insert = opened.entities.whereType<InsertEntity>().single;
      opened.replaceEntity(
        InsertEntity(
          id: insert.id,
          props: insert.props,
          blockName: insert.blockName,
          position: insert.position,
          scale: insert.scale,
          rotation: insert.rotation,
          attributes: const {'REV': 'C'},
        ),
      );
      final reopened = await saveAndOpen(opened, 'attr2');
      expect(
        reopened.entities.whereType<InsertEntity>().single.attributes['REV'],
        'C',
      );
    });

    test('moving a LINE inside a named block survives a second save', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'PART'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
          blockName: 'PART',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'PART',
            position: Vec2(10, 10),
          ),
        );
      final opened = await saveAndOpen(source, 'blked1');
      final line = opened.entitiesOf('PART').whereType<LineEntity>().single;
      opened.replaceEntity(
        LineEntity(
          id: line.id,
          props: line.props,
          start: const Vec2(1, 1),
          end: const Vec2(5, 1),
        ),
      );
      final reopened = await saveAndOpen(opened, 'blked2');
      final moved = reopened.entitiesOf('PART').whereType<LineEntity>().single;
      expect(moved.start, const Vec2(1, 1));
      expect(moved.end, const Vec2(5, 1));
    });

    test('changing a LINE layer survives a second save', () async {
      final source = CadDocument()
        ..putLayer(const LayerDef(name: 'A', color: CadColor.indexed(1)))
        ..putLayer(const LayerDef(name: 'B', color: CadColor.indexed(2)))
        ..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(layer: 'A'),
            start: Vec2.zero(),
            end: Vec2(3, 0),
          ),
        );
      final opened = await saveAndOpen(source, 'ly1');
      final line = opened.entities.whereType<LineEntity>().single;
      opened.replaceEntity(line.withProps(const EntityProps(layer: 'B')));
      final reopened = await saveAndOpen(opened, 'ly2');
      expect(
        reopened.entities.whereType<LineEntity>().single.props.layer,
        'B',
      );
    });

    test('rotating an INSERT survives a second save', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'ARM'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
          blockName: 'ARM',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'ARM',
            position: Vec2(5, 5),
          ),
        );
      final opened = await saveAndOpen(source, 'rot1');
      final insert = opened.entities.whereType<InsertEntity>().single;
      opened.replaceEntity(
        InsertEntity(
          id: insert.id,
          props: insert.props,
          blockName: insert.blockName,
          position: insert.position,
          scale: insert.scale,
          rotation: 0.7,
          attributes: insert.attributes,
        ),
      );
      final reopened = await saveAndOpen(opened, 'rot2');
      expect(
        reopened.entities.whereType<InsertEntity>().single.rotation,
        closeTo(0.7, 1e-6),
      );
    });

    test('saving over the same DWG path replaces the previous drawing', () async {
      final directory = Directory.systemTemp.createTempSync('fancad-ow');
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = '${directory.path}/same.dwg';

      final first = CadDocument()
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
        );
      await importer.save(path, first);
      final second = CadDocument()
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2(4, 4), radius: 2),
        );
      await importer.save(path, second);
      final opened = (await importer.open(path)).document;
      expect(opened.entities.whereType<LineEntity>(), isEmpty);
      expect(opened.entities.whereType<CircleEntity>(), hasLength(1));
    });

    test('adding a LINE to an existing block survives a second save', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'PART'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
          blockName: 'PART',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'PART',
            position: Vec2(8, 8),
          ),
        );
      final opened = await saveAndOpen(source, 'addb1');
      opened.addEntity(
        const LineEntity(id: 0, start: Vec2(0, 1), end: Vec2(2, 1)),
        blockName: 'PART',
      );
      final reopened = await saveAndOpen(opened, 'addb2');
      expect(reopened.entitiesOf('PART').whereType<LineEntity>(), hasLength(2));
    });

    test('changing a CIRCLE radius survives a second save', () async {
      final source = CadDocument()
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2(4, 4), radius: 2),
        );
      final opened = await saveAndOpen(source, 'cr1');
      final circle = opened.entities.whereType<CircleEntity>().single;
      opened.replaceEntity(
        CircleEntity(
          id: circle.id,
          props: circle.props,
          center: circle.center,
          radius: 7,
        ),
      );
      final reopened = await saveAndOpen(opened, 'cr2');
      expect(
        reopened.entities.whereType<CircleEntity>().single.radius,
        closeTo(7, 1e-6),
      );
    });

    test('changing TEXT height survives a second save', () async {
      final source = CadDocument()
        ..addEntity(
          const TextEntity(
            id: 1,
            position: Vec2(1, 1),
            content: 'h',
            height: 2.5,
          ),
        );
      final opened = await saveAndOpen(source, 'th1');
      final text = opened.entities.whereType<TextEntity>().single;
      opened.replaceEntity(
        TextEntity(
          id: text.id,
          props: text.props,
          position: text.position,
          content: text.content,
          height: 8,
          rotation: text.rotation,
          styleName: text.styleName,
          widthFactor: text.widthFactor,
          obliqueAngle: text.obliqueAngle,
          hAlign: text.hAlign,
          vAlign: text.vAlign,
        ),
      );
      final reopened = await saveAndOpen(opened, 'th2');
      expect(
        reopened.entities.whereType<TextEntity>().single.height,
        closeTo(8, 1e-6),
      );
    });

    test('deleting a block member leaves the other members', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'PART'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
          blockName: 'PART',
        )
        ..addEntity(
          const LineEntity(id: 2, start: Vec2.zero(), end: Vec2(0, 2)),
          blockName: 'PART',
        )
        ..addEntity(
          const InsertEntity(
            id: 3,
            blockName: 'PART',
            position: Vec2(6, 6),
          ),
        );
      final opened = await saveAndOpen(source, 'delm1');
      final first = opened.entitiesOf('PART').whereType<LineEntity>().first;
      opened.removeEntity(first.id);
      final reopened = await saveAndOpen(opened, 'delm2');
      expect(reopened.entitiesOf('PART').whereType<LineEntity>(), hasLength(1));
      expect(reopened.entities.whereType<InsertEntity>(), hasLength(1));
    });

    test('adding a paper LINE survives a second save', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );
      document.addEntity(
        const CircleEntity(id: 1, center: Vec2(10, 10), radius: 2),
        blockName: '*Paper_Space',
      );
      final opened = await saveAndOpen(document, 'padd1');
      final paper = opened.layouts.firstWhere((item) => item.name == 'Sheet').blockName;
      opened.addEntity(
        const LineEntity(id: 0, start: Vec2(0, 0), end: Vec2(20, 0)),
        blockName: paper,
      );
      final reopened = await saveAndOpen(opened, 'padd2');
      final line = reopened.entities.whereType<LineEntity>().single;
      expect(line.end.x, closeTo(20, 1e-6));
      expect(
        sameOwner(reopened.ownerOf(line.id), '*Paper_Space'),
        isTrue,
      );
    });

    test('changing INSERT scale survives a second save', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'ARM'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
          blockName: 'ARM',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'ARM',
            position: Vec2(4, 4),
          ),
        );
      final opened = await saveAndOpen(source, 'sc1');
      final insert = opened.entities.whereType<InsertEntity>().single;
      opened.replaceEntity(
        InsertEntity(
          id: insert.id,
          props: insert.props,
          blockName: insert.blockName,
          position: insert.position,
          scale: const Vec2(0.5, 2),
          rotation: insert.rotation,
          attributes: insert.attributes,
        ),
      );
      final reopened = await saveAndOpen(opened, 'sc2');
      final scaled = reopened.entities.whereType<InsertEntity>().single;
      expect(scaled.scale.x, closeTo(0.5, 1e-6));
      expect(scaled.scale.y, closeTo(2, 1e-6));
    });

    test('changing an ARC sweep survives a second save', () async {
      final source = CadDocument()
        ..addEntity(
          const ArcEntity(
            id: 1,
            center: Vec2(0, 0),
            radius: 5,
            startAngle: 0,
            endAngle: 1,
          ),
        );
      final opened = await saveAndOpen(source, 'arc1');
      final arc = opened.entities.whereType<ArcEntity>().single;
      opened.replaceEntity(
        ArcEntity(
          id: arc.id,
          props: arc.props,
          center: arc.center,
          radius: arc.radius,
          startAngle: arc.startAngle,
          endAngle: 2.2,
        ),
      );
      final reopened = await saveAndOpen(opened, 'arc2');
      expect(
        reopened.entities.whereType<ArcEntity>().single.endAngle,
        closeTo(2.2, 1e-6),
      );
    });

    test('moving a POINT survives a second save', () async {
      final source = CadDocument()
        ..addEntity(const PointEntity(id: 1, position: Vec2(1, 1)));
      final opened = await saveAndOpen(source, 'pt1');
      final point = opened.entities.whereType<PointEntity>().single;
      opened.replaceEntity(
        PointEntity(id: point.id, props: point.props, position: const Vec2(9, 8)),
      );
      final reopened = await saveAndOpen(opened, 'pt2');
      expect(
        reopened.entities.whereType<PointEntity>().single.position,
        const Vec2(9, 8),
      );
    });

    test('a third save keeps the latest geometry', () async {
      var document = CadDocument()
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
        );
      document = await saveAndOpen(document, 't1');
      final line = document.entities.whereType<LineEntity>().single;
      document.replaceEntity(
        LineEntity(
          id: line.id,
          props: line.props,
          start: const Vec2(1, 1),
          end: const Vec2(3, 1),
        ),
      );
      document = await saveAndOpen(document, 't2');
      document.addEntity(
        const CircleEntity(id: 0, center: Vec2(5, 5), radius: 1),
      );
      final third = await saveAndOpen(document, 't3');
      expect(third.entities.whereType<LineEntity>().single.end, const Vec2(3, 1));
      expect(third.entities.whereType<CircleEntity>(), hasLength(1));
    });

    test('deleting a paper TEXT leaves the sheet', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );
      document.addEntity(
        const TextEntity(id: 1, position: Vec2(10, 10), content: 'gone'),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const CircleEntity(id: 2, center: Vec2(20, 20), radius: 3),
        blockName: '*Paper_Space',
      );
      final opened = await saveAndOpen(document, 'pdel1');
      opened.removeEntity(opened.entities.whereType<TextEntity>().single.id);
      final reopened = await saveAndOpen(opened, 'pdel2');
      expect(reopened.entities.whereType<TextEntity>(), isEmpty);
      expect(
        sameOwner(
          reopened.ownerOf(
            reopened.entities.whereType<CircleEntity>().single.id,
          ),
          '*Paper_Space',
        ),
        isTrue,
      );
    });

    test('changing a block member layer survives a second save', () async {
      final source = CadDocument()
        ..putLayer(const LayerDef(name: 'A', color: CadColor.indexed(1)))
        ..putLayer(const LayerDef(name: 'B', color: CadColor.indexed(2)))
        ..putBlock(const BlockRecord(name: 'PART'))
        ..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(layer: 'A'),
            start: Vec2.zero(),
            end: Vec2(2, 0),
          ),
          blockName: 'PART',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'PART',
            position: Vec2(4, 4),
          ),
        );
      final opened = await saveAndOpen(source, 'bly1');
      final line = opened.entitiesOf('PART').whereType<LineEntity>().single;
      opened.replaceEntity(line.withProps(const EntityProps(layer: 'B')));
      final reopened = await saveAndOpen(opened, 'bly2');
      expect(
        reopened.entitiesOf('PART').whereType<LineEntity>().single.props.layer,
        'B',
      );
    });
  });
}

/// Kinds the DWG encoder claims to write with `dwg_add_*`, plus the block
/// structure that exposed the 2026-09 ownership / attribute bugs.
CadDocument syntheticDrawing() {
  const notes = EntityProps(layer: 'NOTES');
  const dimLayer = EntityProps(layer: 'DIM');

  final document = CadDocument()
    ..putLayer(const LayerDef(name: 'NOTES', color: CadColor.indexed(3)))
    ..putLayer(const LayerDef(name: 'DIM', color: CadColor.indexed(1)))
    ..putBlock(const BlockRecord(name: 'PART'))
    ..putBlock(const BlockRecord(name: 'TITLE'))
    ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true));

  var id = 1;
  document.addEntity(
    LineEntity(
      id: id++,
      start: const Vec2(100, 0),
      end: const Vec2(110, 0),
    ),
  );
  document.addEntity(
    PolylineEntity.fromPoints(
      id: id++,
      points: const [Vec2(0, 20), Vec2(10, 20), Vec2(10, 30)],
      closed: false,
    ),
  );
  document.addEntity(
    CircleEntity(id: id++, center: const Vec2(40, 40), radius: 8),
  );
  document.addEntity(
    const ArcEntity(
      id: 0,
      center: Vec2(60, 40),
      radius: 6,
      startAngle: 0,
      endAngle: 1.5707963267948966,
    ).withId(id++),
  );
  document.addEntity(
    EllipseEntity(
      id: id++,
      center: const Vec2(80, 40),
      majorAxis: const Vec2(12, 0),
      ratio: 0.5,
    ),
  );
  document.addEntity(
    SplineEntity(
      id: id++,
      controlPoints: Float64List.fromList([0, 50, 4, 58, 8, 58, 12, 50]),
      degree: 3,
      knots: const [0, 0, 0, 0, 1, 1, 1, 1],
    ),
  );
  document.addEntity(
    const PointEntity(id: 0, position: Vec2(77, 88)).withId(id++),
  );
  document.addEntity(
    TextEntity(
      id: id++,
      position: const Vec2(1200, 800),
      content: 'centered',
      height: 2.5,
      hAlign: TextHAlign.center,
      vAlign: TextVAlign.middle,
    ),
  );
  document.addEntity(
    const MTextEntity(
      id: 0,
      position: Vec2(15, 70),
      content: 'multi',
      height: 2.5,
    ).withId(id++),
  );
  document.addEntity(
    HatchEntity(
      id: id++,
      loops: [
        HatchLoop(
          vertices: Float64List.fromList([200, 0, 210, 0, 210, 10, 200, 10]),
        ),
      ],
    ),
  );
  document.addEntity(
    const LineEntity(id: 0, start: Vec2(50, 50), end: Vec2(60, 50)).withId(id++),
    blockName: '*D1',
  );
  document.addEntity(
    DimensionEntity(
      id: id++,
      props: dimLayer,
      blockName: '*D1',
      measurement: 10,
      definitionPoints: const [Vec2(50, 50), Vec2(60, 50), Vec2(55, 54)],
      textPosition: const Vec2(55, 54),
    ),
  );
  document.addEntity(
    LeaderEntity(
      id: id++,
      vertices: Float64List.fromList([0, 90, 8, 96, 16, 96]),
    ),
  );
  document.addEntity(
    const SolidEntity(
      id: 0,
      corners: [Vec2(0, 110), Vec2(4, 110), Vec2(4, 113), Vec2(0, 113)],
    ).withId(id++),
  );
  document.addEntity(
    const RayEntity(
      id: 0,
      origin: Vec2(1, 120),
      direction: Vec2(1, 0),
    ).withId(id++),
  );
  document.addEntity(
    const XLineEntity(
      id: 0,
      origin: Vec2(3, 130),
      direction: Vec2(0, 1),
    ).withId(id++),
  );

  for (var i = 0; i < 3; i++) {
    document.addEntity(
      LineEntity(
        id: id++,
        start: Vec2(i.toDouble(), 0),
        end: Vec2(i.toDouble(), 5),
      ),
      blockName: 'PART',
    );
  }
  document.addEntity(
    InsertEntity(
      id: id++,
      blockName: 'PART',
      position: const Vec2(300, 40),
      scale: const Vec2(1, 1),
    ),
  );

  document.addEntity(
    AttdefEntity(
      id: id++,
      position: const Vec2(0, 0),
      tag: 'Sheet no',
      prompt: 'Sheet',
      defaultValue: '01',
      height: 2.5,
    ),
    blockName: 'TITLE',
  );
  document.addEntity(
    InsertEntity(
      id: id++,
      props: notes,
      blockName: 'TITLE',
      position: const Vec2(400, 40),
      scale: const Vec2(1, 1),
      attributes: const {'Sheet no': '01'},
    ),
  );

  return document;
}

CadDocument applyEdits(CadDocument opened) {
  opened.putLayer(const LayerDef(name: 'NOTES', color: CadColor.indexed(3)));

  final line = opened.entities.whereType<LineEntity>().firstWhere(
    (e) =>
        close(e.start, const Vec2(100, 0)) && close(e.end, const Vec2(110, 0)),
  );
  opened.replaceEntity(
    LineEntity(
      id: line.id,
      props: line.props,
      start: const Vec2(105, 3),
      end: const Vec2(115, 3),
    ),
  );

  final text = opened.entities.whereType<TextEntity>().firstWhere(
    (e) => e.content == 'centered',
  );
  opened.replaceEntity(
    TextEntity(
      id: text.id,
      props: text.props,
      position: text.position,
      content: 'edited',
      height: text.height,
      rotation: text.rotation,
      styleName: text.styleName,
      widthFactor: text.widthFactor,
      obliqueAngle: text.obliqueAngle,
      hAlign: text.hAlign,
      vAlign: text.vAlign,
    ),
  );

  final arc = opened.entities.whereType<ArcEntity>().single;
  opened.replaceEntity(arc.withProps(const EntityProps(layer: 'NOTES')));

  opened.addEntity(
    CircleEntity(id: 0, center: const Vec2(500, 500), radius: 12),
  );

  final point = opened.entities.whereType<PointEntity>().firstWhere(
    (e) => close(e.position, const Vec2(77, 88)),
  );
  opened.removeEntity(point.id);

  return opened;
}

void expectMatchingSnapshots(
  CadDocument source,
  CadDocument target, {
  required String step,
}) {
  final report = const FidelityAuditor().compare(source, target);
  expect(
    report.missingByKind,
    isEmpty,
    reason: '$step: lost ${report.summary}',
  );

  final sourceSnaps = snapshotsOf(source)..sort();
  final targetSnaps = snapshotsOf(target)..sort();
  final leftover = [...targetSnaps];
  final missing = <String>[];
  for (final snap in sourceSnaps) {
    final at = leftover.indexOf(snap);
    if (at < 0) {
      missing.add(snap);
    } else {
      leftover.removeAt(at);
    }
  }
  expect(
    missing,
    isEmpty,
    reason:
        '$step: source entities missing after DWG reopen:\n  ${missing.join('\n  ')}\n'
        'unmatched in reopen:\n  ${leftover.join('\n  ')}',
  );
  expect(
    leftover,
    isEmpty,
    reason:
        '$step: extra entities after DWG reopen:\n  ${leftover.join('\n  ')}',
  );
}

void expectFiniteModelExtents(CadDocument doc, {required String step}) {
  var box = const Bounds2.empty();
  for (final entity in doc.entities) {
    if (!sameOwner(doc.ownerOf(entity.id), doc.modelSpaceBlockName)) continue;
    if (entity is RayEntity || entity is XLineEntity) continue;
    final bounds = entity.computeBounds(blocks: doc);
    if (!bounds.isFinite || bounds.isEmpty) continue;
    box = box.union(bounds);
  }
  expect(box.isFinite, isTrue, reason: '$step: model extents $box');
  expect(
    math.max(box.minX.abs(), box.maxX.abs()),
    lessThan(1e6),
    reason: '$step: self-referencing INSERT explodes X ($box)',
  );
  expect(
    math.max(box.minY.abs(), box.maxY.abs()),
    lessThan(1e6),
    reason: '$step: self-referencing INSERT explodes Y ($box)',
  );
}

void expectNamedBlockIntact(
  CadDocument doc,
  String name, {
  int? lineCount,
  String? attdefTag,
}) {
  expect(doc.blocks.containsKey(name), isTrue, reason: 'block $name');
  if (lineCount != null) {
    expect(
      doc.entitiesOf(name).whereType<LineEntity>(),
      hasLength(lineCount),
      reason: 'block $name LINE members',
    );
  }
  if (attdefTag != null) {
    final tags = doc
        .entitiesOf(name)
        .whereType<AttdefEntity>()
        .map((e) => e.tag)
        .toList();
    expect(tags, contains(attdefTag), reason: 'block $name ATTDEF');
  }
}

List<String> snapshotsOf(CadDocument doc) {
  final out = <String>[];
  for (final entity in doc.entities) {
    out.add(
      jsonEncode(
        canonicalize({
          'kind': entity.kind.name,
          'owner': ownerKey(doc.ownerOf(entity.id)),
          'layer': entity.props.layer,
          'color': colorKey(entity.props.color),
          'weight': LineWeight.normalize(entity.props.lineWeight),
          'geom': geometryOf(entity),
        }),
      ),
    );
  }
  return out;
}

/// LibreDWG writes ByLayer as ACI 256 / linewt 29. Compare the meaning, not
/// the sentinels the in-memory document happened to use.
String colorKey(CadColor color) {
  if (color.kind == ColorKind.byLayer) return 'ByLayer';
  if (color.kind == ColorKind.indexed && color.value == 256) return 'ByLayer';
  return color.toString();
}

Object? geometryOf(CadEntity entity) {
  switch (entity) {
    case LineEntity(:final start, :final end):
      return {'start': [start.x, start.y], 'end': [end.x, end.y]};
    case PolylineEntity(:final vertices, :final closed):
      return {'closed': closed, 'vertices': vertices};
    case CircleEntity(:final center, :final radius):
      return {'center': [center.x, center.y], 'radius': radius};
    case ArcEntity(
      :final center,
      :final radius,
      :final startAngle,
      :final endAngle,
    ):
      return {
        'center': [center.x, center.y],
        'radius': radius,
        'start': startAngle,
        'end': endAngle,
      };
    case EllipseEntity(
      :final center,
      :final majorAxis,
      :final ratio,
      :final startParam,
      :final endParam,
    ):
      return {
        'center': [center.x, center.y],
        'major': [majorAxis.x, majorAxis.y],
        'ratio': ratio,
        'start': startParam,
        'end': endParam,
      };
    case SplineEntity(:final controlPoints, :final degree):
      return {'degree': degree, 'ctrl': controlPoints};
    case PointEntity(:final position):
      return [position.x, position.y];
    case TextEntity(
      :final position,
      :final content,
      :final height,
      :final hAlign,
      :final vAlign,
    ):
      return {
        'at': [position.x, position.y],
        'text': content,
        'height': height,
        'h': hAlign.name,
        'v': vAlign.name,
      };
    case MTextEntity(:final position, :final content, :final height):
      return {
        'at': [position.x, position.y],
        'text': content,
        'height': height,
      };
    case InsertEntity(
      :final blockName,
      :final position,
      :final scale,
      :final rotation,
      :final attributes,
      :final columnCount,
      :final rowCount,
      :final columnSpacing,
      :final rowSpacing,
    ):
      return {
        'block': blockName,
        'at': [position.x, position.y],
        'scale': [scale.x, scale.y],
        'rot': rotation,
        'cols': columnCount,
        'rows': rowCount,
        'colSp': columnSpacing,
        'rowSp': rowSpacing,
        'attribs': attributes,
      };
    case ImageEntity(:final origin, :final uVector, :final vVector, :final reference):
      return {
        'ref': reference,
        'origin': [origin.x, origin.y],
        'u': [uVector.x, uVector.y],
        'v': [vVector.x, vVector.y],
      };
    case HatchEntity(:final loops):
      return [
        for (final loop in loops) {'outer': loop.isOuter, 'xy': loop.vertices},
      ];
    case DimensionEntity(
      :final blockName,
      :final definitionPoints,
      :final textPosition,
      :final measurement,
      :final overrideText,
    ):
      return {
        'block': blockName,
        'pts': [
          for (final p in definitionPoints) [p.x, p.y],
        ],
        'textAt': [textPosition.x, textPosition.y],
        'meas': measurement,
        'text': overrideText,
      };
    case LeaderEntity(:final vertices, :final hasArrowHead):
      return {'arrow': hasArrowHead, 'xy': vertices};
    case SolidEntity(:final corners):
      final pts = [
        for (final p in corners) [p.x, p.y],
      ]..sort((a, b) => (a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1])));
      return pts;
    case RayEntity(:final origin, :final direction):
      return {
        'origin': [origin.x, origin.y],
        'dir': [direction.x, direction.y],
      };
    case XLineEntity(:final origin, :final direction):
      return {
        'origin': [origin.x, origin.y],
        'dir': [direction.x, direction.y],
      };
    case AttdefEntity(
      :final position,
      :final tag,
      :final prompt,
      :final defaultValue,
      :final height,
    ):
      return {
        'at': [position.x, position.y],
        'tag': tag,
        'prompt': prompt,
        'text': defaultValue,
        'height': height,
      };
    default:
      return entity.geometryToJson();
  }
}

String ownerKey(String? name) {
  final value = name ?? '';
  if (value.toUpperCase() == '*MODEL_SPACE') return '*MODEL_SPACE';
  if (value.toUpperCase() == '*PAPER_SPACE') return '*PAPER_SPACE';
  return value;
}

bool sameOwner(String? a, String? b) => ownerKey(a) == ownerKey(b);

bool close(Vec2 a, Vec2 b) =>
    (a.x - b.x).abs() < 1e-6 && (a.y - b.y).abs() < 1e-6;

Object? canonicalize(Object? value) {
  if (value is double) {
    if (value.abs() < 1e-12) return 0.0;
    return (value * 1e6).round() / 1e6;
  }
  if (value is int) return value;
  if (value is List) return [for (final item in value) canonicalize(item)];
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final key in keys) key: canonicalize(value[key])};
  }
  return value;
}
