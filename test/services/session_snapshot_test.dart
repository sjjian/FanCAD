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
    expect(snapshot.describe(), isNot(contains('selection: none')));
  });
}
