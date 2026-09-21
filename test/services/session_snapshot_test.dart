import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/workspace.dart';

void main() {
  test('an empty leftover workspace reports selection none', () {
    final app = Headless(document: false);
    final snapshot = collectSessionSnapshot(app.workspace);
    expect(snapshot.describe(), contains('selection: none'));
    expect(snapshot.describe(), contains('viewport: unknown'));
    expect(snapshot.describe(), contains('drawing: none'));
  });

  test('a leftover pick and camera land in the snapshot', () async {
    final app = Headless();
    app.workspace.active!.viewport.setSize(const Size(800, 600), 1);
    final created = await app.run('draw.line', {
      'start': [0, 0],
      'end': [10, 0],
    });
    final id = (created.data!['ids']! as List).first as int;
    app.workspace.active!.selection.replace([id]);

    final snapshot = collectSessionSnapshot(app.workspace);
    expect(snapshot.selectionCount, 1);
    expect(snapshot.selection.single.id, id);
    expect(snapshot.selection.single.kind, 'line');
    expect(snapshot.viewport, isNotNull);
    expect(snapshot.describe(), contains('#$id line'));
    expect(
      snapshot.describe(),
      contains('tab=${app.workspace.active!.session.id}'),
    );
    expect(snapshot.describe(), isNot(contains('selection: none')));
    expect(snapshot.describe(), contains('running command: none'));
    expect(snapshot.describe(), contains('last created: $id'));
  });

  test('a leftover running command is listed as awareness, not a license', () {
    final app = Headless();
    app.workspace.newDocument();
    // runningCommand is null until run() is in flight.
    final snapshot = collectSessionSnapshot(app.workspace);
    expect(snapshot.runningCommand, isNull);
    expect(snapshot.describe(), contains('running command: none'));
  });

  test('a background drawing can be described without bringing it forward', () {
    final app = Headless();
    final first = app.workspace.active!;
    first.session.title = 'Alpha';
    final second = app.workspace.newDocument(title: 'Beta');
    expect(app.workspace.active, same(second));

    final snapshot = collectSessionSnapshot(app.workspace, drawing: first);
    expect(snapshot.drawingId, first.session.id);
    expect(snapshot.describe(), contains('Alpha'));
    expect(snapshot.describe(), isNot(contains('Beta')));
    expect(app.workspace.active, same(second));
  });
}
