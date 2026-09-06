import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Workspace harness() {
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
        closeActive: (session, {bool force = false}) =>
            workspace.closeSession(session, force: force),
        saveActive: (session, path) => workspace.saveSession(session, path),
        recentFiles: () => const [],
        listDrawings: workspace.listOpenDrawings,
        activateDrawing: workspace.activateDrawing,
      ),
    );
    return workspace;
  }

  test(
    'file.list reports every open drawing and which one is active',
    () async {
      final workspace = harness();
      workspace.newDocument(title: 'Alpha');
      workspace.newDocument(title: 'Beta');

      final result = await workspace.runHeadless('file.list');
      expect(result.status, CommandStatus.ok);
      final drawings = result.data!['drawings'] as List<Object?>;
      expect(drawings, hasLength(2));

      final first = drawings[0] as Map<String, Object?>;
      final second = drawings[1] as Map<String, Object?>;
      expect(first['id'], workspace.tabs[0].session.id);
      expect(first['title'], 'Alpha');
      expect(first['active'], isFalse);
      expect(first['dirty'], isFalse);
      expect(first['entityCount'], 0);
      expect(first['activeLayout'], 'Model');
      expect(second['id'], workspace.tabs[1].session.id);
      expect(second['title'], 'Beta');
      expect(second['active'], isTrue);
      expect(workspace.activeIndex, 1);
    },
  );

  test('file.activate switches the visible tab', () async {
    final workspace = harness();
    final alpha = workspace.newDocument(title: 'Alpha');
    workspace.newDocument(title: 'Beta');
    expect(workspace.activeIndex, 1);

    final result = await workspace.runHeadless(
      'file.activate',
      args: {'id': alpha.session.id},
    );
    expect(result.status, CommandStatus.ok);
    expect(workspace.activeIndex, 0);
    expect(workspace.active!.title, 'Alpha');
  });

  test('tab selector runs query and draw on a background drawing', () async {
    final workspace = harness();
    final alpha = workspace.newDocument(title: 'Alpha');
    final beta = workspace.newDocument(title: 'Beta');
    expect(workspace.activeIndex, 1);

    final drawn = await workspace.runHeadless(
      'draw.line',
      args: const {
        'start': [0, 0],
        'end': [8, 0],
      },
      tab: alpha.session.id,
    );
    expect(drawn.status, CommandStatus.ok, reason: drawn.message);
    expect(alpha.document.entityCount, 1);
    expect(beta.document.entityCount, 0);
    expect(workspace.activeIndex, 1);

    final summary = await workspace.runHeadless(
      'query.summary',
      tab: alpha.session.id,
    );
    expect(summary.status, CommandStatus.ok);
    expect(summary.data!['entityCount'], 1);

    final activeSummary = await workspace.runHeadless('query.summary');
    expect(activeSummary.data!['entityCount'], 0);
  });

  test('unknown tab fails without touching the active drawing', () async {
    final workspace = harness();
    workspace.newDocument(title: 'Alpha');
    final beta = workspace.newDocument(title: 'Beta');

    final result = await workspace.runHeadless(
      'query.summary',
      tab: 'no-such-drawing',
    );
    expect(result.status, CommandStatus.failed);
    expect(result.message, contains('No open drawing matches'));
    expect(workspace.activeIndex, 1);
    expect(beta.document.entityCount, 0);
  });

  test(
    'file.close with tab closes the target instead of the current page',
    () async {
      final workspace = harness();
      final alpha = workspace.newDocument(title: 'Alpha');
      workspace.newDocument(title: 'Beta');
      await workspace.runHeadless(
        'draw.line',
        args: const {
          'start': [0, 0],
          'end': [4, 0],
        },
      );
      expect(workspace.tabs, hasLength(2));
      expect(workspace.active!.title, 'Beta');
      expect(workspace.active!.document.entityCount, 1);

      final closed = await workspace.runHeadless(
        'file.close',
        tab: alpha.session.id,
      );
      expect(closed.status, CommandStatus.ok, reason: closed.message);
      expect(workspace.tabs, hasLength(1));
      expect(workspace.activeIndex, 0);
      expect(workspace.active!.title, 'Beta');
      expect(workspace.active!.document.entityCount, 1);
    },
  );

  test('mcp run with tab hits the same resolver as file.list ids', () async {
    final workspace = harness();
    final alpha = workspace.newDocument(title: 'Alpha');
    workspace.newDocument(title: 'Beta');
    final host = FanCadOpsHost(workspace: workspace, lockPaths: const []);
    final dispatcher = OpsDispatcher(host.catalog());

    final unknown = await dispatcher.dispatch(
      const OpsRequest(
        action: OpsAction.run,
        path: 'query.summary',
        tab: 'missing',
      ),
    );
    expect(unknown['status'], 'failed');
    expect('${unknown['error']}', contains('No open drawing matches'));

    final drawn = await dispatcher.dispatch(
      OpsRequest(
        action: OpsAction.run,
        path: 'draw.line',
        tab: alpha.session.id,
        args: const {
          'start': [0, 0],
          'end': [8, 0],
        },
      ),
    );
    expect(drawn['status'], 'ok');
    expect(alpha.document.entityCount, 1);
    expect(workspace.activeIndex, 1);
  });
}
