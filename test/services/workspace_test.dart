import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Workspace workspace({SettingsStore? settings}) {
    return Headless(settings: settings, document: false).workspace;
  }

  test('tabs activate, refuse a dirty close, and force-close the last one', () {
    final ws = workspace();
    final first = ws.newDocument(title: 'A');
    final second = ws.newDocument(title: 'B');
    expect(ws.tabs, hasLength(2));
    expect(ws.active, same(second));

    ws.activate(0);
    expect(ws.active, same(first));
    ws.activate(0);
    expect(ws.state.activeIndex, 0);
    ws.activateTab(second);
    expect(ws.active, same(second));

    second.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    });
    expect(ws.closeTab(1), isFalse);
    expect(ws.tabs, hasLength(2));
    expect(ws.closeTab(1, force: true), isTrue);
    expect(ws.active, same(first));
    expect(ws.closeTab(99), isTrue);

    expect(ws.closeTab(0, force: true), isTrue);
    expect(ws.hasDocument, isFalse);
    expect(ws.state.activeIndex, -1);
  });

  test('store chrome tracks title and dirty; hover stays off that record', () {
    final ws = workspace();
    final tab = ws.newDocument(title: 'A');
    expect(ws.state.sessions.single.title, 'A');
    expect(ws.state.sessions.single.isDirty, isFalse);

    tab.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    });
    expect(tab.isDirty, isTrue);
    expect(ws.state.sessions.single.isDirty, isTrue);
    expect(ws.state.sessions.single.hoverIds, isEmpty);

    ws.setHoverHighlights(const [3]);
    expect(ws.state.sessions.single.hoverIds, [3]);
    expect(ws.state.sessions.single.isDirty, isTrue);
    expect(ws.state.sessions.single.title, 'A');
  });

  test('the tab plus control opens a start page instead of Drawing1', () {
    final ws = workspace();
    ws.newDocument(title: 'A');
    final start = ws.openStartTab();
    expect(start.isStartPage, isTrue);
    expect(ws.hasDocument, isFalse);
    expect(ws.tabs, hasLength(2));
    expect(ws.openStartTab(), same(start));
    expect(ws.tabs, hasLength(2));

    final drawing = ws.newDocument();
    expect(drawing, same(start));
    expect(start.isStartPage, isFalse);
    expect(ws.hasDocument, isTrue);
    expect(ws.tabs, hasLength(2));
  });

  test('sessionIds skip start pages and session lookup stays on drawings', () {
    final ws = workspace();
    expect(ws.state.sessionIds, isEmpty);
    expect(ws.session(''), isNull);
    expect(ws.session('missing'), isNull);
    expect(ws.activeSession, isNull);
    expect(ws.state.sessionIds, isEmpty);
    expect(ws.state.activeSessionId, isNull);

    final start = ws.openStartTab();
    expect(ws.state.sessionIds, isEmpty);
    expect(ws.session(start.session.id), isNull);
    expect(ws.activeSession, isNull);
    expect(ws.state.activeSessionId, isNull);

    final alpha = ws.newDocument(title: 'Alpha');
    expect(ws.state.sessionIds, [alpha.session.id]);
    expect(ws.session(alpha.session.id), same(alpha.session));
    expect(ws.activeSession, same(alpha.session));

    final startAgain = ws.openStartTab();
    expect(ws.state.sessionIds, [alpha.session.id]);
    expect(ws.session(startAgain.session.id), isNull);
    expect(ws.activeSession, isNull);
    expect(ws.state.sessionIds, [alpha.session.id]);
    expect(ws.state.activeSessionId, isNull);

    ws.activateTab(alpha);
    expect(ws.session(' ${alpha.session.id} '), same(alpha.session));
    expect(ws.state.activeSessionId, alpha.session.id);
    expect(ws.tabForSession(alpha.session), same(alpha));
    expect(ws.indexOfSession(alpha.session), 0);
  });

  test('findDrawing matches id, unique title, or the active drawing', () {
    final ws = workspace();
    final alpha = ws.newDocument(title: 'Alpha');
    final beta = ws.newDocument(title: 'Beta');
    beta.session.filePath = '/tmp/beta.dxf';

    expect(ws.findDrawing(null), same(beta));
    expect(ws.findDrawing(''), same(beta));
    expect(ws.findDrawing(alpha.session.id), same(alpha));
    expect(ws.findDrawing('Alpha'), same(alpha));
    expect(ws.findDrawing('/tmp/beta.dxf'), same(beta));
    expect(ws.findDrawing('missing'), isNull);

    expect(ws.activateDrawing(alpha.session.id), isNull);
    expect(ws.active, same(alpha));
    expect(ws.activateDrawing('gone'), contains('No open drawing'));
  });

  test('a leftover duplicate title is not a drawing match', () {
    final ws = workspace();
    final first = ws.newDocument(title: 'Sheet');
    final second = ws.newDocument(title: 'Sheet');

    expect(ws.findDrawing('Sheet'), isNull);
    expect(
      ws.drawingNotFoundMessage('Sheet'),
      contains('ids: ${first.session.id}, ${second.session.id}'),
    );
    expect(ws.activateDrawing('Sheet'), contains('more than one drawing'));
    expect(ws.active, same(second));
  });

  test('state carries notices; command line stays global', () {
    final ws = workspace();
    ws.notify('saved');
    expect(ws.state.notices.single.message, 'saved');

    final pending = ws.commandLine.request(
      PendingEntry(
        message: 'Specify next point',
        completer: Completer<Object?>(),
        accept: (raw) => raw,
        keywords: const ['Undo'],
      ),
    );
    addTearDown(() {
      if (ws.commandLine.isAwaitingInput) ws.commandLine.cancelPending();
    });
    expect(ws.commandLine.pending?.message, 'Specify next point');
    expect(ws.commandLine.pending?.keywords, ['Undo']);
    expect(ws.commandLine.state.lines, isNotEmpty);
    pending.ignore();
  });

  test('closeSession refuses a dirty drawing and force-closes it', () {
    final ws = workspace();
    final tab = ws.newDocument(title: 'A');
    tab.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    });
    expect(ws.closeSession(tab.session), isFalse);
    expect(ws.state.sessionIds, [tab.session.id]);
    expect(ws.closeSession(tab.session, force: true), isTrue);
    expect(ws.state.sessionIds, isEmpty);
    expect(
      ws.closeSession(DocumentSession(id: 'gone', document: CadDocument())),
      isTrue,
    );
  });

  test('file-backed settings can build without reading workspace state', () {
    final dir = tempDir(prefix: 'fancad-shx-settings');
    final settings = SettingsStore(file: File('${dir.path}/settings.json'));
    expect(workspace(settings: settings).tabs, isEmpty);
  });

  test('locale follows the appearance language', () {
    expect(workspace().locale, 'en');
    final app = Headless(document: false);
    app.container
        .read(appearanceNotifierProvider.notifier)
        .setLanguage(FanCadLanguage.chinese);
    expect(app.workspace.locale, FanCadLanguage.chinese);
  });

  test(
    'missing recent files are pruned and the leftover list can be cleared',
    () {
      final dir = tempDir(prefix: 'fancad-recent');
      final kept = File('${dir.path}/keep.dxf')
        ..writeAsStringSync('0\nSECTION\n2\nENTITIES\n0\nENDSEC\n0\nEOF\n');
      final ws = workspace(
        settings: SettingsStore.inMemory({
          SettingsKeys.recentFiles: [kept.path, '${dir.path}/missing.dxf'],
        }),
      );
      expect(ws.state.recentFiles, hasLength(2));
      expect(ws.pruneMissingRecentFiles(), 1);
      expect(ws.state.recentFiles, [kept.path]);
      expect(ws.pruneMissingRecentFiles(), 0);
      ws.clearRecentFiles();
      expect(ws.state.recentFiles, isEmpty);
    },
  );

  test('selecting an object reveals the properties panel', () async {
    final ws = workspace();
    final tab = ws.newDocument();
    final line = tab.session.document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
    );
    final revealed = <String>[];
    final sub = ws.panelReveals.listen(revealed.add);
    addTearDown(sub.cancel);

    tab.session.selection.replace([line.id]);
    await Future<void>.value();
    expect(revealed, ['properties']);

    tab.session.selection.clear();
    await Future<void>.value();
    expect(revealed, ['properties']);
  });

  test('closing a tab to the left keeps the same drawing active', () {
    final ws = workspace();
    ws.newDocument(title: 'A');
    final second = ws.newDocument(title: 'B');
    final third = ws.newDocument(title: 'C');
    ws.activateTab(second);
    expect(ws.active, same(second));

    expect(ws.closeTab(0), isTrue);
    expect(ws.tabs, [same(second), same(third)]);
    expect(ws.active, same(second));
    expect(ws.state.activeIndex, 0);

    expect(ws.closeTab(1), isTrue);
    expect(ws.tabs, [same(second)]);
    expect(ws.active, same(second));
  });

  test(
    'an already-open path is activated and a missing file becomes a notice',
    () async {
      final ws = workspace();
      final first = ws.newDocument();
      first.session.filePath = '/tmp/already-open.dxf';
      ws.newDocument();
      expect(ws.state.activeIndex, 1);

      final again = await ws.openFile('/tmp/already-open.dxf');
      expect(again, same(first));
      expect(ws.active, same(first));

      expect(await ws.openFile('/tmp/fancad-missing-open.dxf'), isNull);
      expect(ws.state.notices.single.isError, isTrue);
      expect(
        ws.state.notices.single.message,
        contains('fancad-missing-open.dxf'),
      );

      expect(await ws.openFile('   '), isNull);
      expect(ws.state.notices.last.message, contains('no file to open'));
      expect(ws.tabs, hasLength(2));
    },
  );

  test('the same drawing reached via two paths stays one tab', () async {
    final ws = workspace();
    final dir = tempDir(prefix: 'fancad-open-id');
    final file = File('${dir.path}/part.dxf')
      ..writeAsStringSync('0\nSECTION\n2\nENTITIES\n0\nENDSEC\n0\nEOF\n');

    final first = await ws.openFile(file.path);
    expect(first, isNotNull);
    expect(ws.tabs, hasLength(1));

    final dotted = await ws.openFile('${dir.path}/./part.dxf');
    expect(dotted, same(first));
    expect(ws.tabs, hasLength(1));

    final link = Link('${dir.path}/alias.dxf')..createSync(file.path);
    final viaLink = await ws.openFile(link.path);
    expect(viaLink, same(first));
    expect(ws.tabs, hasLength(1));
  });

  test(
    'notices cap at 32 and approval without a listener is a decline',
    () async {
      final ws = workspace();
      for (var i = 0; i < 40; i++) {
        ws.notify('n$i');
      }
      expect(ws.state.notices, hasLength(32));
      expect(ws.state.notices.first.message, 'n8');
      ws.dismissNotice(ws.state.notices.first);
      expect(ws.state.notices, hasLength(31));
      expect(ws.state.notices.first.message, 'n9');

      expect(await ws.requestApproval('Erase', '2 entities'), isFalse);
      expect(
        ws.commandLine.state.lines.any(
          (line) => line.text.contains('no approval UI'),
        ),
        isTrue,
      );

      final seen = ws.approvals.first;
      final pending = ws.requestApprovalFor('Edit', 'ok', const [7, 8]);
      final request = await seen;
      expect(request.request.highlightIds, [7, 8]);
      request.approve();
      request.reject();
      expect(await pending, isTrue);
    },
  );

  test(
    'drafting toggles persist and a saved snap list drops unknown names',
    () {
      final ws = workspace(
        settings: SettingsStore.inMemory({
          SettingsKeys.snapModes: ['nearest', 'bogus'],
          SettingsKeys.orthoMode: true,
          SettingsKeys.showGrid: false,
        }),
      );
      expect(ws.snapEngine.modes, {SnapMode.nearest});
      expect(ws.snapEngine.tracking.ortho, isTrue);

      final tab = ws.newDocument();
      expect(tab.showGrid, isFalse);

      ws.setSnapEnabled(false);
      ws.setPolar(false);
      ws.setPolarIncrement(0.5);
      ws.setShowGrid(true);
      ws.toggleSnapMode(SnapMode.endpoint);
      ws.setPendingHighlights(const [3]);

      expect(ws.snapEngine.enabled, isFalse);
      expect(ws.snapEngine.tracking.polar, isFalse);
      expect(ws.snapEngine.tracking.polarIncrement, 0.5);
      expect(tab.showGrid, isTrue);
      expect(ws.snapEngine.modes, {SnapMode.nearest, SnapMode.endpoint});
      expect(ws.state.highlightIds, [3]);
    },
  );

  test('headless run and save refuse work when nothing is open', () async {
    final ws = workspace();
    expect(await ws.saveActive(), isNull);
    expect(ws.state.notices.single.message, contains('no drawing'));
    expect(
      (await ws.runHeadless('query.summary')).message,
      contains('No drawing'),
    );
    expect(await ws.submitCommandLine(''), isNull);
  });

  test(
    'saveActive refuses a blank path instead of writing the empty string',
    () async {
      final ws = workspace();
      ws.newDocument(title: 'Untitled');
      expect(await ws.saveActive('   '), isNull);
      expect(ws.state.notices.single.message, contains('no path to save'));
      expect(ws.active!.filePath, isNull);
      expect(ws.active!.isDirty, isFalse);
    },
  );

  test('close on an empty workspace does not invent a drawing', () async {
    final ws = workspace();

    final result = await ws.run('file.close');
    expect(result.status, CommandStatus.failed);
    expect(result.message, contains('no drawing to close'));
    expect(ws.tabs, isEmpty);
  });

  test('opening settings without a drawing does not create a tab', () async {
    final ws = workspace();

    expect(ws.tabs, isEmpty);
    final result = await ws.run('workbench.preferences');
    expect(result.isOk, isTrue);
    expect(ws.tabs, isEmpty);
  });

  test('cancelActive drops a selection the way Escape should', () {
    final ws = workspace();
    final tab = ws.newDocument();
    tab.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    });
    tab.selection.replace([tab.document.entities.single.id]);
    ws.cancelActive();
    expect(tab.selection.ids, isEmpty);
  });

  test(
    'cancelActive still drops a selection after a rest that never panned',
    () {
      final ws = workspace();
      final tab = ws.newDocument();
      tab.session.edit('LINE', (transaction) {
        transaction.add(
          const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
        );
      });
      tab.selection.replace([tab.document.entities.single.id]);
      tab.viewport.setSize(const Size(800, 600), 1);
      tab.viewport.beginInteraction();

      ws.cancelActive();
      expect(tab.viewport.isInteracting, isFalse);
      expect(tab.selection.ids, isEmpty);
    },
  );

  test('cancelActive puts the camera back during a pan', () {
    final ws = workspace();
    final tab = ws.newDocument();
    tab.viewport.setSize(const Size(800, 600), 1);
    final origin = tab.viewport.viewport.center;
    tab.viewport.beginInteraction();
    tab.viewport.panBy(const Offset(40, 0));
    expect(tab.viewport.viewport.center, isNot(origin));

    ws.cancelActive();
    expect(tab.viewport.isInteracting, isFalse);
    expect(tab.viewport.viewport.center.x, closeTo(origin.x, 1e-12));
    expect(tab.viewport.viewport.center.y, closeTo(origin.y, 1e-12));
  });

  test(
    'cancelActive drops a typed prompt without clearing the selection',
    () async {
      final ws = workspace();
      final tab = ws.newDocument();
      tab.session.edit('LINE', (transaction) {
        transaction.add(
          const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
        );
      });
      final id = tab.document.entities.single.id;
      tab.selection.replace([id]);

      final pending = ws.commandLine.request(
        PendingEntry(
          message: 'Number of sides:',
          completer: Completer<Object?>(),
          accept: (raw) => raw,
        ),
      );
      expect(ws.commandLine.isAwaitingInput, isTrue);

      ws.cancelActive();
      await expectLater(pending, throwsA(isA<CommandCancelled>()));
      expect(ws.commandLine.isAwaitingInput, isFalse);
      expect(tab.selection.ids, [id]);
    },
  );

  test('cancelActive abandons LINE at the first point', () async {
    final ws = workspace();
    final tab = ws.newDocument();

    final running = ws.run('draw.line');
    await Future<void>.delayed(Duration.zero);
    expect(ws.commandLine.isAwaitingInput, isTrue);
    expect(tab.tools.activeTool, isA<PointPromptTool>());

    ws.cancelActive();
    final result = await running;
    expect(result.isCancelled, isTrue);
    expect(tab.document.entityCount, 0);
  });

  test(
    'cancelActive abandons LINE after a leftover drag on the next point',
    () async {
      final ws = workspace();
      final tab = ws.newDocument();
      tab.viewport.viewport = const CadViewport(
        center: Vec2(5, 0),
        scale: 1,
        size: Size(800, 600),
      );

      final running = ws.run('draw.line');
      await Future<void>.delayed(Duration.zero);
      tab.tools.onPointerDown(
        Vec2.zero(),
        const PointerDownEvent(pointer: 1, buttons: kPrimaryMouseButton),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tab.tools.activeTool, isA<PointPromptTool>());

      tab.tools.onPointerMove(
        const Vec2(10, 0),
        const PointerMoveEvent(pointer: 1, position: Offset(20, 0)),
      );
      expect(tab.tools.hasCancellableGesture, isFalse);

      ws.cancelActive();
      final result = await running;
      expect(result.isCancelled, isTrue);
      expect(tab.document.entityCount, 0);
    },
  );

  test('headless erase without ids cannot eat the leftover pick', () async {
    final app = Headless();
    final id = await app.drawLine(0, 0, 10, 0);
    app.workspace.active!.selection.replace([id]);
    final result = await app.workspace.runHeadless('edit.erase');
    expect(result.isOk, isFalse);
    expect(app.document.entity(id), isNotNull);
  });

  test('an AI write is refused while a person is in a command', () async {
    final app = Headless();
    final running = app.workspace.run('draw.line');
    await Future<void>.delayed(Duration.zero);
    expect(app.workspace.state.runningCommand, 'draw.line');

    final blocked = await app.workspace.runHeadless(
      'draw.circle',
      args: {
        'center': [0, 0],
        'radius': 1,
      },
      source: ChangeSource.ai,
    );
    expect(blocked.isFailed, isTrue);
    expect(blocked.message, contains('draw.line is running'));

    final query = await app.workspace.runHeadless(
      'query.summary',
      source: ChangeSource.ai,
    );
    expect(query.isOk, isTrue);

    app.workspace.cancelActive();
    await running;
  });

  test('an AI erase without ids still leaves the leftover pick', () async {
    final app = Headless();
    final id = await app.drawLine(0, 0, 10, 0);
    app.workspace.active!.selection.replace([id]);
    final result = await app.workspace.runHeadless(
      'edit.erase',
      source: ChangeSource.ai,
    );
    expect(result.isOk, isFalse);
    expect(app.document.entity(id), isNotNull);
  });

  test('the assistant being busy refuses a new interactive verb', () async {
    final app = Headless();
    app.workspace.setAssistantBusy(true);
    final blocked = await app.workspace.run('draw.circle');
    expect(blocked.isFailed, isTrue);
    expect(blocked.message, contains('assistant is working'));
  });

  test('the assistant being busy drops an in-flight grip stretch', () {
    final app = Headless();
    final tab = app.workspace.active!;
    tab.viewport.viewport = const CadViewport(
      center: Vec2(5, 0),
      scale: 1,
      size: Size(800, 600),
    );
    final id = tab.document
        .addEntity(
          const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
        )
        .id;
    final tools = tab.tools;
    PointerDownEvent down(Offset local) => PointerDownEvent(
      pointer: 1,
      position: local,
      buttons: kPrimaryMouseButton,
    );

    tools.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    tools.onPointerDown(const Vec2(0, 0), down(Offset.zero));
    expect((tools.activeTool as SelectionTool).isEditingGrip, isTrue);
    tools.onPointerMove(
      const Vec2(0, 4),
      const PointerMoveEvent(pointer: 1, position: Offset(0, 20)),
    );
    expect(tools.hasCancellableGesture, isTrue);

    app.workspace.setAssistantBusy(true);
    expect((tools.activeTool as SelectionTool).isEditingGrip, isFalse);
    final line = tab.document.entity(id)! as LineEntity;
    expect(line.start, const Vec2.zero());
    expect(line.end, const Vec2(10, 0));
  });

  test('session.supply feeds a point into a live command', () async {
    final app = Headless();
    final running = app.workspace.run('draw.circle');
    await Future<void>.delayed(Duration.zero);
    expect(app.workspace.commandLine.pending, isNotNull);

    final center = app.workspace.supplyInteractive({
      'point': [0, 0],
    });
    expect(center['status'], 'ok');
    await Future<void>.delayed(Duration.zero);

    final radius = app.workspace.supplyInteractive({'number': 5});
    expect(radius['status'], 'ok');
    final result = await running;
    expect(result.isOk, isTrue);
    expect(app.document.entityCount, 1);
  });

  test('an AI circle missing the centre hands off to the crosshair', () async {
    final app = Headless();
    final future = app.workspace.runHeadless(
      'draw.circle',
      args: {'radius': 4},
      source: ChangeSource.ai,
    );
    await Future<void>.delayed(Duration.zero);
    expect(app.workspace.state.runningCommand, 'draw.circle');

    final supplied = app.workspace.supplyInteractive({
      'point': [2, 3],
    });
    expect(supplied['status'], 'ok');
    final result = await future;
    expect(result.isOk, isTrue);
    expect(app.document.entityCount, 1);
  });

  test('flashHighlights show up on the pending overlay list', () {
    final ws = workspace();
    ws.newDocument();
    ws.flashHighlights(const [3, 5]);
    expect(ws.state.highlightIds, [3, 5]);
    ws.setPendingHighlights(const [9]);
    expect(ws.state.highlightIds, [9, 3, 5]);
    ws.flashHighlights(const []);
    expect(ws.state.highlightIds, [9]);
  });

  test('a leftover empty workspace has no view and no leftover last ids', () {
    final ws = workspace();
    expect(ws.describeView(), isEmpty);
    expect(ws.state.lastCreatedIds, isEmpty);
    expect(ws.state.lastModifiedIds, isEmpty);
    expect(ws.collectedPointCount, 0);
  });

  test('a successful draw records lastCreatedIds', () async {
    final app = Headless();
    final id = await app.drawLine(0, 0, 10, 0);
    expect(app.workspace.state.lastCreatedIds, [id]);
    expect(app.workspace.describeView(), isNotEmpty);
  });

  test('collectedPointCount follows an in-flight LINE', () async {
    final app = Headless();
    final running = app.workspace.run('draw.line');
    await Future<void>.delayed(Duration.zero);
    expect(app.workspace.collectedPointCount, 0);

    expect(
      app.workspace.supplyInteractive({
        'point': [0, 0],
      })['status'],
      'ok',
    );
    await Future<void>.delayed(Duration.zero);
    expect(app.workspace.collectedPointCount, 1);

    app.workspace.cancelActive();
    await running;
    expect(app.workspace.collectedPointCount, 0);
  });

  test('hover highlights join the pending overlay list and clear on exit', () {
    final ws = workspace();
    ws.newDocument();
    ws.setHoverHighlights(const [3]);
    expect(ws.state.highlightIds, [3]);
    ws.setPendingHighlights(const [9]);
    expect(ws.state.highlightIds, [9, 3]);
    ws.setHoverHighlights(const []);
    expect(ws.state.highlightIds, [9]);
  });

  test('an AI polyline without points hands off to the crosshair', () async {
    final app = Headless();
    final future = app.workspace.runHeadless(
      'draw.polyline',
      source: ChangeSource.ai,
    );
    await Future<void>.delayed(Duration.zero);
    expect(app.workspace.state.runningCommand, 'draw.polyline');

    expect(
      app.workspace.supplyInteractive({
        'point': [0, 0],
      })['status'],
      'ok',
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      app.workspace.supplyInteractive({
        'point': [10, 0],
      })['status'],
      'ok',
    );
    await Future<void>.delayed(Duration.zero);
    app.workspace.commandLine.submit('');
    final result = await future;
    expect(result.isOk, isTrue);
    expect(app.document.entityCount, 1);
  });

  test(
    'COPYCLIP then PASTECLIP in another tab ghosts and places on click',
    () async {
      final app = Headless();
      final source = app.workspace.active!;
      source.viewport.viewport = const CadViewport(
        center: Vec2(5, 0),
        scale: 1,
        size: Size(800, 600),
      );
      final id = await app.drawLine(0, 0, 10, 0);
      source.selection.replace([id]);

      final copied = await app.workspace.run('edit.copyClip');
      expect(copied.isOk, isTrue, reason: copied.message);
      expect(app.workspace.clipboard.isEmpty, isFalse);

      final dest = app.workspace.newDocument();
      dest.viewport.viewport = const CadViewport(
        center: Vec2(5, 0),
        scale: 1,
        size: Size(800, 600),
      );
      app.workspace.setSnapEnabled(false);
      app.workspace.setOrtho(false);
      app.workspace.setPolar(false);
      app.workspace.setShowGrid(false);

      final pasting = app.workspace.run('edit.pasteClip');
      await Future<void>.delayed(Duration.zero);
      expect(app.workspace.state.runningCommand, 'edit.pasteClip');
      expect(dest.tools.activeTool, isA<PointPromptTool>());

      dest.tools.onPointerMove(
        const Vec2(4, 5),
        const PointerMoveEvent(pointer: 1, position: Offset(4, 5)),
      );
      expect(dest.tools.buildOverlay().shapes, isNotEmpty);

      dest.tools.onPointerDown(
        const Vec2(4, 5),
        const PointerDownEvent(pointer: 1, buttons: kPrimaryMouseButton),
      );
      final pasted = await pasting;
      expect(pasted.isOk, isTrue, reason: pasted.message);
      final line = dest.document.entities.whereType<LineEntity>().single;
      expect(line.start, const Vec2(4, 5));
      expect(line.end, const Vec2(14, 5));
    },
  );

  test(
    'PASTECLIP preview follows the dest cursor even with polar on',
    () async {
      final app = Headless();
      final source = app.workspace.active!;
      source.viewport.viewport = const CadViewport(
        center: Vec2(1000, 2000),
        scale: 1,
        size: Size(800, 600),
      );
      final id = await app.drawLine(1000, 2000, 1010, 2000);
      source.selection.replace([id]);
      final copied = await app.workspace.run('edit.copyClip');
      expect(copied.isOk, isTrue, reason: copied.message);

      final dest = app.workspace.newDocument();
      dest.viewport.viewport = const CadViewport(
        center: Vec2(5, 0),
        scale: 1,
        size: Size(800, 600),
      );
      app.workspace.setSnapEnabled(false);
      app.workspace.setOrtho(false);
      app.workspace.setPolar(true);
      app.workspace.setShowGrid(false);

      final pasting = app.workspace.run('edit.pasteClip');
      await Future<void>.delayed(Duration.zero);
      dest.tools.onPointerMove(
        const Vec2(4, 5),
        const PointerMoveEvent(pointer: 1, position: Offset(4, 5)),
      );
      expect(dest.tools.cursor, const Vec2(4, 5));
      expect(dest.tools.snap?.origin, SnapOrigin.free);

      dest.tools.onPointerDown(
        const Vec2(4, 5),
        const PointerDownEvent(pointer: 1, buttons: kPrimaryMouseButton),
      );
      final pasted = await pasting;
      expect(pasted.isOk, isTrue, reason: pasted.message);
      final line = dest.document.entities.whereType<LineEntity>().single;
      expect(line.start, const Vec2(4, 5));
      expect(line.end, const Vec2(14, 5));
    },
  );
}
