import 'json.dart';

/// The four verbs of the single entry point.
enum OpsAction { list, help, schema, run }

/// One call into [OpsDispatcher].
class OpsRequest {
  const OpsRequest({
    required this.action,
    this.path = '',
    this.args = const {},
  });

  final OpsAction action;
  final String path;
  final Map<String, Object?> args;

  bool get hasPath => path.trim().isNotEmpty;

  /// What the panel should print: the inner command, not the wrapper tool.
  String get displayName => hasPath ? path.trim() : action.name;

  static OpsRequest? tryParse(Map<String, Object?> raw) {
    final action = parseAction(raw['action']);
    if (action == null) return null;
    return OpsRequest(
      action: action,
      path: '${raw['path'] ?? ''}'.trim(),
      args: asObjectMap(raw['args']),
    );
  }

  static OpsRequest parse(Map<String, Object?> raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return parsed;
    throw FormatException(
      'fancad requires action=list|help|schema|run. '
      'Call help with no path to see groups.',
    );
  }

  Map<String, Object?> toJson() => {
    'action': action.name,
    if (hasPath) 'path': path,
    if (args.isNotEmpty) 'args': args,
  };
}

OpsAction? parseAction(Object? raw) {
  final name = '$raw'.trim().toLowerCase();
  for (final action in OpsAction.values) {
    if (action.name == name) return action;
  }
  return null;
}
