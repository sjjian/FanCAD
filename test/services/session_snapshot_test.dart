import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/workspace.dart';

void main() {
  test('an empty workspace has no session to describe', () async {
    final app = Headless(document: false);
    final result = await app.workspace.runHeadless('query.session');
    expect(result.status, CommandStatus.failed);
    expect(result.message, contains('No drawing'));
  });

  test(
    'session statistics report the pick count and camera, not geometry',
    () async {
      final app = Headless();
      app.workspace.active!.viewport.setSize(const Size(800, 600), 1);
      final created = await app.run('draw.line', {
        'start': [0, 0],
        'end': [10, 0],
      });
      final id = (created.data!['ids']! as List).first as int;
      app.workspace.active!.selection.replace([id]);

      final result = await app.run('query.session');
      expect(result.status, CommandStatus.ok, reason: result.message);
      final data = result.data!;
      expect(data['selectionCount'], 1);
      expect(data['drawingId'], app.workspace.active!.session.id);
      expect(data['viewport'], isA<Map<Object?, Object?>>());
      expect(data['lastCreatedIds'], contains(id));
      expect(data.containsKey('entities'), isFalse);
      expect(result.message, contains('1 selected'));
      expect(result.message, contains('Running command: none'));
    },
  );

  test('an idle session omits a running command', () async {
    final app = Headless();
    final result = await app.run('query.session');
    expect(result.data!.containsKey('runningCommand'), isFalse);
    expect(result.data!['selectionCount'], 0);
    expect(result.message, contains('Nothing selected'));
  });

  test(
    'a background drawing is described without bringing it forward',
    () async {
      final app = Headless();
      final first = app.workspace.active!;
      first.session.title = 'Alpha';
      final second = app.workspace.newDocument(title: 'Beta');
      expect(app.workspace.active, same(second));

      final result = await app.workspace.runHeadless(
        'query.session',
        session: first.session,
      );
      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(result.data!['drawingId'], first.session.id);
      expect(result.data!['title'], 'Alpha');
      expect(result.data!['title'], isNot('Beta'));
      expect(app.workspace.active, same(second));
    },
  );
}
