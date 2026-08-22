import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DocumentTab newTab() => DocumentTab(
        session: DocumentSession(id: 't', document: CadDocument()),
        diagnostics: const ['layer 0 renamed'],
      );

  test('prompt and grid skip notify when the value did not change', () {
    final tab = newTab();
    addTearDown(tab.dispose);
    var ticks = 0;
    tab.addListener(() => ticks++);

    tab.setPrompt('Specify first point');
    expect(tab.prompt, 'Specify first point');
    expect(ticks, 1);
    tab.setPrompt('Specify first point');
    expect(ticks, 1);

    expect(tab.showGrid, isTrue);
    tab.setShowGrid(false);
    expect(tab.showGrid, isFalse);
    expect(ticks, 2);
    tab.setShowGrid(false);
    expect(ticks, 2);

    tab.setIsolatedLayers({'0'});
    expect(tab.isolatedLayers, {'0'});
    expect(ticks, 3);
  });

  test('a document edit and invalidateAll share the geometry drop hook', () {
    final tab = newTab();
    addTearDown(tab.dispose);
    final dropped = <DocumentChange>[];
    tab.onGeometryInvalidated = dropped.add;

    tab.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    });
    expect(tab.isDirty, isTrue);
    expect(tab.document.entities, hasLength(1));
    expect(dropped, isNotEmpty);

    tab.invalidateAll();
    expect(dropped.last.tablesChanged, isTrue);
    expect(dropped.last.requiresFullRegeneration, isTrue);
  });

  test('markSaved clears dirty and a selection change wakes the tab', () {
    final tab = newTab();
    addTearDown(tab.dispose);
    expect(tab.diagnostics, ['layer 0 renamed']);
    expect(tab.title, 'Drawingt');

    var ticks = 0;
    tab.addListener(() => ticks++);
    tab.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    });
    expect(tab.selection.add(tab.document.entities.first.id), isTrue);
    expect(ticks, greaterThan(0));

    final scene = RenderScene.empty(tab.viewport.viewport);
    tab.noteScene(scene);
    expect(tab.lastScene, same(scene));

    ticks = 0;
    final dropped = <DocumentChange>[];
    tab.onGeometryInvalidated = dropped.add;
    tab.markSaved('/tmp/part.dxf');
    expect(tab.filePath, '/tmp/part.dxf');
    expect(tab.isDirty, isFalse);
    expect(tab.title, 'part.dxf');
    expect(dropped.single.tablesChanged, isTrue);
    expect(ticks, greaterThan(0));
  });
}
