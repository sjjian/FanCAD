import 'dart:async';
import 'dart:convert';

import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for a plugin's `main.js`.
///
/// The real engine parses JavaScript; this one records what the runtime asked of
/// it and answers the way the prelude would. That keeps these tests about the
/// runtime's own logic — load, reconcile, dispatch, cancel — rather than about
/// QuickJS.
class FakePlugin {
  FakePlugin({
    this.registers = const ['demo.run'],
    this.onInvoke,
    this.throwOnLoad = false,
    this.hasActivate = true,
  });

  final List<String> registers;

  /// Called for each dispatch, with the decoded args.
  Future<Object?> Function(String id, Map<String, Object?> args)? onInvoke;

  final bool throwOnLoad;
  final bool hasActivate;

  bool activated = false;
  bool deactivated = false;
  final List<String> dispatched = [];

  late final ScriptedJsEngine engine;

  JsEngine build({required int memoryLimit, required int stackSize}) {
    engine = ScriptedJsEngine(
      onEvaluate: (source, name) {
        if (name.endsWith('/activate')) {
          if (!hasActivate) return null;
          activated = true;
          return null;
        }
        if (throwOnLoad && name.endsWith('main.js')) {
          throw const JsException('ReferenceError: nope is not defined');
        }
        return null;
      },
    );
    engine.globals[BootstrapGlobals.registered] =
        () => jsonEncode({'commands': registers});
    engine.globals[BootstrapGlobals.deactivate] = () {
      deactivated = true;
      return jsonEncode({'result': null});
    };
    engine.globals[BootstrapGlobals.dispatch] =
        (String kind, String id, String payload) async {
      dispatched.add('$kind:$id');
      final args = jsonDecode(payload) as Map<String, Object?>;
      final result = await (onInvoke?.call(id, args) ?? Future.value(null));
      return jsonEncode({'result': result});
    };
    return engine;
  }
}

PluginManifest manifestFor({
  String id = 'demo',
  List<String> commands = const ['demo.run'],
  Set<PluginPermission> permissions = const {
    PluginPermission.documentRead,
    PluginPermission.commands,
  },
}) => PluginManifest(
  id: id,
  name: id,
  version: '1.0.0',
  entryPoint: 'main.js',
  permissions: permissions,
  commands: [
    for (final command in commands)
      CommandContribution(id: command, title: command),
  ],
);

void main() {
  group('plugin runtime', () {
    test('load evaluates the prelude, the source and activate', () async {
      final plugin = FakePlugin();
      final calls = <String>[];
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async {
          calls.add(method);
          return null;
        },
      );

      final result = await runtime.load(manifestFor(), 'source');

      expect(result['id'], 'demo');
      expect(result['commands'], ['demo.run']);
      expect(result['missing'], isEmpty);
      expect(result['undeclared'], isEmpty);
      expect(plugin.activated, isTrue);
      expect(runtime.isLoaded('demo'), isTrue);
      // The prelude has to be in place before the plugin's own source runs,
      // otherwise `fancad` is undefined at the top level of main.js.
      expect(plugin.engine.evaluated.length, greaterThanOrEqualTo(3));
      expect(plugin.engine.evaluated.first, contains('__fancad_dispatch'));
      expect(plugin.engine.evaluated[1], 'source');
      expect(calls, isEmpty);
    });

    test('the prelude carries the granted permissions, not the request',
        () async {
      final plugin = FakePlugin();
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async => null,
      );
      await runtime.load(
        manifestFor(permissions: {PluginPermission.documentRead}),
        'source',
      );
      // Assert on the granted set, not on the whole script: the guard bodies
      // mention every permission name by design.
      final granted = RegExp(r'new Set\(\[(.*?)\]\)')
          .firstMatch(plugin.engine.evaluated.first)!
          .group(1);
      expect(granted, '"document.read"');
    });

    test('a plugin with no activate function still loads', () async {
      final plugin = FakePlugin(hasActivate: false);
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async => null,
      );
      await runtime.load(manifestFor(), 'source');
      expect(runtime.isLoaded('demo'), isTrue);
      expect(plugin.activated, isFalse);
    });

    test('a throwing entry point fails the load and frees the engine',
        () async {
      final plugin = FakePlugin(throwOnLoad: true);
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async => null,
      );
      await expectLater(
        runtime.load(manifestFor(), 'nope()'),
        throwsA(
          isA<RpcException>()
              .having((e) => e.code, 'code', RpcErrorCode.pluginError)
              .having((e) => e.message, 'message', contains('nope')),
        ),
      );
      expect(runtime.isLoaded('demo'), isFalse);
      expect(plugin.engine.isDisposed, isTrue);
    });

    test('loading the same plugin twice is refused', () async {
      final runtime = PluginRuntime(
        createEngine: FakePlugin().build,
        callHost: (id, method, params) async => null,
      );
      await runtime.load(manifestFor(), 'source');
      await expectLater(
        runtime.load(manifestFor(), 'source'),
        throwsA(isA<RpcException>()),
      );
    });

    test('a manifest/code mismatch is reported both ways', () async {
      final plugin = FakePlugin(registers: ['demo.run', 'demo.extra']);
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async => null,
      );
      final result = await runtime.load(
        manifestFor(commands: ['demo.run', 'demo.promised']),
        'source',
      );
      expect(result['missing'], ['demo.promised']);
      expect(result['undeclared'], ['demo.extra']);
    });

    test('invoke passes args through and returns the handler payload',
        () async {
      Map<String, Object?>? seen;
      final plugin = FakePlugin(
        onInvoke: (id, args) async {
          seen = args;
          return {'drawn': 3};
        },
      );
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async => null,
      );
      await runtime.load(manifestFor(), 'source');

      final result = await runtime.invokeCommand('demo', 'demo.run', {
        'spacing': 10,
        'origin': [1, 2],
      });

      expect(seen, {'spacing': 10, 'origin': [1, 2]});
      expect(result['result'], {'drawn': 3});
      expect(plugin.dispatched, ['command:demo.run']);
    });

    test('invoking a command the plugin never registered fails', () async {
      final runtime = PluginRuntime(
        createEngine: FakePlugin().build,
        callHost: (id, method, params) async => null,
      );
      await runtime.load(manifestFor(), 'source');
      await expectLater(
        runtime.invokeCommand('demo', 'demo.other', const {}),
        throwsA(isA<RpcException>()),
      );
    });

    test('invoking an unloaded plugin fails', () async {
      final runtime = PluginRuntime(
        createEngine: FakePlugin().build,
        callHost: (id, method, params) async => null,
      );
      await expectLater(
        runtime.invokeCommand('ghost', 'a', const {}),
        throwsA(isA<RpcException>()),
      );
    });

    test('a handler that throws surfaces as a plugin error', () async {
      final plugin = FakePlugin(
        onInvoke: (id, args) async =>
            throw const JsException('TypeError: x is not a function'),
      );
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async => null,
      );
      await runtime.load(manifestFor(), 'source');
      await expectLater(
        runtime.invokeCommand('demo', 'demo.run', const {}),
        throwsA(
          isA<RpcException>()
              .having((e) => e.code, 'code', RpcErrorCode.pluginError)
              .having((e) => e.message, 'message', contains('TypeError')),
        ),
      );
    });

    test('a host call from a plugin is forwarded and its result returned',
        () async {
      final plugin = FakePlugin();
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async {
          expect(id, 'demo');
          expect(method, HostMethod.documentSummary);
          return {'entityCount': 7};
        },
      );
      await runtime.load(manifestFor(), 'source');

      final raw = await (plugin.engine.call(BootstrapGlobals.rpc, [
        HostMethod.documentSummary,
        '{}',
      ]) as Future<String>);
      expect(jsonDecode(raw), {
        'result': {'entityCount': 7},
      });
    });

    test('a rejected host call becomes an error envelope, not a throw',
        () async {
      final plugin = FakePlugin();
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async => throw const RpcException(
          RpcErrorCode.permissionDenied,
          'needs document.write',
        ),
      );
      await runtime.load(manifestFor(), 'source');

      final raw = await (plugin.engine.call(BootstrapGlobals.rpc, [
        HostMethod.applyEdit,
        '{}',
      ]) as Future<String>);
      expect(jsonDecode(raw), {
        'error': {
          'code': RpcErrorCode.permissionDenied,
          'message': 'needs document.write',
        },
      });
    });

    test('cancel rejects the next host call the plugin makes', () async {
      final plugin = FakePlugin();
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async => {'ok': true},
      );
      await runtime.load(manifestFor(), 'source');

      runtime.cancel('demo');
      final raw = await (plugin.engine.call(BootstrapGlobals.rpc, [
        HostMethod.documentSummary,
        '{}',
      ]) as Future<String>);
      final envelope = jsonDecode(raw) as Map<String, Object?>;
      expect(
        (envelope['error'] as Map)['code'],
        RpcErrorCode.cancelled,
      );
    });

    test('a fresh dispatch clears a stale cancellation', () async {
      var hostCalls = 0;
      final plugin = FakePlugin(onInvoke: (id, args) async => null);
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async {
          hostCalls++;
          return null;
        },
      );
      await runtime.load(manifestFor(), 'source');

      runtime.cancel('demo');
      await runtime.invokeCommand('demo', 'demo.run', const {});
      final raw = await (plugin.engine.call(BootstrapGlobals.rpc, [
        HostMethod.documentSummary,
        '{}',
      ]) as Future<String>);
      expect(jsonDecode(raw), {'result': null});
      expect(hostCalls, 1);
    });

    test('unload calls deactivate and disposes the engine', () async {
      final plugin = FakePlugin();
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async => null,
      );
      await runtime.load(manifestFor(), 'source');
      final result = await runtime.unload('demo');

      expect(result['unloaded'], isTrue);
      expect(plugin.deactivated, isTrue);
      expect(plugin.engine.isDisposed, isTrue);
      expect(runtime.isLoaded('demo'), isFalse);
    });

    test('unloading something that was never loaded is not an error', () async {
      final runtime = PluginRuntime(
        createEngine: FakePlugin().build,
        callHost: (id, method, params) async => null,
      );
      expect((await runtime.unload('ghost'))['unloaded'], isFalse);
    });

    test('a deactivate that throws still tears the plugin down', () async {
      final plugin = FakePlugin();
      final runtime = PluginRuntime(
        createEngine: plugin.build,
        callHost: (id, method, params) async => null,
      );
      await runtime.load(manifestFor(), 'source');
      plugin.engine.globals[BootstrapGlobals.deactivate] =
          () => throw const JsException('boom');

      await runtime.unload('demo');
      expect(plugin.engine.isDisposed, isTrue);
      expect(runtime.isLoaded('demo'), isFalse);
    });

    test('ping reports what is loaded', () async {
      final runtime = PluginRuntime(
        createEngine: FakePlugin().build,
        callHost: (id, method, params) async => null,
      );
      await runtime.load(manifestFor(), 'source');
      final result = await runtime.handle(
        const RpcRequest(method: WorkerMethod.ping, id: 1),
      );
      expect((result as Map)['loaded'], ['demo']);
    });

    test('an unknown method is a method-not-found error', () async {
      final runtime = PluginRuntime(
        createEngine: FakePlugin().build,
        callHost: (id, method, params) async => null,
      );
      await expectLater(
        runtime.handle(const RpcRequest(method: 'plugin/teleport', id: 1)),
        throwsA(
          isA<RpcException>()
              .having((e) => e.code, 'code', RpcErrorCode.methodNotFound),
        ),
      );
    });
  });

  group('bootstrap prelude', () {
    test('method names stay in lockstep with HostMethod', () {
      // The prelude is one template string, so its method names cannot
      // reference the constants directly. This is the guard against drift.
      expect(BootstrapGlobals.hostMethods.values, containsAll(<String>[
        HostMethod.executeCommand,
        HostMethod.listCommands,
        HostMethod.documentSummary,
        HostMethod.documentQuery,
        HostMethod.documentEntity,
        HostMethod.documentLayers,
        HostMethod.selectionGet,
        HostMethod.selectionSet,
        HostMethod.applyEdit,
        HostMethod.showMessage,
        HostMethod.showPrompt,
        HostMethod.log,
        HostMethod.storageGet,
        HostMethod.storageSet,
      ]));
    });

    test('the script defines the four globals the runtime calls', () {
      final script = buildBootstrapScript(
        pluginId: 'demo',
        version: '1.0.0',
        permissions: const {'document.read'},
        hostVersion: '0.1.0',
      );
      expect(script, contains('global.${BootstrapGlobals.dispatch} ='));
      expect(script, contains('global.${BootstrapGlobals.registered} ='));
      expect(script, contains('global.${BootstrapGlobals.deactivate} ='));
      expect(script, contains(BootstrapGlobals.rpc));
      expect(script, contains('global.fancad ='));
    });
  });

  group('rpc peer', () {
    test('a request is answered by the peer', () async {
      late RpcPeer left;
      late RpcPeer right;
      left = RpcPeer(
        send: (message) => right.accept(message),
        handle: (request) async => null,
      );
      right = RpcPeer(
        send: (message) => left.accept(message),
        handle: (request) async => {'echo': request.params['value']},
      );

      final result = await left.request('anything', params: {'value': 42});
      expect(result, {'echo': 42});
      expect(left.pendingCount, 0);
    });

    test('a handler error crosses back as an RpcException', () async {
      late RpcPeer left;
      late RpcPeer right;
      left = RpcPeer(
        send: (message) => right.accept(message),
        handle: (request) async => null,
      );
      right = RpcPeer(
        send: (message) => left.accept(message),
        handle: (request) async =>
            throw const RpcException(RpcErrorCode.invalidParams, 'bad input'),
      );

      await expectLater(
        left.request('anything'),
        throwsA(
          isA<RpcException>()
              .having((e) => e.code, 'code', RpcErrorCode.invalidParams)
              .having((e) => e.message, 'message', 'bad input'),
        ),
      );
    });

    test('an unexpected throw becomes an internal error with a stack',
        () async {
      late RpcPeer left;
      late RpcPeer right;
      left = RpcPeer(
        send: (message) => right.accept(message),
        handle: (request) async => null,
      );
      right = RpcPeer(
        send: (message) => left.accept(message),
        handle: (request) async => throw StateError('unexpected'),
      );

      await expectLater(
        left.request('anything'),
        throwsA(
          isA<RpcException>()
              .having((e) => e.code, 'code', RpcErrorCode.internalError)
              .having((e) => e.data, 'data', isA<Map<String, Object?>>()),
        ),
      );
    });

    test('a notification gets no reply', () async {
      final seen = <String>[];
      late RpcPeer right;
      final left = RpcPeer(
        send: (message) => right.accept(message),
        handle: (request) async => null,
      );
      var replies = 0;
      right = RpcPeer(
        send: (_) => replies++,
        handle: (request) async {
          seen.add(request.method);
          expect(request.isNotification, isTrue);
          return {'ignored': true};
        },
      );

      left.notify('event', {'a': 1});
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['event']);
      expect(replies, 0);
    });

    test('a timeout fails the request and asks the peer to cancel', () async {
      final cancellations = <Object?>[];
      late RpcPeer left;
      late RpcPeer right;
      left = RpcPeer(
        send: (message) => right.accept(message),
        handle: (request) async => null,
      );
      right = RpcPeer(
        send: (message) => left.accept(message),
        handle: (request) async {
          if (request.method == r'$/cancelRequest') {
            cancellations.add(request.params['id']);
            return null;
          }
          return Completer<Object?>().future;
        },
      );

      await expectLater(
        left.request(
          'slow',
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(
          isA<RpcException>()
              .having((e) => e.code, 'code', RpcErrorCode.timeout),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cancellations, [1]);
      expect(left.pendingCount, 0);
    });

    test('closing fails every in-flight request', () async {
      final left = RpcPeer(send: (_) {}, handle: (request) async => null);
      final pending = left.request('never');
      left.close();
      await expectLater(
        pending,
        throwsA(
          isA<RpcException>()
              .having((e) => e.code, 'code', RpcErrorCode.workerDead),
        ),
      );
      expect(left.isClosed, isTrue);
      expect(() => left.request('again'), throwsA(isA<RpcException>()));
    });

    test('a late response after a timeout is ignored', () async {
      late RpcPeer left;
      Map<String, Object?>? captured;
      left = RpcPeer(
        send: (message) => captured ??= message,
        handle: (request) async => null,
      );
      await expectLater(
        left.request('slow', timeout: const Duration(milliseconds: 10)),
        throwsA(isA<RpcException>()),
      );
      // Arrives after the deadline. Must not throw.
      await left.accept({'jsonrpc': '2.0', 'id': captured!['id'], 'result': 1});
    });
  });
}
