import 'dart:async';
import 'dart:convert';

import 'package:fancad_core/fancad_core.dart';

import 'approval.dart';
import 'authoring.dart';
import 'context.dart';
import 'conversation.dart';
import 'provider.dart';
import 'tools.dart';

/// How a tool is executed by the host.
typedef ToolExecutor =
    Future<CommandResult> Function(
      String commandId,
      Map<String, Object?> args,
    );

/// One completed agent turn.
class AgentTurn {
  AgentTurn({
    required this.reply,
    required this.toolCalls,
    required this.cancelled,
    this.error,
    this.undoEntries = 0,
  });

  final String reply;
  final List<LlmToolCall> toolCalls;
  final bool cancelled;
  final String? error;

  /// How many undo entries this turn produced before they were coalesced.
  final int undoEntries;

  bool get isOk => error == null && !cancelled;
}

/// The agent loop: complete, run tools, complete again.
///
/// The command registry is the tool list. Edits go through the same handlers
/// a person uses, so a tool call that draws a line is the LINE command, and
/// one undo step reverts the whole turn rather than one call inside it.
class AgentLoop {
  AgentLoop({
    required this.provider,
    required this.registry,
    required this.execute,
    required this.document,
    this.conversation,
    this.policy = const ApprovalPolicy(),
    this.askApproval,
    this.typings,
    this.onDelta,
    this.maxRounds = 8,
    this.history,
  });

  final LlmProvider provider;
  final CommandRegistry registry;
  final ToolExecutor execute;
  final CadDocument document;
  final Conversation? conversation;
  final ApprovalPolicy policy;
  final ApprovalAsker? askApproval;
  final String? typings;
  final void Function(String delta)? onDelta;
  final int maxRounds;

  /// When set, every edit this turn produced is collapsed into one undo entry.
  final UndoStack? history;

  final CommandToolCatalog catalog = const CommandToolCatalog();
  final DocumentContextBuilder contextBuilder = const DocumentContextBuilder();
  final PluginAuthoring authoring = const PluginAuthoring();

  /// Runs one user message to completion.
  Future<AgentTurn> run(String userMessage) async {
    if (userMessage.trim().isEmpty) {
      return AgentTurn(
        reply: '',
        toolCalls: const [],
        cancelled: false,
        error: 'The message was empty.',
      );
    }
    final convo = conversation ?? Conversation();
    convo.addUser(userMessage);

    final tools = catalog.toolsOf(registry);
    final system = LlmMessage.system(
      contextBuilder.systemPrompt(
        document: document,
        tools: registry.aiTools(),
        pluginTypings: typings,
      ),
    );

    final collectedCalls = <LlmToolCall>[];
    final undoBefore = history?.depth ?? 0;
    String? error;

    for (var round = 0; round < maxRounds; round++) {
      final messages = [system, ...convo.llmMessages];
      LlmCompletion completion;
      try {
        completion = await provider.completeOnce(
          LlmRequest(messages: messages, tools: tools),
        );
      } on LlmException catch (caught) {
        error = caught.message;
        break;
      }

      if (completion.text.isNotEmpty) {
        onDelta?.call(completion.text);
        convo.addAssistant(completion.text);
      }

      if (!completion.wantsTools) {
        convo.addAssistantLlm(LlmMessage.assistant(completion.text));
        _coalesce(undoBefore);
        return AgentTurn(
          reply: completion.text,
          toolCalls: collectedCalls,
          cancelled: false,
          undoEntries: (history?.depth ?? undoBefore) - undoBefore,
        );
      }

      convo.addAssistantLlm(
        LlmMessage.assistant(completion.text, toolCalls: completion.toolCalls),
      );
      collectedCalls.addAll(completion.toolCalls);

      final pending = policy.pendingOf(completion.toolCalls, registry);
      if (pending != null) {
        final asker = askApproval;
        final allowed = asker == null ? false : await asker(pending);
        if (!allowed) {
          for (final call in pending.calls) {
            convo.addToolResult(
              call: call,
              content: jsonEncode({
                'status': 'cancelled',
                'message': 'The user declined this change.',
              }),
              isError: true,
            );
          }
          final allowedNames = {for (final call in pending.calls) call.name};
          final remainder = [
            for (final call in completion.toolCalls)
              if (!allowedNames.contains(call.name)) call,
          ];
          if (remainder.isEmpty) {
            _coalesce(undoBefore);
            return AgentTurn(
              reply: completion.text,
              toolCalls: collectedCalls,
              cancelled: true,
              undoEntries: (history?.depth ?? undoBefore) - undoBefore,
            );
          }
          await _runCalls(remainder, convo);
          continue;
        }
      }

      await _runCalls(completion.toolCalls, convo);
    }

    _coalesce(undoBefore);
    return AgentTurn(
      reply: convo.visible
          .where((message) => message.role == ChatRole.assistant)
          .map((message) => message.text)
          .join('\n'),
      toolCalls: collectedCalls,
      cancelled: false,
      error: error ?? 'Stopped after $maxRounds tool rounds.',
      undoEntries: (history?.depth ?? undoBefore) - undoBefore,
    );
  }

  Future<void> _runCalls(List<LlmToolCall> calls, Conversation convo) async {
    for (final call in calls) {
      final command = catalog.commandFor(registry, call.name);
      if (command == null) {
        convo.addToolResult(
          call: call,
          content: jsonEncode({
            'status': 'failed',
            'message': 'Unknown tool: ${call.name}',
          }),
          isError: true,
        );
        continue;
      }
      if (command.aiExposure == AiExposure.hidden) {
        convo.addToolResult(
          call: call,
          content: jsonEncode({
            'status': 'failed',
            'message': '${command.id} is not available to the assistant',
          }),
          isError: true,
        );
        continue;
      }

      CommandResult result;
      try {
        result = await execute(command.id, call.arguments);
      } catch (caught) {
        result = CommandResult.failed('$caught');
      }

      if (authoring.isActivationFailure(result)) {
        final repair = authoring.repairPrompt(
          pluginId: '${call.arguments['id'] ?? command.id}',
          error: result.message,
          typings: typings,
        );
        convo.addToolResult(
          call: call,
          content: jsonEncode({
            ...result.toJson(),
            'repairHint': repair,
          }),
          isError: true,
        );
        continue;
      }

      convo.addToolResult(
        call: call,
        content: jsonEncode(result.toJson()),
        isError: result.isFailed,
      );
    }
  }

  void _coalesce(int undoBefore) {
    final stack = history;
    if (stack == null) return;
    final produced = stack.depth - undoBefore;
    if (produced > 1) {
      stack.coalesceLast(produced, label: 'Assistant turn');
    }
  }
}
