import 'dart:io';
import 'dart:math' as math;

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the built-in commands, driven through the headless path.
///
/// This is the same entry point a plugin or an AI tool call takes, so these
/// tests are the closest thing to a contract for "can the assistant actually
/// draw". Running them headlessly also proves the commands hold no hidden
/// dependency on a widget tree.
late Workspace workspace;

CadDocument get document => workspace.active!.document;

Future<CommandResult> run(String id, [Map<String, Object?> args = const {}]) =>
    workspace.runHeadless(id, args: args);

/// Draws a line and returns its id, failing the test if it did not work.
Future<int> drawLine(double x1, double y1, double x2, double y2) async {
  final result = await run('draw.line', {
    'start': [x1, y1],
    'end': [x2, y2],
  });
  expect(result.status, CommandStatus.ok, reason: result.message);
  return (result.data!['ids']! as List).first as int;
}

void main() {
  setUp(() {
    workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(SettingsStore.inMemory()),
    );
    registerBuiltinCommands(
      workspace.commands,
      fileCommands: FileCommands(
        openFile: (_) async => false,
        newDocument: workspace.newDocument,
        closeActive: ({bool force = false}) => true,
        saveActive: (path) async => path,
        recentFiles: () => const [],
      ),
    );
    workspace.newDocument();
  });

  tearDown(() => workspace.dispose());

  group('drawing', () {
    test('line creates one segment from supplied coordinates', () async {
      await drawLine(0, 0, 10, 0);

      expect(document.entityCount, 1);
      final entity = document.entities.first as LineEntity;
      expect(entity.start, const Vec2(0, 0));
      expect(entity.end, const Vec2(10, 0));
    });

    test('circle rejects a non-positive radius', () async {
      final result = await run('draw.circle', {
        'center': [0, 0],
        'radius': 0,
      });

      expect(result.status, CommandStatus.failed);
      expect(document.entityCount, 0);
    });

    test('rectangle produces a closed four-vertex polyline', () async {
      final result = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [10, 5],
      });

      expect(result.status, CommandStatus.ok);
      final polyline = document.entities.first as PolylineEntity;
      expect(polyline.closed, isTrue);
      expect(polyline.vertexCount, 4);
    });

    test('hatch fills a closed rectangle with a scaled pattern', () async {
      final created = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [20, 10],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.hatch', {
        'ids': [id],
        'pattern': 'ANSI31',
        'scale': 2,
        'angle': 90,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final hatch = document.entities.whereType<HatchEntity>().single;
      expect(hatch.patternName, 'ANSI31');
      expect(hatch.solid, isFalse);
      expect(hatch.patternScale, closeTo(2, 1e-9));
      expect(hatch.patternAngle, closeTo(math.pi / 2, 1e-9));
    });

    test('hatch fills the face around an internal point', () async {
      await drawLine(0, 0, 10, 0);
      await drawLine(10, 0, 10, 10);
      await drawLine(10, 10, 0, 10);
      await drawLine(0, 10, 0, 0);

      final result = await run('draw.hatch', {
        'inside': [5, 5],
        'pattern': 'SOLID',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final hatch = document.entities.whereType<HatchEntity>().single;
      expect(hatch.solid, isTrue);
      expect(hatch.loops, isNotEmpty);
      expect(
        Intersect.polygonContains(hatch.loops.first.vertices, const Vec2(5, 5)),
        isTrue,
      );
    });

    test('hatch refuses a non-positive scale', () async {
      final created = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [10, 10],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.hatch', {
        'ids': [id],
        'pattern': 'ANSI31',
        'scale': 0,
      });

      expect(result.status, CommandStatus.failed);
      expect(document.entities.whereType<HatchEntity>(), isEmpty);
    });

    test('mtext places wrapped multiline text', () async {
      final result = await run('draw.mtext', {
        'content': 'NOTE\nRev A',
        'at': [10, 20],
        'height': 2.5,
        'width': 40,
        'justify': 'tr',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final text = document.entities.whereType<MTextEntity>().single;
      expect(text.content, r'NOTE\PRev A');
      expect(text.position, const Vec2(10, 20));
      expect(text.height, closeTo(2.5, 1e-9));
      expect(text.rectangleWidth, closeTo(40, 1e-9));
      expect(text.attachment, 3);
      expect(text.hAlign, TextHAlign.right);
      expect(text.vAlign, TextVAlign.top);

      await run('edit.undo');
      expect(document.entities.whereType<MTextEntity>(), isEmpty);
    });

    test('mtext refuses a bad attachment', () async {
      final result = await run('draw.mtext', {
        'content': 'A',
        'at': [0, 0],
        'attachment': 0,
      });
      expect(result.status, CommandStatus.failed);
      expect(document.entities.whereType<MTextEntity>(), isEmpty);
    });

    test('rectangle refuses a degenerate corner pair', () async {
      final result = await run('draw.rectangle', {
        'corner1': [5, 5],
        'corner2': [5, 9],
      });

      expect(result.status, CommandStatus.failed);
    });

    test('polyline accepts a point array', () async {
      final result = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
        'closed': true,
      });

      expect(result.status, CommandStatus.ok);
      final polyline = document.entities.first as PolylineEntity;
      expect(polyline.vertexCount, 3);
      expect(polyline.closed, isTrue);
    });

    test('circle tan-tan-radius sits in the picked corner', () async {
      final vertical = await drawLine(0, 10, 0, 0);
      final horizontal = await drawLine(0, 0, 10, 0);

      final result = await run('draw.circleTtr', {
        'first': vertical,
        'second': horizontal,
        'radius': 2,
        'pick1': [0, 5],
        'pick2': [5, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final circle = document.entities.whereType<CircleEntity>().single;
      expect(circle.center.x, closeTo(2, 1e-9));
      expect(circle.center.y, closeTo(2, 1e-9));
      expect(circle.radius, closeTo(2, 1e-9));
    });

    test('circle through three points uses the circumcircle', () async {
      final result = await run('draw.circle3p', {
        'first': [1, 0],
        'second': [0, 1],
        'third': [-1, 0],
      });

      expect(result.status, CommandStatus.ok);
      final circle = document.entities.first as CircleEntity;
      expect(circle.center.x, closeTo(0, 1e-9));
      expect(circle.center.y, closeTo(0, 1e-9));
      expect(circle.radius, closeTo(1, 1e-9));
    });

    test('circle through three collinear points is refused', () async {
      final result = await run('draw.circle3p', {
        'first': [0, 0],
        'second': [5, 0],
        'third': [10, 0],
      });

      expect(result.status, CommandStatus.failed);
      expect(document.entityCount, 0);
    });

    test('arc through three collinear points falls back to a line', () async {
      final result = await run('draw.arc', {
        'start': [0, 0],
        'via': [5, 0],
        'end': [10, 0],
      });

      expect(result.status, CommandStatus.ok);
      expect(document.entities.first, isA<LineEntity>());
      expect(result.message, contains('collinear'));
    });

    test('linear dimension measures the axis the dim line implies', () async {
      final result = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [10, 4],
        'dimLine': [5, 8],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entities.first as DimensionEntity;
      expect(dim.measurement, closeTo(10, 1e-9));
      expect(dim.displayText, '10.00');
    });

    test('dimstyle drives regenerated dimension text and arrows', () async {
      final created = await run('annot.dimstyle', {
        'name': 'ARCH',
        'textHeight': 5,
        'arrowSize': 4,
        'decimalPlaces': 0,
      });
      expect(created.status, CommandStatus.ok, reason: created.message);
      expect(document.currentDimStyle, 'ARCH');
      expect(document.namedDimStyle('ARCH')!.textHeight, 5);

      final drawn = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [10, 0],
        'dimLine': [5, 4],
      });
      expect(drawn.status, CommandStatus.ok, reason: drawn.message);
      final dim =
          document.entity((drawn.data!['ids']! as List).first as int)!
              as DimensionEntity;
      expect(dim.styleName, 'ARCH');
      expect(dim.displayTextFor(document.dimStyle('ARCH')), '10');

      final sink = PolylineSink();
      dim.emit(document.emitContext(tolerance: 0.1), sink);
      expect(sink.texts.single.text, '10');
      expect(sink.texts.single.height, closeTo(5, 1e-9));
    });

    test('dimstyle undo restores the previous table', () async {
      final created = await run('annot.dimstyle', {
        'name': 'ARCH',
        'textHeight': 5,
      });
      expect(created.status, CommandStatus.ok, reason: created.message);
      expect(workspace.active!.session.undo(), isTrue);
      expect(document.namedDimStyle('ARCH'), isNull);
      expect(document.currentDimStyle, 'Standard');
    });

    test('dimstyle lists the table when no name is given', () async {
      final result = await run('annot.dimstyle');
      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(result.data!['current'], 'Standard');
      final styles = result.data!['styles']! as List;
      expect(styles, isNotEmpty);
    });

    test('dimstyle refuses a non-positive text height', () async {
      final result = await run('annot.dimstyle', {
        'name': 'ARCH',
        'textHeight': 0,
      });
      expect(result.status, CommandStatus.failed);
      expect(document.namedDimStyle('ARCH'), isNull);
    });

    test('continue dimension chains from the previous second origin', () async {
      final created = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [10, 0],
        'dimLine': [5, 4],
      });
      final base = (created.data!['ids']! as List).first as int;

      final result = await run('draw.dimContinue', {
        'base': base,
        'next': [16, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entities.whereType<DimensionEntity>(), hasLength(2));
      final continued =
          document.entity((result.data!['ids']! as List).first as int)!
              as DimensionEntity;
      expect(continued.measurement, closeTo(6, 1e-9));
      expect(continued.definitionPoints[0], const Vec2(10, 0));
      expect(continued.textPosition.y, closeTo(4, 1e-9));
    });

    test('continue dimension walks several origins in one command', () async {
      final created = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [8, 0],
        'dimLine': [4, 3],
      });
      final base = (created.data!['ids']! as List).first as int;

      final result = await run('draw.dimContinue', {
        'base': base,
        'points': [
          [12, 0],
          [20, 0],
        ],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((result.data!['ids']! as List), hasLength(2));
      expect(document.entities.whereType<DimensionEntity>(), hasLength(3));
    });

    test('continue dimension refuses a radius dimension', () async {
      final circle = await run('draw.circle', {
        'center': [0, 0],
        'radius': 5,
      });
      final circleId = (circle.data!['ids']! as List).first as int;
      final radial = await run('draw.dimRadius', {
        'target': circleId,
        'dimLine': [8, 0],
      });
      final base = (radial.data!['ids']! as List).first as int;

      final result = await run('draw.dimContinue', {
        'base': base,
        'next': [12, 0],
      });

      expect(result.status, CommandStatus.failed);
      expect(document.entities.whereType<DimensionEntity>(), hasLength(1));
    });

    test('baseline dimension stacks from the first origin', () async {
      final created = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [10, 0],
        'dimLine': [5, 4],
      });
      final base = (created.data!['ids']! as List).first as int;

      final result = await run('draw.dimBaseline', {
        'base': base,
        'next': [18, 0],
        'spacing': 8,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entities.whereType<DimensionEntity>(), hasLength(2));
      final stacked =
          document.entity((result.data!['ids']! as List).first as int)!
              as DimensionEntity;
      expect(stacked.measurement, closeTo(18, 1e-9));
      expect(stacked.definitionPoints[0], const Vec2(0, 0));
      expect(stacked.textPosition.y, closeTo(12, 1e-9));
    });

    test('baseline dimension walks several origins in one command', () async {
      final created = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [6, 0],
        'dimLine': [3, 2],
      });
      final base = (created.data!['ids']! as List).first as int;

      final result = await run('draw.dimBaseline', {
        'base': base,
        'points': [
          [12, 0],
          [20, 0],
        ],
        'spacing': 4,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((result.data!['ids']! as List), hasLength(2));
      expect(document.entities.whereType<DimensionEntity>(), hasLength(3));
    });

    test('dimension text override replaces the measured value', () async {
      final created = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [10, 0],
        'dimLine': [5, 4],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.dimensionText', {
        'ids': [id],
        'text': 'TYP <>',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entity(id)! as DimensionEntity;
      expect(dim.overrideText, 'TYP <>');
      expect(dim.displayText, 'TYP 10.00');
    });

    test('dimension text empty restores the measurement', () async {
      final created = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [8, 0],
        'dimLine': [4, 3],
      });
      final id = (created.data!['ids']! as List).first as int;
      await run('edit.dimensionText', {
        'ids': [id],
        'text': 'see detail',
      });

      final result = await run('edit.dimensionText', {
        'ids': [id],
        'text': '',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entity(id)! as DimensionEntity;
      expect(dim.overrideText, isEmpty);
      expect(dim.displayText, '8.00');
    });

    test('dimension text move relocates the label and dim line', () async {
      final created = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [10, 0],
        'dimLine': [5, 4],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.dimTedit', {
        'ids': [id],
        'at': [8, 12],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entity(id)! as DimensionEntity;
      expect(dim.textPosition, const Vec2(8, 12));
      expect(dim.definitionPoints[2], const Vec2(5, 12));
      expect(dim.measurement, closeTo(10, 1e-9));
    });

    test('dimension text move refuses a line', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.dimTedit', {
        'ids': [id],
        'at': [0, 4],
      });

      expect(result.status, CommandStatus.failed);
      expect((document.entity(id)! as LineEntity).start, const Vec2(0, 0));
    });

    test('justify text changes alignment without moving the letters', () async {
      final created = await run('draw.text', {
        'content': 'ABC',
        'at': [0, 0],
        'height': 10,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.justifyText', {
        'ids': [id],
        'justify': 'right',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final text = document.entity(id)! as TextEntity;
      expect(text.hAlign, TextHAlign.right);
      expect(text.position.x, closeTo(3 * 10 * 0.62, 1e-9));
    });

    test('justify text refuses a line', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.justifyText', {
        'ids': [id],
        'justify': 'center',
      });

      expect(result.status, CommandStatus.failed);
      expect((document.entity(id)! as LineEntity).start, const Vec2(0, 0));
    });

    test('edit text changes a placed string', () async {
      final created = await run('draw.text', {
        'content': 'ROOM',
        'at': [0, 0],
        'height': 2.5,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.textContent', {
        'ids': [id],
        'text': 'HALL',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(id)! as TextEntity).content, 'HALL');
    });

    test('edit text overrides a dimension like DIMEDIT', () async {
      final created = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [6, 0],
        'dimLine': [3, 2],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.textContent', {
        'ids': [id],
        'text': '<> mm',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(id)! as DimensionEntity).displayText, '6.00 mm');
    });

    test('leader draws an arrowed polyline from the supplied points', () async {
      final result = await run('draw.leader', {
        'points': [
          [0, 0],
          [10, 4],
          [14, 4],
        ],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 1);
      final leader = document.entities.first as LeaderEntity;
      expect(leader.hasArrowHead, isTrue);
      expect(leader.grips(), const [Vec2(0, 0), Vec2(10, 4), Vec2(14, 4)]);
    });

    test('leader annotation sits on a landing past the last vertex', () async {
      final result = await run('draw.leader', {
        'points': [
          [0, 0],
          [8, 6],
        ],
        'text': 'HOLE',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 2);
      expect(document.entities.whereType<LeaderEntity>(), hasLength(1));
      final text = document.entities.whereType<TextEntity>().single;
      expect(text.content, 'HOLE');
      expect(text.hAlign, TextHAlign.left);
    });

    test('leader refuses a single point', () async {
      final result = await run('draw.leader', {
        'points': [
          [3, 3],
        ],
      });

      expect(result.status, CommandStatus.failed);
      expect(document.entityCount, 0);
    });

    test('center mark draws a cross and extensions on a circle', () async {
      final created = await run('draw.circle', {
        'center': [0, 0],
        'radius': 8,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.centerMark', {
        'ids': [id],
        'size': 2,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entities.whereType<LineEntity>(), hasLength(6));
      expect(
        document.entities.whereType<LineEntity>().every((line) {
          return line.start.x == 0 ||
              line.start.y == 0 ||
              line.end.x == 0 ||
              line.end.y == 0;
        }),
        isTrue,
      );
    });

    test('center mark can omit the extensions', () async {
      final created = await run('draw.circle', {
        'center': [4, 4],
        'radius': 5,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.centerMark', {
        'ids': [id],
        'size': 1.5,
        'extend': false,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entities.whereType<LineEntity>(), hasLength(2));
    });

    test('centerline sits between two parallel lines', () async {
      final first = await drawLine(0, 0, 10, 0);
      final second = await drawLine(2, 4, 12, 4);

      final result = await run('draw.centerLine', {
        'first': first,
        'second': second,
        'extension': 2,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final mark =
          document.entity((result.data!['ids']! as List).first as int)!
              as LineEntity;
      expect(mark.start.y, closeTo(2, 1e-9));
      expect(mark.end.y, closeTo(2, 1e-9));
      expect(mark.start.x, closeTo(-2, 1e-9));
      expect(mark.end.x, closeTo(14, 1e-9));
    });

    test('centerline through two circles overshoots both rims', () async {
      final left = await run('draw.circle', {
        'center': [0, 0],
        'radius': 2,
      });
      final right = await run('draw.circle', {
        'center': [10, 0],
        'radius': 3,
      });

      final result = await run('draw.centerLine', {
        'first': (left.data!['ids']! as List).first,
        'second': (right.data!['ids']! as List).first,
        'extension': 1,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final mark = document.entities.whereType<LineEntity>().single;
      expect(mark.start, const Vec2(-3, 0));
      expect(mark.end, const Vec2(14, 0));
    });

    test('aligned dimension measures the slanted distance', () async {
      final result = await run('draw.dimAligned', {
        'first': [0, 0],
        'second': [3, 4],
        'dimLine': [1, 2],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entities.first as DimensionEntity;
      expect(dim.measurement, closeTo(5, 1e-9));
      expect(dim.displayText, '5.00');
    });

    test('linear dimension can take its origins from a line', () async {
      final line = await drawLine(0, 0, 10, 4);

      final result = await run('draw.dimLinear', {
        'target': line,
        'dimLine': [5, 8],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entities.whereType<DimensionEntity>().single;
      expect(dim.measurement, closeTo(10, 1e-9));
      expect(dim.definitionPoints[0], const Vec2(0, 0));
      expect(dim.definitionPoints[1], const Vec2(10, 4));
      expect(dim.sourceIds, [line]);
    });

    test('aligned dimension can take its origins from a line', () async {
      final line = await drawLine(0, 0, 3, 4);

      final result = await run('draw.dimAligned', {
        'target': line,
        'dimLine': [1, 2],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entities.whereType<DimensionEntity>().single;
      expect(dim.measurement, closeTo(5, 1e-9));
    });

    test('linear dimension from an object refuses a circle', () async {
      final created = await run('draw.circle', {
        'center': [0, 0],
        'radius': 5,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.dimLinear', {
        'target': id,
        'dimLine': [0, 8],
      });

      expect(result.status, CommandStatus.failed);
      expect(document.entities.whereType<DimensionEntity>(), isEmpty);
    });

    test('radius dimension labels a circle with R', () async {
      final created = await run('draw.circle', {
        'center': [0, 0],
        'radius': 5,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.dimRadius', {
        'target': id,
        'dimLine': [8, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entities.whereType<DimensionEntity>().single;
      expect(dim.measurement, closeTo(5, 1e-9));
      expect(dim.displayText, 'R5.00');
    });

    test('diameter dimension labels a circle with Ø', () async {
      final created = await run('draw.circle', {
        'center': [0, 0],
        'radius': 5,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.dimDiameter', {
        'target': id,
        'dimLine': [8, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entities.whereType<DimensionEntity>().single;
      expect(dim.measurement, closeTo(10, 1e-9));
      expect(dim.displayText, 'Ø10.00');
    });

    test('angular dimension labels the picked sector', () async {
      final result = await run('draw.dimAngular', {
        'vertex': [0, 0],
        'first': [10, 0],
        'second': [0, 10],
        'dimLine': [4, 4],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entities.first as DimensionEntity;
      expect(dim.measurement, closeTo(90, 1e-9));
      expect(dim.displayText, '90.00°');
    });

    test('angular dimension from two lines uses their intersection', () async {
      final first = await drawLine(-10, 0, 10, 0);
      final second = await drawLine(0, -10, 0, 10);

      final result = await run('draw.dimAngular', {
        'firstLine': first,
        'secondLine': second,
        'dimLine': [4, 4],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entities.whereType<DimensionEntity>().single;
      expect(dim.definitionPoints.first, const Vec2(0, 0));
      expect(dim.measurement, closeTo(90, 1e-9));
      expect(dim.displayText, '90.00°');
    });

    test('angular dimension from an arc uses the centre as vertex', () async {
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [0, 10],
        'end': [-10, 0],
      });
      final arcId = (created.data!['ids']! as List).first as int;

      final result = await run('draw.dimAngular', {
        'arc': arcId,
        'dimLine': [0, 6],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entities.whereType<DimensionEntity>().single;
      expect(dim.definitionPoints.first, const Vec2(0, 0));
      expect(dim.measurement, closeTo(180, 1e-6));
      expect(dim.displayText, '180.00°');
    });

    test('donut creates a wide circular polyline', () async {
      final result = await run('draw.donut', {
        'inside': 6,
        'outside': 10,
        'center': [0, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final donut = document.entities.first as PolylineEntity;
      expect(donut.closed, isTrue);
      expect(donut.constantWidth, closeTo(2, 1e-9));
    });

    test('spline accepts a control-point array', () async {
      final result = await run('draw.spline', {
        'points': [
          [0, 0],
          [1, 2],
          [3, 2],
          [4, 0],
        ],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final spline = document.entities.first as SplineEntity;
      expect(spline.controlPointCount, 4);
      expect(spline.degree, 3);
    });

    test('spline fit interpolates every supplied point', () async {
      final result = await run('draw.spline', {
        'method': 'fit',
        'points': [
          [0, 0],
          [1, 2],
          [3, 1],
          [4, 0],
        ],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final spline = document.entities.first as SplineEntity;
      expect(spline.fitPointBuffer.length, 8);
      expect(spline.fitPointBuffer[2], closeTo(1, 1e-9));
      expect(spline.fitPointBuffer[3], closeTo(2, 1e-9));
      final at = Flatten.bsplineEvaluate(
        controlPoints: spline.controlPoints,
        knots: spline.knots,
        degree: spline.degree,
        t: 0,
      );
      expect(at, const Vec2(0, 0));
    });

    test('ellipse creates a full ellipse from centre and axes', () async {
      final result = await run('draw.ellipse', {
        'center': [0, 0],
        'axisEnd': [10, 0],
        'otherRadius': 4,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final ellipse = document.entities.first as EllipseEntity;
      expect(ellipse.center, const Vec2(0, 0));
      expect(ellipse.ratio, closeTo(0.4, 1e-9));
    });

    test('xline stores an infinite line through two points', () async {
      final result = await run('draw.xline', {
        'origin': [0, 0],
        'through': [10, 5],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final xline = document.entities.first as XLineEntity;
      expect(xline.origin, const Vec2(0, 0));
      expect(xline.direction, const Vec2(10, 5));
    });

    test('xline refuses coincident points', () async {
      final result = await run('draw.xline', {
        'origin': [3, 3],
        'through': [3, 3],
      });

      expect(result.status, CommandStatus.failed);
      expect(document.entityCount, 0);
    });

    test('ray stores a half-line from the origin through a point', () async {
      final result = await run('draw.ray', {
        'origin': [1, 2],
        'through': [4, 6],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final ray = document.entities.first as RayEntity;
      expect(ray.origin, const Vec2(1, 2));
      expect(ray.direction, const Vec2(3, 4));
    });

    test('divide places interior points along a line', () async {
      final id = await drawLine(0, 0, 12, 0);

      final result = await run('draw.divide', {'target': id, 'segments': 3});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 3);
      final points = document.entities.whereType<PointEntity>().toList();
      expect(points, hasLength(2));
      expect(points[0].position.x, closeTo(4, 1e-9));
      expect(points[1].position.x, closeTo(8, 1e-9));
    });

    test('divide places interior points along a polyline', () async {
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.divide', {'target': id, 'segments': 4});

      expect(result.status, CommandStatus.ok, reason: result.message);
      final points = document.entities.whereType<PointEntity>().toList();
      expect(points, hasLength(3));
      expect(points[1].position, const Vec2(10, 0));
    });

    test('divide places points around a circle', () async {
      final created = await run('draw.circle', {
        'center': [0, 0],
        'radius': 5,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.divide', {'target': id, 'segments': 4});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entities.whereType<PointEntity>(), hasLength(4));
    });

    test('divide follows a joined line and arc along the bulge', () async {
      final lineId = await drawLine(0, 0, 10, 0);
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [7.0710678118654755, 7.0710678118654755],
        'end': [0, 10],
      });
      final arcId = (created.data!['ids']! as List).first as int;
      await run('edit.join', {
        'ids': [lineId, arcId],
      });
      final id = document.entities.first.id;

      final result = await run('draw.divide', {'target': id, 'segments': 2});

      expect(result.status, CommandStatus.ok, reason: result.message);
      final points = document.entities.whereType<PointEntity>().toList();
      expect(points, hasLength(1));
      final along = 10 + 5 * 3.141592653589793;
      final mid = along / 2;
      final arcDistance = mid - 10;
      expect(
        points.first.position.x,
        closeTo(10 * math.cos(arcDistance / 10), 1e-6),
      );
      expect(
        points.first.position.y,
        closeTo(10 * math.sin(arcDistance / 10), 1e-6),
      );
    });

    test('divide places an interior point on an arc', () async {
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [0, 10],
        'end': [-10, 0],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.divide', {'target': id, 'segments': 2});

      expect(result.status, CommandStatus.ok, reason: result.message);
      final points = document.entities.whereType<PointEntity>().toList();
      expect(points, hasLength(1));
      expect(points.first.position.y, closeTo(10, 1e-6));
    });

    test('measure places points at a fixed spacing', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('draw.measure', {
        'target': id,
        'spacing': 3,
        'pick': [0, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entities.whereType<PointEntity>(), hasLength(3));
    });

    test('measure places points along a polyline', () async {
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.measure', {
        'target': id,
        'spacing': 6,
        'pick': [0, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final points = document.entities.whereType<PointEntity>().toList();
      expect(points, hasLength(3));
      expect(points[1].position.y, closeTo(2, 1e-9));
    });

    test('measure follows a joined line and arc along the bulge', () async {
      final lineId = await drawLine(0, 0, 10, 0);
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [7.0710678118654755, 7.0710678118654755],
        'end': [0, 10],
      });
      final arcId = (created.data!['ids']! as List).first as int;
      await run('edit.join', {
        'ids': [lineId, arcId],
      });
      final id = document.entities.first.id;

      final result = await run('draw.measure', {
        'target': id,
        'spacing': 10,
        'pick': [0, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final points = document.entities.whereType<PointEntity>().toList();
      expect(points, hasLength(2));
      expect(points[0].position.x, closeTo(10, 1e-6));
      expect(points[1].position.x, closeTo(10 * math.cos(1), 1e-6));
      expect(points[1].position.y, closeTo(10 * math.sin(1), 1e-6));
    });

    test('measure places points around a circle', () async {
      final created = await run('draw.circle', {
        'center': [0, 0],
        'radius': 5,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('draw.measure', {
        'target': id,
        'spacing': 5,
        'pick': [5, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entities.whereType<PointEntity>(), hasLength(6));
    });

    test('new geometry lands on the current layer', () async {
      await run('layer.new', {'name': 'WALLS'});
      await drawLine(0, 0, 1, 0);

      expect(document.entities.first.props.layer, 'WALLS');
    });

    test('UNITS writes \$INSUNITS as a first-class drawing unit', () async {
      expect(document.insUnits, InsUnits.unitless);
      final result = await run('view.units', {'units': 'mm'});
      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.insUnits, InsUnits.millimeters);
      expect(document.headerVariables[r'$INSUNITS'], '4');
    });
  });

  group('editing', () {
    test('move displaces the selection', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.move', {
        'ids': [id],
        'from': [0, 0],
        'to': [0, 5],
      });

      expect(result.status, CommandStatus.ok);
      final moved = document.entity(id)! as LineEntity;
      expect(moved.start, const Vec2(0, 5));
      expect(moved.end, const Vec2(10, 5));
    });

    test('moving a measured line updates the associative dimension', () async {
      final line = await drawLine(0, 0, 10, 0);
      final drawn = await run('draw.dimLinear', {
        'target': line,
        'dimLine': [5, 4],
      });
      expect(drawn.status, CommandStatus.ok, reason: drawn.message);
      final dimId = (drawn.data!['ids']! as List).first as int;

      final moved = await run('edit.move', {
        'ids': [line],
        'from': [0, 0],
        'to': [4, 0],
      });
      expect(moved.status, CommandStatus.ok, reason: moved.message);
      final dim = document.entity(dimId)! as DimensionEntity;
      expect(dim.measurement, closeTo(10, 1e-9));
      expect(dim.definitionPoints[0], const Vec2(4, 0));
      expect(dim.definitionPoints[1], const Vec2(14, 0));
      expect(dim.definitionPoints[2].y, closeTo(4, 1e-9));
    });

    test('stretch moves vertices inside the crossing window', () async {
      final id = await drawLine(-8, 0, 0, 0);

      final result = await run('edit.stretch', {
        'corner1': [-1, -1],
        'corner2': [1, 1],
        'from': [0, 0],
        'to': [0, 4],
        'ids': [id],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final stretched = document.entity(id)! as LineEntity;
      expect(stretched.start, const Vec2(-8, 0));
      expect(stretched.end, const Vec2(0, 4));
    });

    test('copy leaves the original in place', () async {
      final id = await drawLine(0, 0, 10, 0);

      await run('edit.copy', {
        'ids': [id],
        'from': [0, 0],
        'to': [0, 5],
      });

      expect(document.entityCount, 2);
      expect((document.entity(id)! as LineEntity).start, const Vec2(0, 0));
    });

    test('copy places every extra destination from the same base', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.copy', {
        'ids': [id],
        'from': [0, 0],
        'to': [0, 5],
        'destinations': [
          [10, 0],
          [0, 10],
        ],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 4);
      expect(
        document.entities.whereType<LineEntity>().map((line) => line.start),
        containsAll(const [Vec2(0, 0), Vec2(0, 5), Vec2(10, 0), Vec2(0, 10)]),
      );
    });

    test('align rotates the selection to match two point pairs', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.align', {
        'ids': [id],
        'source1': [0, 0],
        'dest1': [0, 0],
        'source2': [10, 0],
        'dest2': [0, 10],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final aligned = document.entity(id)! as LineEntity;
      expect(aligned.start.x, closeTo(0, 1e-9));
      expect(aligned.start.y, closeTo(0, 1e-9));
      expect(aligned.end.x, closeTo(0, 1e-9));
      expect(aligned.end.y, closeTo(10, 1e-9));
    });

    test('rotate turns the selection about the base point', () async {
      final id = await drawLine(0, 0, 10, 0);

      await run('edit.rotate', {
        'ids': [id],
        'base': [0, 0],
        'angle': 90,
      });

      final rotated = document.entity(id)! as LineEntity;
      expect(rotated.end.x, closeTo(0, 1e-9));
      expect(rotated.end.y, closeTo(10, 1e-9));
    });

    test('scale multiplies about the base point', () async {
      final id = await drawLine(0, 0, 10, 0);

      await run('edit.scale', {
        'ids': [id],
        'base': [0, 0],
        'factor': 2,
      });

      expect((document.entity(id)! as LineEntity).end.x, closeTo(20, 1e-9));
    });

    test('mirror keeps the original by default', () async {
      final id = await drawLine(0, 1, 10, 1);

      await run('edit.mirror', {
        'ids': [id],
        'first': [0, 0],
        'second': [10, 0],
      });

      expect(document.entityCount, 2);
      final mirrored = document.entities.last as LineEntity;
      expect(mirrored.start.y, closeTo(-1, 1e-9));
    });

    test('array creates a grid of copies', () async {
      final id = await drawLine(0, 0, 1, 0);

      await run('edit.array', {
        'ids': [id],
        'columns': 3,
        'rows': 2,
        'columnSpacing': 10,
        'rowSpacing': 10,
      });

      expect(document.entityCount, 6);
    });

    test('polar array copies around a centre', () async {
      final id = await drawLine(10, 0, 12, 0);

      final result = await run('edit.polarArray', {
        'ids': [id],
        'center': [0, 0],
        'count': 4,
        'fillAngle': 360,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 4);
      final rotated = document.entities.whereType<LineEntity>().where(
        (line) => line.id != id,
      );
      expect(
        rotated.any(
          (line) =>
              line.start.x.abs() < 1e-9 &&
              (line.start.y - 10).abs() < 1e-9 &&
              (line.end.y - 12).abs() < 1e-9,
        ),
        isTrue,
      );
    });

    test('change lineweight stores hundredths of a millimetre', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.changeLineweight', {
        'ids': [id],
        'weight': '0.25',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entity(id)!.props.lineWeight, 25);
    });

    test('change linetype installs a stock pattern and assigns it', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.changeLinetype', {
        'ids': [id],
        'linetype': 'dashed',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entity(id)!.props.lineType, 'DASHED');
      expect(document.lineTypes['DASHED'], isNotNull);
      expect(document.lineTypes['DASHED']!.pattern, isNotEmpty);
    });

    test('change linetype rejects an unknown name', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.changeLinetype', {
        'ids': [id],
        'linetype': 'NOT-A-TYPE',
      });

      expect(result.status, CommandStatus.failed);
      expect(document.entity(id)!.props.lineType, 'ByLayer');
    });

    test('match properties copies layer and colour onto the target', () async {
      final target = await drawLine(0, 5, 10, 5);
      await run('layer.new', {'name': 'WALLS', 'color': '1'});
      final source = await drawLine(0, 0, 10, 0);
      await run('edit.changeColor', {
        'ids': [source],
        'color': '1',
      });

      final result = await run('edit.matchProp', {
        'source': source,
        'ids': [target],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final painted = document.entity(target)!;
      expect(painted.props.layer, 'WALLS');
      expect(painted.props.color, CadColor.indexed(1));
      expect(document.entity(source)!.props.layer, 'WALLS');
    });

    test('overkill deletes a line drawn twice', () async {
      final keep = await drawLine(0, 0, 10, 0);
      await drawLine(10, 0, 0, 0);

      final result = await run('edit.overkill');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 1);
      expect(document.entity(keep), isNotNull);
    });

    test('overkill folds overlapping collinear lines into one', () async {
      final keep = await drawLine(0, 0, 10, 0);
      await drawLine(5, 0, 15, 0);

      final result = await run('edit.overkill');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 1);
      final grown = document.entity(keep)! as LineEntity;
      expect(grown.start, const Vec2(0, 0));
      expect(grown.end.x, closeTo(15, 1e-9));
    });

    test('erase removes the selection', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.erase', {
        'ids': [id],
      });

      expect(result.status, CommandStatus.ok);
      expect(document.entityCount, 0);
    });

    test('offset creates a parallel copy on the picked side', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.offset', {
        'distance': 2,
        'ids': [id],
        'side': [5, 5],
      });

      expect(result.status, CommandStatus.ok);
      expect(document.entityCount, 2);
      final offset = document.entities.last as LineEntity;
      expect(offset.start.y, closeTo(2, 1e-9));
    });

    test('offset keeps the bulge of a joined line and arc', () async {
      final lineId = await drawLine(0, 0, 10, 0);
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [7.0710678118654755, 7.0710678118654755],
        'end': [0, 10],
      });
      final arcId = (created.data!['ids']! as List).first as int;
      await run('edit.join', {
        'ids': [lineId, arcId],
      });
      final id = document.entities.first.id;

      final result = await run('edit.offset', {
        'distance': 2,
        'ids': [id],
        'side': [0, 5],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final offset = document.entities.last as PolylineEntity;
      expect(offset.hasBulges, isTrue);
      expect(offset.vertexAt(0).y, closeTo(2, 1e-6));
      expect(offset.vertexAt(2).y, closeTo(8, 1e-6));
    });

    test('trim shortens a line back to a cutting edge', () async {
      final target = await drawLine(0, 0, 10, 0);
      final cutter = await drawLine(4, -5, 4, 5);

      final result = await run('edit.trim', {
        'edges': [cutter],
        'target': target,
        'pick': [8, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(target)! as LineEntity).end.x, closeTo(4, 1e-9));
    });

    test('trim shortens a polyline back to a cutting edge', () async {
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
      });
      final target = (created.data!['ids']! as List).first as int;
      final cutter = await drawLine(5, -5, 5, 5);

      final result = await run('edit.trim', {
        'edges': [cutter],
        'target': target,
        'pick': [8, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final polyline = document.entity(target)! as PolylineEntity;
      expect(polyline.vertexCount, 2);
      expect(polyline.vertexAt(1).x, closeTo(5, 1e-9));
    });

    test('trim opens a closed polyline at the picked span', () async {
      final created = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [10, 10],
      });
      final target = (created.data!['ids']! as List).first as int;
      final cutter = await drawLine(5, -5, 5, 15);

      final result = await run('edit.trim', {
        'edges': [cutter],
        'target': target,
        'pick': [10, 5],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final polyline = document.entity(target)! as PolylineEntity;
      expect(polyline.closed, isFalse);
      expect(polyline.vertexAt(0).x, closeTo(5, 1e-9));
      expect(polyline.vertexAt(0).y, closeTo(10, 1e-9));
    });

    test('trim cuts a joined bulge on the arc', () async {
      final lineId = await drawLine(0, 0, 10, 0);
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [7.0710678118654755, 7.0710678118654755],
        'end': [0, 10],
      });
      final arcId = (created.data!['ids']! as List).first as int;
      await run('edit.join', {
        'ids': [lineId, arcId],
      });
      final target = document.entities.first.id;
      final cutter = await drawLine(
        0,
        14.142135623730951,
        14.142135623730951,
        0,
      );

      final result = await run('edit.trim', {
        'edges': [cutter],
        'target': target,
        'pick': [0, 10],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final polyline = document.entity(target)! as PolylineEntity;
      expect(polyline.vertexAt(2).x, closeTo(7.0710678118654755, 1e-6));
      expect(polyline.vertexAt(2).y, closeTo(7.0710678118654755, 1e-6));
      expect(polyline.hasBulges, isTrue);
    });

    test('trim shortens an arc back to a cutting edge', () async {
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [0, 10],
        'end': [-10, 0],
      });
      final target = (created.data!['ids']! as List).first as int;
      final cutter = await drawLine(0, -5, 0, 15);

      final result = await run('edit.trim', {
        'edges': [cutter],
        'target': target,
        'pick': [8, 6],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final arc = document.entity(target)! as ArcEntity;
      expect(arc.startAngle, closeTo(3.141592653589793 / 2, 1e-6));
      expect(arc.endAngle, closeTo(3.141592653589793, 1e-6));
    });

    test('fillet rounds two lines and adds an arc', () async {
      final vertical = await drawLine(0, 10, 0, 0);
      final horizontal = await drawLine(0, 0, 10, 0);

      final result = await run('edit.fillet', {
        'radius': 2,
        'first': vertical,
        'second': horizontal,
        'pick1': [0, 5],
        'pick2': [5, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 3);
      final trimmed = document.entity(vertical)! as LineEntity;
      expect(trimmed.start.y, closeTo(2, 1e-9));
      expect(document.entities.whereType<ArcEntity>(), hasLength(1));
    });

    test('fillet rounds a polyline vertex into a bulge', () async {
      final drawn = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [10, 10],
      });
      expect(drawn.status, CommandStatus.ok);
      final id = (drawn.data!['ids']! as List).first as int;

      final result = await run('edit.fillet', {
        'radius': 2,
        'first': id,
        'pick1': [0, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final polyline = document.entity(id)! as PolylineEntity;
      expect(polyline.vertexCount, 5);
      expect(polyline.vertexAt(0).x, closeTo(0, 1e-9));
      expect(polyline.vertexAt(0).y, closeTo(2, 1e-9));
      expect(polyline.vertexAt(1).x, closeTo(2, 1e-9));
      expect(polyline.vertexAt(1).y, closeTo(0, 1e-9));
    });

    test('fillet all rounds every polyline vertex', () async {
      final drawn = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [10, 10],
      });
      final id = (drawn.data!['ids']! as List).first as int;

      final result = await run('edit.fillet', {
        'radius': 2,
        'first': id,
        'all': true,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final polyline = document.entity(id)! as PolylineEntity;
      expect(polyline.vertexCount, 8);
    });

    test('fillet with zero radius makes a sharp corner', () async {
      final vertical = await drawLine(0, 10, 0, 2);
      final horizontal = await drawLine(2, 0, 10, 0);

      final result = await run('edit.fillet', {
        'radius': 0,
        'first': vertical,
        'second': horizontal,
        'pick1': [0, 6],
        'pick2': [6, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 2);
      expect(
        (document.entity(vertical)! as LineEntity).start,
        const Vec2(0, 0),
      );
    });

    test('chamfer bevels a polyline vertex', () async {
      final drawn = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [10, 10],
      });
      final id = (drawn.data!['ids']! as List).first as int;

      final result = await run('edit.chamfer', {
        'dist1': 2,
        'first': id,
        'pick1': [0, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final polyline = document.entity(id)! as PolylineEntity;
      expect(polyline.vertexCount, 5);
      expect(polyline.vertexAt(0).y, closeTo(2, 1e-9));
      expect(polyline.vertexAt(1).x, closeTo(2, 1e-9));
    });

    test('chamfer all bevels every polyline vertex', () async {
      final drawn = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [10, 10],
      });
      final id = (drawn.data!['ids']! as List).first as int;

      final result = await run('edit.chamfer', {
        'dist1': 2,
        'first': id,
        'all': true,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final polyline = document.entity(id)! as PolylineEntity;
      expect(polyline.vertexCount, 8);
    });

    test('chamfer bevels two lines and adds the cut', () async {
      final vertical = await drawLine(0, 10, 0, 0);
      final horizontal = await drawLine(0, 0, 10, 0);

      final result = await run('edit.chamfer', {
        'dist1': 2,
        'dist2': 2,
        'first': vertical,
        'second': horizontal,
        'pick1': [0, 5],
        'pick2': [5, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 3);
      expect(
        (document.entity(vertical)! as LineEntity).start.y,
        closeTo(2, 1e-9),
      );
    });

    test('break splits a line at a point', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.break', {
        'target': id,
        'first': [4, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 2);
      expect((document.entity(id)! as LineEntity).end.x, closeTo(4, 1e-9));
    });

    test('break removes the portion between two points', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.break', {
        'target': id,
        'first': [2, 0],
        'second': [8, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 2);
      expect((document.entity(id)! as LineEntity).end.x, closeTo(2, 1e-9));
    });

    test('break splits a polyline at a vertex', () async {
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.break', {
        'target': id,
        'first': [10, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 2);
      final remnant = document.entity(id)! as PolylineEntity;
      expect(remnant.vertexCount, 2);
      expect(remnant.vertexAt(1), const Vec2(10, 0));
    });

    test('break splits a bulged polyline at a point on the arc', () async {
      final lineId = await drawLine(0, 0, 10, 0);
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [7.0710678118654755, 7.0710678118654755],
        'end': [0, 10],
      });
      final arcId = (created.data!['ids']! as List).first as int;
      await run('edit.join', {
        'ids': [lineId, arcId],
      });
      final id = document.entities.first.id;

      final result = await run('edit.break', {
        'target': id,
        'first': [7.0710678118654755, 7.0710678118654755],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 2);
      final first = document.entity(id)! as PolylineEntity;
      expect(first.hasBulges, isTrue);
      expect(first.vertexAt(first.vertexCount - 1).y, closeTo(7.071, 1e-3));
    });

    test('break splits an arc at a point', () async {
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [0, 10],
        'end': [-10, 0],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.break', {
        'target': id,
        'first': [0, 10],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 2);
      expect(document.entities.every((each) => each is ArcEntity), isTrue);
    });

    test('lengthen sets the total length from the picked end', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.lengthen', {
        'target': id,
        'pick': [10, 0],
        'total': 16,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(id)! as LineEntity).end.x, closeTo(16, 1e-9));
    });

    test('lengthen extends a polyline from the picked end', () async {
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.lengthen', {
        'target': id,
        'pick': [10, 10],
        'total': 25,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final polyline = document.entity(id)! as PolylineEntity;
      expect(polyline.vertexAt(2).y, closeTo(15, 1e-9));
    });

    test('lengthen grows a joined bulge along its arc', () async {
      final lineId = await drawLine(0, 0, 10, 0);
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [7.0710678118654755, 7.0710678118654755],
        'end': [0, 10],
      });
      final arcId = (created.data!['ids']! as List).first as int;
      await run('edit.join', {
        'ids': [lineId, arcId],
      });
      final id = document.entities.first.id;

      final result = await run('edit.lengthen', {
        'target': id,
        'pick': [0, 10],
        'delta': 5 * 3.141592653589793 / 2,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final polyline = document.entity(id)! as PolylineEntity;
      expect(polyline.vertexAt(2).x, closeTo(-7.0710678118654755, 1e-6));
      expect(polyline.vertexAt(2).y, closeTo(7.0710678118654755, 1e-6));
    });

    test('lengthen extends an arc from the picked end', () async {
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [0, 10],
        'end': [-10, 0],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.lengthen', {
        'target': id,
        'pick': [-10, 0],
        'total': 15 * 3.141592653589793,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final arc = document.entity(id)! as ArcEntity;
      expect(arc.sweep, closeTo(1.5 * 3.141592653589793, 1e-6));
    });

    test('lengthen accepts a signed delta', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.lengthen', {
        'target': id,
        'pick': [0, 0],
        'delta': -2,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(id)! as LineEntity).start.x, closeTo(2, 1e-9));
    });

    test('extend lengthens a line to a boundary', () async {
      final target = await drawLine(0, 0, 5, 0);
      final boundary = await drawLine(10, -5, 10, 5);

      final result = await run('edit.extend', {
        'edges': [boundary],
        'target': target,
        'pick': [4, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(target)! as LineEntity).end.x, closeTo(10, 1e-9));
    });

    test('extend lengthens an arc to a boundary', () async {
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [7.0710678118654755, 7.0710678118654755],
        'end': [0, 10],
      });
      final target = (created.data!['ids']! as List).first as int;
      final boundary = await drawLine(-15, 0, -5, 0);

      final result = await run('edit.extend', {
        'edges': [boundary],
        'target': target,
        'pick': [0, 10],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final arc = document.entity(target)! as ArcEntity;
      expect(arc.startAngle, closeTo(0, 1e-6));
      expect(arc.endAngle, closeTo(3.141592653589793, 1e-6));
    });

    test('extend grows a joined bulge to a boundary', () async {
      final lineId = await drawLine(0, 0, 10, 0);
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [7.0710678118654755, 7.0710678118654755],
        'end': [0, 10],
      });
      final arcId = (created.data!['ids']! as List).first as int;
      await run('edit.join', {
        'ids': [lineId, arcId],
      });
      final target = document.entities.first.id;
      final boundary = await drawLine(-15, 0, -5, 0);

      final result = await run('edit.extend', {
        'edges': [boundary],
        'target': target,
        'pick': [0, 10],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final polyline = document.entity(target)! as PolylineEntity;
      expect(polyline.vertexAt(2).x, closeTo(-10, 1e-6));
      expect(polyline.vertexAt(2).y, closeTo(0, 1e-6));
      expect(polyline.bulgeAt(1), closeTo(1, 1e-6));
    });

    test('extend lengthens a polyline to a boundary', () async {
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 5],
        ],
      });
      final target = (created.data!['ids']! as List).first as int;
      final boundary = await drawLine(5, 10, 15, 10);

      final result = await run('edit.extend', {
        'edges': [boundary],
        'target': target,
        'pick': [10, 5],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(
        (document.entity(target)! as PolylineEntity).vertexAt(2).y,
        closeTo(10, 1e-9),
      );
    });

    test('explode turns a polyline into its segments', () async {
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.explode', {
        'ids': [id],
      });

      expect(result.status, CommandStatus.ok);
      expect(document.entityCount, 2);
      expect(document.entities.every((each) => each is LineEntity), isTrue);
    });

    test('explode turns a dimension into lines, arrows and text', () async {
      final created = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [10, 0],
        'dimLine': [5, 4],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.explode', {
        'ids': [id],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entity(id), isNull);
      expect(document.entities.whereType<LineEntity>(), isNotEmpty);
      expect(document.entities.whereType<TextEntity>().single.content, '10.00');
      expect(document.entities.whereType<SolidEntity>(), hasLength(2));
    });

    test('block replaces a selection with one insert', () async {
      final a = await drawLine(0, 0, 10, 0);
      final b = await drawLine(0, 0, 0, 10);

      final result = await run('edit.block', {
        'ids': [a, b],
        'name': 'CORNER',
        'base': [0, 0],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeEntities, hasLength(1));
      final insert = document.activeEntities.first as InsertEntity;
      expect(insert.blockName, 'CORNER');
      expect(insert.position, const Vec2(0, 0));
      expect(document.blocks['CORNER']!.entityIds, hasLength(2));
      expect(document.blocks['CORNER']!.basePoint, const Vec2(0, 0));
    });

    test('block refuses a name that already exists', () async {
      await drawLine(0, 0, 4, 0);
      await run('edit.block', {
        'ids': [document.activeEntities.first.id],
        'name': 'BOLT',
        'base': [0, 0],
      });
      final extra = await drawLine(8, 0, 12, 0);

      final result = await run('edit.block', {
        'ids': [extra],
        'name': 'bolt',
        'base': [8, 0],
      });

      expect(result.status, CommandStatus.failed);
      expect(result.message, contains('already exists'));
    });

    test('explode restores the objects a block insert draws', () async {
      final a = await drawLine(0, 0, 6, 0);
      final b = await drawLine(0, 2, 6, 2);
      final created = await run('edit.block', {
        'ids': [a, b],
        'name': 'SLOT',
        'base': [0, 0],
      });
      final insertId = (created.data!['ids']! as List).first as int;

      final result = await run('edit.explode', {
        'ids': [insertId],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeEntities.whereType<LineEntity>(), hasLength(2));
      expect(document.activeEntities.whereType<InsertEntity>(), isEmpty);
    });

    test('insert places another reference to a named block', () async {
      final a = await drawLine(0, 0, 4, 0);
      await run('edit.block', {
        'ids': [a],
        'name': 'STUD',
        'base': [0, 0],
      });

      final result = await run('edit.insert', {
        'name': 'stud',
        'at': [20, 5],
        'scale': 2,
        'rotation': 90,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeEntities.whereType<InsertEntity>(), hasLength(2));
      final placed =
          document.entity((result.data!['ids']! as List).first as int)!
              as InsertEntity;
      expect(placed.blockName, 'STUD');
      expect(placed.position, const Vec2(20, 5));
      expect(placed.scale, const Vec2(2, 2));
      expect(placed.rotation, closeTo(math.pi / 2, 1e-9));
    });

    test('insert stamps a block at several points', () async {
      final a = await drawLine(0, 0, 2, 0);
      await run('edit.block', {
        'ids': [a],
        'name': 'PIN',
        'base': [0, 0],
      });

      final result = await run('edit.insert', {
        'name': 'PIN',
        'points': [
          [10, 0],
          [20, 0],
          [30, 0],
        ],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((result.data!['ids']! as List), hasLength(3));
      expect(document.activeEntities.whereType<InsertEntity>(), hasLength(4));
    });

    test('insert refuses an unknown block', () async {
      final result = await run('edit.insert', {
        'name': 'MISSING',
        'at': [0, 0],
      });

      expect(result.status, CommandStatus.failed);
      expect(document.activeEntities, isEmpty);
    });

    test('minsert places a block as one rectangular array', () async {
      final a = await drawLine(0, 0, 2, 0);
      await run('edit.block', {
        'ids': [a],
        'name': 'RIVET',
        'base': [0, 0],
      });

      final result = await run('edit.minsert', {
        'name': 'rivet',
        'at': [10, 4],
        'columns': 3,
        'rows': 2,
        'columnSpacing': 5,
        'rowSpacing': 8,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeEntities.whereType<InsertEntity>(), hasLength(2));
      final grid =
          document.entity((result.data!['ids']! as List).first as int)!
              as InsertEntity;
      expect(grid.blockName, 'RIVET');
      expect(grid.position, const Vec2(10, 4));
      expect(grid.columnCount, 3);
      expect(grid.rowCount, 2);
      expect(grid.columnSpacing, 5);
      expect(grid.rowSpacing, 8);
      expect(grid.isArray, isTrue);
    });

    test('minsert refuses a 1 by 1 grid', () async {
      final a = await drawLine(0, 0, 2, 0);
      await run('edit.block', {
        'ids': [a],
        'name': 'DOT',
        'base': [0, 0],
      });

      final result = await run('edit.minsert', {
        'name': 'DOT',
        'at': [0, 0],
        'columns': 1,
        'rows': 1,
      });

      expect(result.status, CommandStatus.failed);
      expect(document.activeEntities.whereType<InsertEntity>(), hasLength(1));
    });

    test(
      'purge blocks removes a definition with no remaining insert',
      () async {
        final a = await drawLine(0, 0, 4, 0);
        final created = await run('edit.block', {
          'ids': [a],
          'name': 'SCRAP',
          'base': [0, 0],
        });
        final insertId = (created.data!['ids']! as List).first as int;
        await run('edit.explode', {
          'ids': [insertId],
        });
        expect(document.blocks.containsKey('SCRAP'), isTrue);

        final result = await run('block.purge');

        expect(result.status, CommandStatus.ok, reason: result.message);
        expect(document.blocks.containsKey('SCRAP'), isFalse);
        expect(document.insertableBlocks, isEmpty);
      },
    );

    test('purge blocks keeps a definition that still has an insert', () async {
      final a = await drawLine(0, 0, 4, 0);
      await run('edit.block', {
        'ids': [a],
        'name': 'KEEP',
        'base': [0, 0],
      });

      final result = await run('block.purge');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(result.message, contains('No unused'));
      expect(document.blocks.containsKey('KEEP'), isTrue);
    });

    test('rename block updates the definition and every insert', () async {
      final a = await drawLine(0, 0, 4, 0);
      await run('edit.block', {
        'ids': [a],
        'name': 'CORNER',
        'base': [0, 0],
      });
      await run('edit.insert', {
        'name': 'CORNER',
        'at': [20, 0],
      });

      final result = await run('block.rename', {
        'name': 'corner',
        'newName': 'ANGLE',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.blocks.containsKey('CORNER'), isFalse);
      expect(document.blocks['ANGLE']!.entityIds, hasLength(1));
      expect(
        document.activeEntities.whereType<InsertEntity>().every(
          (insert) => insert.blockName == 'ANGLE',
        ),
        isTrue,
      );
      expect(document.activeEntities.whereType<InsertEntity>(), hasLength(2));
    });

    test('rename block refuses a name that already exists', () async {
      final a = await drawLine(0, 0, 2, 0);
      await run('edit.block', {
        'ids': [a],
        'name': 'ONE',
        'base': [0, 0],
      });
      final b = await drawLine(0, 2, 2, 2);
      await run('edit.block', {
        'ids': [b],
        'name': 'TWO',
        'base': [0, 2],
      });

      final result = await run('block.rename', {
        'name': 'ONE',
        'newName': 'two',
      });

      expect(result.status, CommandStatus.failed);
      expect(document.blocks.containsKey('ONE'), isTrue);
      expect(document.blocks.containsKey('TWO'), isTrue);
    });

    test('join merges connected lines into one polyline', () async {
      final a = await drawLine(0, 0, 10, 0);
      final b = await drawLine(10, 0, 10, 10);

      final result = await run('edit.join', {
        'ids': [a, b],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 1);
      expect((document.entities.first as PolylineEntity).vertexCount, 3);
    });

    test('join merges a line onto an open polyline', () async {
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
      });
      final polylineId = (created.data!['ids']! as List).first as int;
      final lineId = await drawLine(10, 10, 20, 10);

      final result = await run('edit.join', {
        'ids': [polylineId, lineId],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 1);
      expect((document.entities.first as PolylineEntity).vertexCount, 4);
    });

    test('join merges a line onto an arc', () async {
      final lineId = await drawLine(0, 0, 10, 0);
      final created = await run('draw.arc', {
        'start': [10, 0],
        'via': [7.0710678118654755, 7.0710678118654755],
        'end': [0, 10],
      });
      final arcId = (created.data!['ids']! as List).first as int;

      final result = await run('edit.join', {
        'ids': [lineId, arcId],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 1);
      final polyline = document.entities.first as PolylineEntity;
      expect(polyline.vertexCount, 3);
      expect(polyline.bulgeAt(1), closeTo(0.41421356237, 1e-6));
    });

    test('join refuses lines that do not touch', () async {
      final a = await drawLine(0, 0, 10, 0);
      final b = await drawLine(50, 50, 60, 50);

      final result = await run('edit.join', {
        'ids': [a, b],
      });

      expect(result.status, CommandStatus.failed);
      expect(document.entityCount, 2);
    });

    test('close marks an open polyline as closed', () async {
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
      });
      final id = (created.data!['ids']! as List).first as int;
      expect((document.entity(id)! as PolylineEntity).closed, isFalse);

      final result = await run('edit.close', {
        'ids': [id],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(id)! as PolylineEntity).closed, isTrue);
    });

    test('close refuses a polyline that is already closed', () async {
      final created = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [4, 3],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.close', {
        'ids': [id],
      });

      expect(result.status, CommandStatus.failed);
    });

    test('convert turns a line into a two-vertex polyline', () async {
      final id = await drawLine(0, 0, 8, 2);

      final result = await run('edit.toPolyline', {
        'ids': [id],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entity(id), isNull);
      final polyline = document.entities.first as PolylineEntity;
      expect(polyline.vertexCount, 2);
      expect(polyline.vertexAt(0), const Vec2(0, 0));
      expect(polyline.vertexAt(1), const Vec2(8, 2));
    });

    test('open drops the closing segment of a polyline', () async {
      final created = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [4, 3],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.open', {
        'ids': [id],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(id)! as PolylineEntity).closed, isFalse);
    });

    test('polyline width stores a constant stroke', () async {
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.polylineWidth', {
        'ids': [id],
        'width': 2,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(id)! as PolylineEntity).constantWidth, 2);
    });

    test('polyline width refuses a line', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.polylineWidth', {
        'ids': [id],
        'width': 2,
      });

      expect(result.status, CommandStatus.failed);
      expect(document.entity(id), isA<LineEntity>());
    });

    test('hatch edit changes pattern scale and angle', () async {
      final created = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [20, 10],
      });
      final boundary = (created.data!['ids']! as List).first as int;
      await run('draw.hatch', {
        'ids': [boundary],
        'pattern': 'ANSI31',
        'scale': 1,
      });
      final hatchId = document.entities.whereType<HatchEntity>().single.id;

      final result = await run('edit.hatch', {
        'ids': [hatchId],
        'scale': 2.5,
        'angle': 45,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final hatch = document.entity(hatchId)! as HatchEntity;
      expect(hatch.patternName, 'ANSI31');
      expect(hatch.patternScale, closeTo(2.5, 1e-9));
      expect(hatch.patternAngle, closeTo(math.pi / 4, 1e-9));

      await run('edit.undo');
      expect(
        (document.entity(hatchId)! as HatchEntity).patternScale,
        closeTo(1, 1e-9),
      );
    });

    test('hatch edit can switch a fill to solid', () async {
      final created = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [10, 10],
      });
      final boundary = (created.data!['ids']! as List).first as int;
      await run('draw.hatch', {
        'ids': [boundary],
        'pattern': 'ANSI31',
      });
      final hatchId = document.entities.whereType<HatchEntity>().single.id;

      final result = await run('edit.hatch', {
        'ids': [hatchId],
        'pattern': 'SOLID',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final hatch = document.entity(hatchId)! as HatchEntity;
      expect(hatch.patternName, 'SOLID');
      expect(hatch.solid, isTrue);
    });

    test('reverse swaps the ends of a line', () async {
      final id = await drawLine(0, 0, 10, 4);

      final result = await run('edit.reverse', {
        'ids': [id],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final reversed = document.entity(id)! as LineEntity;
      expect(reversed.start, const Vec2(10, 4));
      expect(reversed.end, const Vec2(0, 0));
    });

    test('a locked layer refuses edits', () async {
      final id = await drawLine(0, 0, 10, 0);
      await run('layer.toggleLock', {'name': '0', 'locked': true});

      final result = await run('edit.move', {
        'ids': [id],
        'from': [0, 0],
        'to': [0, 5],
      });

      expect(result.status, CommandStatus.failed);
      expect((document.entity(id)! as LineEntity).start, const Vec2(0, 0));
    });
  });

  group('undo', () {
    test('undo and redo walk one command at a time', () async {
      await drawLine(0, 0, 10, 0);
      await drawLine(0, 5, 10, 5);
      expect(document.entityCount, 2);

      await run('edit.undo');
      expect(document.entityCount, 1);

      await run('edit.undo');
      expect(document.entityCount, 0);

      await run('edit.redo');
      expect(document.entityCount, 1);
    });

    test('undo reports failure when the stack is empty', () async {
      final result = await run('edit.undo');
      expect(result.status, CommandStatus.failed);
    });

    test('a rejected command leaves no undo entry', () async {
      await run('draw.circle', {
        'center': [0, 0],
        'radius': -1,
      });
      expect(workspace.active!.history.canUndo, isFalse);
    });
  });

  group('layers', () {
    test(
      'purge deletes unused layers and keeps ones that are occupied',
      () async {
        await run('layer.new', {'name': 'UNUSED'});
        await run('layer.new', {'name': 'USED'});
        await drawLine(0, 0, 1, 0);

        final result = await run('layer.purge');

        expect(result.status, CommandStatus.ok, reason: result.message);
        expect(document.layer('UNUSED'), isNull);
        expect(document.layer('USED'), isNotNull);
        expect(document.layer('0'), isNotNull);
        expect(document.currentLayer, 'USED');
      },
    );

    test('new layer becomes current and is undoable', () async {
      final result = await run('layer.new', {'name': 'DIMS', 'color': '1'});

      expect(result.status, CommandStatus.ok);
      expect(document.currentLayer, 'DIMS');

      await run('edit.undo');
      expect(document.layer('DIMS'), isNull);
      expect(document.currentLayer, '0');
    });

    test('toggling visibility flips the layer state', () async {
      await run('layer.new', {'name': 'GRID'});

      await run('layer.toggleVisible', {'name': 'GRID'});
      expect(document.layer('GRID')!.visible, isFalse);

      await run('layer.toggleVisible', {'name': 'GRID'});
      expect(document.layer('GRID')!.visible, isTrue);
    });

    test('isolate turns off every other layer', () async {
      await run('layer.new', {'name': 'A'});
      await run('layer.new', {'name': 'B'});

      await run('layer.isolate', {'name': 'A'});

      expect(document.layer('A')!.visible, isTrue);
      expect(document.layer('B')!.visible, isFalse);
      expect(document.layer('0')!.visible, isFalse);
    });

    test('isolate hides every object except the selection', () async {
      final keep = await drawLine(0, 0, 10, 0);
      final other = await drawLine(0, 5, 10, 5);

      final result = await run('view.isolateObjects', {
        'ids': [keep],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entity(keep)!.props.visible, isTrue);
      expect(document.entity(other)!.props.visible, isFalse);

      await run('view.unisolateObjects');
      expect(document.entity(other)!.props.visible, isTrue);
    });

    test('hide turns off the selection and unisolate restores it', () async {
      final id = await drawLine(0, 0, 1, 0);

      await run('view.hideObjects', {
        'ids': [id],
      });
      expect(document.entity(id)!.props.visible, isFalse);

      await run('view.unisolateObjects');
      expect(document.entity(id)!.props.visible, isTrue);
    });

    test('layer 0 cannot be deleted', () async {
      final result = await run('layer.delete', {'name': '0'});
      expect(result.status, CommandStatus.failed);
    });

    test(
      'deleting a populated layer is declined without an approver',
      () async {
        await run('layer.new', {'name': 'JUNK'});
        await drawLine(0, 0, 1, 0);

        // Nothing is listening for approvals, so the destructive path must
        // refuse rather than proceed or hang.
        final result = await run('layer.delete', {'name': 'JUNK'});

        expect(result.status, CommandStatus.cancelled);
        expect(document.layer('JUNK'), isNotNull);
        expect(document.entityCount, 1);
      },
    );

    test('deleting a populated layer proceeds once approved', () async {
      await run('layer.new', {'name': 'JUNK'});
      await drawLine(0, 0, 1, 0);
      final subscription = workspace.approvals.listen(
        (request) => request.approve(),
      );
      addTearDown(subscription.cancel);

      final result = await run('layer.delete', {'name': 'JUNK'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.layer('JUNK'), isNull);
      expect(document.entityCount, 0);
      expect(document.currentLayer, '0');
    });

    test('deleting the current layer makes layer 0 current', () async {
      await run('layer.new', {'name': 'TEMP'});
      expect(document.currentLayer, 'TEMP');

      final result = await run('layer.delete', {'name': 'TEMP'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.layer('TEMP'), isNull);
      expect(document.currentLayer, '0');
    });
  });

  group('selection and queries', () {
    test('select all picks up every entity', () async {
      await drawLine(0, 0, 10, 0);
      await drawLine(0, 5, 10, 5);

      await run('select.all');

      expect(workspace.active!.selection.length, 2);
    });

    test('select by layer filters correctly', () async {
      await drawLine(0, 0, 1, 0);
      await run('layer.new', {'name': 'OTHER'});
      await drawLine(0, 1, 1, 1);

      await run('select.byLayer', {'layer': 'OTHER'});

      expect(workspace.active!.selection.length, 1);
    });

    test('select by colour matches the stored colour only', () async {
      await drawLine(0, 0, 1, 0);
      final painted = await drawLine(0, 1, 1, 1);
      await run('edit.changeColor', {
        'ids': [painted],
        'color': '1',
      });

      final result = await run('select.byColor', {'color': '1'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids, [painted]);
    });

    test('select by linetype matches the stored linetype only', () async {
      await drawLine(0, 0, 1, 0);
      final dashed = await drawLine(0, 1, 1, 1);
      await run('edit.changeLinetype', {
        'ids': [dashed],
        'linetype': 'DASHED',
      });

      final result = await run('select.byLinetype', {'linetype': 'dashed'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids, [dashed]);
    });

    test('select by lineweight matches the stored weight only', () async {
      await drawLine(0, 0, 1, 0);
      final thick = await drawLine(0, 1, 1, 1);
      await run('edit.changeLineweight', {
        'ids': [thick],
        'weight': '0.25',
      });

      final result = await run('select.byLineweight', {'weight': '25'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids, [thick]);
    });

    test('select by type keeps only that kind of object', () async {
      await drawLine(0, 0, 1, 0);
      final circle = await run('draw.circle', {
        'center': [0, 0],
        'radius': 3,
      });
      final circleId = (circle.data!['ids']! as List).first as int;

      final result = await run('select.byType', {'kind': 'CIRCLE'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids, [circleId]);
    });

    test('select by type accepts a polyline alias', () async {
      await drawLine(0, 0, 1, 0);
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [2, 0],
          [2, 2],
        ],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('select.byType', {'kind': 'lwpolyline'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids, [id]);
    });

    test('select by type refuses an unknown kind', () async {
      final result = await run('select.byType', {'kind': 'widget'});

      expect(result.status, CommandStatus.failed);
      expect(result.message, contains('not an object type'));
    });

    test('select by block keeps only inserts of that definition', () async {
      final a = await drawLine(0, 0, 2, 0);
      final created = await run('edit.block', {
        'ids': [a],
        'name': 'STUD',
        'base': [0, 0],
      });
      final first = (created.data!['ids']! as List).first as int;
      final extra = await run('edit.insert', {
        'name': 'STUD',
        'at': [10, 0],
      });
      final second = (extra.data!['ids']! as List).first as int;
      final other = await drawLine(0, 4, 2, 4);
      await run('edit.block', {
        'ids': [other],
        'name': 'PIN',
        'base': [0, 4],
      });

      final result = await run('select.byBlock', {'name': 'stud'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids.toSet(), {first, second});
    });

    test('select by block refuses an unknown name', () async {
      final result = await run('select.byBlock', {'name': 'MISSING'});

      expect(result.status, CommandStatus.failed);
      expect(result.message, contains('no insertable block'));
    });

    test('summary reports counts and extents', () async {
      await drawLine(0, 0, 10, 0);
      await run('draw.circle', {
        'center': [0, 0],
        'radius': 5,
      });

      final result = await run('query.summary');

      expect(result.status, CommandStatus.ok);
      expect(result.data!['entityCount'], 2);
      expect((result.data!['byKind']! as Map)['line'], 1);
      expect(result.data!['extents'], isNotNull);
    });

    test('entity query filters by layer, kind and window', () async {
      await drawLine(0, 0, 1, 0);
      await run('draw.circle', {
        'center': [100, 100],
        'radius': 5,
      });

      final byKind = await run('query.entities', {'kind': 'circle'});
      expect(byKind.data!['total'], 1);

      final byWindow = await run('query.entities', {
        'window': [-10, -10, 10, 10],
      });
      expect(byWindow.data!['total'], 1);
      final entities = byWindow.data!['entities']! as List;
      expect((entities.first as Map)['kind'], 'line');
    });

    test('id reports the coordinates of a point', () async {
      final result = await run('query.id', {
        'at': [12.5, -3],
      });

      expect(result.status, CommandStatus.ok);
      expect(result.data!['x'], closeTo(12.5, 1e-9));
      expect(result.data!['y'], closeTo(-3, 1e-9));
      expect(result.message, contains('12.5000'));
    });

    test('angle measures the interior angle at a vertex', () async {
      final result = await run('query.angle', {
        'vertex': [0, 0],
        'first': [10, 0],
        'second': [0, 10],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(result.data!['angle'], closeTo(90, 1e-9));
      expect(result.data!['signed'], closeTo(90, 1e-9));
    });

    test('angle reports a clockwise turn as negative signed', () async {
      final result = await run('query.angle', {
        'vertex': [0, 0],
        'first': [10, 0],
        'second': [0, -10],
      });

      expect(result.data!['angle'], closeTo(90, 1e-9));
      expect(result.data!['signed'], closeTo(-90, 1e-9));
    });

    test('distance reports length and angle', () async {
      final result = await run('query.distance', {
        'from': [0, 0],
        'to': [3, 4],
      });

      expect(result.data!['distance'], closeTo(5, 1e-9));
    });

    test('area measures a closed polyline', () async {
      final created = await run('draw.rectangle', {
        'corner1': [0, 0],
        'corner2': [4, 3],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('query.area', {
        'ids': [id],
      });

      expect(result.data!['area'], closeTo(12, 1e-9));
      expect(result.data!['perimeter'], closeTo(14, 1e-9));
    });
  });

  group('layouts', () {
    test('set layout switches to a paper tab and frames the sheet', () async {
      document.addLayout(
        const Layout(name: 'Layout1', blockName: '*Paper_Space', tabOrder: 1),
      );

      final result = await run('layout.set', {'name': 'Layout1'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'Layout1');
      expect(document.activeLayout.isModelSpace, isFalse);
      expect(document.extents.width, closeTo(297, 1e-9));
    });

    test('new layout opens a paper tab and frames the sheet', () async {
      final result = await run('layout.new');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'Layout1');
      expect(document.activeLayout.isModelSpace, isFalse);
      expect(document.activeLayout.blockName, '*Paper_Space');
      expect(document.extents.width, closeTo(297, 1e-9));
      expect(document.extents.height, closeTo(210, 1e-9));

      await run('edit.undo');
      expect(document.activeLayoutName, 'Model');
      expect(document.layouts, hasLength(1));
    });

    test('new layout accepts a name and a sheet size', () async {
      final result = await run('layout.new', {
        'name': 'A3',
        'width': 420,
        'height': 297,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'A3');
      expect(document.activeLayout.paperWidth, closeTo(420, 1e-9));
      expect(document.activeLayout.paperHeight, closeTo(297, 1e-9));
    });

    test('new layout refuses a duplicate name', () async {
      await run('layout.new');
      final result = await run('layout.new', {'name': 'Layout1'});

      expect(result.status, CommandStatus.failed);
      expect(
        document.layouts.where((item) => !item.isModelSpace),
        hasLength(1),
      );
    });

    test('delete layout removes the current paper tab', () async {
      await run('layout.new');
      final result = await run('layout.delete');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'Model');
      expect(document.layouts.where((item) => !item.isModelSpace), isEmpty);

      await run('edit.undo');
      expect(document.activeLayoutName, 'Layout1');
    });

    test(
      'copy layout duplicates the sheet, viewports and paper entities',
      () async {
        await run('layout.new');
        await run('layout.pagesetup', {'width': 420, 'height': 297});
        await run('layout.mview', {
          'corner1': [10, 10],
          'corner2': [200, 150],
          'scale': 1,
        });
        await drawLine(10, 10, 40, 10);
        expect(document.entitiesOf('*Paper_Space'), hasLength(1));

        final result = await run('layout.copy');

        expect(result.status, CommandStatus.ok, reason: result.message);
        expect(document.activeLayoutName, 'Layout2');
        expect(document.activeLayout.paperWidth, closeTo(420, 1e-9));
        expect(document.activeLayout.paperHeight, closeTo(297, 1e-9));
        expect(document.activeLayout.blockName, '*Paper_Space0');
        expect(document.activeLayout.viewports, hasLength(1));
        expect(
          document.activeLayout.viewports.single.paperBounds,
          const Bounds2(10, 10, 200, 150),
        );
        expect(document.entitiesOf('*Paper_Space0'), hasLength(1));
        expect(document.entitiesOf('*Paper_Space'), hasLength(1));
        expect(
          document.entitiesOf('*Paper_Space').single.id,
          isNot(document.entitiesOf('*Paper_Space0').single.id),
        );

        await run('edit.undo');
        expect(document.activeLayoutName, 'Layout1');
        expect(document.layouts.any((item) => item.name == 'Layout2'), isFalse);
        expect(document.blocks.containsKey('*Paper_Space0'), isFalse);
      },
    );

    test('copy layout refuses the model tab', () async {
      final result = await run('layout.copy', {'name': 'Model'});
      expect(result.status, CommandStatus.failed);
      expect(document.layouts, hasLength(1));
    });

    test('rename layout keeps the sheet and paper entities', () async {
      await run('layout.new');
      await run('layout.pagesetup', {'width': 420, 'height': 297});
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 1,
      });
      await drawLine(10, 10, 40, 10);

      final result = await run('layout.rename', {'to': 'Title'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'Title');
      expect(document.layouts.any((item) => item.name == 'Layout1'), isFalse);
      expect(document.activeLayout.blockName, '*Paper_Space');
      expect(document.activeLayout.paperWidth, closeTo(420, 1e-9));
      expect(document.activeLayout.viewports, hasLength(1));
      expect(document.entitiesOf('*Paper_Space'), hasLength(1));

      await run('edit.undo');
      expect(document.activeLayoutName, 'Layout1');
      expect(document.layouts.any((item) => item.name == 'Title'), isFalse);
      expect(document.entitiesOf('*Paper_Space'), hasLength(1));
    });

    test('rename layout refuses the model tab', () async {
      final result = await run('layout.rename', {
        'name': 'Model',
        'to': 'World',
      });
      expect(result.status, CommandStatus.failed);
      expect(document.activeLayoutName, 'Model');
    });

    test('order layout moves a paper tab and keeps Model first', () async {
      await run('layout.new');
      await run('layout.new');
      await run('layout.new');
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout1', 'Layout2', 'Layout3'],
      );

      final result = await run('layout.order', {'name': 'Layout3', 'index': 0});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout3', 'Layout1', 'Layout2'],
      );
      expect(
        [for (final layout in document.layouts) layout.tabOrder],
        [0, 1, 2, 3],
      );

      await run('edit.undo');
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout1', 'Layout2', 'Layout3'],
      );
    });

    test('order layout can insert before or after another paper tab', () async {
      await run('layout.new');
      await run('layout.new');
      await run('layout.new');

      final before = await run('layout.order', {
        'name': 'Layout3',
        'before': 'Layout2',
      });
      expect(before.status, CommandStatus.ok, reason: before.message);
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout1', 'Layout3', 'Layout2'],
      );

      final after = await run('layout.order', {
        'name': 'Layout1',
        'after': 'Layout2',
      });
      expect(after.status, CommandStatus.ok, reason: after.message);
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout3', 'Layout2', 'Layout1'],
      );
    });

    test('order layout refuses Model', () async {
      await run('layout.new');
      final result = await run('layout.order', {'name': 'Model', 'index': 0});
      expect(result.status, CommandStatus.failed);
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout1'],
      );
    });

    test('rename layout refuses a duplicate name', () async {
      await run('layout.new');
      await run('layout.new');
      final result = await run('layout.rename', {
        'name': 'Layout1',
        'to': 'Layout2',
      });
      expect(result.status, CommandStatus.failed);
      expect(document.layouts.any((item) => item.name == 'Layout1'), isTrue);
    });

    test('copy layout refuses a duplicate name', () async {
      await run('layout.new');
      await run('layout.new');
      final result = await run('layout.copy', {
        'name': 'Layout1',
        'to': 'Layout2',
      });
      expect(result.status, CommandStatus.failed);
    });

    test('delete layout erases paper-space entities', () async {
      await run('layout.new');
      await drawLine(10, 10, 40, 10);
      expect(document.entitiesOf('*Paper_Space'), hasLength(1));

      final result = await run('layout.delete', {'name': 'Layout1'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entitiesOf('*Paper_Space'), isEmpty);
      expect(document.layouts.any((item) => item.name == 'Layout1'), isFalse);
    });

    test('page setup changes the current sheet size', () async {
      await run('layout.new');
      final result = await run('layout.pagesetup', {
        'width': 420,
        'height': 297,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.paperWidth, closeTo(420, 1e-9));
      expect(document.activeLayout.paperHeight, closeTo(297, 1e-9));
      expect(document.extents.width, closeTo(420, 1e-9));

      await run('edit.undo');
      expect(document.activeLayout.paperWidth, closeTo(297, 1e-9));
      expect(document.activeLayout.paperHeight, closeTo(210, 1e-9));
    });

    test('page setup stores a plot rotation', () async {
      await run('layout.new');
      final result = await run('layout.pagesetup', {
        'width': 297,
        'height': 210,
        'rotation': 90,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.plotRotation, 90);

      await run('edit.undo');
      expect(document.activeLayout.plotRotation, 0);
    });

    test('page setup stores a plot window', () async {
      await run('layout.new');
      final result = await run('layout.pagesetup', {
        'width': 297,
        'height': 210,
        'corner1': [10, 20],
        'corner2': [110, 80],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.plotWindow, const Bounds2(10, 20, 110, 80));

      await run('edit.undo');
      expect(document.activeLayout.plotWindow, isNull);
    });

    test('page setup stores plot scale, fit and offset', () async {
      await run('layout.new');
      final result = await run('layout.pagesetup', {
        'width': 297,
        'height': 210,
        'scale': 0.5,
        'offset': [10, 20],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.plotScale, closeTo(0.5, 1e-9));
      expect(document.activeLayout.plotOffsetX, closeTo(10, 1e-9));
      expect(document.activeLayout.plotOffsetY, closeTo(20, 1e-9));
      expect(document.activeLayout.plotFit, isFalse);

      final fitted = await run('layout.pagesetup', {
        'width': 297,
        'height': 210,
        'fit': true,
      });
      expect(fitted.status, CommandStatus.ok, reason: fitted.message);
      expect(document.activeLayout.plotFit, isTrue);
    });

    test('page setup refuses Model', () async {
      final result = await run('layout.pagesetup', {
        'name': 'Model',
        'width': 420,
        'height': 297,
      });

      expect(result.status, CommandStatus.failed);
    });

    test('delete layout refuses Model', () async {
      final result = await run('layout.delete', {'name': 'Model'});

      expect(result.status, CommandStatus.failed);
      expect(document.layouts, hasLength(1));
    });

    test('mview works on a layout created by layout.new', () async {
      await drawLine(0, 0, 80, 0);
      await run('layout.new');
      final result = await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.viewports, hasLength(1));
    });

    test('mview refuses the model tab', () async {
      final result = await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
      });

      expect(result.status, CommandStatus.failed);
      expect(document.activeLayout.viewports, isEmpty);
    });

    test('mview cuts a window that frames the model', () async {
      await drawLine(0, 0, 80, 0);
      document.addLayout(
        const Layout(name: 'Layout1', blockName: '*Paper_Space', tabOrder: 1),
      );
      await run('layout.set', {'name': 'Layout1'});

      final result = await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.viewports, hasLength(1));
      final viewport = document.activeLayout.viewports.single;
      expect(viewport.paperBounds, const Bounds2(10, 10, 200, 150));
      expect(viewport.modelCenter.x, closeTo(40, 1e-9));
      expect(viewport.scale, closeTo(190 / 80, 1e-9));

      await run('edit.undo');
      expect(document.activeLayout.viewports, isEmpty);
    });

    test('vpscale changes the only viewport on the sheet', () async {
      await run('layout.new');
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 1,
      });

      final result = await run('layout.vpscale', {'scale': 0.5});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.viewports.single.scale, closeTo(0.5, 1e-9));

      await run('edit.undo');
      expect(document.activeLayout.viewports.single.scale, closeTo(1, 1e-9));
    });

    test('vpscale fit frames the model again', () async {
      await drawLine(0, 0, 80, 0);
      await run('layout.new');
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 1,
      });

      final result = await run('layout.vpscale', {'fit': true});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(
        document.activeLayout.viewports.single.scale,
        closeTo(190 / 80, 1e-9),
      );
      expect(
        document.activeLayout.viewports.single.modelCenter.x,
        closeTo(40, 1e-9),
      );
    });

    test('vpscale refuses a locked viewport', () async {
      await run('layout.new');
      final layout = document.activeLayout;
      document.addLayout(
        layout.copyWith(
          viewports: const [
            PaperViewport(
              paperBounds: Bounds2(10, 10, 200, 150),
              modelCenter: Vec2.zero(),
              scale: 1,
              locked: true,
            ),
          ],
        ),
      );

      final result = await run('layout.vpscale', {'scale': 0.25});

      expect(result.status, CommandStatus.failed);
      expect(document.activeLayout.viewports.single.scale, closeTo(1, 1e-9));
    });

    test('vpscale refuses the model tab', () async {
      final result = await run('layout.vpscale', {'scale': 1});
      expect(result.status, CommandStatus.failed);
    });

    test('vplock toggles the only viewport and blocks vpscale', () async {
      await run('layout.new');
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 1,
      });

      final locked = await run('layout.vplock');
      expect(locked.status, CommandStatus.ok, reason: locked.message);
      expect(document.activeLayout.viewports.single.locked, isTrue);

      final refused = await run('layout.vpscale', {'scale': 0.25});
      expect(refused.status, CommandStatus.failed);
      expect(document.activeLayout.viewports.single.scale, closeTo(1, 1e-9));

      final unlocked = await run('layout.vplock', {'locked': false});
      expect(unlocked.status, CommandStatus.ok, reason: unlocked.message);
      expect(document.activeLayout.viewports.single.locked, isFalse);

      final scaled = await run('layout.vpscale', {'scale': 0.25});
      expect(scaled.status, CommandStatus.ok, reason: scaled.message);
      expect(document.activeLayout.viewports.single.scale, closeTo(0.25, 1e-9));

      await run('edit.undo');
      await run('edit.undo');
      expect(document.activeLayout.viewports.single.locked, isTrue);
    });

    test('vplock refuses the model tab', () async {
      final result = await run('layout.vplock', {'locked': true});
      expect(result.status, CommandStatus.failed);
    });

    test(
      'vpon toggles the only viewport and refuses vpmax while off',
      () async {
        await run('layout.new');
        await run('layout.mview', {
          'corner1': [10, 10],
          'corner2': [200, 150],
          'scale': 1,
        });

        final off = await run('layout.vpon');
        expect(off.status, CommandStatus.ok, reason: off.message);
        expect(document.activeLayout.viewports.single.isOn, isFalse);

        final refused = await run('layout.vpmax');
        expect(refused.status, CommandStatus.failed);
        expect(document.activeLayout.isModelSpace, isFalse);

        final on = await run('layout.vpon', {'on': true});
        expect(on.status, CommandStatus.ok, reason: on.message);
        expect(document.activeLayout.viewports.single.isOn, isTrue);

        await run('edit.undo');
        expect(document.activeLayout.viewports.single.isOn, isFalse);
      },
    );

    test('vpon refuses the model tab', () async {
      final result = await run('layout.vpon', {'on': false});
      expect(result.status, CommandStatus.failed);
    });

    test('vplayer freezes a layer in the only viewport', () async {
      await run('layer.new', {'name': 'DIMS'});
      await run('layout.new');
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 1,
      });

      final frozen = await run('layout.vplayer', {'layers': 'DIMS'});
      expect(frozen.status, CommandStatus.ok, reason: frozen.message);
      expect(document.activeLayout.viewports.single.frozenLayers, ['DIMS']);

      final thawed = await run('layout.vplayer', {
        'layers': 'DIMS',
        'freeze': false,
      });
      expect(thawed.status, CommandStatus.ok, reason: thawed.message);
      expect(document.activeLayout.viewports.single.frozenLayers, isEmpty);

      await run('edit.undo');
      expect(document.activeLayout.viewports.single.frozenLayers, ['DIMS']);
    });

    test('vplayer refuses the model tab', () async {
      await run('layer.new', {'name': 'DIMS'});
      final result = await run('layout.vplayer', {'layers': 'DIMS'});
      expect(result.status, CommandStatus.failed);
    });

    test('vpmax opens model space through the viewport', () async {
      await run('layout.new');
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 0.5,
      });

      final result = await run('layout.vpmax');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.isModelSpace, isTrue);
      expect(workspace.active!.session.maximizedLayoutName, 'Layout1');
      expect(workspace.active!.session.maximizedViewportIndex, 0);

      final back = await run('layout.vpmin');
      expect(back.status, CommandStatus.ok, reason: back.message);
      expect(document.activeLayoutName, 'Layout1');
      expect(workspace.active!.session.maximizedLayoutName, isNull);
    });

    test('vpmax refuses the model tab', () async {
      final result = await run('layout.vpmax');
      expect(result.status, CommandStatus.failed);
    });

    test('vpmin refuses when nothing is maximized', () async {
      final result = await run('layout.vpmin');
      expect(result.status, CommandStatus.failed);
    });

    test('mview honours an explicit scale', () async {
      document.addLayout(
        const Layout(name: 'Layout1', blockName: '*Paper_Space', tabOrder: 1),
      );
      await run('layout.set', {'name': 'Layout1'});

      final result = await run('layout.mview', {
        'corner1': [0, 0],
        'corner2': [100, 80],
        'scale': 0.1,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.viewports.single.scale, closeTo(0.1, 1e-12));
    });
  });

  group('plot', () {
    test('plots a named paper layout without switching tabs', () async {
      await run('layout.new', {'name': 'A3', 'width': 420, 'height': 297});
      await run('layout.set', {'name': 'Model'});
      final dir = Directory.systemTemp.createTempSync('fancad_plot');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/sheet.svg';

      final result = await run('print.exportSvg', {
        'path': path,
        'layout': 'A3',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'Model');
      expect(result.data!['layout'], 'A3');
      final svg = File(path).readAsStringSync();
      expect(svg, contains('width="420'));
      expect(svg, contains('height="297'));
    });

    test('plot honours a window on the named layout', () async {
      await run('layout.new', {'name': 'A3', 'width': 420, 'height': 297});
      final dir = Directory.systemTemp.createTempSync('fancad_plot');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/window.svg';

      final result = await run('print.exportSvg', {
        'path': path,
        'layout': 'A3',
        'corner1': [10, 20],
        'corner2': [110, 80],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final svg = File(path).readAsStringSync();
      expect(svg, contains('width="100'));
      expect(svg, contains('height="60'));
    });

    test('plot refuses an unknown layout', () async {
      final result = await run('print.exportSvg', {
        'path': '/tmp/out.svg',
        'layout': 'Missing',
      });
      expect(result.status, CommandStatus.failed);
    });
  });

  group('xrefs', () {
    test('attach places an insert in model space', () async {
      final dir = Directory.systemTemp.createTempSync('fancad_xref');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/bracket.dxf';
      final foreign = CadDocument()
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
        );
      File(path).writeAsStringSync(const DxfWriter().writeString(foreign));

      final result = await run('xref.attach', {
        'path': path,
        'at': [5, 6],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.blocks['BRACKET']!.isXref, isTrue);
      final insert = document.activeEntities.whereType<InsertEntity>().single;
      expect(insert.blockName, 'BRACKET');
      expect(insert.position, const Vec2(5, 6));
    });

    test('reload rereads the file and keeps the insert', () async {
      final dir = Directory.systemTemp.createTempSync('fancad_xref');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/part.dxf';
      File(path).writeAsStringSync(
        const DxfWriter().writeString(
          CadDocument()..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          ),
        ),
      );

      await run('xref.attach', {
        'path': path,
        'at': [3, 4],
      });
      final insertId = document.activeEntities
          .whereType<InsertEntity>()
          .single
          .id;

      File(path).writeAsStringSync(
        const DxfWriter().writeString(
          CadDocument()..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(20, 0)),
          ),
        ),
      );

      final result = await run('xref.reload');

      expect(result.status, CommandStatus.ok, reason: result.message);
      final insert = document.entity(insertId)! as InsertEntity;
      expect(insert.position, const Vec2(3, 4));
      final line =
          document.entity(document.blocks['PART']!.entityIds.single)!
              as LineEntity;
      expect(line.end.x, closeTo(20, 1e-9));
    });

    test('reload refuses when there is no xref', () async {
      final result = await run('xref.reload');
      expect(result.status, CommandStatus.failed);
    });

    test('reload refuses a missing file', () async {
      final dir = Directory.systemTemp.createTempSync('fancad_xref');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/gone.dxf';
      File(path).writeAsStringSync(
        const DxfWriter().writeString(
          CadDocument()..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          ),
        ),
      );
      await run('xref.attach', {'path': path});
      File(path).deleteSync();

      final result = await run('xref.reload');

      expect(result.status, CommandStatus.failed);
      expect(document.blocks['GONE']!.entityIds, hasLength(1));
    });

    test('detach removes the insert and the xref block', () async {
      final dir = Directory.systemTemp.createTempSync('fancad_xref');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/part.dxf';
      File(path).writeAsStringSync(
        const DxfWriter().writeString(
          CadDocument()..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          ),
        ),
      );
      await run('xref.attach', {
        'path': path,
        'at': [3, 4],
      });

      final result = await run('xref.detach');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.blocks.containsKey('PART'), isFalse);
      expect(document.activeEntities.whereType<InsertEntity>(), isEmpty);

      await run('edit.undo');
      expect(document.blocks['PART']!.isXref, isTrue);
      expect(
        document.activeEntities.whereType<InsertEntity>().single.position,
        const Vec2(3, 4),
      );
    });

    test('detach refuses when there is no xref', () async {
      final result = await run('xref.detach');
      expect(result.status, CommandStatus.failed);
    });

    test('bind keeps the insert and drops the file path', () async {
      final dir = Directory.systemTemp.createTempSync('fancad_xref');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/part.dxf';
      File(path).writeAsStringSync(
        const DxfWriter().writeString(
          CadDocument()..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          ),
        ),
      );
      await run('xref.attach', {
        'path': path,
        'at': [3, 4],
      });

      final result = await run('xref.bind');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.blocks['PART']!.isXref, isFalse);
      expect(
        document.activeEntities.whereType<InsertEntity>().single.position,
        const Vec2(3, 4),
      );

      final reload = await run('xref.reload');
      expect(reload.status, CommandStatus.failed);
    });

    test('bind refuses when there is no xref', () async {
      final result = await run('xref.bind');
      expect(result.status, CommandStatus.failed);
    });
  });

  group('registry contract', () {
    test('every alias resolves to its command', () {
      for (final descriptor in workspace.commands.all) {
        for (final alias in descriptor.aliases) {
          expect(
            workspace.commands.find(alias)?.id,
            descriptor.id,
            reason: 'alias "$alias" should resolve to ${descriptor.id}',
          );
        }
      }
    });

    test('every command exposes a valid tool schema', () {
      for (final descriptor in workspace.commands.all) {
        final schema = descriptor.toolSchema();
        expect(schema['type'], 'object');
        expect(schema['properties'], isA<Map<String, Object?>>());
        // A tool name with a dot in it is rejected by some providers, so the
        // normalisation has to actually happen.
        expect(descriptor.toolName, isNot(contains('.')));
      }
    });

    test('an unknown command fails rather than throwing', () async {
      final result = await run('does.not.exist');
      expect(result.status, CommandStatus.failed);
    });
  });
}
