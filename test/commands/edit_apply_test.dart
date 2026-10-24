import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/workspace.dart';

void main() {
  late Headless app;

  setUp(() {
    app = Headless();
  });

  test('edit.apply adds two circles in one undo entry', () async {
    final history = app.workspace.active!.session.history;
    final before = history.depth;
    final result = await app.run('edit.apply', {
      'label': 'rings',
      'operations': [
        {
          'op': 'add',
          'kind': 'circle',
          'center': [0, 0],
          'radius': 1,
        },
        {
          'op': 'add',
          'kind': 'circle',
          'center': [0, 0],
          'radius': 2,
        },
      ],
    });

    expect(result.status, CommandStatus.ok, reason: result.message);
    expect(app.document.entityCount, 2);
    expect(history.depth, before + 1);
    expect(result.data!['created'], hasLength(2));
    expect(result.data!['label'], 'rings');
  });

  test(
    'edit.apply rejects an unknown operation without changing the drawing',
    () async {
      final result = await app.run('edit.apply', {
        'operations': [
          {
            'op': 'add',
            'kind': 'circle',
            'center': [0, 0],
            'radius': 1,
          },
          {'op': 'nope'},
        ],
      });
      expect(result.status, CommandStatus.failed);
      expect(app.document.entityCount, 0);
    },
  );
}
