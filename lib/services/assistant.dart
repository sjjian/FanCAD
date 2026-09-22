import 'dart:async';
import 'dart:io';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../ai/authoring.dart';
import '../ai/skills/bundled.dart';
import '../models/assistant.dart';
import '../storage/assistant_settings.dart';
import 'plugin.dart';
import 'providers.dart';
import 'settings.dart';
import 'workspace.dart';

part 'assistant.g.dart';

/// Owns the assistant session for the application.
///
/// Created even when no key is configured so the panel can explain how to
/// set one up. Streamed tokens mutate [Conversation] in place, so
/// [AssistantModel.transcriptEpoch] bumps on each delta and the panel can
/// rebuild without the rest of the window knowing an agent exists.
@Riverpod(keepAlive: true)
class AssistantNotifier extends _$AssistantNotifier {
  @override
  AssistantModel build() {
    final assistant = ref.read(appSettingsProvider).assistant;
    final chats = assistant.loadChats();
    ref.onDispose(() {
      _disposed = true;
      _settlePending(false);
      _settleAsk(const {'status': 'cancelled'});
      _active?.cancel();
    });
    return AssistantModel(
      chats: chats,
      activeChatId: assistant.activeChatId(chats),
      pane: AssistantPaneModel(
        isOpen: assistant.paneOpen(),
        width: assistant
            .paneWidth(fallback: AssistantPaneLayout.defaultWidth)
            .clamp(AssistantPaneLayout.minWidth, AssistantPaneLayout.maxWidth),
      ),
    );
  }

  void setAssistantOpen(bool value) {
    state = state.copyWith(pane: state.pane.copyWith(isOpen: value));
    _assistant.setPaneOpen(value);
  }

  void toggleAssistant() => setAssistantOpen(!state.pane.isOpen);

  void resizeAssistant(double width) {
    state = state.copyWith(
      pane: state.pane.copyWith(
        width: width.roundToDouble().clamp(
          AssistantPaneLayout.minWidth,
          AssistantPaneLayout.maxWidth,
        ),
      ),
    );
  }

  void commitAssistantWidth() => _assistant.setPaneWidth(state.pane.width);

  void resetAssistantWidth() {
    state = state.copyWith(
      pane: state.pane.copyWith(width: AssistantPaneLayout.defaultWidth),
    );
    commitAssistantWidth();
  }

  Workspace get workspace => ref.read(workspaceNotifierProvider.notifier);
  AssistantSettings get _assistant => ref.read(appSettingsProvider).assistant;
  PluginHost? get host => ref.read(pluginNotifierProvider.notifier).host;

  AssistantModel get _store => state;

  bool _stopping = false;
  bool _disposed = false;
  AgentLoop? _active;
  Completer<bool>? _pendingDecision;
  Completer<Map<String, Object?>>? _askDecision;

  AssistantChatModel get _chat => state.activeChat;

  bool get isConfigured => _provider() != null;

  void setDraft(String value) {
    if (value == _chat.draft) return;
    _patchChat((chat) => chat.copyWith(draft: value));
  }

  void clear() {
    _active?.cancel();
    _settlePending(false);
    _chat.conversation.clear();
    _patchChat((chat) => chat.copyWith(title: '', usage: null));
    _setStore(_store.copyWith(error: null));
    _persistChats();
  }

  /// Starts an empty thread. A leftover empty current chat is not duplicated.
  void newSession() {
    _active?.cancel();
    _settlePending(false);
    if (_chat.isEmpty) {
      _setStore(_store.copyWith(error: null));
      return;
    }
    final created = AssistantChatModel(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
    );
    final chats = [..._store.chats];
    final index = chats.indexWhere((chat) => chat.id == _store.activeChatId);
    chats.insert(index < 0 ? chats.length : index + 1, created);
    _setStore(
      _store.copyWith(chats: chats, activeChatId: created.id, error: null),
    );
    _persistChats();
  }

  void selectSession(String id) {
    if (id == _store.activeChatId) return;
    if (!_store.chats.any((chat) => chat.id == id)) return;
    _active?.cancel();
    _settlePending(false);
    _setStore(_store.copyWith(activeChatId: id, error: null));
    _persistChats();
  }

  void deleteSession([String? id]) {
    final target = id ?? _store.activeChatId;
    _active?.cancel();
    _settlePending(false);
    if (_store.chats.length <= 1) {
      _chat.conversation.clear();
      _patchChat((chat) => chat.copyWith(title: '', usage: null, draft: ''));
      _setStore(_store.copyWith(error: null));
      _persistChats();
      return;
    }
    final chats = [
      for (final chat in _store.chats)
        if (chat.id != target) chat,
    ];
    final activeId = chats.any((chat) => chat.id == _store.activeChatId)
        ? _store.activeChatId
        : chats.first.id;
    _setStore(
      _store.copyWith(chats: chats, activeChatId: activeId, error: null),
    );
    _persistChats();
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

  void flashPin(ComposerPinModel pin) {
    if (pin.kind == ComposerPinKind.drawing) {
      workspace.activateDrawing(pin.tabId);
      return;
    }
    flashEntities(pin.ids, tabId: pin.tabId);
  }

  void hoverPin(ComposerPinModel? pin) {
    hoverPins(pin == null ? const [] : [pin]);
  }

  void hoverPins(List<ComposerPinModel> pins) {
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

  ComposerPinModel resolvePin(ComposerPinModel pin) {
    if (pin.kind != ComposerPinKind.drawing) return pin;
    if (pin.tabTitle.trim().isNotEmpty) return pin;
    final tab = workspace.findDrawing(pin.tabId);
    if (tab == null) return pin;
    return ComposerPinModel.drawing(
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
    _setStore(
      _store.copyWith(
        pins: [
          ..._store.pins,
          ComposerPinModel.drawing(
            tabId: tabId,
            tabTitle: tab.title,
            path: tab.filePath,
          ),
        ],
      ),
    );
  }

  void removePin(int index) {
    if (index < 0 || index >= _store.pins.length) return;
    _setStore(
      _store.copyWith(
        pins: [
          for (var i = 0; i < _store.pins.length; i++)
            if (i != index) _store.pins[i],
        ],
      ),
    );
  }

  void _pinEntities(List<int> ids, {required DocumentTab tab}) {
    final document = tab.document;
    final live = entityIdsStillInDocument(document, ids);
    if (live.isEmpty) return;
    var total = live.length;
    for (final pin in _store.pins) {
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
    _setStore(
      _store.copyWith(
        pins: [
          ..._store.pins,
          ComposerPinModel.entities(
            live,
            tabId: tab.session.id,
            tabTitle: tab.title,
            path: tab.filePath,
            label: kinds.entries.map((e) => '${e.value} ${e.key}').join(', '),
          ),
        ],
      ),
    );
  }

  List<ComposerPinModel> _livePins(List<ComposerPinModel> pins) {
    final live = <ComposerPinModel>[];
    for (final pin in pins) {
      if (pin.kind == ComposerPinKind.drawing) {
        final tab = workspace.findDrawing(pin.tabId);
        if (tab == null) continue;
        live.add(
          ComposerPinModel.drawing(
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
        ComposerPinModel.entities(
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
    if (_store.error == null) return;
    _setStore(_store.copyWith(error: null));
  }

  /// Sends the draft, or [text] when supplied, and runs the agent loop.
  Future<void> send([String? text]) async {
    final typed = (text ?? _chat.draft).trim();
    if ((_store.pins.isEmpty && typed.isEmpty) || state.busy) return;
    final provider = _provider();
    if (provider == null) {
      _setStore(
        _store.copyWith(
          error:
              'No API key. Paste one in Settings → Assistant, '
              'or point the assistant at a local endpoint.',
        ),
      );
      return;
    }
    final pinned = _livePins([..._store.pins]);
    if (pinned.isEmpty && typed.isEmpty) {
      if (_store.pins.isNotEmpty) {
        _setStore(_store.copyWith(pins: const []));
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
      _setStore(_store.copyWith(error: 'Open a drawing first.'));
      return;
    }

    _setStore(_store.copyWith(pins: const [], error: null, busy: true));
    final message = flattenComposerPins(pinned, typed);

    _patchChat((chat) {
      final titled = chat.title.trim().isEmpty
          ? titleFromUserMessage(message)
          : chat.title;
      return chat.copyWith(draft: '', title: titled, updatedAt: DateTime.now());
    });
    workspace.setAssistantBusy(true);

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
      conversation: _chat.conversation,
      history: session.history,
      typings: typings,
      sessionOf: () => collectSessionSnapshot(workspace, drawing: target),
      skills: bundledSkillRegistry(),
      authoring: const PluginAuthoring(),
      policy: ApprovalPolicy(
        autoApproveEdits: ref
            .read(assistantAccountsNotifierProvider)
            .autoApprove,
      ),
      askApproval: _askApproval,
      askQuestion: _askQuestion,
      supplyToSession: (args) async => workspace.supplyInteractive(args),
      onDelta: (_) => _bumpTranscript(),
      onUsage: (usage) {
        _patchChat((chat) => chat.copyWith(usage: usage));
      },
    );
    _active = agent;

    try {
      final turn = await agent.run(message);
      if (_stopping) {
        workspace.notify('Assistant stopped.');
      } else if (turn.error != null) {
        _replaceStore(_store.copyWith(error: turn.error));
      }
    } catch (error) {
      _replaceStore(_store.copyWith(error: '$error'));
    } finally {
      if (identical(_active, agent)) _active = null;
      _stopping = false;
      workspace.setAssistantBusy(false);
      _settlePending(false);
      _settleAsk(const {'status': 'cancelled'});
      _persistChats();
      _setStore(_store.copyWith(busy: false));
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
  List<ComposerPinModel> debugLivePins() => _livePins([..._store.pins]);

  Future<bool> _askApproval(PendingChangeSet pending) async {
    _settlePending(false);
    _replaceStore(_store.copyWith(approval: pending));
    final decision = Completer<bool>();
    _pendingDecision = decision;
    workspace.setPendingHighlights(pending.highlightIds);
    try {
      return await decision.future;
    } finally {
      if (identical(_store.approval, pending)) {
        _setStore(_store.copyWith(approval: null));
        _pendingDecision = null;
        workspace.setPendingHighlights(const []);
      }
    }
  }

  Future<Map<String, Object?>> _askQuestion(SessionQuestion question) async {
    _settleAsk(const {'status': 'cancelled'});
    _replaceStore(_store.copyWith(question: question));
    final decision = Completer<Map<String, Object?>>();
    _askDecision = decision;
    try {
      return await decision.future;
    } finally {
      if (identical(_store.question, question)) {
        _setStore(_store.copyWith(question: null));
        _askDecision = null;
        hoverEntities(const []);
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

  LlmProvider? _provider() {
    final accounts = ref.read(assistantAccountsNotifierProvider);
    return OpenAiCompatibleProvider.fromEnvironment(
      baseUrl: accounts.activeProfile.baseUrl,
      model: accounts.activeProfile.model,
      apiKey: accounts.activeProfile.apiKey,
      apiKeyEnvVar: accounts.apiKeyRef,
      environment: Platform.environment,
    );
  }

  void _setStore(AssistantModel next) {
    if (_disposed) return;
    state = next;
  }

  void _replaceStore(AssistantModel next) => _setStore(next);

  void _bumpTranscript() {
    if (_disposed) return;
    state = state.copyWith(transcriptEpoch: state.transcriptEpoch + 1);
  }

  @visibleForTesting
  void debugSetBusy(bool value) {
    _setStore(_store.copyWith(busy: value));
    workspace.setAssistantBusy(value);
  }

  @visibleForTesting
  void debugSetUsage(LlmUsage? usage) {
    _patchChat((chat) => chat.copyWith(usage: usage));
  }

  void _patchChat(AssistantChatModel Function(AssistantChatModel chat) update) {
    final current = _chat;
    final next = update(current);
    if (identical(next, current)) return;
    _setStore(
      _store.copyWith(
        chats: [
          for (final chat in _store.chats)
            if (chat.id == current.id) next else chat,
        ],
      ),
    );
  }

  void _persistChats() {
    final chats = [..._store.chats];
    while (chats.length > AssistantSettings.chatCap) {
      AssistantChatModel? oldest;
      for (final chat in chats) {
        if (chat.id == _store.activeChatId) continue;
        if (oldest == null || chat.updatedAt.isBefore(oldest.updatedAt)) {
          oldest = chat;
        }
      }
      if (oldest == null) break;
      chats.remove(oldest);
    }
    if (chats.length != _store.chats.length) {
      _setStore(_store.copyWith(chats: chats));
    }
    _assistant.saveChats(_store.chats, activeId: _store.activeChatId);
  }
}
