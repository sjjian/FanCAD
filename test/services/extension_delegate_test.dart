import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Workspace workspace() => Headless(document: false).workspace;

  test('sessionFor follows the active tab and is null with no drawing', () {
    final ws = workspace();
    final delegate = ExtensionDelegate(workspace: () => ws);
    expect(delegate.sessionFor(null), isNull);

    final tab = ws.newDocument(title: 'A');
    expect(delegate.sessionFor(null), same(tab.session));
    expect(delegate.commands.toList(), ws.commands.all.toList());
  });

  test(
    'runCommand uses the headless path and attributes the edit to the script',
    () async {
      final ws = workspace();
      ChangeSource? seen;
      ws.commands.register(
        CommandDescriptor(
          id: 'test.mark',
          title: 'Mark',
          handler: (context) async {
            seen = context.source;
            return const CommandResult.ok(data: {'ok': true});
          },
        ),
      );
      ws.newDocument();
      final delegate = ExtensionDelegate(workspace: () => ws);

      final result = await delegate.runCommand(
        'test.mark',
        const {},
        scope: 'run-1',
      );
      expect(result.isOk, isTrue);
      expect(seen, ChangeSource.extension);
    },
  );

  test('runCommand refuses exec before starting another run', () async {
    final ws = workspace();
    var ran = false;
    if (ws.commands.find('exec') == null) {
      ws.commands.register(
        CommandDescriptor(
          id: 'exec',
          title: 'Exec',
          handler: (context) async {
            ran = true;
            return const CommandResult.ok();
          },
        ),
      );
    }
    final delegate = ExtensionDelegate(workspace: () => ws);

    final result = await delegate.runCommand('exec', const {
      'source': '1 + 1',
    }, scope: 'run-1');
    expect(result.isFailed, isTrue);
    expect(result.message, contains('cannot be called'));
    expect(ran, isFalse);
  });

  test(
    'runCommand refuses a saved extension before starting another run',
    () async {
      final ws = workspace();
      var ran = false;
      ws.commands.register(
        CommandDescriptor(
          id: 'extension.rings',
          title: 'rings',
          handler: (context) async {
            ran = true;
            return const CommandResult.ok();
          },
        ),
      );
      final delegate = ExtensionDelegate(workspace: () => ws);

      final result = await delegate.runCommand(
        'extension.rings',
        const {},
        scope: 'run-1',
      );
      expect(result.isFailed, isTrue);
      expect(result.message, contains('cannot be called'));
      expect(ran, isFalse);
    },
  );

  test('runCommand refuses what the drawing cannot undo', () async {
    final ws = workspace();
    ws.newDocument();
    final delegate = ExtensionDelegate(workspace: () => ws);
    final before = ws.active!.document.entityCount;

    for (final (id, args) in <(String, Map<String, Object?>)>[
      (
        'edit.erase',
        const {
          'ids': [1],
        },
      ),
      ('edit.apply', const {'operations': [], 'replace': true}),
      ('file.save', const {}),
      ('file.saveAs', const {'path': '/tmp/out.dwg'}),
      ('file.close', const {}),
      ('edit.undo', const {}),
      ('edit.redo', const {}),
      ('extensions.write', const {'name': 'x', 'content': '1'}),
      ('extensions.delete', const {'name': 'x'}),
      ('extensions.run', const {'source': '1'}),
    ]) {
      final result = await delegate.runCommand(id, args, scope: 'run-1');
      expect(result.isFailed, isTrue, reason: id);
      expect(result.message, contains('cannot be called'), reason: id);
    }
    expect(ws.active!.document.entityCount, before);
  });

  test('scriptRefusal follows aliases and lets ordinary edits through', () {
    final ws = workspace();
    final commands = ws.commands;
    String? refusal(String id, [Map<String, Object?> args = const {}]) =>
        scriptRefusal(id, commands.find(id), args);

    expect(refusal('erase'), isNotNull);
    expect(refusal('draw.line'), isNull);
    expect(refusal('edit.apply', const {'operations': []}), isNull);
    expect(refusal('extensions.list'), isNull);
    expect(refusal('file.new'), isNull);
  });

  test('saveAs and a replacing edit.apply count as destructive', () {
    final commands = workspace().commands;
    expect(commands.find('file.saveAs')!.risk, CommandRisk.destructive);
    final apply = commands.find('edit.apply')!;
    expect(apply.riskFor(const {}), CommandRisk.edit);
    expect(apply.riskFor(const {'replace': true}), CommandRisk.destructive);
    expect(
      apply.riskFor(const {
        'operations': [
          {
            'op': 'erase',
            'ids': [1],
          },
        ],
      }),
      CommandRisk.destructive,
    );
  });

  test('showMessage notifies the workspace', () {
    final ws = workspace();
    final delegate = ExtensionDelegate(workspace: () => ws);

    delegate.showMessage('run-1', 'hello');
    delegate.showMessage('run-1', 'broken', isError: true);

    expect(ws.state.notices.map((notice) => notice.message), [
      'hello',
      'broken',
    ]);
    expect(ws.state.notices.last.isError, isTrue);
  });

  test('console lines land on the command line', () {
    final ws = workspace();
    final delegate = ExtensionDelegate(workspace: () => ws);

    delegate.log('run-1', 'info', 'counted 3');
    delegate.log('run-1', 'error', 'bad input');

    final lines = ws.commandLine.state.lines;
    expect(
      lines.map((line) => line.text),
      containsAllInOrder(['counted 3', 'bad input']),
    );
    expect(lines.last.level, HistoryLevel.error);
  });
}
