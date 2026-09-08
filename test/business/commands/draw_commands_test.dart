import 'dart:math' as math;

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workspace.dart';

late Headless app;

CadDocument get document => app.document;

Workspace get workspace => app.workspace;

Future<CommandResult> run(String id, [Map<String, Object?> args = const {}]) =>
    app.run(id, args);

Future<int> drawLine(double x1, double y1, double x2, double y2) =>
    app.drawLine(x1, y1, x2, y2);

void main() {
  setUp(() {
    app = Headless();
  });

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
      expect(result.data!['ids']! as List, hasLength(2));
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
      expect(result.data!['ids']! as List, hasLength(2));
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
  });
}
