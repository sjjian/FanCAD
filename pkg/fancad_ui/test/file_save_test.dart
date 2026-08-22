import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('save writes the existing path instead of asking again', () async {
    String? written;
    final workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      settings: SettingsStore.inMemory(),
    );
    addTearDown(workspace.dispose);
    registerBuiltinCommands(
      workspace.commands,
      fileCommands: FileCommands(
        openFile: (_) async => false,
        newDocument: workspace.newDocument,
        closeActive: ({bool force = false}) => true,
        saveActive: (path) async {
          written = path;
          return path;
        },
        recentFiles: () => const [],
      ),
    );
    final tab = workspace.newDocument(title: 'Part');
    tab.markSaved('/tmp/part.dxf');

    final result = await workspace.runHeadless('file.save');
    expect(result.status, CommandStatus.ok);
    expect(result.message, contains('/tmp/part.dxf'));
    expect(written, '/tmp/part.dxf');
  });
}
