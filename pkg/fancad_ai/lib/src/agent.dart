import 'dart:async';
import 'dart:convert';

import 'package:fancad_core/fancad_core.dart';

import 'approval.dart';
import 'authoring.dart';
import 'context.dart';
import 'conversation.dart';
import 'provider.dart';
import 'skills/host_tools.dart';
import 'skills/skill.dart';
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
    this.onUsage,
    this.maxRounds = 16,
    this.history,
    this.session,
    this.skills,
    this.hostTools = const [],
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
  final void Function(LlmUsage usage)? onUsage;
  final int maxRounds;
  final SessionSnapshot? session;
  final SkillRegistry? skills;
  final List<HostTool> hostTools;

  /// When set, every edit this turn produced is collapsed into one undo entry.
  final UndoStack? history;

  final CommandToolCatalog catalog = const CommandToolCatalog();
  final DocumentContextBuilder contextBuilder = const DocumentContextBuilder();
  final PluginAuthoring authoring = const PluginAuthoring();

  bool _cancelled = false;

  /// Asks the loop to stop after the in-flight model reply or tool call.
  void cancel() => _cancelled = true;

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

    final extras = _hostTools();
    final tools = catalog.toolsOf(
      registry,
      extra: [for (final tool in extras) tool.definition],
    );
    final system = LlmMessage.system(
      contextBuilder.systemPrompt(
        document: document,
        tools: registry.aiTools(),
        pluginTypings: typings,
        session: session,
        skills: skills?.listSummaries() ?? const [],
      ),
    );

    final collectedCalls = <LlmToolCall>[];
    final undoBefore = history?.depth ?? 0;
    String? error;

    for (var round = 0; round < maxRounds; round++) {
      if (_cancelled) {
        return _stopped(convo, collectedCalls, undoBefore);
      }
      final messages = [system, ...convo.llmMessages];
      final request = LlmRequest(messages: messages, tools: tools);
      LlmCompletion completion;
      try {
        completion = await _complete(request, convo);
      } on LlmException catch (caught) {
        error = caught.message;
        break;
      }
      if (_cancelled) {
        return _stopped(convo, collectedCalls, undoBefore);
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
          if (_cancelled) {
            return _stopped(convo, collectedCalls, undoBefore);
          }
          continue;
        }
      }

      await _runCalls(completion.toolCalls, convo);
      if (_cancelled) {
        return _stopped(convo, collectedCalls, undoBefore);
      }
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

  AgentTurn _stopped(
    Conversation convo,
    List<LlmToolCall> collectedCalls,
    int undoBefore,
  ) {
    _coalesce(undoBefore);
    return AgentTurn(
      reply: convo.visible
          .where((message) => message.role == ChatRole.assistant)
          .map((message) => message.text)
          .join('\n'),
      toolCalls: collectedCalls,
      cancelled: true,
      undoEntries: (history?.depth ?? undoBefore) - undoBefore,
    );
  }

  /// Streams tokens into the visible transcript, then falls back once if a
  /// tool call arrived without its required arguments.
  Future<LlmCompletion> _complete(LlmRequest request, Conversation convo) async {
    var text = '';
    var calls = const <LlmToolCall>[];
    var finish = 'stop';
    LlmUsage? usage;
    await for (final event in provider.complete(request)) {
      if (_cancelled) break;
      switch (event) {
        case LlmTextDelta delta:
          text += delta.text;
          convo.appendAssistantDelta(delta.text);
          onDelta?.call(delta.text);
        case LlmReasoningDelta delta:
          convo.appendReasoningDelta(delta.text);
          onDelta?.call(delta.text);
        case LlmToolCalls tools:
          calls = tools.calls;
        case LlmFinished(:final finishReason, usage: final seen):
          finish = finishReason;
          if (seen != null) {
            usage = seen;
            onUsage?.call(seen);
          }
        case LlmError(:final message):
          throw LlmException(message);
      }
    }

    if (_shouldRetryTools(calls, finish)) {
      try {
        final fallback = await provider.completeOnce(request);
        if (fallback.toolCalls.isNotEmpty) calls = fallback.toolCalls;
        if (fallback.text.isNotEmpty && fallback.text != text) {
          text = fallback.text;
          convo.replaceLastAssistant(text);
        }
        finish = fallback.finishReason;
        if (fallback.usage != null) {
          usage = fallback.usage;
          onUsage?.call(fallback.usage!);
        }
      } catch (_) {
        // Keep the streamed calls if the one-shot retry fails.
      }
    }

    return LlmCompletion(
      text: text,
      toolCalls: calls,
      finishReason: finish,
      usage: usage,
    );
  }

  bool _shouldRetryTools(List<LlmToolCall> calls, String finish) {
    if (finish == 'tool_calls' && calls.isEmpty) return true;
    if (calls.isEmpty) return false;
    return _toolCallsIncomplete(calls);
  }

  bool _toolCallsIncomplete(List<LlmToolCall> calls) {
    for (final call in calls) {
      if (call.name.isEmpty) return true;
      if (call.arguments.length == 1 && call.arguments.containsKey('raw')) {
        return true;
      }
      final command = catalog.commandFor(registry, call.name);
      if (command != null) {
        for (final param in command.params) {
          if (!param.required) continue;
          final value = call.arguments[param.name];
          if (value == null) return true;
          if (value is String && value.trim().isEmpty) return true;
        }
        continue;
      }
      final host = _hostTool(call.name);
      if (host == null) continue;
      final required = host.definition.parameters['required'];
      if (required is! List) continue;
      for (final key in required) {
        final value = call.arguments['$key'];
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) return true;
      }
    }
    return false;
  }

  List<HostTool> _hostTools() {
    if (hostTools.isNotEmpty) return hostTools;
    final registry = skills;
    if (registry == null) return const [];
    return bundledHostTools(registry);
  }

  HostTool? _hostTool(String name) {
    for (final tool in _hostTools()) {
      if (tool.definition.name == name) return tool;
    }
    return null;
  }

  Future<void> _runCalls(List<LlmToolCall> calls, Conversation convo) async {
    for (final call in calls) {
      if (_cancelled) return;
      final host = _hostTool(call.name);
      if (host != null) {
        try {
          final payload = await host.execute(call.arguments);
          convo.addToolResult(
            call: call,
            content: jsonEncode(payload),
            isError: payload['status'] == 'failed',
          );
        } catch (caught) {
          convo.addToolResult(
            call: call,
            content: jsonEncode({
              'status': 'failed',
              'error': '$caught',
              'message': '$caught',
            }),
            isError: true,
          );
        }
        continue;
      }
      final command = catalog.commandFor(registry, call.name);
      if (command == null) {
        final message = 'Unknown tool: ${call.name}';
        convo.addToolResult(
          call: call,
          content: jsonEncode({
            'status': 'failed',
            'error': message,
            'message': message,
          }),
          isError: true,
        );
        continue;
      }
      if (command.aiExposure == AiExposure.hidden) {
        final message = '${command.id} is not available to the assistant';
        convo.addToolResult(
          call: call,
          content: jsonEncode({
            'status': 'failed',
            'error': message,
            'message': message,
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
            ...encodeAssistantToolResult(result, command),
            'repairHint': repair,
          }),
          isError: true,
        );
        continue;
      }

      final payload = encodeAssistantToolResult(result, command);
      convo.addToolResult(
        call: call,
        content: jsonEncode(payload),
        isError: payload['status'] != 'ok',
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
