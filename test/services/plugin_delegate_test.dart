import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Workspace workspace() => Headless(document: false).workspace;

  test('sessionFor follows the active tab and is null with no drawing', () {
    final ws = workspace();
    final delegate = AppPluginDelegate(workspace: () => ws);
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
      final delegate = AppPluginDelegate(workspace: () => ws);

      final result = await delegate.runCommand(
        'test.mark',
        const {},
        scope: 'run-1',
      );
      expect(result.isOk, isTrue);
      expect(seen, ChangeSource.plugin);
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
    final delegate = AppPluginDelegate(workspace: () => ws);

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
      final delegate = AppPluginDelegate(workspace: () => ws);

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

  test('showMessage notifies the workspace', () {
    final ws = workspace();
    final delegate = AppPluginDelegate(workspace: () => ws);

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
    final delegate = AppPluginDelegate(workspace: () => ws);

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
