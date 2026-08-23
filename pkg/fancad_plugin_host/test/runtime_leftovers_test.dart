import 'dart:convert';

import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';

JsEngine scriptedEngine({
  Object? Function(String source, String name)? onEvaluate,
}) {
  final engine = ScriptedJsEngine(onEvaluate: onEvaluate);
  engine.globals[BootstrapGlobals.registered] = () => jsonEncode({
    'commands': ['demo.run'],
  });
  engine.globals[BootstrapGlobals.deactivate] = () =>
      jsonEncode({'result': null});
  engine.globals[BootstrapGlobals.dispatch] =
      (String kind, String id, String payload) => jsonEncode({'result': null});
  return engine;
}

PluginManifest demoManifest() => const PluginManifest(
  id: 'demo',
  name: 'demo',
  version: '1.0.0',
  entryPoint: 'main.js',
  permissions: {PluginPermission.documentRead, PluginPermission.commands},
  commands: [CommandContribution(id: 'demo.run', title: 'demo.run')],
);

void main() {
  test('eval via the worker returns a JSON-safe value', () async {
    late ScriptedJsEngine engine;
    final runtime = PluginRuntime(
      createEngine: ({required memoryLimit, required stackSize}) {
        engine =
            scriptedEngine(
                  onEvaluate: (source, name) {
                    if (name.endsWith('/<console>')) return {1: source};
                    return null;
                  },
                )
                as ScriptedJsEngine;
        return engine;
      },
      callHost: (id, method, params) async => null,
    );
    await runtime.load(demoManifest(), 'source');

    final result = await runtime.handle(
      const RpcRequest(
        method: WorkerMethod.eval,
        id: 2,
        params: {'pluginId': 'demo', 'source': '1+1'},
      ),
    );
    expect(result, {
      'value': {'1': '1+1'},
    });
    expect(engine.evaluated.last, '1+1');
  });

  test(
    'eval of a throw is a plugin error, not an unhandled exception',
    () async {
      final runtime = PluginRuntime(
        createEngine: ({required memoryLimit, required stackSize}) =>
            scriptedEngine(
              onEvaluate: (source, name) {
                if (name.endsWith('/<console>')) {
                  throw const JsException('SyntaxError: unexpected');
                }
                return null;
              },
            ),
        callHost: (id, method, params) async => null,
      );
      await runtime.load(demoManifest(), 'source');

      await expectLater(
        runtime.handle(
          const RpcRequest(
            method: WorkerMethod.eval,
            id: 3,
            params: {'pluginId': 'demo', 'source': '???'},
          ),
        ),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', RpcErrorCode.pluginError)
              .having(
                (error) => error.message,
                'message',
                contains('SyntaxError'),
              ),
        ),
      );
    },
  );

  test('stats and cancel go through the worker envelope', () async {
    late ScriptedJsEngine engine;
    final runtime = PluginRuntime(
      createEngine: ({required memoryLimit, required stackSize}) {
        engine = scriptedEngine() as ScriptedJsEngine;
        return engine;
      },
      callHost: (id, method, params) async => {'ok': true},
    );
    await runtime.load(demoManifest(), 'source');

    final stats = await runtime.handle(
      const RpcRequest(method: WorkerMethod.stats, id: 4),
    );
    expect((stats as Map)['plugins'], [
      {
        'id': 'demo',
        'memory': 0,
        'commands': ['demo.run'],
      },
    ]);

    await runtime.handle(
      const RpcRequest(
        method: WorkerMethod.cancel,
        id: 5,
        params: {'pluginId': 'demo'},
      ),
    );
    final raw =
        await (engine.call(BootstrapGlobals.rpc, [
              HostMethod.documentSummary,
              '{}',
            ])
            as Future<String>);
    expect(
      (jsonDecode(raw) as Map)['error'],
      containsPair('code', RpcErrorCode.cancelled),
    );
  });
}
