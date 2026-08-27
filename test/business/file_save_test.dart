import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('save writes the existing path instead of asking again', () async {
    String? written;
    final workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(SettingsStore.inMemory()),
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

  test('save on an empty workspace does not invent a drawing', () async {
    var saved = false;
    final workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(SettingsStore.inMemory()),
    );
    addTearDown(workspace.dispose);
    registerBuiltinCommands(
      workspace.commands,
      fileCommands: FileCommands(
        openFile: (_) async => false,
        newDocument: workspace.newDocument,
        closeActive: ({bool force = false}) => true,
        saveActive: (path) async {
          saved = true;
          return path;
        },
        recentFiles: () => const [],
      ),
    );

    final result = await workspace.run('file.save');
    expect(result.status, CommandStatus.failed);
    expect(result.message, contains('no drawing'));
    expect(workspace.tabs, isEmpty);
    expect(saved, isFalse);

    final saveAs = await workspace.run('file.saveAs');
    expect(saveAs.status, CommandStatus.failed);
    expect(workspace.tabs, isEmpty);
  });

  test('a failing save dialog is a failed command, not a throw', () async {
    var saved = false;
    final workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(SettingsStore.inMemory()),
    );
    addTearDown(workspace.dispose);
    registerBuiltinCommands(
      workspace.commands,
      fileCommands: FileCommands(
        openFile: (_) async => false,
        newDocument: workspace.newDocument,
        closeActive: ({bool force = false}) => true,
        saveActive: (path) async {
          saved = true;
          return path;
        },
        recentFiles: () => const [],
        chooseSavePath: ({suggestedName = 'Drawing'}) async {
          throw StateError('dialog channel missing');
        },
      ),
    );
    workspace.newDocument(title: 'Untitled');

    final result = await workspace.run('file.save');
    expect(result.status, CommandStatus.failed);
    expect(result.message, contains('dialog'));
    expect(saved, isFalse);

    final saveAs = await workspace.run('file.saveAs');
    expect(saveAs.status, CommandStatus.failed);
    expect(saveAs.message, contains('dialog'));
    expect(saved, isFalse);
  });
}
