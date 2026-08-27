import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Workspace workspace;

  setUp(() {
    workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(SettingsStore.inMemory()),
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

  SelectionSet selection() => workspace.active!.session.selection;

  test('deselect clears a leftover pick', () async {
    await run('draw.line', {
      'start': [0, 0],
      'end': [1, 0],
    });
    expect(selection().ids, isNotEmpty);

    final result = await run('select.none');
    expect(result.status, CommandStatus.ok);
    expect(selection().ids, isEmpty);
  });

  test('invert swaps the leftover pick for everything else', () async {
    final first = await run('draw.line', {
      'start': [0, 0],
      'end': [1, 0],
    });
    final second = await run('draw.circle', {
      'center': [0, 0],
      'radius': 2,
    });
    final a = (first.data!['ids']! as List).first as int;
    final b = (second.data!['ids']! as List).first as int;
    selection().replace([a]);

    final result = await run('select.invert');
    expect(result.status, CommandStatus.ok);
    expect(selection().ids.toSet(), {b});
  });

  test(
    'similar grows the selection by kind and layer, not by a missing pick',
    () async {
      expect((await run('select.similar')).status, CommandStatus.failed);

      await run('layer.new', {'name': 'WALLS'});
      await run('layer.setCurrent', {'name': '0'});
      final seed = await run('draw.line', {
        'start': [0, 0],
        'end': [1, 0],
      });
      await run('draw.line', {
        'start': [2, 0],
        'end': [3, 0],
      });
      await run('layer.setCurrent', {'name': 'WALLS'});
      await run('draw.line', {
        'start': [4, 0],
        'end': [5, 0],
      });
      await run('draw.circle', {
        'center': [0, 0],
        'radius': 1,
      });

      final id = (seed.data!['ids']! as List).first as int;
      selection().replace([id]);
      final result = await run('select.similar');
      expect(result.status, CommandStatus.ok);
      expect(selection().ids, hasLength(2));
      expect(
        selection().ids.every((each) {
          final entity = workspace.active!.document.entity(each);
          return entity is LineEntity && entity.props.layer == '0';
        }),
        isTrue,
      );
    },
  );
}
