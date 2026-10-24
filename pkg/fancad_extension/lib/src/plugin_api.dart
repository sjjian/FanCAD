import 'dart:async';

import 'package:fancad_core/fancad_core.dart';

import 'protocol.dart';

/// What the application must provide for scripts to be useful.
///
/// The runner depends on this rather than on the Flutter workspace, which
/// keeps the script pipeline testable without the widget tree.
abstract class PluginDelegate {
  /// The drawing named by a script `tab` argument. Null selector is the
  /// active drawing.
  DocumentSession? sessionFor(String? selector);

  /// Runs a registered command, exactly as the user would.
  Future<CommandResult> runCommand(
    String commandId,
    Map<String, Object?> args, {
    required String scope,
    String? tab,
  });

  /// Every command a script may see.
  Iterable<CommandDescriptor> get commands;

  /// Shows a message in the command line or as a toast.
  void showMessage(String scope, String message, {bool isError = false});

  /// One `console` line from a running script.
  void log(String scope, String level, String message);

  void hold(DocumentSession session, List<int> ids);

  void flash(DocumentSession session, List<int> ids);
}

/// Serves the `fancad.*` calls a script makes.
class PluginApi {
  PluginApi({required this.delegate});

  final PluginDelegate delegate;

  Future<Object?> call(
    String scope,
    String method,
    Map<String, Object?> params,
  ) async {
    switch (method) {
      case HostMethod.executeCommand:
        return _executeCommand(scope, params);
      case HostMethod.listCommands:
        return {
          'commands': [
            for (final command in delegate.commands) command.toJson(),
          ],
        };
      case HostMethod.canvasHold:
        delegate.hold(_session(params), _idsOf(params['ids']));
        return null;
      case HostMethod.canvasFlash:
        delegate.flash(_session(params), _idsOf(params['ids']));
        return null;
      case HostMethod.showMessage:
        delegate.showMessage(
          scope,
          '${params['message']}',
          isError: params['error'] == true,
        );
        return null;
      case HostMethod.log:
        delegate.log(
          scope,
          '${params['level'] ?? 'info'}',
          '${params['message'] ?? ''}',
        );
        return null;
      default:
        throw RpcException(
          RpcErrorCode.methodNotFound,
          'the host does not provide "$method"',
        );
    }
  }

  DocumentSession _session(Map<String, Object?> params) {
    final raw = params['tab'];
    final selector = raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
    final session = delegate.sessionFor(selector);
    if (session == null) {
      throw RpcException(
        RpcErrorCode.invalidRequest,
        selector == null
            ? 'no drawing is open'
            : 'no drawing matches "$selector"',
      );
    }
    return session;
  }

  Future<Object?> _executeCommand(
    String scope,
    Map<String, Object?> params,
  ) async {
    final commandId = params['command'];
    if (commandId is! String) {
      throw const RpcException(
        RpcErrorCode.invalidParams,
        '"command" must be a string',
      );
    }
    final args = params['args'];
    final commandArgs = args is Map<String, Object?>
        ? args
        : args is Map
        ? Map<String, Object?>.from(args)
        : const <String, Object?>{};
    final rawTab = commandArgs['tab'];
    final tab = rawTab is String && rawTab.trim().isNotEmpty
        ? rawTab.trim()
        : null;
    final result = await delegate.runCommand(
      commandId,
      commandArgs,
      scope: scope,
      tab: tab,
    );
    return result.toJson();
  }

  List<int> _idsOf(Object? raw) => [
    if (raw is num) raw.toInt(),
    if (raw is List)
      for (final value in raw)
        if (value is num) value.toInt(),
  ];
}
