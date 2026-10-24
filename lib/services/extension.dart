import 'dart:async';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_extension/fancad_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../commands/extension/commands.dart';
import '../models/extension.dart';
import 'providers.dart';
import 'workspace.dart';

part 'extension.g.dart';

/// Connects running commands to the application.
///
/// Everything a script can reach passes through here, and every method routes
/// into machinery the user already drives: commands run through
/// [Workspace.runHeadless], so a script cannot reach a code path the command
/// line cannot, and every edit lands in the same undo stack.
class ExtensionDelegate implements ExtensionHost {
  ExtensionDelegate({required Workspace Function() workspace})
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
    final refused = scriptRefusal(
      commandId,
      workspace.commands.find(commandId),
      args,
    );
    if (refused != null) return Future.value(CommandResult.failed(refused));
    // Script-initiated commands are non-interactive by construction: there is
    // no user at the crosshair when a script runs LINE, so an unanswered
    // prompt has to be an error rather than a wait.
    return workspace.runHeadless(
      commandId,
      args: args,
      source: ChangeSource.extension,
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

/// Why a script may not run [commandId], or null when it may.
///
/// The user approved the run, not every command inside it. Anything that
/// cannot be undone from the drawing's history, or that would start another
/// run while this one waits on the host, is refused here.
String? scriptRefusal(
  String commandId,
  CommandDescriptor? found,
  Map<String, Object?> args,
) {
  final id = found?.id ?? commandId;
  if (id == 'exec') return 'exec cannot be called from inside a script.';
  if (id.startsWith('extension.') || _reentrant.contains(id)) {
    return '$id cannot be called from inside a script.';
  }
  if (_outsideHistory.contains(id)) {
    return '$id cannot be called from inside a script. '
        'It changes files or the undo history, which the drawing cannot undo.';
  }
  if (found != null && found.riskFor(args) == CommandRisk.destructive) {
    return '$id cannot be called from inside a script because it is '
        'destructive. Ask the user to run it.';
  }
  return null;
}

/// Commands that write, delete or run extension files.
const _reentrant = {'extensions.write', 'extensions.delete', 'extensions.run'};

/// Commands whose effect is outside the drawing's undo stack.
const _outsideHistory = {
  'file.save',
  'file.saveAs',
  'file.close',
  'edit.undo',
  'edit.redo',
};

/// Saved extensions and the runner that evaluates them.
@Riverpod(keepAlive: true)
class ExtensionNotifier extends _$ExtensionNotifier {
  late ExtensionDelegate delegate;
  ScriptRunner? _runner;
  ExtensionCommands? _commands;
  DisposableBag? _commandScope;

  /// The runner, or null when this session has no extensions folder.
  ScriptRunner? get runner => _runner;

  @override
  ExtensionModel build() {
    _disposeRuntime();
    final directory = ref.watch(extensionsDirectoryProvider);
    delegate = ExtensionDelegate(
      workspace: () => ref.read(workspaceNotifierProvider.notifier),
    );
    ref.onDispose(_disposeRuntime);
    if (directory.isEmpty) {
      return ExtensionModel(directory: directory);
    }
    // No worker yet: it starts on the first run, so nothing third-party sits
    // between launch and the first frame.
    _runner = ScriptRunner(
      openTransport: ref.watch(extensionTransportProvider),
      onCall: ExtensionApi(delegate: delegate).call,
    );
    _registerCommands(directory);
    return ExtensionModel(directory: directory);
  }

  void _registerCommands(String directory) {
    final settings = ref.read(appSettingsProvider).extensions;
    final commands = ExtensionCommands(
      directory: directory,
      disabled: settings.disabledIds(),
      runSource: (source, {required args, required label}) =>
          _runAsOneStep(source, args: args, label: label),
      onChanged: () {
        state = state.copyWith(epoch: state.epoch + 1);
      },
      onEnabled: (name, enabled) {
        ref.read(appSettingsProvider).extensions.setDisabled(name, !enabled);
      },
    );
    _commands = commands;
    final registry = ref.read(commandRegistryProvider);
    final scope = DisposableBag(debugLabel: 'extension-commands');
    for (final descriptor in commands.descriptors()) {
      scope.add(registry.register(descriptor));
    }
    commands.watch(registry);
    _commandScope = scope;
  }

  /// Turns one saved extension on or off. A disabled extension stays in the
  /// list and leaves the command line until it is enabled again.
  void setEnabled(String name, bool enabled) {
    _commands?.setEnabled(name, enabled);
  }

  /// Evaluates [source] on the script worker. Chat calls this directly. It is
  /// not a [CommandRegistry] entry, so a script cannot `commands.execute` it
  /// back into another run.
  Future<Map<String, Object?>> exec(String source) async {
    final result = await _runAsOneStep(source, label: 'exec');
    if (!result.isOk) {
      return {'status': 'failed', 'message': result.message};
    }
    return {'status': 'ok', 'value': result.data?['value']};
  }

  /// Runs [source] and folds what it did to each drawing into one undo step
  /// named [label], so undo takes back the whole run, not its last command.
  Future<CommandResult> _runAsOneStep(
    String source, {
    Map<String, Object?> args = const {},
    required String label,
  }) async {
    final runner = _runner;
    if (runner == null) {
      return const CommandResult.failed('extensions are unavailable');
    }
    final workspace = ref.read(workspaceNotifierProvider.notifier);
    final before = <String, int>{
      for (final id in workspace.state.sessionIds)
        id: workspace.session(id)?.history.depth ?? 0,
    };
    try {
      return await runner.run(source, args: args);
    } finally {
      for (final id in workspace.state.sessionIds) {
        final history = workspace.session(id)?.history;
        if (history == null) continue;
        history.coalesceLast(history.depth - (before[id] ?? 0), label: label);
      }
    }
  }

  void _disposeRuntime() {
    _commands?.release();
    _commands = null;
    _commandScope?.dispose();
    _commandScope = null;
    unawaited(_runner?.dispose());
    _runner = null;
  }
}
