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

  /// Command titles grouped for the approval card, never leftover arguments.
  List<String> get groupedTitles {
    final counts = <String, int>{};
    final order = <String>[];
    for (var i = 0; i < calls.length; i++) {
      final label = i < commands.length ? commands[i].title : calls[i].name;
      if (counts.containsKey(label)) {
        counts[label] = counts[label]! + 1;
      } else {
        counts[label] = 1;
        order.add(label);
      }
    }
    return [
      for (final label in order)
        counts[label] == 1 ? label : '$label ×${counts[label]}',
    ];
  }

  String get details {
    final lines = [...groupedTitles];
    if (highlightIds.isNotEmpty) {
      lines.add('Affects ${highlightIds.length} object(s).');
    }
    return lines.join('\n');
  }
}

/// Decides whether a tool call may run unattended.
///
/// Drawing and other edits run. Only [CommandRisk.destructive] tools — erase,
/// overkill, delete layer — wait for a card in the chat. The leftover
/// auto-approve switch skips that card too. An unanswered delete is no.
class ApprovalPolicy {
  const ApprovalPolicy({this.autoApproveEdits = false});

  /// When true, even destructive tools run without asking.
  final bool autoApproveEdits;

  bool requiresApproval(CommandDescriptor command) {
    if (command.risk != CommandRisk.destructive) return false;
    return !autoApproveEdits;
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
