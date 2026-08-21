import 'package:fancad_core/fancad_core.dart';
import 'package:meta/meta.dart';

import 'provider.dart';
import 'tools.dart';

/// A set of tool calls waiting for the user to approve them.
@immutable
class PendingChangeSet {
  const PendingChangeSet({
    required this.calls,
    required this.commands,
    this.highlightIds = const [],
  });

  final List<LlmToolCall> calls;
  final List<CommandDescriptor> commands;
  final List<int> highlightIds;

  bool get isEmpty => calls.isEmpty;
  bool get isNotEmpty => calls.isNotEmpty;

  String get title => calls.length == 1
      ? 'Allow ${commands.first.title}?'
      : 'Allow ${calls.length} changes?';

  String get details {
    final lines = <String>[];
    for (var i = 0; i < calls.length; i++) {
      final command = i < commands.length ? commands[i] : null;
      final call = calls[i];
      final label = command?.title ?? call.name;
      final args = call.arguments.entries
          .where((entry) => entry.value != null)
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      lines.add(args.isEmpty ? label : '$label ($args)');
    }
    if (highlightIds.isNotEmpty) {
      lines.add('Affects ${highlightIds.length} object(s).');
    }
    return lines.join('\n');
  }
}

/// Decides whether a tool call may run unattended.
///
/// Read-only commands run. Edits run when the user has opted into auto-approve.
/// Destructive commands, and anything marked [AiExposure.approvalRequired],
/// always ask. The default for an unanswered question is no.
class ApprovalPolicy {
  const ApprovalPolicy({this.autoApproveEdits = false});

  /// When true, [CommandRisk.edit] tools run without asking. Destructive
  /// tools still ask.
  final bool autoApproveEdits;

  bool requiresApproval(CommandDescriptor command) {
    if (command.aiExposure == AiExposure.approvalRequired) return true;
    if (command.aiExposure == AiExposure.hidden) return true;
    switch (command.risk) {
      case CommandRisk.readOnly:
        return false;
      case CommandRisk.edit:
        return !autoApproveEdits;
      case CommandRisk.destructive:
        return true;
    }
  }

  /// Groups [calls] that need a decision. Empty when everything may run.
  PendingChangeSet? pendingOf(
    List<LlmToolCall> calls,
    CommandRegistry registry,
  ) {
    const catalog = CommandToolCatalog();
    final pendingCalls = <LlmToolCall>[];
    final pendingCommands = <CommandDescriptor>[];
    final highlights = <int>{};
    for (final call in calls) {
      final command = catalog.commandFor(registry, call.name);
      if (command == null) continue;
      if (!requiresApproval(command)) continue;
      pendingCalls.add(call);
      pendingCommands.add(command);
      highlights.addAll(CommandToolCatalog.highlightIdsOf(call.arguments));
    }
    if (pendingCalls.isEmpty) return null;
    return PendingChangeSet(
      calls: pendingCalls,
      commands: pendingCommands,
      highlightIds: highlights.toList(),
    );
  }
}

/// Asks the host whether a pending change set may proceed.
typedef ApprovalAsker = Future<bool> Function(PendingChangeSet pending);
