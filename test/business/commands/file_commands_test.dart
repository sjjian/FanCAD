import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workspace.dart';

void main() {
  group('new and open', () {
    ({Headless app, List<String> opened}) harness({
      Future<bool> Function(String path)? openFile,
    }) {
      final opened = <String>[];
      final app = Headless(
        files: (workspace) => FileCommands(
          openFile: (path) async {
            opened.add(path);
            if (openFile != null) return openFile(path);
            return true;
          },
          newDocument: workspace.newDocument,
          closeActive: (session, {bool force = false}) =>
              workspace.closeSession(session, force: force),
          saveActive: (session, path) async => path,
          recentFiles: () => const [],
        ),
      );
      return (app: app, opened: opened);
    }

    test('file.new opens another empty tab', () async {
      final env = harness();
      expect(env.app.workspace.tabs, hasLength(1));

      final result = await env.app.run('file.new');
      expect(result.status, CommandStatus.ok);
      expect(env.app.workspace.tabs, hasLength(2));
      expect(env.app.workspace.active!.document.entityCount, 0);
    });

    test('file.open with a path does not invent a dialog', () async {
      final env = harness();
      final result = await env.app.run(
        'file.open',
        const {'path': '/tmp/demo.dxf'},
      );
      expect(result.status, CommandStatus.ok);
      expect(env.opened, ['/tmp/demo.dxf']);
      expect(result.message, contains('/tmp/demo.dxf'));
    });

    test(
      'file.open reports a failed importer instead of a silent success',
      () async {
        final env = harness(openFile: (_) async => false);
        final result = await env.app.run(
          'file.open',
          const {'path': '/tmp/missing.dxf'},
        );
        expect(result.status, CommandStatus.failed);
        expect(result.message, contains('/tmp/missing.dxf'));
        expect(env.opened, ['/tmp/missing.dxf']);
      },
    );
  });

  group('save', () {
    test('save writes the existing path instead of asking again', () async {
      String? written;
      final app = Headless(
        document: false,
        files: (workspace) => FileCommands(
          openFile: (_) async => false,
          newDocument: workspace.newDocument,
          closeActive: (session, {bool force = false}) => true,
          saveActive: (session, path) async {
            written = path;
            return path;
          },
          recentFiles: () => const [],
        ),
      );
      final tab = app.workspace.newDocument(title: 'Part');
      tab.markSaved('/tmp/part.dxf');

      final result = await app.workspace.runHeadless('file.save');
      expect(result.status, CommandStatus.ok);
      expect(result.message, contains('/tmp/part.dxf'));
      expect(written, '/tmp/part.dxf');
    });

    test('save on an empty workspace does not invent a drawing', () async {
      var saved = false;
      final app = Headless(
        document: false,
        files: (workspace) => FileCommands(
          openFile: (_) async => false,
          newDocument: workspace.newDocument,
          closeActive: (session, {bool force = false}) => true,
          saveActive: (session, path) async {
            saved = true;
            return path;
          },
          recentFiles: () => const [],
        ),
      );

      final result = await app.workspace.run('file.save');
      expect(result.status, CommandStatus.failed);
      expect(result.message, contains('no drawing'));
      expect(app.workspace.tabs, isEmpty);
      expect(saved, isFalse);

      final saveAs = await app.workspace.run('file.saveAs');
      expect(saveAs.status, CommandStatus.failed);
      expect(app.workspace.tabs, isEmpty);
    });

    test('a failing save dialog is a failed command, not a throw', () async {
      var saved = false;
      final app = Headless(
        document: false,
        files: (workspace) => FileCommands(
          openFile: (_) async => false,
          newDocument: workspace.newDocument,
          closeActive: (session, {bool force = false}) => true,
          saveActive: (session, path) async {
            saved = true;
            return path;
          },
          recentFiles: () => const [],
          chooseSavePath: ({suggestedName = 'Drawing'}) async {
            throw StateError('dialog channel missing');
          },
        ),
      );
      app.workspace.newDocument(title: 'Untitled');

      final result = await app.workspace.run('file.save');
      expect(result.status, CommandStatus.failed);
      expect(result.message, contains('dialog'));
      expect(saved, isFalse);

      final saveAs = await app.workspace.run('file.saveAs');
      expect(saveAs.status, CommandStatus.failed);
      expect(saveAs.message, contains('dialog'));
      expect(saved, isFalse);
    });
  });

  group('tabs', () {
    Headless harness() {
      return Headless(
        document: false,
        files: (workspace) => FileCommands(
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
    }

    test(
      'file.list reports every open drawing and which one is active',
      () async {
        final app = harness();
        final workspace = app.workspace;
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
      final app = harness();
      final workspace = app.workspace;
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
      final app = harness();
      final workspace = app.workspace;
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
      final app = harness();
      final workspace = app.workspace;
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
        final app = harness();
        final workspace = app.workspace;
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
      final app = harness();
      final workspace = app.workspace;
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
  });

  group('open recent', () {
    Headless workspaceWithRecent(
      List<String> recent, {
      required Future<bool> Function(String path) openFile,
    }) {
      return Headless(
        files: (workspace) => FileCommands(
          openFile: openFile,
          newDocument: workspace.newDocument,
          closeActive: (session, {bool force = false}) => true,
          saveActive: (session, path) async => path,
          recentFiles: () => recent,
        ),
      );
    }

    test('an empty recent list fails without asking for a path', () async {
      var opened = false;
      final app = workspaceWithRecent(
        const [],
        openFile: (_) async {
          opened = true;
          return true;
        },
      );

      final result = await app.run('file.openRecent');
      expect(result.status, CommandStatus.failed);
      expect(result.message, contains('no recent files'));
      expect(opened, isFalse);
    });

    test('a blank path does not open an empty file', () async {
      String? opened;
      final app = workspaceWithRecent(
        const ['/tmp/a.dxf', '/tmp/b.dxf'],
        openFile: (path) async {
          opened = path;
          return true;
        },
      );

      final result = await app.run(
        'file.openRecent',
        const {'path': '  '},
      );
      expect(result.status, CommandStatus.failed);
      expect(result.message, contains('No recent file'));
      expect(opened, isNull);
    });

    test('a named recent path is reopened', () async {
      String? opened;
      final app = workspaceWithRecent(
        const ['/tmp/a.dxf', '/tmp/b.dxf'],
        openFile: (path) async {
          opened = path;
          return true;
        },
      );

      final result = await app.run(
        'file.openRecent',
        const {'path': '/tmp/b.dxf'},
      );
      expect(result.status, CommandStatus.ok);
      expect(result.message, contains('/tmp/b.dxf'));
      expect(opened, '/tmp/b.dxf');
    });
  });
}
