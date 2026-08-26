import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Workspace workspace;
  late Directory dir;

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
    dir = Directory.systemTemp.createTempSync('fancad-print-');
  });

  tearDown(() {
    workspace.dispose();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<CommandResult> run(
    String id, [
    Map<String, Object?> args = const {},
  ]) => workspace.runHeadless(id, args: args);

  test('exportPdf writes a vector PDF of the current layout', () async {
    final path = '${dir.path}/sheet.pdf';
    final result = await run('print.exportPdf', {'path': path});
    expect(result.status, CommandStatus.ok, reason: result.message);
    expect(result.data!['layout'], 'Model');
    expect(result.data!['path'], path);
    expect(File(path).readAsBytesSync(), isNotEmpty);
    expect(String.fromCharCodes(File(path).readAsBytesSync().take(5)), '%PDF-');
  });

  test('exportSvg with a .pdf path writes PDF instead of SVG', () async {
    final path = '${dir.path}/alias.pdf';
    final result = await run('print.exportSvg', {'path': path});
    expect(result.status, CommandStatus.ok, reason: result.message);
    expect(String.fromCharCodes(File(path).readAsBytesSync().take(5)), '%PDF-');
  });

  test('a plot window needs both corners and a positive size', () async {
    expect(
      (await run('print.exportPdf', {
        'path': '${dir.path}/half.pdf',
        'corner1': [0, 0],
      })).status,
      CommandStatus.failed,
    );
    expect(
      (await run('print.exportSvg', {
        'path': '${dir.path}/flat.svg',
        'corner1': [0, 0],
        'corner2': [10, 0],
      })).status,
      CommandStatus.failed,
    );
    expect(
      (await run('print.exportPdf', {
        'path': '${dir.path}/missing.pdf',
        'layout': 'Ghost',
      })).status,
      CommandStatus.failed,
    );
  });
}
