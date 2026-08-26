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

  test('a two-point circle sits on the diameter midpoint', () async {
    final result = await run('draw.circle2p', {
      'first': [0, 0],
      'second': [10, 0],
    });
    expect(result.status, CommandStatus.ok, reason: result.message);
    final circle = workspace.active!.document.entities
        .whereType<CircleEntity>()
        .single;
    expect(circle.center, const Vec2(5, 0));
    expect(circle.radius, closeTo(5, 1e-9));
  });

  test('coincident diameter ends cannot invent a circle', () async {
    final result = await run('draw.circle2p', {
      'first': [2, 2],
      'second': [2, 2],
    });
    expect(result.status, CommandStatus.failed);
    expect(result.message, contains('coincide'));
    expect(workspace.active!.document.entityCount, 0);
  });

  test(
    'leftover polyline vertices still draw; empty points fail, not cancel',
    () async {
      final drawn = await run('draw.polyline', {
        'points': {
          'vertices': [
            [0, 0],
            [20, 0],
            [20, 8],
          ],
        },
      });
      expect(drawn.status, CommandStatus.ok, reason: drawn.message);
      expect(
        workspace.active!.document.entities.whereType<PolylineEntity>(),
        hasLength(1),
      );

      final empty = await run('draw.polyline', {'points': <Object?>[]});
      expect(empty.status, CommandStatus.failed);
      expect(empty.message, contains('[[x, y]'));
      expect(empty.status, isNot(CommandStatus.cancelled));
    },
  );
}
