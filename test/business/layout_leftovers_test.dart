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

  test(
    'list reports Model as the only current tab on a blank drawing',
    () async {
      final result = await run('layout.list');
      expect(result.status, CommandStatus.ok);
      expect(result.message, '1 layout(s).');

      final layouts = (result.data!['layouts']! as List).cast<Map>();
      expect(layouts, hasLength(1));
      expect(layouts.single['name'], 'Model');
      expect(layouts.single['model'], isTrue);
      expect(layouts.single['current'], isTrue);
      expect(layouts.single['viewports'], 0);
      expect(layouts.single['tabOrder'], 0);
      expect(layouts.single.containsKey('plotWindow'), isFalse);
    },
  );

  test(
    'list marks the paper tab current and includes plot window and viewports',
    () async {
      expect((await run('layout.new')).status, CommandStatus.ok);
      expect(
        (await run('layout.pagesetup', {
          'width': 420,
          'height': 297,
          'rotation': 90,
          'corner1': [10, 20],
          'corner2': [110, 80],
          'scale': 2,
          'fit': false,
          'offset': [5, 7],
        })).status,
        CommandStatus.ok,
      );
      expect(
        (await run('layout.mview', {
          'corner1': [10, 10],
          'corner2': [200, 150],
          'scale': 1,
        })).status,
        CommandStatus.ok,
      );

      final result = await run('layout.list');
      expect(result.status, CommandStatus.ok);
      expect(result.message, '2 layout(s).');

      final layouts = (result.data!['layouts']! as List).cast<Map>();
      final model = layouts.firstWhere((layout) => layout['name'] == 'Model');
      final paper = layouts.firstWhere((layout) => layout['name'] == 'Layout1');

      expect(model['current'], isFalse);
      expect(model['model'], isTrue);

      expect(paper['current'], isTrue);
      expect(paper['model'], isFalse);
      expect(paper['paper'], [420.0, 297.0]);
      expect(paper['viewports'], 1);
      expect(paper['tabOrder'], 1);
      expect(paper['plotRotation'], 90);
      expect(paper['plotScale'], 2);
      expect(paper['plotFit'], isFalse);
      expect(paper['plotOffset'], [5.0, 7.0]);
      expect(paper['plotWindow'], [10.0, 20.0, 110.0, 80.0]);
    },
  );
}
