import 'dart:convert';
import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A delegate over a real document, so edits are checked against the model
/// rather than against a mock's expectations.
class TestDelegate implements PluginHostDelegate {
  TestDelegate(this.registry) {
    session = DocumentSession(id: 'test', document: CadDocument());
  }

  final CommandRegistry registry;
  @override
  late DocumentSession session;

  final List<String> messages = [];
  final List<String> logs = [];
  final Map<String, Map<String, Object?>> storage = {};

  /// Answers `window.prompt`. Null means "the user cancelled".
  Object? promptAnswer;

  @override
  Iterable<CommandDescriptor> get commands => registry.all;

  @override
  Future<CommandResult> runCommand(
    String commandId,
    Map<String, Object?> args, {
    required String pluginId,
  }) async {
    final descriptor = registry.find(commandId);
    if (descriptor == null) {
      return CommandResult.failed('no such command: $commandId');
    }
    final parsed = CommandArgs(args);
    return descriptor.handler(
      CommandContext(
        session: session,
        args: parsed,
        input: ArgsCommandInput(
          args: parsed,
          params: descriptor.params,
          selection: session.selection,
        ),
        source: ChangeSource.plugin,
        commandId: commandId,
      ),
    );
  }

  @override
  void showMessage(String pluginId, String message, {bool isError = false}) {
    messages.add('${isError ? 'error' : 'info'}: $message');
  }

  @override
  void log(String pluginId, String level, String message) {
    logs.add('[$level] $message');
  }

  @override
  Future<Object?> prompt(String pluginId, Map<String, Object?> spec) async =>
      promptAnswer;

  @override
  Future<Object?> readStorage(String pluginId, String key) async =>
      storage[pluginId]?[key];

  @override
  Future<void> writeStorage(String pluginId, String key, Object? value) async {
    storage.putIfAbsent(pluginId, () => {})[key] = value;
  }
}

/// Builds a scripted engine whose dispatch runs a Dart handler, standing in for
/// the plugin's JavaScript.
JsEngineFactory engineRunning(
  Map<String, Future<Object?> Function(Map<String, Object?> args)> handlers, {
  List<String>? registers,
  void Function(ScriptedJsEngine engine)? capture,
}) => ({required int memoryLimit, required int stackSize}) {
      final engine = ScriptedJsEngine();
      engine.globals[BootstrapGlobals.registered] = () =>
          jsonEncode({'commands': registers ?? handlers.keys.toList()});
      engine.globals[BootstrapGlobals.deactivate] =
          () => jsonEncode({'result': null});
      engine.globals[BootstrapGlobals.dispatch] =
          (String kind, String id, String payload) async {
        final handler = handlers[id];
        if (handler == null) throw JsException('no handler for $id');
        final args = jsonDecode(payload) as Map<String, Object?>;
        return jsonEncode({'result': await handler(args)});
      };
      capture?.call(engine);
      return engine;
    };

PluginManifest demoManifest({
  String id = 'demo',
  List<String> commands = const ['demo.run'],
  Set<PluginPermission> permissions = const {
    PluginPermission.documentRead,
    PluginPermission.documentWrite,
    PluginPermission.commands,
  },
  List<ActivationEvent> activation = const [],
  List<PanelContribution> panels = const [],
}) => PluginManifest(
  id: id,
  name: 'Demo $id',
  version: '1.0.0',
  entryPoint: 'main.js',
  permissions: permissions,
  activation: activation,
  panels: panels,
  commands: [
    for (final command in commands)
      CommandContribution(id: command, title: command, category: 'Demo'),
  ],
);

Future<
  ({
    PluginHost host,
    TestDelegate delegate,
    CommandRegistry registry,
    LocalTransport transport,
  })
> buildHost(JsEngineFactory factory) async {
  final registry = CommandRegistry();
  final delegate = TestDelegate(registry);
  final transport = LocalTransport(engineFactory: factory);
  final host = PluginHost(
    registry: registry,
    delegate: delegate,
    transport: transport,
  );
  await host.start();
  return (
    host: host,
    delegate: delegate,
    registry: registry,
    transport: transport,
  );
}

void main() {
  group('registration', () {
    test('contributed commands reach the registry before any code runs',
        () async {
      var engineBuilt = 0;
      final context = await buildHost(
        ({required int memoryLimit, required int stackSize}) {
          engineBuilt++;
          return ScriptedJsEngine();
        },
      );
      context.host.registerManifest(demoManifest());

      final descriptor = context.registry.find('demo.run');
      expect(descriptor, isNotNull);
      expect(descriptor!.extensionId, 'demo');
      expect(descriptor.category, 'Demo');
      // The whole point of lazy activation: the command is visible, but the
      // plugin has not been given a runtime.
      expect(engineBuilt, 0);
      expect(context.host.plugin('demo')!.state, PluginState.installed);
    });

    test('uninstalling removes the commands again', () async {
      final context = await buildHost(engineRunning({}));
      context.host.registerManifest(demoManifest());
      expect(context.registry.find('demo.run'), isNotNull);

      await context.host.uninstall('demo');
      expect(context.registry.find('demo.run'), isNull);
      expect(context.host.plugin('demo'), isNull);
    });

    test('panels are contributed and withdrawn with the plugin', () async {
      final context = await buildHost(engineRunning({}));
      context.host.registerManifest(
        demoManifest(
          panels: const [
            PanelContribution(id: 'demo.panel', title: 'Demo'),
          ],
        ),
      );
      expect(
        context.host.contributions.panelsAt(PanelLocation.sidebar).single.id,
        'demo.panel',
      );
      expect(context.host.contributions.ownerOfPanel('demo.panel'), 'demo');

      await context.host.uninstall('demo');
      expect(context.host.contributions.panelsAt(PanelLocation.sidebar),
          isEmpty);
    });

    test('two plugins claiming the same command id: the second is rejected',
        () async {
      final context = await buildHost(engineRunning({}));
      context.host.registerManifest(demoManifest(id: 'first'));
      final second = context.host.registerManifest(
        demoManifest(id: 'second'),
      );
      expect(second.state, PluginState.failed);
      expect(second.error, contains('already registered'));
      // The winner keeps working.
      expect(context.registry.find('demo.run')!.extensionId, 'first');
    });
  });

  group('activation', () {
    test('invoking a contributed command activates its plugin', () async {
      var ran = 0;
      final context = await buildHost(
        engineRunning({
          'demo.run': (args) async {
            ran++;
            return {'ok': true};
          },
        }),
      );
      context.host.registerManifest(demoManifest());
      context.host.setSource('demo', 'source');

      final result = await context.delegate.runCommand(
        'demo.run',
        const {},
        pluginId: 'test',
      );

      expect(result.isOk, isTrue);
      expect(result.data, {'ok': true});
      expect(ran, 1);
      expect(context.host.plugin('demo')!.state, PluginState.active);
    });

    test('a second invocation reuses the runtime', () async {
      var engines = 0;
      final context = await buildHost(
        ({required int memoryLimit, required int stackSize}) {
          engines++;
          final engine = ScriptedJsEngine();
          engine.globals[BootstrapGlobals.registered] =
              () => jsonEncode({'commands': ['demo.run']});
          engine.globals[BootstrapGlobals.deactivate] =
              () => jsonEncode({'result': null});
          engine.globals[BootstrapGlobals.dispatch] =
              (String kind, String id, String payload) async =>
                  jsonEncode({'result': null});
          return engine;
        },
      );
      context.host.registerManifest(demoManifest());
      context.host.setSource('demo', 'source');

      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect(engines, 1);
    });

    test('activation without source on disk fails with a clear reason',
        () async {
      final context = await buildHost(engineRunning({}));
      context.host.registerManifest(demoManifest());

      final activated = await context.host.activate('demo');
      expect(activated, isFalse);
      final handle = context.host.plugin('demo')!;
      expect(handle.state, PluginState.failed);
      expect(handle.error, contains('no source'));
    });

    test('a disabled plugin refuses to run', () async {
      final context = await buildHost(
        engineRunning({'demo.run': (args) async => null}),
      );
      context.host.registerManifest(demoManifest());
      context.host.setSource('demo', 'source');
      await context.host.setEnabled('demo', false);

      final result = await context.delegate.runCommand(
        'demo.run',
        const {},
        pluginId: 'test',
      );
      expect(result.isFailed, isTrue);
      expect(result.message, contains('disabled'));

      await context.host.setEnabled('demo', true);
      expect(context.host.plugin('demo')!.state, PluginState.installed);
    });

    test('startup activation only touches plugins that asked for it', () async {
      final activated = <String>[];
      final context = await buildHost(
        ({required int memoryLimit, required int stackSize}) {
          final engine = ScriptedJsEngine(
            onEvaluate: (source, name) {
              if (name.endsWith('/activate')) activated.add(name);
              return null;
            },
          );
          engine.globals[BootstrapGlobals.registered] =
              () => jsonEncode({'commands': const <String>[]});
          engine.globals[BootstrapGlobals.deactivate] =
              () => jsonEncode({'result': null});
          return engine;
        },
      );
      context.host.registerManifest(
        demoManifest(
          id: 'eager',
          commands: const [],
          activation: const [ActivationEvent(ActivationKind.startup)],
        ),
      );
      context.host.registerManifest(demoManifest(id: 'lazy', commands: const []));
      context.host.setSource('eager', 'source');
      context.host.setSource('lazy', 'source');

      await context.host.activateStartupPlugins();
      expect(context.host.plugin('eager')!.state, PluginState.active);
      expect(context.host.plugin('lazy')!.state, PluginState.installed);
      expect(activated, ['eager/activate']);
    });

    test('a plugin whose handler throws reports failure, not a crash',
        () async {
      final context = await buildHost(
        engineRunning({
          'demo.run': (args) async => throw const JsException('boom'),
        }),
      );
      context.host.registerManifest(demoManifest());
      context.host.setSource('demo', 'source');

      final result = await context.delegate.runCommand(
        'demo.run',
        const {},
        pluginId: 'test',
      );
      expect(result.isFailed, isTrue);
      expect(result.message, contains('boom'));
      expect(context.host.plugin('demo')!.log, isNotEmpty);
    });
  });

  group('host api', () {
    Future<
      ({
        PluginHost host,
        TestDelegate delegate,
        CommandRegistry registry,
        LocalTransport transport,
      })
    > hostCalling(
      String method,
      Map<String, Object?> params, {
      Set<PluginPermission> permissions = const {
        PluginPermission.documentRead,
        PluginPermission.documentWrite,
        PluginPermission.commands,
        PluginPermission.ui,
        PluginPermission.fileWrite,
      },
      void Function(Object? result, Object? error)? onResult,
    }) async {
      late ScriptedJsEngine engine;
      final context = await buildHost(
        engineRunning(
          {
            'demo.run': (args) async {
              final raw = await (engine.call(BootstrapGlobals.rpc, [
                method,
                jsonEncode(params),
              ]) as Future<String>);
              final envelope = jsonDecode(raw) as Map<String, Object?>;
              onResult?.call(envelope['result'], envelope['error']);
              return envelope;
            },
          },
          capture: (value) => engine = value,
        ),
      );
      context.host.registerManifest(demoManifest(permissions: permissions));
      context.host.setSource('demo', 'source');
      return context;
    }

    test('document.summary reports counts, layers and extents', () async {
      Object? seen;
      final context = await hostCalling(
        HostMethod.documentSummary,
        const {},
        onResult: (result, error) => seen = result,
      );
      context.delegate.session.edit('setup', (transaction) {
        transaction.add(
          LineEntity(id: 0, start: const Vec2.zero(), end: Vec2(10, 0)),
        );
        transaction.add(
          CircleEntity(id: 0, center: Vec2(5, 5), radius: 2),
        );
      });

      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');

      final summary = seen as Map<String, Object?>;
      expect(summary['entityCount'], 2);
      expect(summary['byKind'], {'line': 1, 'circle': 1});
      expect(summary['currentLayer'], '0');
      expect(summary['extents'], [0.0, 0.0, 10.0, 7.0]);
    });

    test('document.query filters by layer, kind and window', () async {
      Object? seen;
      final context = await hostCalling(
        HostMethod.documentQuery,
        const {'kinds': ['line'], 'window': [-1, -1, 5, 5]},
        onResult: (result, error) => seen = result,
      );
      context.delegate.session.edit('setup', (transaction) {
        transaction.add(LineEntity(id: 0, start: const Vec2.zero(), end: Vec2(1, 1)));
        transaction.add(
          LineEntity(id: 0, start: Vec2(100, 100), end: Vec2(101, 101)),
        );
        transaction.add(CircleEntity(id: 0, center: const Vec2.zero(), radius: 1));
      });

      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');

      final entities =
          (seen as Map<String, Object?>)['entities'] as List<Object?>;
      expect(entities, hasLength(1));
      expect((entities.single as Map)['kind'], 'line');
    });

    test('document.edit creates geometry in one undoable transaction',
        () async {
      Object? seen;
      final context = await hostCalling(
        HostMethod.applyEdit,
        const {
          'label': 'Plugin grid',
          'operations': [
            {'op': 'add', 'kind': 'line', 'start': [0, 0], 'end': [10, 0]},
            {'op': 'add', 'kind': 'circle', 'center': [5, 5], 'radius': 2},
            {
              'op': 'add',
              'kind': 'polyline',
              'points': [[0, 0], [1, 0], [1, 1]],
              'closed': true,
            },
          ],
        },
        onResult: (result, error) => seen = result,
      );

      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');

      final session = context.delegate.session;
      expect(session.document.entities.length, 3);
      expect((seen as Map<String, Object?>)['created'], hasLength(3));

      // One command, one undo entry.
      session.undo();
      expect(session.document.entities, isEmpty);
    });

    test('an edit is attributed to the plugin, not the user', () async {
      final context = await hostCalling(
        HostMethod.applyEdit,
        const {
          'label': 'Plugin line',
          'operations': [
            {'op': 'add', 'kind': 'line', 'start': [0, 0], 'end': [1, 0]},
          ],
        },
      );
      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect(
        context.delegate.session.history.undoEntries.last.source,
        ChangeSource.plugin,
      );
    });

    test('document.edit without the permission is denied', () async {
      Object? error;
      final context = await hostCalling(
        HostMethod.applyEdit,
        const {
          'operations': [
            {'op': 'add', 'kind': 'line', 'start': [0, 0], 'end': [1, 0]},
          ],
        },
        permissions: const {PluginPermission.documentRead},
        onResult: (result, thrown) => error = thrown,
      );

      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');

      expect(error, isNotNull);
      expect((error as Map)['code'], RpcErrorCode.permissionDenied);
      expect(context.delegate.session.document.entities, isEmpty);
    });

    test('a read without the permission is denied', () async {
      Object? error;
      final context = await hostCalling(
        HostMethod.documentSummary,
        const {},
        permissions: const {PluginPermission.commands},
        onResult: (result, thrown) => error = thrown,
      );
      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect((error as Map)['code'], RpcErrorCode.permissionDenied);
    });

    test('an unsupported entity kind is refused with a useful message',
        () async {
      Object? error;
      final context = await hostCalling(
        HostMethod.applyEdit,
        const {
          'operations': [
            {'op': 'add', 'kind': 'spline', 'points': [[0, 0]]},
          ],
        },
        onResult: (result, thrown) => error = thrown,
      );
      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect((error as Map)['message'], contains('spline'));
    });

    test('a malformed point is refused rather than silently zeroed', () async {
      Object? error;
      final context = await hostCalling(
        HostMethod.applyEdit,
        const {
          'operations': [
            {'op': 'add', 'kind': 'circle', 'center': 'somewhere', 'radius': 1},
          ],
        },
        onResult: (result, thrown) => error = thrown,
      );
      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect((error as Map)['message'], contains('point'));
      expect(context.delegate.session.document.entities, isEmpty);
    });

    test('a non-positive radius is refused', () async {
      Object? error;
      final context = await hostCalling(
        HostMethod.applyEdit,
        const {
          'operations': [
            {'op': 'add', 'kind': 'circle', 'center': [0, 0], 'radius': 0},
          ],
        },
        onResult: (result, thrown) => error = thrown,
      );
      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect((error as Map)['message'], contains('greater than zero'));
    });

    test('an edit skips entities on a locked layer and says so', () async {
      Object? seen;
      final context = await hostCalling(
        HostMethod.applyEdit,
        const {'operations': []},
        onResult: (result, error) => seen = result,
      );
      final session = context.delegate.session;
      late int id;
      session.edit('setup', (transaction) {
        id = transaction.add(
          LineEntity(id: 0, start: const Vec2.zero(), end: Vec2(1, 0)),
        );
        transaction.putLayer(const LayerDef(name: '0', locked: true));
      });

      // Rebuild the request now that we know the id.
      final engineContext = await hostCalling(
        HostMethod.applyEdit,
        {
          'operations': [
            {'op': 'erase', 'ids': [id]},
          ],
        },
        onResult: (result, error) => seen = result,
      );
      engineContext.delegate.session = session;
      await engineContext.delegate.runCommand('demo.run', const {},
          pluginId: 'test');

      expect(session.document.entity(id), isNotNull);
      expect(
        (seen as Map<String, Object?>)['blockedByLockedLayer'],
        ['$id'],
      );
      await context.host.dispose();
    });

    test('selection round trips and ignores ids that do not exist', () async {
      Object? seen;
      final context = await hostCalling(
        HostMethod.selectionSet,
        const {'ids': [1, 9999]},
        onResult: (result, error) => seen = result,
      );
      context.delegate.session.edit('setup', (transaction) {
        transaction.add(LineEntity(id: 0, start: const Vec2.zero(), end: Vec2(1, 0)));
      });

      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect((seen as Map<String, Object?>)['ids'], [1]);
    });

    test('commands.execute runs a real command', () async {
      Object? seen;
      final context = await hostCalling(
        HostMethod.executeCommand,
        const {'command': 'test.echo', 'args': {'value': 5}},
        onResult: (result, error) => seen = result,
      );
      context.registry.register(
        CommandDescriptor(
          id: 'test.echo',
          title: 'Echo',
          handler: (commandContext) async => CommandResult.ok(
            data: {'echoed': commandContext.args.integer('value')},
          ),
        ),
      );

      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect((seen as Map<String, Object?>)['data'], {'echoed': 5});
    });

    test('commands.execute without the permission is denied', () async {
      Object? error;
      final context = await hostCalling(
        HostMethod.executeCommand,
        const {'command': 'test.echo'},
        permissions: const {PluginPermission.documentRead},
        onResult: (result, thrown) => error = thrown,
      );
      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect((error as Map)['code'], RpcErrorCode.permissionDenied);
    });

    test('storage is namespaced per plugin and persists across calls',
        () async {
      final context = await hostCalling(
        HostMethod.storageSet,
        const {'key': 'lastRun', 'value': 42},
      );
      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect(context.delegate.storage['demo'], {'lastRun': 42});
    });

    test('window.showMessage reaches the delegate', () async {
      final context = await hostCalling(
        HostMethod.showMessage,
        const {'message': 'hello', 'error': true},
      );
      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect(context.delegate.messages, ['error: hello']);
    });

    test('an unknown host method is a method-not-found error', () async {
      Object? error;
      final context = await hostCalling(
        'window/openTheGarageDoor',
        const {},
        onResult: (result, thrown) => error = thrown,
      );
      await context.delegate.runCommand('demo.run', const {},
          pluginId: 'test');
      expect((error as Map)['code'], RpcErrorCode.methodNotFound);
    });
  });

  group('discovery and hot reload', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fancad_plugins');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    Future<void> writePlugin(
      String id, {
      String manifest = '',
      String source = '',
    }) async {
      final directory = Directory(p.join(root.path, id));
      await directory.create(recursive: true);
      await File(p.join(directory.path, PluginManifest.fileName))
          .writeAsString(manifest.isEmpty
              ? jsonEncode({
                  'id': id,
                  'name': id,
                  'version': '1.0.0',
                  'permissions': ['document.read'],
                  'contributes': {
                    'commands': [
                      {'id': '$id.run', 'title': 'Run $id'},
                    ],
                  },
                })
              : manifest);
      await File(p.join(directory.path, 'main.js'))
          .writeAsString(source.isEmpty ? '// nothing' : source);
    }

    test('discovery registers every valid plugin folder', () async {
      await writePlugin('alpha');
      await writePlugin('beta');
      final context = await buildHost(engineRunning({}));

      final found = await context.host.discover(root.path);
      expect(found.map((handle) => handle.id).toList()..sort(),
          ['alpha', 'beta']);
      expect(context.registry.find('alpha.run'), isNotNull);
      expect(context.registry.find('beta.run'), isNotNull);
    });

    test('one broken manifest does not stop the scan', () async {
      await writePlugin('good');
      await writePlugin('broken', manifest: '{ this is not json');
      final context = await buildHost(engineRunning({}));

      final found = await context.host.discover(root.path);
      expect(found, hasLength(2));
      expect(context.host.plugin('good')!.state, PluginState.installed);
      final broken = context.host.plugin('broken')!;
      expect(broken.state, PluginState.failed);
      expect(broken.error, isNotNull);
      // The healthy one is fully usable.
      expect(context.registry.find('good.run'), isNotNull);
    });

    test('a folder without a manifest is ignored', () async {
      await Directory(p.join(root.path, 'not-a-plugin')).create();
      final context = await buildHost(engineRunning({}));
      expect(await context.host.discover(root.path), isEmpty);
    });

    test('discovering a missing directory returns nothing', () async {
      final context = await buildHost(engineRunning({}));
      expect(
        await context.host.discover(p.join(root.path, 'nope')),
        isEmpty,
      );
    });

    test('reload picks up a changed manifest, not just changed code',
        () async {
      await writePlugin('alpha');
      final context = await buildHost(engineRunning({}, registers: const []));
      await context.host.discover(root.path);
      expect(context.registry.find('alpha.run'), isNotNull);
      expect(context.registry.find('alpha.extra'), isNull);

      await writePlugin(
        'alpha',
        manifest: jsonEncode({
          'id': 'alpha',
          'name': 'alpha',
          'contributes': {
            'commands': [
              {'id': 'alpha.run', 'title': 'Run'},
              {'id': 'alpha.extra', 'title': 'Extra'},
            ],
          },
        }),
      );
      await context.host.reload('alpha');

      expect(context.registry.find('alpha.extra'), isNotNull);
      expect(context.registry.find('alpha.run'), isNotNull);
    });

    test('scaffold writes a loadable plugin', () async {
      final manifest = await PluginHost.scaffold(
        root: root.path,
        id: 'generated',
        name: 'Generated',
        description: 'Written by a test.',
      );

      expect(manifest.id, 'generated');
      expect(
        File(p.join(manifest.directory, PluginManifest.fileName)).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(manifest.directory, 'main.js')).existsSync(),
        isTrue,
      );

      // The written manifest has to survive the parser it will be read with.
      final context = await buildHost(engineRunning({}, registers: const []));
      final installed = await context.host.install(manifest.directory);
      expect(installed, isNotNull);
      expect(installed!.state, PluginState.installed);
      expect(context.registry.find('generated.run'), isNotNull);
      expect(
        installed.manifest.activatesOnCommand('generated.run'),
        isTrue,
      );
    });

    test('the watcher reloads after a source change settles', () async {
      await writePlugin('alpha');
      final context = await buildHost(engineRunning({}, registers: const []));
      await context.host.discover(root.path);

      final watcher = PluginWatcher(
        host: context.host,
        debounce: const Duration(milliseconds: 40),
      );
      addTearDown(watcher.dispose);
      await watcher.watch(root.path);

      final reloaded = watcher.reloads.first;
      await File(p.join(root.path, 'alpha', 'main.js'))
          .writeAsString('// changed');

      await expectLater(
        reloaded.timeout(const Duration(seconds: 5)),
        completion('alpha'),
      );
    });

    test('the watcher ignores files that are not code or manifest', () async {
      await writePlugin('alpha');
      final context = await buildHost(engineRunning({}, registers: const []));
      await context.host.discover(root.path);

      final watcher = PluginWatcher(
        host: context.host,
        debounce: const Duration(milliseconds: 20),
      );
      addTearDown(watcher.dispose);
      await watcher.watch(root.path);

      // Let events from writing the plugin itself drain first. The platform
      // watcher can deliver a short backlog from before the watch started, and
      // counting those would test the operating system rather than the filter.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      var reloads = 0;
      watcher.reloads.listen((_) => reloads++);
      await File(p.join(root.path, 'alpha', 'notes.txt'))
          .writeAsString('scratch');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(reloads, 0);
    });
  });

  group('type declarations', () {
    test('generated d.ts names every command and its parameters', () {
      final registry = CommandRegistry();
      registry.register(
        CommandDescriptor(
          id: 'draw.line',
          title: 'Line',
          description: 'Draws a straight segment between two points.',
          aliases: const ['L'],
          params: const [
            ParamSpec(name: 'start', type: ParamType.point),
            ParamSpec(name: 'end', type: ParamType.point),
            ParamSpec(
              name: 'mode',
              type: ParamType.choice,
              options: ['single', 'chain'],
              required: false,
            ),
          ],
          handler: (context) async => const CommandResult.ok(),
        ),
      );

      final output = buildTypeDeclarations(commands: registry.all);

      expect(output, contains("| 'draw.line';"));
      expect(output, contains('interface DrawLine {'));
      expect(output, contains('start: Point;'));
      expect(output, contains("mode?: 'single' | 'chain';"));
      expect(output, contains('Draws a straight segment'));
      expect(output, contains('Aliases: L'));
      // The hand-written part has to be there too, or plugin code gets no help.
      expect(output, contains('declare const fancad: FanCadApi;'));
      expect(output, contains('beginEdit(label: string): EditBuilder;'));
    });

    test('an empty registry still produces valid declarations', () {
      final output = buildTypeDeclarations(commands: const []);
      expect(output, contains('declare type FanCadCommandId ='));
      expect(output, contains('string;'));
    });
  });
}
