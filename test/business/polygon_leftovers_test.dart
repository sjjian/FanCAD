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

  test('a hexagon is inscribed so vertices sit on the circle', () async {
    final result = await run('draw.polygon', {
      'sides': 6,
      'center': [0, 0],
      'radius': 10,
    });
    expect(result.status, CommandStatus.ok, reason: result.message);
    final polygon = workspace.active!.document.entities
        .whereType<PolylineEntity>()
        .single;
    expect(polygon.closed, isTrue);
    expect(polygon.vertexCount, 6);
    expect(polygon.vertexAt(0).x, closeTo(0, 1e-9));
    expect(polygon.vertexAt(0).y, closeTo(10, 1e-9));
    for (var i = 0; i < polygon.vertexCount; i++) {
      expect(polygon.vertexAt(i).length, closeTo(10, 1e-9));
    }
  });

  test('a zero radius or too few sides cannot invent a polygon', () async {
    final vanished = await run('draw.polygon', {
      'sides': 6,
      'center': [0, 0],
      'radius': 0,
    });
    expect(vanished.status, CommandStatus.failed);
    expect(vanished.message, contains('positive'));
    expect(workspace.active!.document.entityCount, 0);

    final degenerate = await run('draw.polygon', {
      'sides': 2,
      'center': [0, 0],
      'radius': 10,
    });
    expect(degenerate.status, CommandStatus.failed);
    expect(degenerate.message, contains('at least 3'));
    expect(workspace.active!.document.entityCount, 0);
  });
}
