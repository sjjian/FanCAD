import 'dart:ui';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workspace.dart';

late Headless app;

Workspace get workspace => app.workspace;

Future<CommandResult> run(String id, [Map<String, Object?> args = const {}]) =>
    app.run(id, args);

Future<int> drawLine(double x1, double y1, double x2, double y2) =>
    app.drawLine(x1, y1, x2, y2);

void main() {
  setUp(() {
    app = Headless();
  });

  group('queries', () {
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

    test('list cancels when nothing is selected', () async {
      final result = await run('query.list');
      expect(result.status, CommandStatus.cancelled);
    });

    test('list reports geometry for the selected objects', () async {
      final created = await run('draw.line', {
        'start': [0, 0],
        'end': [4, 0],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('query.list', {
        'ids': [id],
      });
      expect(result.status, CommandStatus.ok, reason: result.message);
      final entities = result.data!['entities']! as List;
      final record = entities.single as Map;
      expect(record['kind'], 'line');
      expect(record['length'], closeTo(4, 1e-9));
      expect(record['start'], [0.0, 0.0]);
    });

    test('query.selection reports none or the current pick', () async {
      final empty = await run('query.selection');
      expect(empty.status, CommandStatus.ok);
      expect(empty.data!['count'], 0);
      expect(empty.message, contains('Nothing is selected'));

      final created = await run('draw.circle', {
        'center': [2, 2],
        'radius': 1,
      });
      final id = (created.data!['ids']! as List).first as int;
      workspace.active!.selection.replace([id]);

      final picked = await run('query.selection');
      expect(picked.status, CommandStatus.ok);
      expect(picked.data!['count'], 1);
      final record = (picked.data!['entities']! as List).single as Map;
      expect(record['id'], id);
      expect(record['kind'], 'circle');
      expect(record['radius'], closeTo(1, 1e-9));
    });

    test('query.viewport returns the active camera window', () async {
      workspace.active!.viewport.setSize(const Size(800, 600), 1);
      final result = await run('query.viewport');
      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(result.data!['scale'], isA<num>());
      expect(result.data!['center'], isA<List<Object?>>());
      expect(result.data!['visible'], isA<List<Object?>>());
      expect(result.data!['visible']! as List, hasLength(4));
    });

    test(
      'layers reports the current layer and how many objects sit on it',
      () async {
        await run('draw.line', {
          'start': [0, 0],
          'end': [1, 0],
        });
        workspace.active!.session.edit('layer', (Transaction transaction) {
          transaction.putLayer(const LayerDef(name: 'Notes', locked: true));
        });

        final result = await run('query.layers');
        expect(result.status, CommandStatus.ok);
        final layers = (result.data!['layers']! as List)
            .cast<Map<String, Object?>>();
        final zero = layers.firstWhere((layer) => layer['name'] == '0');
        expect(zero['current'], isTrue);
        expect(zero['count'], 1);
        final notes = layers.firstWhere((layer) => layer['name'] == 'Notes');
        expect(notes['locked'], isTrue);
        expect(notes['count'], 0);
      },
    );

    test('query.selection is palette-visible and read_skill is not', () {
      expect(
        workspace.commands.find('query.selection')?.title,
        'Query Selection',
      );
      expect(workspace.commands.find('query.viewport')?.title, 'Query Viewport');
      expect(workspace.commands.find('read_skill'), isNull);
      expect(workspace.commands.findByToolName('read_skill'), isNull);
      expect(
        workspace.commands.search('query.selection').map((item) => item.id),
        contains('query.selection'),
      );
      expect(
        workspace.commands.search('read_skill').map((item) => item.id),
        isEmpty,
      );
      expect(
        workspace.commands.aiTools().map((item) => item.id),
        containsAll(['query.selection', 'query.viewport']),
      );
    });
  });
}
