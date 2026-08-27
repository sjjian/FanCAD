import 'dart:ui';

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
    workspace.active!.viewport.setSize(const Size(800, 600), 1);
  });

  tearDown(() => workspace.dispose());

  Future<CommandResult> run(
    String id, [
    Map<String, Object?> args = const {},
  ]) => workspace.runHeadless(id, args: args);

  double scale() => workspace.active!.viewport.viewport.scale;

  test('zoom extents refuses an empty drawing', () async {
    expect((await run('view.zoomExtents')).status, CommandStatus.failed);
  });

  test('zoom in, out and extents change the camera', () async {
    await run('draw.line', {
      'start': [0, 0],
      'end': [100, 0],
    });
    await run('view.zoomExtents');
    final fitted = scale();

    await run('view.zoomIn');
    expect(scale(), closeTo(fitted * 2, 1e-9));

    await run('view.zoomOut');
    expect(scale(), closeTo(fitted, 1e-9));
  });

  test('zoom selected and zoom window frame the requested area', () async {
    final created = await run('draw.line', {
      'start': [0, 0],
      'end': [40, 0],
    });
    final id = (created.data!['ids']! as List).first as int;
    workspace.active!.session.selection.clear();

    expect((await run('view.zoomSelected')).status, CommandStatus.failed);

    workspace.active!.session.selection.replace([id]);
    expect((await run('view.zoomSelected')).status, CommandStatus.ok);
    final selected = scale();

    await run('view.zoomWindow', {
      'corner1': [0, -1],
      'corner2': [4, 1],
    });
    expect(scale(), greaterThan(selected));
  });

  test('regen reports success without touching the drawing', () async {
    final result = await run('view.regen');
    expect(result.status, CommandStatus.ok);
    expect(result.message, contains('regenerated'));
    expect(workspace.active!.document.entityCount, 0);
  });
}
