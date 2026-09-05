import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:flutter_test/flutter_test.dart';

late Workspace workspace;

CadDocument get document => workspace.active!.document;

Future<CommandResult> run(String id, [Map<String, Object?> args = const {}]) =>
    workspace.runHeadless(id, args: args);

void main() {
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
      clipboard: workspace.clipboard,
    );
    workspace.newDocument();
  });

  tearDown(() => workspace.dispose());

  Future<int> drawLine(double x1, double y1, double x2, double y2) async {
    final result = await run('draw.line', {
      'start': [x1, y1],
      'end': [x2, y2],
    });
    expect(result.status, CommandStatus.ok, reason: result.message);
    return (result.data!['ids']! as List).first as int;
  }

  test(
    'COPYCLIP then PASTECLIP in another tab places relative to the base',
    () async {
      final id = await drawLine(0, 0, 10, 0);
      final copied = await run('edit.copyClip', {
        'ids': [id],
      });
      expect(copied.status, CommandStatus.ok, reason: copied.message);
      expect(workspace.clipboard.isEmpty, isFalse);

      workspace.newDocument();
      expect(document.entityCount, 0);

      final pasted = await run('edit.pasteClip', {
        'to': [4, 5],
      });
      expect(pasted.status, CommandStatus.ok, reason: pasted.message);
      final line = document.entities.whereType<LineEntity>().single;
      // COPYCLIP base is the lower-left of the line, (0, 0).
      expect(line.start, const Vec2(4, 5));
      expect(line.end, const Vec2(14, 5));
    },
  );

  test(
    'CUTCLIP removes the source and still pastes in another drawing',
    () async {
      final id = await drawLine(0, 0, 6, 0);
      final cut = await run('edit.cutClip', {
        'ids': [id],
      });
      expect(cut.status, CommandStatus.ok, reason: cut.message);
      expect(document.entity(id), isNull);

      workspace.newDocument();
      final pasted = await run('edit.pasteClip', {
        'to': [0, 0],
      });
      expect(pasted.status, CommandStatus.ok, reason: pasted.message);
      expect(document.entities.whereType<LineEntity>(), hasLength(1));
    },
  );

  test('COPYBASE uses the specified base, not the extents corner', () async {
    final id = await drawLine(10, 0, 20, 0);
    await run('edit.copyBase', {
      'from': [10, 0],
      'ids': [id],
    });

    workspace.newDocument();
    await run('edit.pasteClip', {
      'to': [0, 5],
    });
    final line = document.entities.whereType<LineEntity>().single;
    expect(line.start, const Vec2(0, 5));
    expect(line.end, const Vec2(10, 5));
  });

  test('PASTEORIG keeps the source coordinates', () async {
    final id = await drawLine(8, 2, 12, 2);
    await run('edit.copyClip', {
      'ids': [id],
    });

    workspace.newDocument();
    final pasted = await run('edit.pasteOrig');
    expect(pasted.status, CommandStatus.ok, reason: pasted.message);
    final line = document.entities.whereType<LineEntity>().single;
    expect(line.start, const Vec2(8, 2));
    expect(line.end, const Vec2(12, 2));
  });

  test('an empty clipboard cancels PASTECLIP', () async {
    final result = await run('edit.pasteClip', {
      'to': [0, 0],
    });
    expect(result.status, CommandStatus.cancelled);
    expect(result.message.toLowerCase(), contains('empty'));
  });

  test('PASTEBLOCK creates one insert at the insertion point', () async {
    final first = await drawLine(0, 0, 10, 0);
    final second = await drawLine(0, 0, 0, 4);
    await run('edit.copyClip', {
      'ids': [first, second],
    });

    workspace.newDocument();
    final pasted = await run('edit.pasteBlock', {
      'to': [1, 1],
    });
    expect(pasted.status, CommandStatus.ok, reason: pasted.message);
    expect(document.activeEntities.whereType<InsertEntity>(), hasLength(1));
    expect(document.activeEntities.whereType<LineEntity>(), isEmpty);
    final insert = document.activeEntities.whereType<InsertEntity>().single;
    expect(insert.position, const Vec2(1, 1));
  });
}
