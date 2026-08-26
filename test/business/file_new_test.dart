import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ({Workspace workspace, List<String> opened}) harness({
    Future<bool> Function(String path)? openFile,
  }) {
    final opened = <String>[];
    final workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      settings: SettingsStore.inMemory(),
    );
    addTearDown(workspace.dispose);
    registerBuiltinCommands(
      workspace.commands,
      fileCommands: FileCommands(
        openFile: (path) async {
          opened.add(path);
          if (openFile != null) return openFile(path);
          return true;
        },
        newDocument: workspace.newDocument,
        closeActive: ({bool force = false}) =>
            workspace.closeTab(workspace.activeIndex, force: force),
        saveActive: (path) async => path,
        recentFiles: () => const [],
      ),
    );
    workspace.newDocument();
    return (workspace: workspace, opened: opened);
  }

  test('file.new opens another empty tab', () async {
    final env = harness();
    expect(env.workspace.tabs, hasLength(1));

    final result = await env.workspace.runHeadless('file.new');
    expect(result.status, CommandStatus.ok);
    expect(env.workspace.tabs, hasLength(2));
    expect(env.workspace.active!.document.entityCount, 0);
  });

  test('file.open with a path does not invent a dialog', () async {
    final env = harness();
    final result = await env.workspace.runHeadless(
      'file.open',
      args: const {'path': '/tmp/demo.dxf'},
    );
    expect(result.status, CommandStatus.ok);
    expect(env.opened, ['/tmp/demo.dxf']);
    expect(result.message, contains('/tmp/demo.dxf'));
  });

  test(
    'file.open reports a failed importer instead of a silent success',
    () async {
      final env = harness(openFile: (_) async => false);
      final result = await env.workspace.runHeadless(
        'file.open',
        args: const {'path': '/tmp/missing.dxf'},
      );
      expect(result.status, CommandStatus.failed);
      expect(result.message, contains('/tmp/missing.dxf'));
      expect(env.opened, ['/tmp/missing.dxf']);
    },
  );
}
