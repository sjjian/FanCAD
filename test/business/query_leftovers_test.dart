import 'dart:ui';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
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
    workspace.newDocument();
  });

  tearDown(() => workspace.dispose());

  Future<CommandResult> run(
    String id, [
    Map<String, Object?> args = const {},
  ]) => workspace.runHeadless(id, args: args);

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
    expect(result.data!['center'], isA<List>());
    expect(result.data!['visible'], isA<List>());
    expect((result.data!['visible']! as List), hasLength(4));
  });

  test(
    'layers reports the current layer and how many objects sit on it',
    () async {
      await run('draw.line', {
        'start': [0, 0],
        'end': [1, 0],
      });
      workspace.active!.session.edit('layer', (transaction) {
        transaction.putLayer(const LayerDef(name: 'Notes', locked: true));
      });

      final result = await run('query.layers');
      expect(result.status, CommandStatus.ok);
      final layers = (result.data!['layers']! as List).cast<Map>();
      final zero = layers.firstWhere((layer) => layer['name'] == '0');
      expect(zero['current'], isTrue);
      expect(zero['count'], 1);
      final notes = layers.firstWhere((layer) => layer['name'] == 'Notes');
      expect(notes['locked'], isTrue);
      expect(notes['count'], 0);
    },
  );
}
