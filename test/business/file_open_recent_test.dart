import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Workspace workspaceWithRecent(
    List<String> recent, {
    required Future<bool> Function(String path) openFile,
  }) {
    final workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(SettingsStore.inMemory()),
    );
    addTearDown(workspace.dispose);
    registerBuiltinCommands(
      workspace.commands,
      fileCommands: FileCommands(
        openFile: openFile,
        newDocument: workspace.newDocument,
        closeActive: ({bool force = false}) => true,
        saveActive: (path) async => path,
        recentFiles: () => recent,
      ),
    );
    workspace.newDocument();
    return workspace;
  }

  test('an empty recent list fails without asking for a path', () async {
    var opened = false;
    final workspace = workspaceWithRecent(
      const [],
      openFile: (_) async {
        opened = true;
        return true;
      },
    );

    final result = await workspace.runHeadless('file.openRecent');
    expect(result.status, CommandStatus.failed);
    expect(result.message, contains('no recent files'));
    expect(opened, isFalse);
  });

  test('a blank path does not open an empty file', () async {
    String? opened;
    final workspace = workspaceWithRecent(
      const ['/tmp/a.dxf', '/tmp/b.dxf'],
      openFile: (path) async {
        opened = path;
        return true;
      },
    );

    final result = await workspace.runHeadless(
      'file.openRecent',
      args: const {'path': '  '},
    );
    expect(result.status, CommandStatus.failed);
    expect(result.message, contains('No recent file'));
    expect(opened, isNull);
  });

  test('a named recent path is reopened', () async {
    String? opened;
    final workspace = workspaceWithRecent(
      const ['/tmp/a.dxf', '/tmp/b.dxf'],
      openFile: (path) async {
        opened = path;
        return true;
      },
    );

    final result = await workspace.runHeadless(
      'file.openRecent',
      args: const {'path': '/tmp/b.dxf'},
    );
    expect(result.status, CommandStatus.ok);
    expect(result.message, contains('/tmp/b.dxf'));
    expect(opened, '/tmp/b.dxf');
  });
}
