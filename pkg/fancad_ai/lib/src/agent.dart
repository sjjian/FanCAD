import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';

import 'approval.dart';
import 'context.dart';
import 'context_compact.dart';
import 'conversation.dart';
import 'provider.dart';
import 'session_ask.dart';
import 'session_exec.dart';
import 'skills/host_tools.dart';
import 'tools.dart';

/// PNG bytes lifted out of one tool result, and the visible row to hang them on.
class ToolImage {
  const ToolImage({required this.visibleIndex, required this.bytes});

  final int visibleIndex;
  final Uint8List bytes;
}

/// Saves tool images and places them after that tool-result run.
typedef ToolImageHandler =
    Future<void> Function(
      Conversation conversation,
      List<ToolImage> images,
      bool forModel,
    );

/// How a tool is executed by the host.
typedef ToolExecutor =
    Future<CommandResult> Function(
      String commandId,
      Map<String, Object?> args, {
      String? tab,
    });

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

/// Whether to compact a full model window and keep the turn going.
typedef CompactAsker = Future<bool> Function();

/// The agent loop: complete, run tools, complete again.
///
/// CAD platform ops go through the fancad CLI (same handlers a person uses).
/// Chat primitives such as ask and exec are sibling LLM tools, not catalog paths.
/// One undo step reverts the whole turn rather than one call inside it.
class AgentLoop {
  AgentLoop({
    required this.provider,
    required this.registry,
    required this.execute,
    this.conversation,
    this.policy = const ApprovalPolicy(),
    this.askApproval,
    this.onDelta,
    this.onUsage,
    this.history,
    this.askQuestion,
    this.execCode,
    this.supplyToSession,
    this.hostTools = const [],
    this.contextWindowTokens = LlmUsage.contextWindowTokens,
    this.onToolImage,
    this.askCompact,
  });

  final LlmProvider provider;
  final CommandRegistry registry;
  final ToolExecutor execute;
  final Conversation? conversation;
  final ApprovalPolicy policy;
  final ApprovalAsker? askApproval;
  final void Function(String delta)? onDelta;
  final void Function(LlmUsage usage)? onUsage;
  final QuestionAsker? askQuestion;

  /// Evaluates one snippet above the command registry. Null hides [execLlmTool].
  final CodeExecutor? execCode;

  final SessionSupplier? supplyToSession;
  final List<HostTool> hostTools;
  final int contextWindowTokens;

  /// Called once after a tool batch, with every image that batch returned.
  final ToolImageHandler? onToolImage;

  /// When reported prompt tokens exceed the window, asks whether to compact.
  ///
  /// Null compacts from the local estimate without asking.
  final CompactAsker? askCompact;

  /// When set, every edit this turn produced is collapsed into one undo entry.
  final UndoStack? history;

  final CommandToolCatalog catalog = const CommandToolCatalog();
  final DocumentContextBuilder contextBuilder = const DocumentContextBuilder();

  bool _cancelled = false;
  int? _lastPromptTokens;

  /// Last reported prompt size the user already agreed to compact past.
  int? _roomConsent;

  /// Asks the loop to stop after the in-flight model reply or tool call.
  void cancel() => _cancelled = true;

  /// Tools for this turn. Descriptions go out on [LlmRequest.tools], not the
  /// system prompt. CAD platform is fancad; chat primitives are siblings.
  List<LlmTool> get advertisedTools => [
    fancadLlmTool,
    extensionsLlmTool,
    if (askQuestion != null) askLlmTool,
    if (execCode != null) execLlmTool,
  ];

  /// Runs one user message to completion.
  Future<AgentTurn> run(
    String userMessage, {
    List<LlmImage> images = const [],
  }) async {
    if (userMessage.trim().isEmpty && images.isEmpty) {
      return AgentTurn(
        reply: '',
        toolCalls: const [],
        cancelled: false,
        error: 'The message was empty.',
      );
    }
    final convo = conversation ?? Conversation();
    convo.addUser(userMessage, images: images);

    final tools = advertisedTools;
    final collectedCalls = <LlmToolCall>[];
    final undoBefore = history?.depth ?? 0;
    String? error;

    for (;;) {
      if (_cancelled) {
        return _stopped(convo, collectedCalls, undoBefore);
      }
      final system = LlmMessage.system(contextBuilder.systemPrompt());
      if (askCompact == null) {
        await _compactTranscript(convo, system);
      } else if (!await _askIfUsageOver(convo, system)) {
        return _stopped(convo, collectedCalls, undoBefore);
      }
      final messages = [system, ...convo.llmMessages];
      final request = LlmRequest(messages: messages, tools: tools);
      LlmCompletion completion;
      try {
        completion = await _complete(request, convo);
      } on LlmException catch (caught) {
        if (!isContextOverflowMessage(caught.message)) {
          error = caught.message;
          break;
        }
        if (!await _askOnOverflow(convo, system)) {
          return _stopped(convo, collectedCalls, undoBefore);
        }
        final retried = LlmRequest(
          messages: [system, ...convo.llmMessages],
          tools: tools,
        );
        try {
          completion = await _complete(retried, convo);
        } on LlmException catch (retry) {
          error = retry.message;
          break;
        }
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
          final declinedIds = {for (final call in pending.calls) call.id};
          final remainder = [
            for (final call in completion.toolCalls)
              if (!declinedIds.contains(call.id)) call,
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
      error: error,
      undoEntries: (history?.depth ?? undoBefore) - undoBefore,
    );
  }

  /// Asks when the last response's prompt tokens exceed the window.
  ///
  /// The size just agreed covers later rounds until a new reading exceeds it.
  Future<bool> _askIfUsageOver(Conversation convo, LlmMessage system) async {
    final reported = _lastPromptTokens;
    if (reported == null || reported <= contextWindowTokens) return true;
    if (_roomConsent != null && reported <= _roomConsent!) return true;
    return _confirmAndCompact(convo, system, reported);
  }

  /// A context-length rejection has no usage. Ask, then compact and retry.
  Future<bool> _askOnOverflow(Conversation convo, LlmMessage system) async {
    if (askCompact == null) {
      await _compactTranscript(convo, system, force: true);
      return !_cancelled;
    }
    return _confirmAndCompact(convo, system, _lastPromptTokens);
  }

  Future<bool> _confirmAndCompact(
    Conversation convo,
    LlmMessage system,
    int? reported,
  ) async {
    final asker = askCompact;
    if (asker == null || _cancelled) return false;
    final allowed = await asker();
    if (!allowed || _cancelled) return false;
    if (reported != null) _roomConsent = reported;
    await _compactTranscript(convo, system, force: true);
    return !_cancelled;
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
  Future<LlmCompletion> _complete(
    LlmRequest request,
    Conversation convo,
  ) async {
    var text = '';
    var calls = const <LlmToolCall>[];
    var finish = 'stop';
    LlmUsage? usage;
    await for (final event in provider.complete(request)) {
      if (_cancelled) break;
      switch (event) {
        case final LlmTextDelta delta:
          text += delta.text;
          convo.appendAssistantDelta(delta.text);
          onDelta?.call(delta.text);
        case final LlmReasoningDelta delta:
          convo.appendReasoningDelta(delta.text);
          onDelta?.call(delta.text);
        case final LlmToolCalls tools:
          calls = tools.calls;
        case LlmFinished(:final finishReason, usage: final seen):
          finish = finishReason;
          if (seen != null) {
            usage = seen;
            _lastPromptTokens = seen.promptTokens;
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
          _lastPromptTokens = fallback.usage!.promptTokens;
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
      if (call.name == askToolId) {
        final question = '${call.arguments['question'] ?? ''}'.trim();
        return question.isEmpty || call.arguments['options'] == null;
      }
      if (call.name == execToolId) {
        return parseExecSource(call.arguments) == null;
      }
      if (call.name != fancadToolName && call.name != extensionsToolName)
        continue;
      final request = OpsRequest.tryParse(call.arguments);
      if (request == null) return true;
      if (request.action != OpsAction.run) continue;
      if (!request.hasPath) return true;
      final command = catalog.commandFor(registry, request.path);
      if (command != null) {
        for (final param in command.params) {
          if (!param.required) continue;
          final value = request.args[param.name];
          if (value == null) return true;
          if (value is String && value.trim().isEmpty) return true;
        }
        continue;
      }
      final host = _hostOperation(request.path);
      if (host == null) continue;
      for (final param in host.params) {
        if (!param.required) continue;
        final value = request.args[param.name];
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) return true;
      }
    }
    return false;
  }

  List<HostTool> _hostTools() {
    final tools = <HostTool>[...hostTools];
    final supplier = supplyToSession;
    if (supplier != null) tools.add(sessionSupplyTool(supplier));
    return tools;
  }

  Operation? _hostOperation(String path) {
    final provider = HostOperationProvider(_hostTools());
    for (final operation in provider.operations()) {
      if (operation.id == path) return operation;
    }
    return null;
  }

  OperationCatalog _opsCatalog() => OperationCatalog()
    ..addProvider(
      CommandOperationProvider(
        registry: registry,
        execute: execute,
        include: (command) => !isExtensionCliCommand(command.id),
      ),
    )
    ..addProvider(HostOperationProvider(_hostTools()));

  OperationCatalog _scriptCatalog() => OperationCatalog()
    ..addProvider(
      CommandOperationProvider(
        registry: registry,
        execute: execute,
        include: (command) => isExtensionCliCommand(command.id),
      ),
    );

  Future<void> _runCalls(List<LlmToolCall> calls, Conversation convo) async {
    final drawing = OpsDispatcher(_opsCatalog());
    final scripts = OpsDispatcher(_scriptCatalog());
    final images = <ToolImage>[];
    var answeredAll = true;
    for (final call in calls) {
      if (_cancelled) {
        answeredAll = false;
        break;
      }
      if (call.name == askToolId) {
        await _runAsk(call, convo);
        continue;
      }
      if (call.name == execToolId) {
        await _runExec(call, convo);
        continue;
      }
      if (call.name == fancadToolName || call.name == extensionsToolName) {
        final png = await _runCli(
          call,
          convo,
          call.name == extensionsToolName ? scripts : drawing,
          call.name,
        );
        if (png != null) {
          images.add(
            ToolImage(visibleIndex: convo.visible.length - 1, bytes: png),
          );
        }
        continue;
      }
      final allowed = [
        fancadToolName,
        extensionsToolName,
        if (askQuestion != null) askToolId,
        if (execCode != null) execToolId,
      ].join(' or ');
      final message = 'Unknown tool: ${call.name}. Use $allowed.';
      convo.addToolResult(
        call: call,
        content: jsonEncode({
          'status': 'failed',
          'error': message,
          'message': message,
        }),
        isError: true,
      );
    }
    await _attachToolImages(convo, images, forModel: answeredAll);
  }

  Future<void> _attachToolImages(
    Conversation convo,
    List<ToolImage> images, {
    required bool forModel,
  }) async {
    final handler = onToolImage;
    if (handler == null || images.isEmpty) return;
    await handler(convo, images, forModel);
  }

  Future<void> _runAsk(LlmToolCall call, Conversation convo) async {
    final asker = askQuestion;
    Map<String, Object?> payload;
    if (asker == null) {
      payload = {
        'status': 'failed',
        'error': 'ask is not available in this session.',
        'message': 'ask is not available in this session.',
      };
    } else {
      final question = parseSessionQuestion(call.arguments);
      if (question == null) {
        payload = {
          'status': 'failed',
          'error':
              'ask needs a question and 2–6 options '
              '({id, label} or strings).',
          'message':
              'ask needs a question and 2–6 options '
              '({id, label} or strings).',
        };
      } else {
        payload = await asker(question);
      }
    }
    convo.addToolResult(
      call: call,
      content: jsonEncode(payload),
      isError: payload['status'] == 'failed',
      toolName: askToolId,
    );
  }

  Future<void> _runExec(LlmToolCall call, Conversation convo) async {
    final executor = execCode;
    Map<String, Object?> payload;
    final source = parseExecSource(call.arguments);
    if (executor == null) {
      payload = {
        'status': 'failed',
        'error': 'exec is not available in this session.',
        'message': 'exec is not available in this session.',
      };
    } else if (source == null) {
      payload = {
        'status': 'failed',
        'error': 'exec needs source, the JavaScript to evaluate.',
        'message': 'exec needs source, the JavaScript to evaluate.',
      };
    } else {
      try {
        payload = await executor(source);
      } catch (error) {
        payload = {'status': 'failed', 'error': '$error', 'message': '$error'};
      }
    }
    if (payload['status'] == null) {
      payload = {
        'status': 'failed',
        'error': 'exec returned no status.',
        'message': 'exec returned no status.',
      };
    }
    final encoded = encodeExecPayload(payload);
    convo.addToolResult(
      call: call,
      content: encoded,
      visibleContent: source == null ? null : encodeExecCard(encoded, source),
      isError: payload['status'] == 'failed',
      toolName: execToolId,
    );
  }

  Future<Uint8List?> _runCli(
    LlmToolCall call,
    Conversation convo,
    OpsDispatcher dispatcher,
    String toolName,
  ) async {
    final request = OpsRequest.tryParse(call.arguments);
    if (request == null) {
      final message =
          '$toolName requires action=list|help|schema|run. '
          'Call help with no path to see groups.';
      final encoded = jsonEncode({
        'status': 'failed',
        'error': message,
        'message': message,
      });
      convo.addToolResult(
        call: call,
        content: encoded,
        visibleContent: encodeCliCard(encoded, call.arguments),
        isError: true,
        toolName: toolName,
      );
      return null;
    }

    Map<String, Object?> payload;
    try {
      payload = await dispatcher.dispatch(request);
    } catch (caught) {
      payload = {'status': 'failed', 'error': '$caught', 'message': '$caught'};
    }

    final image = takeCommandImage(payload);
    final encoded = jsonEncode(image.payload);
    convo.addToolResult(
      call: call,
      content: encoded,
      visibleContent: encodeCliCard(encoded, call.arguments),
      isError: image.payload['status'] == 'failed',
      toolName: request.displayName,
    );
    return image.bytes;
  }

  Future<void> _compactTranscript(
    Conversation convo,
    LlmMessage system, {
    bool force = false,
  }) async {
    final next = await compactLlmMessages(
      messages: convo.llmMessages,
      system: system,
      lastPromptTokens: _lastPromptTokens,
      window: contextWindowTokens,
      force: force,
      summarize: _summarizePrior,
    );
    if (next.length == convo.llmMessages.length) {
      var same = true;
      for (var i = 0; i < next.length; i++) {
        if (!identical(next[i], convo.llmMessages[i]) &&
            next[i].content != convo.llmMessages[i].content) {
          same = false;
          break;
        }
      }
      if (same) return;
    }
    convo.compactLlm(next);
  }

  Future<String?> _summarizePrior(String source) async {
    try {
      final result = await provider.completeOnce(
        LlmRequest(
          messages: [
            const LlmMessage.system(compactSummarySystemPrompt),
            LlmMessage.user(source),
          ],
          stream: false,
        ),
      );
      final text = result.text.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
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

/// JSON for an exec tool result. The model sees this payload.
/// A short [message] is filled in when the executor omitted one.
/// The source stays off it; the panel reads [value] from the visible card.
String encodeExecPayload(Map<String, Object?> payload) {
  final shaped = <String, Object?>{
    ...payload,
    if (payload['message'] == null && payload['status'] == 'ok')
      'message': execPreview(payload['value']),
  };
  try {
    return jsonEncode(shaped);
  } catch (_) {
    return jsonEncode({
      'status': '${shaped['status'] ?? 'ok'}',
      'message': execPreview(shaped['value']),
      'value': '${shaped['value']}',
    });
  }
}

/// Visible exec card. [source] is what the panel shows in full. The model
/// transcript keeps [encoded], which does not repeat the snippet.
String encodeExecCard(String encoded, String source) {
  Object? decoded;
  try {
    decoded = jsonDecode(encoded);
  } catch (_) {}
  if (decoded is Map) {
    return jsonEncode({
      for (final entry in decoded.entries) '${entry.key}': entry.value,
      'source': source,
    });
  }
  return jsonEncode({'status': 'ok', 'message': encoded, 'source': source});
}

/// Visible CLI card. [input] is the tool call the panel shows above the
/// result. The model transcript keeps [encoded], which does not repeat it.
String encodeCliCard(String encoded, Map<String, Object?> input) {
  Object? decoded;
  try {
    decoded = jsonDecode(encoded);
  } catch (_) {}
  if (decoded is Map) {
    return jsonEncode({
      for (final entry in decoded.entries) '${entry.key}': entry.value,
      'input': input,
    });
  }
  return jsonEncode({'status': 'ok', 'message': encoded, 'input': input});
}

/// One line of an exec value, stored as the model message.
/// The card shows the full value.
String execPreview(Object? value) {
  if (value == null) return 'undefined';
  String text;
  try {
    text = value is String ? value : jsonEncode(value);
  } catch (_) {
    text = '$value';
  }
  return text.length <= 120 ? text : '${text.substring(0, 117)}...';
}
