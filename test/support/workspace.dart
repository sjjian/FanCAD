import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Headless [WorkspaceNotifier] with built-in commands and an in-memory importer.
///
/// This is the same entry point a plugin or an AI tool call takes, so tests
/// that go through [run] are the closest thing to a contract for "can the
/// assistant actually draw". Running them headlessly also proves the
/// commands hold no hidden dependency on a widget tree.
class Headless {
  Headless({
    SettingsStore? settings,
    FileCommands Function(WorkspaceNotifier workspace)? files,
    bool document = true,
  }) : settings = settings ?? SettingsStore.inMemory() {
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWithValue(this.settings),
        drawingFilesProvider.overrideWithValue(DrawingFileService.inMemory()),
        if (files != null)
          workspaceFileCommandsOverrideProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
    workspace = container.read(workspaceNotifierProvider.notifier);
    if (document) workspace.newDocument();
  }

  final SettingsStore settings;
  late final ProviderContainer container;
  late final WorkspaceNotifier workspace;

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
