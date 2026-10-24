import 'dart:async';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_extension/fancad_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../commands/extension/commands.dart';
import '../models/plugin.dart';
import 'providers.dart';
import 'workspace.dart';

part 'plugin.g.dart';

/// Connects running scripts to the application.
///
/// Everything a script can reach passes through here, and every method routes
/// into machinery the user already drives: commands run through
/// [Workspace.runHeadless], so a script cannot reach a code path the command
/// line cannot, and every edit lands in the same undo stack.
class AppPluginDelegate implements PluginDelegate {
  AppPluginDelegate({required Workspace Function() workspace})
    : _workspace = workspace;

  /// Resolved on demand rather than injected.
  ///
  /// The workspace registers the extension commands, which need the runner,
  /// which needs this delegate. Looking the workspace up at call time rather
  /// than at construction is what keeps that chain from being a cycle.
  final Workspace Function() _workspace;

  Workspace get workspace => _workspace();

  @override
  DocumentSession? sessionFor(String? selector) =>
      workspace.findDrawing(selector)?.session;

  @override
  void hold(DocumentSession session, List<int> ids) {
    workspace.holdHighlightsOn(session.id, ids);
  }

  @override
  void flash(DocumentSession session, List<int> ids) {
    workspace.flashHighlightsOn(session.id, ids);
  }

  @override
  Iterable<CommandDescriptor> get commands => workspace.commands.all;

  @override
  Future<CommandResult> runCommand(
    String commandId,
    Map<String, Object?> args, {
    required String scope,
    String? tab,
  }) {
    // `exec` and `extension.<name>` are the shell. A snippet that reached either
    // through commands.execute would start another run while this one is
    // still waiting on the host.
    final found = workspace.commands.find(commandId);
    if (commandId == 'exec' || found?.id == 'exec') {
      return Future.value(
        const CommandResult.failed(
          'exec cannot be called from inside a script.',
        ),
      );
    }
    if (found != null && found.id.startsWith('extension.')) {
      return Future.value(
        const CommandResult.failed(
          'script cannot be called from inside a script.',
        ),
      );
    }
    // Script-initiated commands are non-interactive by construction: there is
    // no user at the crosshair when a script runs LINE, so an unanswered
    // prompt has to be an error rather than a wait.
    return workspace.runHeadless(
      commandId,
      args: args,
      source: ChangeSource.plugin,
      tab: tab,
      log: (message) => log(scope, 'info', message),
    );
  }

  @override
  void showMessage(String scope, String message, {bool isError = false}) {
    workspace.notify(message, isError: isError);
  }

  @override
  void log(String scope, String level, String message) {
    final commandLine = workspace.commandLine;
    if (level == 'error') {
      commandLine.writeError(message);
    } else {
      commandLine.write(message);
    }
  }
}

/// Saved extensions and the runner that evaluates them.
@Riverpod(keepAlive: true)
class PluginNotifier extends _$PluginNotifier {
  late AppPluginDelegate delegate;
  ScriptRunner? _runner;
  ScriptCommands? _scripts;
  DisposableBag? _commandScope;

  /// The runner, or null when this session has no extensions folder.
  ScriptRunner? get runner => _runner;

  @override
  PluginModel build() {
    _disposeRuntime();
    final directory = ref.watch(pluginsDirectoryProvider);
    delegate = AppPluginDelegate(
      workspace: () => ref.read(workspaceNotifierProvider.notifier),
    );
    ref.onDispose(_disposeRuntime);
    if (directory.isEmpty) {
      return PluginModel(directory: directory);
    }
    // No worker yet: it starts on the first run, so nothing third-party sits
    // between launch and the first frame.
    _runner = ScriptRunner(
      openTransport: ref.watch(pluginTransportProvider),
      onCall: PluginApi(delegate: delegate).call,
    );
    _registerCommands(directory);
    return PluginModel(directory: directory);
  }

  void _registerCommands(String directory) {
    final settings = ref.read(appSettingsProvider).plugins;
    final scripts = ScriptCommands(
      directory: directory,
      disabled: settings.disabledScriptIds(),
      runScript: (source, {required args}) async {
        final runner = _runner;
        if (runner == null) {
          return const CommandResult.failed('extensions are unavailable');
        }
        return runner.run(source, args: args);
      },
      onChanged: () {
        state = state.copyWith(epoch: state.epoch + 1);
      },
      onEnabled: (name, enabled) {
        ref.read(appSettingsProvider).plugins.setScriptDisabled(name, !enabled);
      },
    );
    _scripts = scripts;
    final registry = ref.read(commandRegistryProvider);
    final scope = DisposableBag(debugLabel: 'extension-commands');
    for (final descriptor in scripts.descriptors()) {
      scope.add(registry.register(descriptor));
    }
    scripts.watch(registry);
    _commandScope = scope;
  }

  /// Turns one saved extension on or off. A disabled extension stays in the
  /// list and leaves the command line until it is enabled again.
  void setScriptEnabled(String name, bool enabled) {
    _scripts?.setEnabled(name, enabled);
  }

  /// Evaluates [source] on the script worker. Chat calls this directly. It is
  /// not a [CommandRegistry] entry, so a script cannot `commands.execute` it
  /// back into another run.
  Future<Map<String, Object?>> execScript(String source) async {
    final runner = _runner;
    if (runner == null) {
      return {'status': 'failed', 'message': 'extensions are unavailable'};
    }
    final result = await runner.run(source);
    if (!result.isOk) {
      return {'status': 'failed', 'message': result.message};
    }
    return {'status': 'ok', 'value': result.data?['value']};
  }

  void _disposeRuntime() {
    _scripts?.release();
    _scripts = null;
    _commandScope?.dispose();
    _commandScope = null;
    unawaited(_runner?.dispose());
    _runner = null;
  }
}
