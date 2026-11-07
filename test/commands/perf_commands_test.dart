import 'package:fancad_command/fancad_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/workspace.dart';

void main() {
  test('perf.session reports renderer and frame statistics', () async {
    final app = Headless();
    final result = await app.run('perf.session');

    expect(result.status, CommandStatus.ok, reason: result.message);
    expect(result.data!['supported'], isTrue);
    expect(result.data!['drawingId'], app.workspace.active!.session.id);
    expect(result.data!['viewport'], isA<Map<Object?, Object?>>());

    final render = result.data!['render']! as Map<Object?, Object?>;
    expect(render['retained'], isA<bool>());
    expect(render['segments'], isA<num>());
    expect(render['drawnSegments'], isA<num>());
    expect(render['blockCache'], isA<Map<Object?, Object?>>());

    final frame = result.data!['frame']! as Map<Object?, Object?>;
    expect(frame['samples'], isA<num>());
    expect(frame['buildP50Ms'], isA<num>());
    expect(frame['rasterP50Ms'], isA<num>());
  });

  test('query.session no longer carries renderer diagnostics', () async {
    final app = Headless();
    final result = await app.run('query.session');

    expect(result.status, CommandStatus.ok, reason: result.message);
    expect(result.data!.containsKey('render'), isFalse);
    expect(result.data!.containsKey('frame'), isFalse);
  });

  test(
    'perf.reset clears the frame window without touching the drawing',
    () async {
      final app = Headless();
      final id = await app.drawLine(0, 0, 10, 0);

      final result = await app.run('perf.reset', {'regen': false});
      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(result.data!['cleared'], isTrue);
      expect(result.data!['regen'], isFalse);
      expect(app.document.entityCount, 1);
      expect(app.document.entity(id), isNotNull);
    },
  );
}
