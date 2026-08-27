// ignore_for_file: invalid_annotation_target

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;

import 'contributions.dart';
import 'host_bridge.dart';
import 'manifest.dart';
import 'protocol.dart';
import 'transport.dart';

part 'plugin_host.g.dart';

/// Where a plugin is in its lifecycle.
enum PluginState {
  /// Discovered and its contributions registered, but no code has run.
  installed,

  /// Its entry point is being evaluated.
  activating,

  /// Running.
  active,

  /// Refused to load, or threw during activation. [PluginHandle.error] says why.
  failed,

  /// Switched off by the user, or quarantined after wedging the worker.
  disabled,
}

/// A plugin as the application sees it.
class PluginHandle {
  PluginHandle({required this.manifest, required this.state, this.error});

  final PluginManifest manifest;
  PluginState state;

  /// Why it failed, when it did.
  String? error;

  /// Log lines the plugin produced, newest last.
  final List<String> log = [];

  String get id => manifest.id;
  bool get isActive => state == PluginState.active;

  Map<String, Object?> toJson() => _PluginHandleJson(
    id: id,
    name: manifest.name,
    version: manifest.version,
    state: state.name,
    error: error,
    commands: [for (final command in manifest.commands) command.id],
  ).toJson();
}

@JsonSerializable(createFactory: false, includeIfNull: false)
class _PluginHandleJson {
  const _PluginHandleJson({
    required this.id,
    required this.name,
    required this.version,
    required this.state,
    this.error,
    required this.commands,
  });

  final String id;
  final String name;
  final String version;
  final String state;
  final String? error;
  final List<String> commands;

  Map<String, Object?> toJson() => _$PluginHandleJsonToJson(this);
}

/// Builds the handler that serves plugin-to-host `fancad.*` calls.
///
/// The application supplies this so the product-named bridge lives outside
/// this package. Tests that omit it get [HostBridge].
typedef HostCallFactory =
    HostCallHandler Function({
      required PluginHostDelegate delegate,
      required PluginManifest? Function(String pluginId) manifests,
    });

/// Loads plugins, registers what they contribute, and routes calls to them.
///
/// The invariant worth stating: a plugin's commands appear in the registry as
/// soon as it is discovered, before any of its code runs. Invoking one is what
/// activates it. That keeps startup free of third-party code while still making
/// every contributed command visible to the palette, the command line and the
/// model from the first frame.
class PluginHost {
  PluginHost({
    required this.registry,
    required this.delegate,
    required this.transport,
    ContributionRegistry? contributions,
    this.hostVersion = '0.1.0',
    this.activationTimeout = const Duration(seconds: 10),
    this.invokeTimeout = const Duration(seconds: 30),
    HostCallFactory? createHostCall,
  }) : contributions = contributions ?? ContributionRegistry(),
       createHostCall = createHostCall ?? _defaultHostCall;

  final CommandRegistry registry;
  final PluginHostDelegate delegate;
  final PluginTransport transport;
  final ContributionRegistry contributions;
  final String hostVersion;
  final HostCallFactory createHostCall;

  /// How long a plugin gets to evaluate and activate.
  final Duration activationTimeout;

  /// How long one command handler gets before the host gives up on it.
  final Duration invokeTimeout;

  final Map<String, PluginHandle> _plugins = {};
  final Map<String, Disposable> _registrations = {};
  final StreamController<PluginHost> _changes =
      StreamController<PluginHost>.broadcast(sync: true);

  late final HostCallHandler _hostCall = createHostCall(
    delegate: delegate,
    manifests: (id) => _plugins[id]?.manifest,
  );

  bool _started = false;

  static HostCallHandler _defaultHostCall({
    required PluginHostDelegate delegate,
    required PluginManifest? Function(String pluginId) manifests,
  }) {
    return HostBridge(delegate: delegate, manifests: manifests).call;
  }

  /// Fires when a plugin's state changes.
  Stream<PluginHost> get changes => _changes.stream;

  List<PluginHandle> get plugins => List.unmodifiable(_plugins.values);
  PluginHandle? plugin(String id) => _plugins[id];

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await transport.start(_hostCall);
    // A dead worker is not fatal: built-in commands keep working, and the
    // extensions panel shows what stopped.
    transport.died.listen(_onWorkerDied);
  }

  /// Reads every plugin folder under [root] and registers what it finds.
  ///
  /// A malformed manifest disables one plugin; it never stops the scan, because
  /// one bad extension should not cost the user all the others.
  Future<List<PluginHandle>> discover(String root) async {
    final directory = Directory(root);
    if (!directory.existsSync()) return const [];
    final found = <PluginHandle>[];
    for (final entry in directory.listSync()) {
      if (entry is! Directory) continue;
      final handle = await install(entry.path);
      if (handle != null) found.add(handle);
    }
    return found;
  }

  /// Registers the plugin in [directory] without running it.
  Future<PluginHandle?> install(String directory) async {
    final file = File(p.join(directory, PluginManifest.fileName));
    if (!file.existsSync()) return null;
    try {
      final manifest = PluginManifest.parse(
        await file.readAsString(),
        path: file.path,
      ).withDirectory(directory);
      return _register(manifest);
    } on ManifestException catch (error) {
      final id = p.basename(directory);
      final handle = PluginHandle(
        manifest: PluginManifest(
          id: id,
          name: id,
          version: '0.0.0',
          entryPoint: '',
          directory: directory,
        ),
        state: PluginState.failed,
        error: '$error',
      );
      _plugins[id] = handle;
      _notify();
      return handle;
    }
  }

  /// Registers an in-memory manifest. Used by the AI plugin authoring loop,
  /// which writes a plugin and loads it without a restart.
  PluginHandle registerManifest(PluginManifest manifest) => _register(manifest);

  PluginHandle _register(PluginManifest manifest) {
    final existing = _plugins[manifest.id];
    if (existing != null) {
      throw StateError('${manifest.id} is already installed');
    }
    final handle = PluginHandle(
      manifest: manifest,
      state: PluginState.installed,
    );
    _plugins[manifest.id] = handle;

    final bag = DisposableBag();
    try {
      bag.add(
        registry.registerAll([
          for (final command in manifest.commands)
            command.toDescriptor(
              extensionId: manifest.id,
              // Activation is lazy and happens here: the first invocation of a
              // contributed command is what brings its plugin to life.
              handler: (context) =>
                  _runContributedCommand(manifest.id, command.id, context),
            ),
        ]),
      );
      bag.add(contributions.registerAll(manifest));
    } catch (error) {
      bag.dispose();
      _plugins.remove(manifest.id);
      handle.state = PluginState.failed;
      handle.error = '$error';
      _plugins[manifest.id] = handle;
      _notify();
      return handle;
    }
    _registrations[manifest.id] = bag;
    _notify();
    return handle;
  }

  /// Evaluates a plugin's entry point. Safe to call repeatedly.
  Future<bool> activate(String pluginId) async {
    final handle = _plugins[pluginId];
    if (handle == null) return false;
    if (handle.state == PluginState.active) return true;
    if (handle.state == PluginState.disabled) return false;
    if (handle.state == PluginState.activating) {
      return _pendingActivations[pluginId]?.future ?? false;
    }

    final pending = Completer<bool>();
    _pendingActivations[pluginId] = pending;
    handle.state = PluginState.activating;
    handle.error = null;
    _notify();

    try {
      final source = await _readEntryPoint(handle.manifest);
      final result = await transport.request(
        WorkerMethod.load,
        params: {'manifest': handle.manifest.toJson(), 'source': source},
        timeout: activationTimeout,
      );
      _reconcile(handle, result);
      handle.state = PluginState.active;
      _notify();
      pending.complete(true);
      return true;
    } on RpcException catch (error) {
      handle.state = PluginState.failed;
      handle.error = error.message;
      // A plugin that wedged the worker must not be retried on every
      // keystroke, so a timeout costs it its place until the user re-enables it.
      if (error.code == RpcErrorCode.timeout) {
        handle.state = PluginState.disabled;
        handle.error =
            'Disabled after failing to activate within '
            '${activationTimeout.inSeconds}s: ${error.message}';
      }
      _notify();
      pending.complete(false);
      return false;
    } catch (error) {
      handle.state = PluginState.failed;
      handle.error = '$error';
      _notify();
      pending.complete(false);
      return false;
    } finally {
      _pendingActivations.remove(pluginId);
    }
  }

  final Map<String, Completer<bool>> _pendingActivations = {};

  /// Records the gap between what a manifest declared and what its code
  /// registered. Surfaced rather than silently reconciled.
  void _reconcile(PluginHandle handle, Object? result) {
    if (result is! Map) return;
    final missing = result['missing'];
    if (missing is List && missing.isNotEmpty) {
      handle.log.add(
        'warning: declared but never registered: ${missing.join(', ')}',
      );
    }
    final undeclared = result['undeclared'];
    if (undeclared is List && undeclared.isNotEmpty) {
      handle.log.add(
        'warning: registered but not in the manifest, so unreachable from the '
        'palette: ${undeclared.join(', ')}',
      );
    }
  }

  Future<String> _readEntryPoint(PluginManifest manifest) async {
    if (manifest.directory.isEmpty) {
      final source = _inMemorySources[manifest.id];
      if (source == null) {
        throw RpcException(
          RpcErrorCode.invalidParams,
          '${manifest.id} has no source on disk and none was supplied',
        );
      }
      return source;
    }
    final file = File(p.join(manifest.directory, manifest.entryPoint));
    if (!file.existsSync()) {
      throw RpcException(
        RpcErrorCode.invalidParams,
        'entry point not found: ${file.path}',
      );
    }
    return file.readAsString();
  }

  final Map<String, String> _inMemorySources = {};

  /// Supplies source for a manifest with no directory, for generated plugins.
  void setSource(String pluginId, String source) {
    _inMemorySources[pluginId] = source;
  }

  Future<CommandResult> _runContributedCommand(
    String pluginId,
    String commandId,
    CommandContext context,
  ) async {
    final handle = _plugins[pluginId];
    if (handle == null) {
      return CommandResult.failed('$pluginId is not installed');
    }
    if (handle.state == PluginState.disabled) {
      return CommandResult.failed(
        '${handle.manifest.name} is disabled${handle.error == null ? '' : ': ${handle.error}'}',
      );
    }
    if (!await activate(pluginId)) {
      return CommandResult.failed(
        'could not activate ${handle.manifest.name}: ${handle.error ?? 'unknown error'}',
      );
    }

    try {
      final response = await transport.request(
        WorkerMethod.invoke,
        params: {
          'pluginId': pluginId,
          'commandId': commandId,
          'args': context.args.raw,
        },
        timeout: invokeTimeout,
      );
      final payload = response is Map ? response['result'] : null;
      return CommandResult.ok(
        message: payload is Map && payload['message'] is String
            ? payload['message'] as String
            : '',
        data: payload is Map
            ? {for (final entry in payload.entries) '${entry.key}': entry.value}
            : (payload == null ? null : {'value': payload}),
      );
    } on RpcException catch (error) {
      if (error.code == RpcErrorCode.cancelled) {
        return const CommandResult.cancelled();
      }
      if (error.code == RpcErrorCode.timeout) {
        // The handler is still running and cannot be stopped. Telling it to
        // cancel unblocks it if it is merely waiting on us.
        transport.notify(WorkerMethod.cancel, {'pluginId': pluginId});
        handle.log.add(
          '$commandId timed out after ${invokeTimeout.inSeconds}s',
        );
      }
      handle.log.add('$commandId failed: ${error.message}');
      _notify();
      return CommandResult.failed('${handle.manifest.name}: ${error.message}');
    }
  }

  /// Sends an event to every active plugin that might care.
  void broadcast(String event, [Map<String, Object?> payload = const {}]) {
    for (final handle in _plugins.values) {
      if (!handle.isActive) continue;
      transport.notify(WorkerMethod.event, {
        'pluginId': handle.id,
        'event': event,
        'payload': payload,
      });
    }
  }

  /// Unloads a plugin's code but keeps it installed.
  Future<void> deactivate(String pluginId) async {
    final handle = _plugins[pluginId];
    if (handle == null || !handle.isActive) return;
    try {
      await transport.request(
        WorkerMethod.unload,
        params: {'pluginId': pluginId},
        timeout: const Duration(seconds: 5),
      );
    } on RpcException catch (error) {
      handle.log.add('unload failed: ${error.message}');
    }
    handle.state = PluginState.installed;
    _notify();
  }

  /// Unloads and re-reads a plugin from disk.
  ///
  /// The contribution registrations are torn down and rebuilt, which is what
  /// makes a manifest edit take effect rather than only a code edit.
  Future<PluginHandle?> reload(String pluginId) async {
    final handle = _plugins[pluginId];
    if (handle == null) return null;
    final directory = handle.manifest.directory;
    final source = _inMemorySources[pluginId];
    await uninstall(pluginId);
    if (directory.isNotEmpty) {
      final reinstalled = await install(directory);
      if (reinstalled != null) await activate(reinstalled.id);
      return reinstalled;
    }
    if (source == null) return null;
    final reinstalled = _register(handle.manifest);
    _inMemorySources[pluginId] = source;
    await activate(pluginId);
    return reinstalled;
  }

  /// Removes a plugin entirely: code, commands, panels and menus.
  Future<void> uninstall(String pluginId) async {
    await deactivate(pluginId);
    _registrations.remove(pluginId)?.dispose();
    _plugins.remove(pluginId);
    _notify();
  }

  /// Switches a plugin off without forgetting it.
  Future<void> setEnabled(String pluginId, bool enabled) async {
    final handle = _plugins[pluginId];
    if (handle == null) return;
    if (!enabled) {
      await deactivate(pluginId);
      handle.state = PluginState.disabled;
      handle.error = null;
    } else if (handle.state == PluginState.disabled) {
      handle.state = PluginState.installed;
    }
    _notify();
  }

  /// Activates everything that asked to run at startup.
  Future<void> activateStartupPlugins() async {
    for (final handle in _plugins.values.toList()) {
      if (handle.manifest.activatesAtStartup) {
        await activate(handle.id);
      }
    }
  }

  /// Runs arbitrary source inside a plugin's scope, for the developer console.
  Future<Object?> evaluate(String pluginId, String source) async {
    if (!await activate(pluginId)) {
      throw StateError('$pluginId is not active');
    }
    final result = await transport.request(
      WorkerMethod.eval,
      params: {'pluginId': pluginId, 'source': source},
      timeout: invokeTimeout,
    );
    return result is Map ? result['value'] : result;
  }

  void _onWorkerDied(String reason) {
    for (final handle in _plugins.values) {
      if (handle.state == PluginState.active ||
          handle.state == PluginState.activating) {
        handle.state = PluginState.failed;
        handle.error = reason;
      }
    }
    _notify();
  }

  /// Records a log line a plugin emitted.
  void appendLog(String pluginId, String level, String message) {
    final handle = _plugins[pluginId];
    if (handle == null) return;
    handle.log.add('[$level] $message');
    // Bounded: a chatty plugin should not be able to grow the host's memory
    // without limit.
    if (handle.log.length > 500) {
      handle.log.removeRange(0, handle.log.length - 500);
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(this);
  }

  Future<void> dispose() async {
    for (final registration in _registrations.values) {
      registration.dispose();
    }
    _registrations.clear();
    _plugins.clear();
    await transport.dispose();
    contributions.dispose();
    await _changes.close();
  }

  /// Writes a plugin folder to disk. The AI authoring loop uses this, and so
  /// does the "create extension" command.
  static Future<PluginManifest> scaffold({
    required String root,
    required String id,
    required String name,
    String description = '',
    List<CommandContribution> commands = const [],
    Set<PluginPermission> permissions = const {
      PluginPermission.documentRead,
      PluginPermission.documentWrite,
      PluginPermission.commands,
    },
    String? source,
  }) async {
    final directory = Directory(p.join(root, id));
    await directory.create(recursive: true);
    final effectiveCommands = commands.isEmpty
        ? [
            CommandContribution(
              id: '$id.run',
              title: name,
              description: 'Runs $name.',
            ),
          ]
        : commands;
    final manifest = PluginManifest(
      id: id,
      name: name,
      version: '0.1.0',
      entryPoint: 'main.js',
      description: description,
      activation: [
        for (final command in effectiveCommands)
          ActivationEvent(ActivationKind.command, command.id),
      ],
      permissions: permissions,
      commands: effectiveCommands,
      directory: directory.path,
    );
    await File(p.join(directory.path, PluginManifest.fileName)).writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
    await File(
      p.join(directory.path, manifest.entryPoint),
    ).writeAsString(source ?? _defaultSource(effectiveCommands.first.id));
    return manifest;
  }

  static String _defaultSource(String commandId) =>
      '''
fancad.commands.register("$commandId", async (args) => {
  const summary = await fancad.document.summary();
  await fancad.window.showMessage(
    `This drawing has \${summary.entityCount} entities.`
  );
  return { entityCount: summary.entityCount };
});
''';
}
