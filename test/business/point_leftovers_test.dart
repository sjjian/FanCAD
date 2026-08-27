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

  test('a point lands at the supplied location', () async {
    final result = await run('draw.point', {
      'at': [3, 7],
    });
    expect(result.status, CommandStatus.ok, reason: result.message);
    final point = workspace.active!.document.entities
        .whereType<PointEntity>()
        .single;
    expect(point.position, const Vec2(3, 7));
  });

  test('a missing location cannot invent a point', () async {
    final result = await run('draw.point');
    expect(result.status, CommandStatus.cancelled);
    expect(workspace.active!.document.entityCount, 0);
  });
}
