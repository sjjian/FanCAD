import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workspace.dart';

late Headless app;

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
  });
}
