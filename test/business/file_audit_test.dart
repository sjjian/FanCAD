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

  test('audit of a blank drawing is a clean DXF round trip', () async {
    final result = await run('file.audit');
    expect(result.status, CommandStatus.ok, reason: result.message);
    expect(result.data!['clean'], isTrue);
    expect(result.data!['sourceEntities'], 0);
    expect(result.message, contains('0 entities'));
  });

  test(
    'audit keeps a line and a paper tab after the temp DXF round trip',
    () async {
      expect(
        (await run('draw.line', {
          'start': [0, 0],
          'end': [10, 0],
        })).status,
        CommandStatus.ok,
      );
      expect(
        (await run('layout.new', {'name': 'A3'})).status,
        CommandStatus.ok,
      );

      final result = await run('file.audit');
      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(result.data!['clean'], isTrue);
      expect(result.data!['sourceEntities'], 1);
      expect(result.data!['missingLayouts'], isEmpty);
      expect(result.message, contains('1 entities'));
    },
  );
}
