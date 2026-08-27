import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Workspace workspace({SettingsStore? settings}) {
    final created = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(settings ?? SettingsStore.inMemory()),
    );
    addTearDown(created.dispose);
    return created;
  }

  test('session follows the active tab and is null with no drawing', () {
    final ws = workspace();
    final delegate = WorkspacePluginDelegate(
      workspace: () => ws,
      plugins: PluginSettings(SettingsStore.inMemory()),
    );
    expect(delegate.session, isNull);

    final tab = ws.newDocument(title: 'A');
    expect(delegate.session, same(tab.session));
    expect(delegate.commands.toList(), ws.commands.all.toList());
  });

  test(
    'runCommand uses the headless path and attributes the edit to the plugin',
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
      final delegate = WorkspacePluginDelegate(
        workspace: () => ws,
        plugins: PluginSettings(SettingsStore.inMemory()),
      );

      final result = await delegate.runCommand(
        'test.mark',
        const {},
        pluginId: 'demo',
      );
      expect(result.isOk, isTrue);
      expect(seen, ChangeSource.plugin);
    },
  );

  test('showMessage notifies the workspace and writes a plugin log line', () {
    final ws = workspace();
    final delegate = WorkspacePluginDelegate(
      workspace: () => ws,
      plugins: PluginSettings(SettingsStore.inMemory()),
    );

    delegate.showMessage('demo', 'hello');
    delegate.showMessage('demo', 'broken', isError: true);

    expect(ws.notices.map((notice) => notice.message), ['hello', 'broken']);
    expect(ws.notices.last.isError, isTrue);
    expect(delegate.logs['demo'], ['[info] hello', '[error] broken']);
  });

  test('plugin logs drop the oldest lines after 500', () {
    final ws = workspace();
    final delegate = WorkspacePluginDelegate(
      workspace: () => ws,
      plugins: PluginSettings(SettingsStore.inMemory()),
    );

    for (var i = 0; i < 501; i++) {
      delegate.log('demo', 'info', '$i');
    }

    expect(delegate.logs['demo'], hasLength(500));
    expect(delegate.logs['demo']!.first, '[info] 1');
    expect(delegate.logs['demo']!.last, '[info] 500');
  });

  test('a prompt without a handler cancels instead of hanging', () async {
    final ws = workspace();
    final delegate = WorkspacePluginDelegate(
      workspace: () => ws,
      plugins: PluginSettings(SettingsStore.inMemory()),
    );
    expect(await delegate.prompt('demo', const {'text': '?'}), isNull);

    delegate.promptHandler = (pluginId, spec) async =>
        '$pluginId:${spec['text']}';
    expect(await delegate.prompt('demo', const {'text': '?'}), 'demo:?');
  });

  test('plugin storage is namespaced inside the settings file', () async {
    final settings = SettingsStore.inMemory();
    final ws = workspace(settings: settings);
    final delegate = WorkspacePluginDelegate(
      workspace: () => ws,
      plugins: PluginSettings(settings),
    );

    await delegate.writeStorage('demo', 'token', 'abc');
    expect(await delegate.readStorage('demo', 'token'), 'abc');
    expect(settings.values['plugins.storage.demo.token'], 'abc');
    expect(await delegate.readStorage('other', 'token'), isNull);
  });
}
