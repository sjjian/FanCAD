import 'dart:async';
import 'dart:io';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter/foundation.dart';

import '../business/ai/authoring.dart';
import '../business/ai/skills/bundled.dart';
import '../models/assistant_chat.dart';
import '../models/assistant_profile.dart';
import '../storage/assistant_settings.dart';
import 'session_snapshot.dart';
import 'workspace.dart';

/// Owns the assistant session for the application.
///
/// The controller is a [ChangeNotifier] so the panel can rebuild on every
/// streamed token without the rest of the shell knowing an agent exists.
class AiController extends ChangeNotifier {
  AiController({required this.workspace, required this.assistant, this.host})
    : _chats = assistant.loadChats() {
    _activeChatId = assistant.activeChatId(_chats);
  }

  final Workspace workspace;
  final AssistantSettings assistant;
  final PluginHost? host;

  final List<AssistantChat> _chats;
  late String _activeChatId;

  bool _busy = false;
  bool _stopping = false;
  bool _disposed = false;
  String? _error;
  AgentLoop? _active;
  PendingChangeSet? _pending;
  Completer<bool>? _pendingDecision;

  bool get isBusy => _busy;
  String? get error => _error;
  String get draft => _chat.draft;
  Conversation get conversation => _chat.conversation;
  List<ChatMessage> get messages => conversation.visible;
  PendingChangeSet? get pendingApproval => _pending;
  LlmUsage? get lastUsage => _chat.usage;
  List<AssistantChat> get chats => List.unmodifiable(_chats);
  AssistantChat get activeChat => _chat;

  AssistantChat get _chat => _chats.firstWhere(
    (chat) => chat.id == _activeChatId,
    orElse: () => _chats.first,
  );

  bool get isConfigured => _provider() != null;

  List<AssistantProfile> get profiles => assistant.loadProfiles();

  AssistantProfile get activeProfile => assistant.activeProfile;

  String get model => activeProfile.model;

  String get baseUrl => activeProfile.baseUrl;

  String get apiKey => activeProfile.apiKey;

  String get apiKeyRef => assistant.apiKeyRef;

  void setDraft(String value) {
    if (value == _chat.draft) return;
    _patchChat((chat) => chat.copyWith(draft: value));
    notifyListeners();
  }

  void setModel(String value) {
    final next = value.trim();
    if (next.isEmpty || next == model) return;
    _writeActive((profile) => profile.copyWith(model: next));
  }

  void setBaseUrl(String value) {
    final next = value.trim();
    if (next.isEmpty || next == baseUrl) return;
    _writeActive((profile) => profile.copyWith(baseUrl: next));
  }

  void setAutoApprove(bool value) {
    if (value == autoApprove) return;
    assistant.setAutoApprove(value);
    notifyListeners();
  }

  void setApiKey(String value) {
    final next = value.trim();
    if (next == apiKey) return;
    _writeActive((profile) => profile.copyWith(apiKey: next));
  }

  void setApiKeyRef(String value) {
    final next = value.trim();
    if (next.isEmpty || next == apiKeyRef) return;
    assistant.setApiKeyRef(next);
    notifyListeners();
  }

  void setProfileLabel(String value) {
    if (value == activeProfile.label) return;
    _writeActive((profile) => profile.copyWith(label: value));
  }

  void selectProfile(String id) {
    if (_busy) return;
    if (id == activeProfile.id) return;
    final all = profiles;
    if (!all.any((profile) => profile.id == id)) return;
    _persist(all, activeId: id);
  }

  void addProfile() {
    if (_busy) return;
    final created = AssistantProfile(
      id: 'p${DateTime.now().microsecondsSinceEpoch}',
      model: model,
      baseUrl: baseUrl,
    );
    _persist([...profiles, created], activeId: created.id);
  }

  void removeProfile(String id) {
    if (_busy) return;
    final all = [...profiles]..removeWhere((profile) => profile.id == id);
    if (all.isEmpty) return;
    final nextId = id == activeProfile.id ? all.first.id : activeProfile.id;
    _persist(all, activeId: nextId);
  }

  bool get autoApprove => assistant.autoApprove;

  void clear() {
    _active?.cancel();
    _settlePending(false);
    conversation.clear();
    _patchChat((chat) => chat.copyWith(title: '', usage: null));
    _error = null;
    _persistChats();
    _notify();
  }

  /// Starts an empty thread. A leftover empty current chat is not duplicated.
  void newSession() {
    _active?.cancel();
    _settlePending(false);
    if (_chat.isEmpty) {
      _error = null;
      _notify();
      return;
    }
    final created = AssistantChat(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
    );
    final index = _chats.indexWhere((chat) => chat.id == _activeChatId);
    _chats.insert(index < 0 ? _chats.length : index + 1, created);
    _activeChatId = created.id;
    _error = null;
    _persistChats();
    _notify();
  }

  void selectSession(String id) {
    if (id == _activeChatId) return;
    if (!_chats.any((chat) => chat.id == id)) return;
    _active?.cancel();
    _settlePending(false);
    _activeChatId = id;
    _error = null;
    _persistChats();
    _notify();
  }

  void deleteSession([String? id]) {
    final target = id ?? _activeChatId;
    _active?.cancel();
    _settlePending(false);
    if (_chats.length <= 1) {
      conversation.clear();
      _patchChat((chat) => chat.copyWith(title: '', usage: null, draft: ''));
      _error = null;
      _persistChats();
      _notify();
      return;
    }
    _chats.removeWhere((chat) => chat.id == target);
    if (!_chats.any((chat) => chat.id == _activeChatId)) {
      _activeChatId = _chats.first.id;
    }
    _error = null;
    _persistChats();
    _notify();
  }

  /// Stops the in-flight turn after the current model reply or tool call.
  void stop() {
    _settlePending(false);
    if (_active == null) return;
    _stopping = true;
    _active!.cancel();
  }

  /// Lets the pending tool batch run.
  void acceptPending() => _settlePending(true);

  /// Refuses the pending tool batch. A click outside the pane must not
  /// reach this — that was the black-mask decline.
  void rejectPending() => _settlePending(false);

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Sends the draft, or [text] when supplied, and runs the agent loop.
  Future<void> send([String? text]) async {
    final message = (text ?? draft).trim();
    if (message.isEmpty || _busy) return;
    final provider = _provider();
    if (provider == null) {
      _error =
          'No API key. Paste one in Settings → Assistant, '
          'or point the assistant at a local endpoint.';
      notifyListeners();
      return;
    }
    final session = workspace.active?.session;
    if (session == null) {
      _error = 'Open a drawing first.';
      notifyListeners();
      return;
    }

    _patchChat((chat) {
      final titled = chat.title.trim().isEmpty
          ? titleFromUserMessage(message)
          : chat.title;
      return chat.copyWith(
        draft: '',
        title: titled,
        updatedAt: DateTime.now(),
      );
    });
    _busy = true;
    _error = null;
    notifyListeners();

    final typings = host == null
        ? null
        : buildTypeDeclarations(
            commands: workspace.commands.all,
            hostVersion: host!.hostVersion,
          );

    final agent = AgentLoop(
      provider: provider,
      registry: workspace.commands,
      execute: (id, args) => workspace.runHeadless(
        id,
        args: args,
        source: ChangeSource.ai,
        session: session,
      ),
      document: session.document,
      conversation: conversation,
      history: session.history,
      typings: typings,
      session: collectSessionSnapshot(workspace),
      skills: bundledSkillRegistry(),
      authoring: const PluginAuthoring(),
      policy: ApprovalPolicy(autoApproveEdits: autoApprove),
      askApproval: _askApproval,
      onDelta: (_) => notifyListeners(),
      onUsage: (usage) {
        _patchChat((chat) => chat.copyWith(usage: usage));
        notifyListeners();
      },
    );
    _active = agent;

    try {
      final turn = await agent.run(message);
      if (_stopping) {
        workspace.notify('Assistant stopped.');
      } else if (turn.error != null) {
        _error = turn.error;
      }
    } catch (error) {
      _error = '$error';
    } finally {
      if (identical(_active, agent)) _active = null;
      _busy = false;
      _stopping = false;
      _settlePending(false);
      _persistChats();
      _notify();
    }
  }

  /// Presents [pending] in the chat pane and waits for Continue or Cancel.
  ///
  /// A leftover modal barrier used to sit on the window; a click there
  /// declined every pending draw. The pane card has no barrier.
  @visibleForTesting
  Future<bool> debugAskApproval(PendingChangeSet pending) =>
      _askApproval(pending);

  Future<bool> _askApproval(PendingChangeSet pending) async {
    _settlePending(false);
    _pending = pending;
    final decision = Completer<bool>();
    _pendingDecision = decision;
    workspace.setPendingHighlights(pending.highlightIds);
    _notify();
    try {
      return await decision.future;
    } finally {
      if (identical(_pending, pending)) {
        _pending = null;
        _pendingDecision = null;
        workspace.setPendingHighlights(const []);
        _notify();
      }
    }
  }

  void _settlePending(bool approved) {
    final decision = _pendingDecision;
    if (decision == null || decision.isCompleted) return;
    decision.complete(approved);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settlePending(false);
    _active?.cancel();
    super.dispose();
  }

  LlmProvider? _provider() {
    return OpenAiCompatibleProvider.fromEnvironment(
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      apiKeyEnvVar: apiKeyRef,
      environment: Platform.environment,
    );
  }

  void _writeActive(AssistantProfile Function(AssistantProfile) update) {
    final all = [...profiles];
    final index = all.indexWhere((profile) => profile.id == activeProfile.id);
    final at = index < 0 ? 0 : index;
    all[at] = update(all[at]);
    _persist(all, activeId: all[at].id);
  }

  void _persist(List<AssistantProfile> all, {required String activeId}) {
    assistant.saveProfiles(all, activeId: activeId);
    notifyListeners();
  }

  @visibleForTesting
  void debugSetBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetUsage(LlmUsage? usage) {
    _patchChat((chat) => chat.copyWith(usage: usage));
    notifyListeners();
  }

  void _patchChat(AssistantChat Function(AssistantChat chat) update) {
    final current = _chat;
    final next = update(current);
    if (identical(next, current)) return;
    final index = _chats.indexWhere((chat) => chat.id == current.id);
    if (index < 0) return;
    _chats[index] = next;
  }

  void _persistChats() {
    while (_chats.length > AssistantSettings.chatCap) {
      AssistantChat? oldest;
      for (final chat in _chats) {
        if (chat.id == _activeChatId) continue;
        if (oldest == null || chat.updatedAt.isBefore(oldest.updatedAt)) {
          oldest = chat;
        }
      }
      if (oldest == null) break;
      _chats.remove(oldest);
    }
    assistant.saveChats(_chats, activeId: _activeChatId);
  }
}
