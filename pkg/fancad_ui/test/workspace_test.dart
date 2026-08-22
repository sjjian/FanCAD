import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Workspace workspace({SettingsStore? settings}) {
    final created = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      settings: settings ?? SettingsStore.inMemory(),
    );
    addTearDown(created.dispose);
    return created;
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
    expect(ws.activeIndex, 0);
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
    expect(ws.activeIndex, -1);
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
    expect(ws.activeIndex, 0);

    expect(ws.closeTab(1), isTrue);
    expect(ws.tabs, [same(second)]);
    expect(ws.active, same(second));
  });

  test('an already-open path is activated and a missing file becomes a notice',
      () async {
    final ws = workspace();
    final first = ws.newDocument();
    first.filePath = '/tmp/already-open.dxf';
    ws.newDocument();
    expect(ws.activeIndex, 1);

    final again = await ws.openFile('/tmp/already-open.dxf');
    expect(again, same(first));
    expect(ws.active, same(first));

    expect(await ws.openFile('/tmp/fancad-missing-open.dxf'), isNull);
    expect(ws.notices.single.isError, isTrue);
    expect(ws.notices.single.message, contains('fancad-missing-open.dxf'));
  });

  test('notices cap at 32 and approval without a listener is a decline',
      () async {
    final ws = workspace();
    for (var i = 0; i < 40; i++) {
      ws.notify('n$i');
    }
    expect(ws.notices, hasLength(32));
    expect(ws.notices.first.message, 'n8');
    ws.dismissNotice(ws.notices.first);
    expect(ws.notices, hasLength(31));
    expect(ws.notices.first.message, 'n9');

    expect(await ws.requestApproval('Erase', '2 entities'), isFalse);
    expect(
      ws.commandLine.lines.any(
        (line) => line.text.contains('no approval UI'),
      ),
      isTrue,
    );

    final seen = ws.approvals.first;
    final pending = ws.requestApprovalFor('Edit', 'ok', const [7, 8]);
    final request = await seen;
    expect(request.highlightIds, [7, 8]);
    request.approve();
    request.reject();
    expect(await pending, isTrue);
  });

  test('drafting toggles persist and a saved snap list drops unknown names', () {
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
    expect(ws.settings.getBool(SettingsKeys.snapEnabled), isFalse);
    expect(ws.snapEngine.tracking.polar, isFalse);
    expect(ws.snapEngine.tracking.polarIncrement, 0.5);
    expect(tab.showGrid, isTrue);
    expect(ws.snapEngine.modes, {SnapMode.nearest, SnapMode.endpoint});
    expect(ws.pendingHighlightIds, [3]);
  });

  test('headless run and save refuse work when nothing is open', () async {
    final ws = workspace();
    ws.commands.register(
      CommandDescriptor(
        id: 'query.summary',
        title: 'Summary',
        handler: (_) async => const CommandResult.ok(),
      ),
    );
    expect(await ws.saveActive(), isNull);
    expect(ws.notices.single.message, contains('no drawing'));
    expect(
      (await ws.runHeadless('query.summary')).message,
      contains('No drawing'),
    );
    expect(await ws.submitCommandLine(''), isNull);
  });
}
