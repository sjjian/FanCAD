import 'dart:async';
import 'dart:convert';

import 'bootstrap.dart';
import 'js_engine.dart';
import 'manifest.dart';
import 'protocol.dart';

/// One loaded plugin inside the worker.
class _LoadedPlugin {
  _LoadedPlugin({
    required this.manifest,
    required this.engine,
    required this.registeredCommands,
  });

  final PluginManifest manifest;
  final JsEngine engine;

  /// What the entry point actually registered, which may differ from what the
  /// manifest promised.
  final Set<String> registeredCommands;
}

/// Runs plugins. Lives on the worker isolate; never touches Flutter.
///
/// Holds no reference to the document or the registry: everything it needs from
/// the application it asks for over [callHost]. That is what allows the whole
/// class to be exercised in a plain unit test with a scripted engine.
class PluginRuntime {
  PluginRuntime({
    required this.createEngine,
    required this.callHost,
    this.hostVersion = '0.1.0',
    this.memoryLimit = 64 * 1024 * 1024,
    this.stackSize = 1024 * 1024,
  });

  /// Builds an engine for a plugin about to load.
  final JsEngineFactory createEngine;

  /// Forwards a plugin's request to the application.
  final Future<Object?> Function(String pluginId, String method,
      Map<String, Object?> params) callHost;

  final String hostVersion;
  final int memoryLimit;
  final int stackSize;

  final Map<String, _LoadedPlugin> _plugins = {};

  /// Plugins whose in-flight work has been cancelled.
  ///
  /// The engine cannot be interrupted mid-bytecode, so cancellation works the
  /// only way it can: the next host call the plugin makes is rejected, and its
  /// `await` throws. That covers the case that actually matters — a handler
  /// waiting on the document or on a prompt — and a handler spinning in pure
  /// computation is beyond reach of anything but abandoning the worker.
  final Set<String> _cancelled = {};

  Iterable<String> get loadedIds => _plugins.keys;
  bool isLoaded(String id) => _plugins.containsKey(id);

  /// Marks [pluginId]'s current work cancelled.
  void cancel(String pluginId) => _cancelled.add(pluginId);

  /// Serves one request from the host.
  Future<Object?> handle(RpcRequest request) async {
    switch (request.method) {
      case WorkerMethod.load:
        return load(
          PluginManifest.fromJson(_requireMap(request.params, 'manifest')),
          _requireString(request.params, 'source'),
        );
      case WorkerMethod.unload:
        return unload(_requireString(request.params, 'pluginId'));
      case WorkerMethod.invoke:
        return invokeCommand(
          _requireString(request.params, 'pluginId'),
          _requireString(request.params, 'commandId'),
          _optionalMap(request.params, 'args'),
        );
      case WorkerMethod.event:
        await dispatchEvent(
          _requireString(request.params, 'pluginId'),
          _requireString(request.params, 'event'),
          _optionalMap(request.params, 'payload'),
        );
        return null;
      case WorkerMethod.eval:
        return evaluate(
          _requireString(request.params, 'pluginId'),
          _requireString(request.params, 'source'),
        );
      case WorkerMethod.cancel:
        cancel(_requireString(request.params, 'pluginId'));
        return null;
      case WorkerMethod.ping:
        return {'loaded': _plugins.keys.toList()};
      case WorkerMethod.stats:
        return {
          'plugins': [
            for (final plugin in _plugins.values)
              {
                'id': plugin.manifest.id,
                'memory': plugin.engine.memoryUsage,
                'commands': plugin.registeredCommands.toList(),
              },
          ],
        };
      default:
        throw RpcException(
          RpcErrorCode.methodNotFound,
          'the plugin worker does not handle "${request.method}"',
        );
    }
  }

  /// Creates a runtime for [manifest] and evaluates [source] in it.
  ///
  /// Returns the commands the plugin actually registered. A mismatch against
  /// the manifest is reported rather than corrected, because guessing which
  /// side is right would hide the bug.
  Future<Map<String, Object?>> load(
    PluginManifest manifest,
    String source,
  ) async {
    if (_plugins.containsKey(manifest.id)) {
      throw RpcException(
        RpcErrorCode.invalidParams,
        '${manifest.id} is already loaded',
      );
    }
    final engine = createEngine(
      memoryLimit: memoryLimit,
      stackSize: stackSize,
    );
    try {
      engine.defineFunction(
        BootstrapGlobals.rpc,
        (String method, String paramsJson) =>
            _serveFromPlugin(manifest, method, paramsJson),
      );
      engine.evaluate(
        buildBootstrapScript(
          pluginId: manifest.id,
          version: manifest.version,
          permissions: {
            for (final permission in manifest.permissions) permission.wireName,
          },
          hostVersion: hostVersion,
        ),
        name: '${manifest.id}/bootstrap.js',
      );
      engine.evaluate(source, name: '${manifest.id}/${manifest.entryPoint}');

      // `activate` is optional: a plugin whose whole job is registering
      // commands at load time has nothing to put in it.
      await _maybeAwait(engine.evaluate(
        'typeof activate === "function" ? activate(fancad) : null',
        name: '${manifest.id}/activate',
      ));

      final registered = _decodeRegistered(engine);
      _plugins[manifest.id] = _LoadedPlugin(
        manifest: manifest,
        engine: engine,
        registeredCommands: registered,
      );
      final declared = {for (final c in manifest.commands) c.id};
      return {
        'id': manifest.id,
        'commands': registered.toList(),
        'missing': declared.difference(registered).toList(),
        'undeclared': registered.difference(declared).toList(),
      };
    } on JsException catch (error) {
      engine.dispose();
      throw RpcException(
        RpcErrorCode.pluginError,
        'failed to load ${manifest.id}: ${error.message}',
        data: {'stack': error.stack},
      );
    } catch (error) {
      engine.dispose();
      rethrow;
    }
  }

  Future<Map<String, Object?>> unload(String pluginId) async {
    final plugin = _plugins.remove(pluginId);
    if (plugin == null) return {'id': pluginId, 'unloaded': false};
    try {
      // Give the plugin a chance to undo side effects it made outside its own
      // scope. A failure here must not prevent the teardown below.
      await _maybeAwait(
        plugin.engine.callGlobal(BootstrapGlobals.deactivate, const []),
      );
    } on JsException catch (_) {
      // Deliberately ignored: the runtime is going away regardless.
    }
    plugin.engine.dispose();
    return {'id': pluginId, 'unloaded': true};
  }

  /// Calls a command handler and returns its payload.
  Future<Map<String, Object?>> invokeCommand(
    String pluginId,
    String commandId,
    Map<String, Object?> args,
  ) async {
    final plugin = _require(pluginId);
    if (!plugin.registeredCommands.contains(commandId)) {
      throw RpcException(
        RpcErrorCode.invalidParams,
        '$pluginId did not register a handler for "$commandId"',
      );
    }
    return _dispatch(plugin, 'command', commandId, args);
  }

  Future<void> dispatchEvent(
    String pluginId,
    String event,
    Map<String, Object?> payload,
  ) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) return;
    await _dispatch(plugin, 'event', event, payload);
  }

  /// Evaluates arbitrary source in a plugin's scope, for the developer console.
  Future<Map<String, Object?>> evaluate(String pluginId, String source) async {
    final plugin = _require(pluginId);
    try {
      final value = await _maybeAwait(
        plugin.engine.evaluate(source, name: '$pluginId/<console>'),
      );
      return {'value': _jsonSafe(value)};
    } on JsException catch (error) {
      throw RpcException(
        RpcErrorCode.pluginError,
        error.message,
        data: {'stack': error.stack},
      );
    }
  }

  Future<Map<String, Object?>> _dispatch(
    _LoadedPlugin plugin,
    String kind,
    String id,
    Map<String, Object?> args,
  ) async {
    _cancelled.remove(plugin.manifest.id);
    try {
      final raw = await _maybeAwait(
        plugin.engine.callGlobal(BootstrapGlobals.dispatch, [
          kind,
          id,
          jsonEncode(args),
        ]),
      );
      plugin.engine.pumpEventLoop();
      final decoded = _decodeEnvelope(raw);
      return {'result': decoded};
    } on JsException catch (error) {
      throw RpcException(
        RpcErrorCode.pluginError,
        '${plugin.manifest.id}/$id threw: ${error.message}',
        data: {'stack': error.stack},
      );
    }
  }

  /// Handles one `__fancad_rpc` call, returning the JSON envelope the prelude
  /// expects.
  ///
  /// Errors are encoded rather than thrown, so a rejected host call becomes a
  /// catchable JavaScript error instead of an unhandled Dart exception crossing
  /// the FFI boundary.
  Future<String> _serveFromPlugin(
    PluginManifest manifest,
    String method,
    String paramsJson,
  ) async {
    try {
      if (_cancelled.contains(manifest.id)) {
        throw const RpcException(RpcErrorCode.cancelled, 'cancelled');
      }
      final decoded = paramsJson.isEmpty ? null : jsonDecode(paramsJson);
      final params = decoded is Map<String, Object?>
          ? decoded
          : const <String, Object?>{};
      final result = await callHost(manifest.id, method, params);
      if (_cancelled.contains(manifest.id)) {
        throw const RpcException(RpcErrorCode.cancelled, 'cancelled');
      }
      return jsonEncode({'result': _jsonSafe(result)});
    } on RpcException catch (error) {
      return jsonEncode({
        'error': {'code': error.code, 'message': error.message},
      });
    } catch (error) {
      return jsonEncode({
        'error': {
          'code': RpcErrorCode.internalError,
          'message': '$error',
        },
      });
    }
  }

  Set<String> _decodeRegistered(JsEngine engine) {
    final raw = engine.callGlobal(BootstrapGlobals.registered, const []);
    if (raw is! String) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    final commands = decoded['commands'];
    if (commands is! List) return const {};
    return {for (final value in commands) '$value'};
  }

  Object? _decodeEnvelope(Object? raw) {
    if (raw is! String) return raw;
    final decoded = jsonDecode(raw);
    if (decoded is Map && decoded.containsKey('result')) {
      return decoded['result'];
    }
    return decoded;
  }

  _LoadedPlugin _require(String pluginId) {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw RpcException(
        RpcErrorCode.invalidParams,
        '$pluginId is not loaded',
      );
    }
    return plugin;
  }

  /// Disposes every runtime. Called when the worker shuts down.
  Future<void> disposeAll() async {
    for (final id in _plugins.keys.toList()) {
      await unload(id);
    }
  }

  static Future<Object?> _maybeAwait(Object? value) async =>
      value is Future ? await value : value;

  /// Normalises engine output into something `jsonEncode` accepts.
  ///
  /// The JavaScript bridge hands back `Map<dynamic, dynamic>` and `List<dynamic>`
  /// which `jsonEncode` rejects for non-string keys, so keys are stringified
  /// here rather than at every call site.
  static Object? _jsonSafe(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          '${entry.key}': _jsonSafe(entry.value),
      };
    }
    if (value is Iterable) {
      return [for (final item in value) _jsonSafe(item)];
    }
    return '$value';
  }

  static Map<String, Object?> _requireMap(
    Map<String, Object?> params,
    String key,
  ) {
    final value = params[key];
    if (value is! Map<String, Object?>) {
      throw RpcException(
        RpcErrorCode.invalidParams,
        '"$key" must be an object',
      );
    }
    return value;
  }

  static Map<String, Object?> _optionalMap(
    Map<String, Object?> params,
    String key,
  ) {
    final value = params[key];
    return value is Map<String, Object?> ? value : const {};
  }

  static String _requireString(Map<String, Object?> params, String key) {
    final value = params[key];
    if (value is! String) {
      throw RpcException(
        RpcErrorCode.invalidParams,
        '"$key" must be a string',
      );
    }
    return value;
  }
}
