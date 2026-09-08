import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:flutter_test/flutter_test.dart';

/// Headless [Workspace] with built-in commands and an in-memory importer.
///
/// This is the same entry point a plugin or an AI tool call takes, so tests
/// that go through [run] are the closest thing to a contract for "can the
/// assistant actually draw". Running them headlessly also proves the
/// commands hold no hidden dependency on a widget tree.
class Headless {
  Headless({
    SettingsStore? settings,
    FileCommands Function(Workspace workspace)? files,
    bool document = true,
  }) : settings = settings ?? SettingsStore.inMemory() {
    workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(this.settings),
    );
    registerBuiltinCommands(
      workspace.commands,
      fileCommands:
          files?.call(workspace) ??
          FileCommands(
            openFile: (_) async => false,
            newDocument: workspace.newDocument,
            closeActive: (session, {bool force = false}) => true,
            saveActive: (session, path) async => path,
            recentFiles: () => const [],
          ),
      clipboard: workspace.clipboard,
    );
    if (document) workspace.newDocument();
    addTearDown(workspace.dispose);
  }

  final SettingsStore settings;
  late final Workspace workspace;

  CadDocument get document => workspace.active!.document;

  Future<CommandResult> run(
    String id, [
    Map<String, Object?> args = const {},
  ]) => workspace.runHeadless(id, args: args);

  /// Draws a line and returns its id, failing the test if it did not work.
  Future<int> drawLine(double x1, double y1, double x2, double y2) async {
    final result = await run('draw.line', {
      'start': [x1, y1],
      'end': [x2, y2],
    });
    expect(result.status, CommandStatus.ok, reason: result.message);
    return (result.data!['ids']! as List).first as int;
  }
}
