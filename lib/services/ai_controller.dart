import 'dart:async';
import 'dart:io';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter/foundation.dart';

import '../ai/authoring.dart';
import '../ai/skills/bundled.dart';
import '../models/assistant_chat.dart';
import '../models/assistant_profile.dart';
import '../storage/assistant_settings.dart';
import 'composer_pin.dart';
import 'document_tab.dart';
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
  SessionQuestion? _pendingQuestion;
  Completer<Map<String, Object?>>? _askDecision;
  final List<ComposerPin> _pins = [];

  bool get isBusy => _busy;
  String? get error => _error;
  String get draft => _chat.draft;
  Conversation get conversation => _chat.conversation;
  List<ChatMessage> get messages => conversation.visible;
  PendingChangeSet? get pendingApproval => _pending;
  SessionQuestion? get pendingQuestion => _pendingQuestion;
  List<ComposerPin> get pins => List.unmodifiable(_pins);
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

  /// Hits `{baseUrl}/models` with this card's key. Notifies success or failure.
  Future<void> testProfile(AssistantProfile profile) async {
    final provider = OpenAiCompatibleProvider.fromEnvironment(
      baseUrl: profile.baseUrl,
      model: profile.model,
      apiKey: profile.apiKey,
      apiKeyEnvVar: apiKeyRef,
      environment: Platform.environment,
    );
    if (provider == null) {
      workspace.notify(
        'No API key. Paste one in Settings, '
        'or point the endpoint at a local server.',
        isError: true,
      );
      return;
    }
    try {
      await provider.probe();
      workspace.notify('${profile.displayName} is reachable.');
    } on LlmException catch (error) {
      workspace.notify(error.message, isError: true);
    }
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
    _settleAsk(const {'status': 'cancelled'});
    if (_active == null) return;
    _stopping = true;
    _active!.cancel();
  }

  /// Lets the pending tool batch run.
  void acceptPending() => _settlePending(true);

  /// Refuses the pending tool batch. A click outside the pane must not
  /// reach this — that was the black-mask decline.
  void rejectPending() => _settlePending(false);

  void answerQuestion(SessionAskOption option) {
    submitQuestion([option], '');
  }

  void answerQuestionCustom(String text) {
    submitQuestion(const [], text);
  }

  void submitQuestion(List<SessionAskOption> selected, String custom) {
    final result = encodeAskAnswer(selected: selected, custom: custom);
    if (result == null) return;
    _settleAsk(result);
  }

  void cancelQuestion() => _settleAsk(const {'status': 'cancelled'});

  void flashEntities(List<int> ids, {String? tabId}) {
    if (ids.isEmpty) return;
    if (tabId != null && tabId.isNotEmpty) {
      final error = workspace.activateDrawing(tabId);
      if (error != null) return;
    }
    workspace.flashHighlights(ids);
  }

  void hoverEntities(List<int> ids, {String? tabId}) {
    if (tabId != null &&
        tabId.isNotEmpty &&
        workspace.activeDrawing?.session.id != tabId) {
      workspace.setHoverHighlights(const []);
      return;
    }
    workspace.setHoverHighlights(ids);
  }

  void flashPin(ComposerPin pin) {
    if (pin.kind == ComposerPinKind.drawing) {
      workspace.activateDrawing(pin.tabId);
      return;
    }
    flashEntities(pin.ids, tabId: pin.tabId);
  }

  void hoverPin(ComposerPin? pin) {
    hoverPins(pin == null ? const [] : [pin]);
  }

  void hoverPins(List<ComposerPin> pins) {
    final entityPins = [
      for (final pin in pins)
        if (pin.kind == ComposerPinKind.entity && pin.ids.isNotEmpty) pin,
    ];
    if (entityPins.isEmpty) {
      hoverEntities(const []);
      return;
    }
    hoverEntities([
      for (final pin in entityPins) ...pin.ids,
    ], tabId: entityPins.first.tabId);
  }

  ComposerPin resolvePin(ComposerPin pin) {
    if (pin.kind != ComposerPinKind.drawing) return pin;
    if (pin.tabTitle.trim().isNotEmpty) return pin;
    final tab = workspace.findDrawing(pin.tabId);
    if (tab == null) return pin;
    return ComposerPin.drawing(
      tabId: pin.tabId,
      tabTitle: tab.title,
      path: tab.filePath,
    );
  }

  void pinSelection() {
    final tab = workspace.activeDrawing;
    if (tab == null) return;
    _pinEntities(tab.selection.ids.toList(), tab: tab);
  }

  void pinClipboard() {
    final tab = workspace.activeDrawing;
    final clip = workspace.clipboard.clip;
    if (tab == null || clip == null || clip.isEmpty) return;
    final ids = entityIdsStillInDocument(
      tab.document,
      clip.entities.map((entity) => entity.id),
    );
    if (ids.isEmpty) {
      workspace.notify(
        'Those objects are no longer in the drawing. Select them and Pin.',
        isError: true,
      );
      return;
    }
    _pinEntities(ids, tab: tab);
  }

  void pinReceiptIds(List<int> ids) {
    final tab = workspace.activeDrawing;
    if (tab == null) return;
    _pinEntities(ids, tab: tab);
  }

  void pinDrawing(DocumentTab tab) {
    if (tab.isStartPage) return;
    final tabId = tab.session.id;
    _pins.add(
      ComposerPin.drawing(
        tabId: tabId,
        tabTitle: tab.title,
        path: tab.filePath,
      ),
    );
    notifyListeners();
  }

  void removePin(int index) {
    if (index < 0 || index >= _pins.length) return;
    _pins.removeAt(index);
    notifyListeners();
  }

  void _pinEntities(List<int> ids, {required DocumentTab tab}) {
    final document = tab.document;
    final live = entityIdsStillInDocument(document, ids);
    if (live.isEmpty) return;
    var total = live.length;
    for (final pin in _pins) {
      if (pin.kind == ComposerPinKind.entity) {
        total += pin.ids.length;
      }
    }
    if (total > composerPinIdCap) {
      workspace.notify(
        'Too many objects to pin. Shrink the selection.',
        isError: true,
      );
      return;
    }
    final kinds = <String, int>{};
    for (final id in live) {
      final entity = document.entity(id);
      if (entity == null) continue;
      kinds.update(entity.kind.name, (n) => n + 1, ifAbsent: () => 1);
    }
    _pins.add(
      ComposerPin.entities(
        live,
        tabId: tab.session.id,
        tabTitle: tab.title,
        path: tab.filePath,
        label: kinds.entries.map((e) => '${e.value} ${e.key}').join(', '),
      ),
    );
    notifyListeners();
  }

  List<ComposerPin> _livePins(List<ComposerPin> pins) {
    final live = <ComposerPin>[];
    for (final pin in pins) {
      if (pin.kind == ComposerPinKind.drawing) {
        final tab = workspace.findDrawing(pin.tabId);
        if (tab == null) continue;
        live.add(
          ComposerPin.drawing(
            tabId: tab.session.id,
            tabTitle: tab.title,
            path: tab.filePath,
          ),
        );
        continue;
      }
      final tab = workspace.findDrawing(pin.tabId);
      if (tab == null) continue;
      final ids = entityIdsStillInDocument(tab.document, pin.ids);
      if (ids.isEmpty) continue;
      live.add(
        ComposerPin.entities(
          ids,
          tabId: tab.session.id,
          tabTitle: tab.title,
          path: tab.filePath,
          label: pin.label,
        ),
      );
    }
    return live;
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Sends the draft, or [text] when supplied, and runs the agent loop.
  Future<void> send([String? text]) async {
    final typed = (text ?? draft).trim();
    if ((_pins.isEmpty && typed.isEmpty) || _busy) return;
    final provider = _provider();
    if (provider == null) {
      _error =
          'No API key. Paste one in Settings → Assistant, '
          'or point the assistant at a local endpoint.';
      notifyListeners();
      return;
    }
    final pinned = _livePins([..._pins]);
    if (pinned.isEmpty && typed.isEmpty) {
      if (_pins.isNotEmpty) {
        _pins.clear();
        notifyListeners();
      }
      return;
    }
    final tabIds = {
      for (final pin in pinned)
        if (pin.tabId.isNotEmpty) pin.tabId,
    };
    DocumentTab? target = workspace.activeDrawing;
    if (tabIds.length == 1) {
      target = workspace.findDrawing(tabIds.single) ?? target;
    }
    final session = target?.session ?? workspace.active?.session;
    if (session == null) {
      _error = 'Open a drawing first.';
      notifyListeners();
      return;
    }

    _pins.clear();
    final message = flattenComposerPins(pinned, typed);

    _patchChat((chat) {
      final titled = chat.title.trim().isEmpty
          ? titleFromUserMessage(message)
          : chat.title;
      return chat.copyWith(draft: '', title: titled, updatedAt: DateTime.now());
    });
    _busy = true;
    _error = null;
    workspace.setAssistantBusy(true);
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
      execute: (id, args, {tab}) => workspace.runHeadless(
        id,
        args: args,
        source: ChangeSource.ai,
        session: session,
        tab: tab,
      ),
      document: session.document,
      conversation: conversation,
      history: session.history,
      typings: typings,
      sessionOf: () => collectSessionSnapshot(workspace, drawing: target),
      skills: bundledSkillRegistry(),
      authoring: const PluginAuthoring(),
      policy: ApprovalPolicy(autoApproveEdits: autoApprove),
      askApproval: _askApproval,
      askQuestion: _askQuestion,
      supplyToSession: (args) async => workspace.supplyInteractive(args),
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
      workspace.setAssistantBusy(false);
      _settlePending(false);
      _settleAsk(const {'status': 'cancelled'});
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

  @visibleForTesting
  Future<Map<String, Object?>> debugAskQuestion(SessionQuestion question) =>
      _askQuestion(question);

  @visibleForTesting
  List<ComposerPin> debugLivePins() => _livePins([..._pins]);

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

  Future<Map<String, Object?>> _askQuestion(SessionQuestion question) async {
    _settleAsk(const {'status': 'cancelled'});
    _pendingQuestion = question;
    final decision = Completer<Map<String, Object?>>();
    _askDecision = decision;
    _notify();
    try {
      return await decision.future;
    } finally {
      if (identical(_pendingQuestion, question)) {
        _pendingQuestion = null;
        _askDecision = null;
        hoverEntities(const []);
        _notify();
      }
    }
  }

  void _settlePending(bool approved) {
    final decision = _pendingDecision;
    if (decision == null || decision.isCompleted) return;
    decision.complete(approved);
  }

  void _settleAsk(Map<String, Object?> result) {
    final decision = _askDecision;
    if (decision == null || decision.isCompleted) return;
    decision.complete(result);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settlePending(false);
    _settleAsk(const {'status': 'cancelled'});
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
