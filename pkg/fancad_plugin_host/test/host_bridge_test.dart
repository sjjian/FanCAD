import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingDelegate implements PluginHostDelegate {
  RecordingDelegate({DocumentSession? session}) : session = session;

  @override
  DocumentSession? session;

  final CommandRegistry registry = CommandRegistry();
  final List<String> messages = [];
  final List<String> logs = [];
  final Map<String, Object?> storage = {};
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
    return descriptor.handler(
      CommandContext(
        session:
            session ?? DocumentSession(id: 'none', document: CadDocument()),
        args: CommandArgs(args),
        input: ArgsCommandInput(
          args: CommandArgs(args),
          params: descriptor.params,
          selection: session?.selection ?? SelectionSet(),
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
      storage['$pluginId:$key'];

  @override
  Future<void> writeStorage(String pluginId, String key, Object? value) async {
    storage['$pluginId:$key'] = value;
  }
}

PluginManifest manifest({
  Set<PluginPermission> permissions = const {
    PluginPermission.documentRead,
    PluginPermission.documentWrite,
    PluginPermission.commands,
    PluginPermission.ui,
    PluginPermission.fileWrite,
  },
}) => PluginManifest(
  id: 'demo',
  name: 'Demo',
  version: '1.0.0',
  entryPoint: 'main.js',
  permissions: permissions,
);

HostBridge bridge(RecordingDelegate delegate) => HostBridge(
  delegate: delegate,
  manifests: (id) => id == 'demo' ? manifest() : null,
);

void main() {
  group('HostBridge leftovers', () {
    test('an unknown plugin cannot call the host', () async {
      final delegate = RecordingDelegate();
      final host = bridge(delegate);

      await expectLater(
        host.call('ghost', HostMethod.documentSummary, const {}),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', RpcErrorCode.internalError)
              .having((error) => error.message, 'message', contains('ghost')),
        ),
      );
    });

    test('a missing method is refused instead of ignored', () async {
      final host = bridge(RecordingDelegate());

      await expectLater(
        host.call('demo', 'window/teleport', const {}),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.methodNotFound,
          ),
        ),
      );
    });

    test('document reads fail when no drawing is open', () async {
      final host = bridge(RecordingDelegate());

      await expectLater(
        host.call('demo', HostMethod.documentLayers, const {}),
        throwsA(
          isA<RpcException>()
              .having(
                (error) => error.code,
                'code',
                RpcErrorCode.invalidRequest,
              )
              .having(
                (error) => error.message,
                'message',
                contains('no drawing'),
              ),
        ),
      );
    });

    test('document.entity returns geometry and refuses a missing id', () async {
      final session = DocumentSession(id: 'doc', document: CadDocument());
      late int id;
      session.edit('setup', (transaction) {
        id = transaction.add(
          LineEntity(id: 0, start: const Vec2.zero(), end: Vec2(4, 0)),
        );
      });
      final host = bridge(RecordingDelegate(session: session));

      final detailed =
          await host.call('demo', HostMethod.documentEntity, {'id': id})
              as Map<String, Object?>;
      expect(detailed['kind'], 'line');
      expect(detailed['start'], [0.0, 0.0]);
      expect(detailed['end'], [4.0, 0.0]);

      await expectLater(
        host.call('demo', HostMethod.documentEntity, const {}),
        throwsA(
          isA<RpcException>().having(
            (error) => error.message,
            'message',
            contains('"id"'),
          ),
        ),
      );
      await expectLater(
        host.call('demo', HostMethod.documentEntity, const {'id': 999}),
        throwsA(
          isA<RpcException>().having(
            (error) => error.message,
            'message',
            contains('999'),
          ),
        ),
      );
    });

    test('document.layers reports visibility flags', () async {
      final session = DocumentSession(id: 'doc', document: CadDocument());
      session.edit('setup', (transaction) {
        transaction.putLayer(
          const LayerDef(name: 'Hidden', visible: false, frozen: true),
        );
      });
      final host = bridge(RecordingDelegate(session: session));

      final result =
          await host.call('demo', HostMethod.documentLayers, const {})
              as Map<String, Object?>;
      expect(result['current'], '0');
      final layers = result['layers'] as List<Object?>;
      expect(
        layers.cast<Map<String, Object?>>().map((layer) => layer['name']),
        containsAll(['0', 'Hidden']),
      );
      final hidden = layers.cast<Map<String, Object?>>().firstWhere(
        (layer) => layer['name'] == 'Hidden',
      );
      expect(hidden['visible'], isFalse);
      expect(hidden['frozen'], isTrue);
    });

    test(
      'document.query accepts a kind string and honours the limit',
      () async {
        final session = DocumentSession(id: 'doc', document: CadDocument());
        session.edit('setup', (transaction) {
          for (var i = 0; i < 3; i++) {
            transaction.add(
              PointEntity(id: 0, position: Vec2(i.toDouble(), 0)),
            );
          }
          transaction.add(
            LineEntity(id: 0, start: const Vec2.zero(), end: Vec2(1, 0)),
          );
        });
        final host = bridge(RecordingDelegate(session: session));

        final result =
            await host.call('demo', HostMethod.documentQuery, const {
                  'kinds': 'point',
                  'limit': 2,
                })
                as Map<String, Object?>;
        expect((result['entities'] as List).length, 2);
        expect(result['truncated'], isTrue);
      },
    );

    test('commands.list exposes registered descriptors', () async {
      final delegate = RecordingDelegate();
      delegate.registry.register(
        CommandDescriptor(
          id: 'draw.line',
          title: 'Line',
          handler: (context) async => const CommandResult.ok(),
        ),
      );
      final host = bridge(delegate);

      final result =
          await host.call('demo', HostMethod.listCommands, const {})
              as Map<String, Object?>;
      final commands = result['commands'] as List<Object?>;
      expect(
        commands.cast<Map<String, Object?>>().map((command) => command['id']),
        contains('draw.line'),
      );
    });

    test('storage, log, message and prompt reach the delegate', () async {
      final delegate = RecordingDelegate()..promptAnswer = 'yes';
      final host = HostBridge(
        delegate: delegate,
        manifests: (id) => manifest(),
      );

      await host.call('demo', HostMethod.storageSet, const {
        'key': 'token',
        'value': 'abc',
      });
      expect(
        await host.call('demo', HostMethod.storageGet, const {'key': 'token'}),
        'abc',
      );

      await host.call('demo', HostMethod.log, const {
        'level': 'warn',
        'message': 'slow',
      });
      await host.call('demo', HostMethod.showMessage, const {
        'message': 'hello',
        'error': true,
      });
      expect(
        await host.call('demo', HostMethod.showPrompt, const {'text': '?'}),
        'yes',
      );
      expect(delegate.logs, ['[warn] slow']);
      expect(delegate.messages, ['error: hello']);
    });

    test(
      'document.edit can transform, restyle, and add leftover kinds',
      () async {
        final session = DocumentSession(id: 'doc', document: CadDocument());
        late int id;
        session.edit('setup', (transaction) {
          id = transaction.add(
            LineEntity(id: 0, start: const Vec2.zero(), end: Vec2(1, 0)),
          );
          transaction.putLayer(const LayerDef(name: 'Notes'));
        });
        final host = bridge(RecordingDelegate(session: session));

        final result =
            await host.call('demo', HostMethod.applyEdit, {
                  'operations': [
                    {
                      'op': 'transform',
                      'ids': [id],
                      'translate': [2, 3],
                    },
                    {
                      'op': 'props',
                      'ids': [id],
                      'props': {'layer': 'Notes', 'visible': false},
                    },
                    {
                      'op': 'add',
                      'kind': 'arc',
                      'center': [0, 0],
                      'radius': 2,
                      'startAngle': 0,
                      'endAngle': 1,
                    },
                    {
                      'op': 'add',
                      'kind': 'point',
                      'position': [1, 1],
                      'props': {'layer': 'Missing'},
                    },
                    {
                      'op': 'add',
                      'kind': 'text',
                      'position': [0, 2],
                      'text': 'N',
                      'height': 4,
                    },
                  ],
                })
                as Map<String, Object?>;

        expect(result['applied'], isTrue);
        expect(result['created'], hasLength(3));
        final moved = session.document.entity(id) as LineEntity;
        expect(moved.start, Vec2(2, 3));
        expect(moved.props.layer, 'Notes');
        expect(moved.props.visible, isFalse);
        expect(
          session.document.entities.whereType<PointEntity>().single.props.layer,
          '0',
        );
        expect(
          session.document.entities.whereType<TextEntity>().single.content,
          'N',
        );
      },
    );

    test(
      'document.edit refuses a missing operations array or unknown op',
      () async {
        final session = DocumentSession(id: 'doc', document: CadDocument());
        final host = bridge(RecordingDelegate(session: session));

        await expectLater(
          host.call('demo', HostMethod.applyEdit, const {}),
          throwsA(
            isA<RpcException>().having(
              (error) => error.message,
              'message',
              contains('operations'),
            ),
          ),
        );
        await expectLater(
          host.call('demo', HostMethod.applyEdit, const {
            'operations': [
              {'op': 'explode'},
            ],
          }),
          throwsA(
            isA<RpcException>().having(
              (error) => error.message,
              'message',
              contains('explode'),
            ),
          ),
        );
      },
    );

    test('commands.execute refuses a missing command name', () async {
      final host = bridge(RecordingDelegate());

      await expectLater(
        host.call('demo', HostMethod.executeCommand, const {}),
        throwsA(
          isA<RpcException>().having(
            (error) => error.message,
            'message',
            contains('"command"'),
          ),
        ),
      );
    });
  });
}
