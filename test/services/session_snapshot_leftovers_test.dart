import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Workspace workspace;

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
  });

  tearDown(() => workspace.dispose());

  test('an empty leftover workspace reports selection none', () {
    final snapshot = collectSessionSnapshot(workspace);
    expect(snapshot.describe(), contains('selection: none'));
    expect(snapshot.describe(), contains('viewport: unknown'));
  });

  test('a leftover pick and camera land in the snapshot', () async {
    workspace.newDocument();
    workspace.active!.viewport.setSize(const Size(800, 600), 1);
    final created = await workspace.runHeadless(
      'draw.line',
      args: {
        'start': [0, 0],
        'end': [10, 0],
      },
    );
    final id = (created.data!['ids']! as List).first as int;
    workspace.active!.selection.replace([id]);

    final snapshot = collectSessionSnapshot(workspace);
    expect(snapshot.selectionCount, 1);
    expect(snapshot.selection.single.id, id);
    expect(snapshot.selection.single.kind, 'line');
    expect(snapshot.viewport, isNotNull);
    expect(snapshot.describe(), contains('#$id line'));
    expect(snapshot.describe(), isNot(contains('selection: none')));
  });

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
}
