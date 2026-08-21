import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_ui/fancad_ui.dart';
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
      settings: SettingsStore.inMemory(),
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

    test('new geometry lands on the current layer', () async {
      await run('layer.new', {'name': 'WALLS'});
      await drawLine(0, 0, 1, 0);

      expect(document.entities.first.props.layer, 'WALLS');
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

    test('erase removes the selection', () async {
      final id = await drawLine(0, 0, 10, 0);

      final result = await run('edit.erase', {'ids': [id]});

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
      expect((document.entity(vertical)! as LineEntity).start, const Vec2(0, 0));
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
      expect((document.entity(vertical)! as LineEntity).start.y, closeTo(2, 1e-9));
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

    test('explode turns a polyline into its segments', () async {
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [10, 0],
          [10, 10],
        ],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.explode', {'ids': [id]});

      expect(result.status, CommandStatus.ok);
      expect(document.entityCount, 2);
      expect(document.entities.every((each) => each is LineEntity), isTrue);
    });

    test('join merges connected lines into one polyline', () async {
      final a = await drawLine(0, 0, 10, 0);
      final b = await drawLine(10, 0, 10, 10);

      final result = await run('edit.join', {'ids': [a, b]});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entityCount, 1);
      expect((document.entities.first as PolylineEntity).vertexCount, 3);
    });

    test('join refuses lines that do not touch', () async {
      final a = await drawLine(0, 0, 10, 0);
      final b = await drawLine(50, 50, 60, 50);

      final result = await run('edit.join', {'ids': [a, b]});

      expect(result.status, CommandStatus.failed);
      expect(document.entityCount, 2);
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
      await run('draw.circle', {'center': [0, 0], 'radius': -1});
      expect(workspace.active!.history.canUndo, isFalse);
    });
  });

  group('layers', () {
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

    test('layer 0 cannot be deleted', () async {
      final result = await run('layer.delete', {'name': '0'});
      expect(result.status, CommandStatus.failed);
    });

    test('deleting a populated layer is declined without an approver', () async {
      await run('layer.new', {'name': 'JUNK'});
      await drawLine(0, 0, 1, 0);

      // Nothing is listening for approvals, so the destructive path must
      // refuse rather than proceed or hang.
      final result = await run('layer.delete', {'name': 'JUNK'});

      expect(result.status, CommandStatus.cancelled);
      expect(document.layer('JUNK'), isNotNull);
      expect(document.entityCount, 1);
    });

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

    test('summary reports counts and extents', () async {
      await drawLine(0, 0, 10, 0);
      await run('draw.circle', {'center': [0, 0], 'radius': 5});

      final result = await run('query.summary');

      expect(result.status, CommandStatus.ok);
      expect(result.data!['entityCount'], 2);
      expect((result.data!['byKind']! as Map)['line'], 1);
      expect(result.data!['extents'], isNotNull);
    });

    test('entity query filters by layer, kind and window', () async {
      await drawLine(0, 0, 1, 0);
      await run('draw.circle', {'center': [100, 100], 'radius': 5});

      final byKind = await run('query.entities', {'kind': 'circle'});
      expect(byKind.data!['total'], 1);

      final byWindow = await run('query.entities', {
        'window': [-10, -10, 10, 10],
      });
      expect(byWindow.data!['total'], 1);
      final entities = byWindow.data!['entities']! as List;
      expect((entities.first as Map)['kind'], 'line');
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

      final result = await run('query.area', {'ids': [id]});

      expect(result.data!['area'], closeTo(12, 1e-9));
      expect(result.data!['perimeter'], closeTo(14, 1e-9));
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
