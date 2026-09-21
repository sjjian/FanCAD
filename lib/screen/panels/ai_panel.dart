import 'dart:async';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/assistant.dart';
import '../../services/assistant.dart';
import '../../services/workspace.dart';
import '../theme/tokens.dart';
import '../widgets/object_pin_chip.dart';
import '../workbench/shell_widgets.dart';
import 'assistant_markdown.dart';

/// The assistant chat pane.
///
/// Cursor-shaped: a transcript of user blocks, streamed markdown, tool
/// cards and in-thread approval cards, with the composer at the bottom.
/// Edits ask in the chat, not behind a window-wide dialog.

/// Inset from the assistant pane chrome so the thread markdown can breathe.
@visibleForTesting
const assistantPaneInset = FanCadTokens.space5;

/// Tighter inset for user leftovers and the composer so those bars sit
/// wider than the thread, Cursor-style.
@visibleForTesting
const assistantPromptInset = FanCadTokens.space3;

/// Fill for user leftovers and the composer. One step above the pane so the
/// bars read as chrome, not as more of the thread.
@visibleForTesting
Color assistantPromptFill(FanCadTokens tokens) {
  return tokens.isDark ? tokens.surfaceOverlay : tokens.surfaceRaised;
}

@visibleForTesting
const assistantTranscriptKey = Key('assistant-transcript');

@visibleForTesting
const assistantUserBlockKey = Key('assistant-user-block');

@visibleForTesting
const assistantTranscriptTailKey = Key('assistant-transcript-tail');

/// Empty space under the last leftover so the latest user prompt can sit at
/// the top of the thread, Cursor-style, instead of against the composer.
double assistantTranscriptTail(double viewportHeight) {
  if (viewportHeight <= 0) return FanCadTokens.space5;
  return viewportHeight;
}

class _AssistantTurn {
  const _AssistantTurn({this.user, required this.body});

  final ChatMessage? user;
  final List<AssistantLogEntryModel> body;
}

List<_AssistantTurn> _assistantTurns(List<AssistantLogEntryModel> entries) {
  final turns = <_AssistantTurn>[];
  ChatMessage? user;
  var body = <AssistantLogEntryModel>[];

  void flush() {
    if (user == null && body.isEmpty) return;
    turns.add(
      _AssistantTurn(user: user, body: List<AssistantLogEntryModel>.of(body)),
    );
    user = null;
    body = <AssistantLogEntryModel>[];
  }

  for (final entry in entries) {
    if (entry is AssistantLogMessageModel && entry.message.role == ChatRole.user) {
      flush();
      user = entry.message;
      continue;
    }
    body.add(entry);
  }
  flush();
  return turns;
}

class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({super.key, required this.controller});

  final AiController controller;

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _lastUserKey = GlobalKey();
  ChatMessage? _pinnedUser;
  late final _MentionTextController _input;

  @override
  void initState() {
    super.initState();
    _input = _MentionTextController(text: widget.controller.draft);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pinLastUserToTop();
    });
  }

  @override
  void didUpdateWidget(AiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _pinnedUser = null;
      _syncDraft();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ChatMessage? _lastUserMessage() {
    ChatMessage? last;
    for (final message in widget.controller.messages) {
      if (message.role == ChatRole.user) last = message;
    }
    return last;
  }

  void _pinLastUserToTop() {
    final last = _lastUserMessage();
    if (last == null || identical(last, _pinnedUser)) return;
    final ctx = _lastUserKey.currentContext;
    if (ctx == null || !_scroll.hasClients) return;
    Scrollable.ensureVisible(ctx, alignment: 0);
    _pinnedUser = last;
  }

  void _syncDraft() {
    if (_input.text == widget.controller.draft) return;
    _input.value = TextEditingValue(
      text: widget.controller.draft,
      selection: TextSelection.collapsed(
        offset: widget.controller.draft.length,
      ),
    );
  }

  void _copy(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    widget.controller.workspace.notify(context.l10n.copied_text(text));
  }

  void _send() {
    final text = _input.text;
    widget.controller.send(text);
  }

  Future<void> _onPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text?.trim().isNotEmpty == true) return;
    widget.controller.pinClipboard();
  }

  Widget _threadPad(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: assistantPaneInset),
      child: child,
    );
  }

  Widget _userHeader(ChatMessage message, {required bool isLast}) {
    final tokens = context.tokens;
    final controller = widget.controller;
    Widget header = ColoredBox(
      color: tokens.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          assistantPromptInset,
          FanCadTokens.space4,
          assistantPromptInset,
          FanCadTokens.space3,
        ),
        child: _UserBlock(
          key: isLast ? assistantUserBlockKey : null,
          text: message.text,
          onCopy: () => _copy(message.text),
          onFlashPin: controller.flashPin,
          onHoverPin: controller.hoverPin,
          resolvePin: controller.resolvePin,
        ),
      ),
    );
    if (isLast) {
      header = KeyedSubtree(key: _lastUserKey, child: header);
    }
    return header;
  }

  Widget _entryTile(
    AssistantLogEntryModel entry, {
    required bool live,
    required bool showWorking,
    required bool showCaret,
  }) {
    final controller = widget.controller;
    return switch (entry) {
      AssistantLogMessageModel(:final message) when message.role == ChatRole.user =>
        const SizedBox.shrink(),
      AssistantLogMessageModel(:final message)
          when message.role == ChatRole.reasoning =>
        _ThinkingBlock(
          text: message.text,
          live: live && showWorking == false,
          onCopy: () => _copy(message.text),
          onEntityId: controller.flashEntities,
          onHoverEntityId: controller.hoverEntities,
          onPin: controller.flashPin,
          onHoverPin: controller.hoverPin,
          resolvePin: controller.resolvePin,
        ),
      AssistantLogMessageModel(:final message)
          when message.role == ChatRole.assistant =>
        _AssistantBlock(
          text: message.text,
          live: live && showCaret,
          onCopy: () => _copy(message.text),
          onEntityId: controller.flashEntities,
          onHoverEntityId: controller.hoverEntities,
          onPin: controller.flashPin,
          onHoverPin: controller.hoverPin,
          resolvePin: controller.resolvePin,
        ),
      AssistantLogReceiptModel(:final receipt) => _ToolCard(
        receipt: receipt,
        onCopy: () => _copy(receipt.raw),
        onFlash: () =>
            controller.flashEntities(assistantReceiptEntityIds(receipt)),
        onPin: () =>
            controller.pinReceiptIds(assistantReceiptEntityIds(receipt)),
      ),
      AssistantLogMessageModel() => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      assistantNotifierProvider.select(
        (s) => (
          s.activeChatId,
          s.transcriptEpoch,
          s.busy,
          s.approval,
          s.question,
          s.pins,
          s.error,
          s.activeChat.draft,
        ),
      ),
    );
    _syncDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pinLastUserToTop();
    });
    final tokens = context.tokens;
    final controller = widget.controller;
    final messages = controller.messages;
    final entries = groupAssistantLog(messages);
    final busy = controller.isBusy;
    final pending = controller.pendingApproval;
    final question = controller.pendingQuestion;
    final showWorking =
        pending == null &&
        question == null &&
        assistantPanelShowsWorking(busy: busy, messages: messages);
    final showCaret = assistantPanelShowsCaret(busy: busy, messages: messages);
    final canSend =
        !busy &&
        controller.isConfigured &&
        (controller.draft.trim().isNotEmpty || controller.pins.isNotEmpty);
    _input.pins = controller.pins;
    _input.onFlashPin = controller.flashPin;
    _input.onHoverPin = controller.hoverPin;
    return Column(
      children: [
        _ChatTabStrip(
          chats: controller.chats,
          activeChatId: controller.activeChat.id,
          emptyTitle: context.l10n.new_chat,
          onSelect: controller.selectSession,
          onClose: controller.deleteSession,
          onNew: controller.newSession,
        ),
        Expanded(
          child:
              messages.isEmpty && !busy && pending == null && question == null
              ? _EmptyAssistant(
                  configured: controller.isConfigured,
                  onUsePrompt: (prompt) {
                    controller.setDraft(prompt);
                    _syncDraft();
                  },
                  onOpenSettings: () =>
                      controller.workspace.revealPanel('preferences:models'),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final turns = _assistantTurns(entries);
                    final extras = <Widget>[
                      if (showWorking)
                        _WorkingLine(label: context.l10n.working),
                      if (pending != null)
                        _ApprovalCard(
                          pending: pending,
                          onAccept: controller.acceptPending,
                          onReject: controller.rejectPending,
                          onFlash: () =>
                              controller.flashEntities(pending.highlightIds),
                          onPin: () =>
                              controller.pinReceiptIds(pending.highlightIds),
                        ),
                    ];
                    return CustomScrollView(
                      key: assistantTranscriptKey,
                      controller: _scroll,
                      slivers: [
                        for (var i = 0; i < turns.length; i++)
                          SliverMainAxisGroup(
                            slivers: [
                              if (turns[i].user != null)
                                PinnedHeaderSliver(
                                  child: _userHeader(
                                    turns[i].user!,
                                    isLast: i == turns.length - 1,
                                  ),
                                ),
                              SliverList.list(
                                children: [
                                  for (final entry in turns[i].body)
                                    _threadPad(
                                      _entryTile(
                                        entry,
                                        live:
                                            busy &&
                                            i == turns.length - 1 &&
                                            identical(
                                              entry,
                                              turns[i].body.last,
                                            ),
                                        showWorking: showWorking,
                                        showCaret: showCaret,
                                      ),
                                    ),
                                  if (i == turns.length - 1)
                                    for (final extra in extras)
                                      _threadPad(extra),
                                ],
                              ),
                            ],
                          ),
                        if (turns.isEmpty)
                          SliverList.list(
                            children: [
                              for (final extra in extras) _threadPad(extra),
                            ],
                          ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            key: assistantTranscriptTailKey,
                            height: assistantTranscriptTail(
                              constraints.maxHeight,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        if (controller.error != null)
          ShellBanner(
            tone: ShellTone.danger,
            inset: true,
            message: controller.error!,
            onDismiss: controller.clearError,
          ),
        _Composer(
          controller: _input,
          enabled: controller.isConfigured,
          canSend: canSend,
          busy: busy,
          hint: !controller.isConfigured
              ? context.l10n.ask_assistant_unavailable
              : busy
              ? context.l10n.ask_follow_up
              : context.l10n.ask_assistant,
          tokens: tokens,
          usage: controller.lastUsage,
          pins: controller.pins,
          workspace: controller.workspace,
          ask: question == null
              ? null
              : _AskCard(
                  question: question,
                  onSubmit: controller.submitQuestion,
                  onCancel: controller.cancelQuestion,
                  onFlashPin: controller.flashPin,
                  onHoverPin: controller.hoverPin,
                  onHoverPins: controller.hoverPins,
                  resolvePin: controller.resolvePin,
                ),
          onChanged: controller.setDraft,
          onSend: _send,
          onStop: controller.stop,
          onPaste: _onPaste,
          onPinSelection: controller.pinSelection,
          onPinDrawing: (id) {
            final tab = controller.workspace.findDrawing(id);
            if (tab != null) controller.pinDrawing(tab);
          },
          onRemovePin: controller.removePin,
          onOpenSettings: () =>
              controller.workspace.revealPanel('preferences:assistant'),
        ),
      ],
    );
  }
}

class _ChatTabStrip extends StatelessWidget {
  const _ChatTabStrip({
    required this.chats,
    required this.activeChatId,
    required this.emptyTitle,
    required this.onSelect,
    required this.onClose,
    required this.onNew,
  });

  final List<AssistantChatModel> chats;
  final String activeChatId;
  final String emptyTitle;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      key: const Key('assistant-session-tabs'),
      height: FanCadTokens.tabBarHeight,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.borderMuted)),
      ),
      child: Row(
        children: [
          Flexible(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return _ChatSessionTab(
                  chat: chat,
                  title: chat.displayTitle(emptyTitle),
                  isActive: chat.id == activeChatId,
                  onTap: () => onSelect(chat.id),
                  onClose: () => onClose(chat.id),
                );
              },
            ),
          ),
          ShellIconButton(
            key: const Key('assistant-new-session'),
            icon: Icons.add,
            tooltip: context.l10n.new_chat,
            iconSize: FanCadTokens.iconSmall,
            onPressed: onNew,
          ),
          const SizedBox(width: FanCadTokens.space1),
        ],
      ),
    );
  }
}

class _ChatSessionTab extends StatefulWidget {
  const _ChatSessionTab({
    required this.chat,
    required this.title,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  final AssistantChatModel chat;
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_ChatSessionTab> createState() => _ChatSessionTabState();
}

class _ChatSessionTabState extends State<_ChatSessionTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ShellTab(
      key: Key('assistant-session-${widget.chat.id}'),
      selected: widget.isActive,
      onTap: widget.onTap,
      onClose: widget.onClose,
      onHoverChanged: (hovered) => setState(() => _hovered = hovered),
      constraints: const BoxConstraints(minWidth: 72, maxWidth: 160),
      padding: const EdgeInsets.only(
        left: FanCadTokens.space2,
        right: FanCadTokens.space1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: tokens.bodyStyle.copyWith(
                fontSize: 12,
                color: widget.isActive ? tokens.text : tokens.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_hovered || widget.isActive)
            ShellIconButton(
              key: Key('assistant-session-close-${widget.chat.id}'),
              icon: Icons.close,
              size: 18,
              iconSize: FanCadTokens.iconSmall,
              tooltip: context.l10n.close,
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }
}

class _EmptyAssistant extends StatelessWidget {
  const _EmptyAssistant({
    required this.configured,
    required this.onUsePrompt,
    required this.onOpenSettings,
  });

  final bool configured;
  final ValueChanged<String> onUsePrompt;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final prompts = [
      l10n.prompt_object_count,
      l10n.prompt_square,
      l10n.prompt_list_selection,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = (constraints.maxHeight - assistantPaneInset * 2)
            .clamp(0.0, double.infinity);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(assistantPaneInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  key: const Key('assistant-empty-guide'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      configured
                          ? l10n.assistant_empty_configured
                          : l10n.assistant_empty_unconfigured,
                      style: tokens.bodyStyle.copyWith(height: 1.45),
                      textAlign: TextAlign.center,
                    ),
                    if (!configured) ...[
                      const SizedBox(height: FanCadTokens.space4),
                      Center(
                        child: FilledButton(
                          onPressed: onOpenSettings,
                          child: Text(l10n.open_settings),
                        ),
                      ),
                    ],
                    if (configured) ...[
                      const SizedBox(height: FanCadTokens.space4),
                      Text(
                        l10n.try_section,
                        style: tokens.sectionTitleStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: FanCadTokens.space2),
                      for (final prompt in prompts)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: FanCadTokens.space2,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tokens.surfaceRaised,
                              borderRadius: BorderRadius.circular(
                                FanCadTokens.radius,
                              ),
                            ),
                            child: ShellRow(
                              onTap: () => onUsePrompt(prompt),
                              height: 36,
                              padding: const EdgeInsets.symmetric(
                                horizontal: FanCadTokens.space3,
                              ),
                              child: Text(prompt, style: tokens.bodyStyle),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserBlock extends StatefulWidget {
  const _UserBlock({
    super.key,
    required this.text,
    required this.onCopy,
    this.onFlashPin,
    this.onHoverPin,
    this.resolvePin,
  });

  final String text;
  final VoidCallback onCopy;
  final ValueChanged<ComposerPinModel>? onFlashPin;
  final ValueChanged<ComposerPinModel?>? onHoverPin;
  final ComposerPinModel Function(ComposerPinModel pin)? resolvePin;

  @override
  State<_UserBlock> createState() => _UserBlockState();
}

class _UserBlockState extends State<_UserBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: context.l10n.click_to_copy,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _open = !_open),
          onSecondaryTap: widget.onCopy,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space3,
              vertical: FanCadTokens.space3,
            ),
            decoration: BoxDecoration(
              color: assistantPromptFill(tokens),
              borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
              border: Border.all(color: tokens.borderStrong),
            ),
            child: PinAwareText(
              text: widget.text,
              maxLines: _open ? null : 2,
              overflow: _open ? null : TextOverflow.ellipsis,
              style: tokens.bodyStyle.copyWith(height: 1.45),
              onFlash: widget.onFlashPin,
              onHover: widget.onHoverPin,
              resolve: widget.resolvePin,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingBlock extends StatefulWidget {
  const _ThinkingBlock({
    required this.text,
    required this.onCopy,
    this.live = false,
    this.onEntityId,
    this.onHoverEntityId,
    this.onPin,
    this.onHoverPin,
    this.resolvePin,
  });

  final String text;
  final VoidCallback onCopy;
  final bool live;
  final ValueChanged<List<int>>? onEntityId;
  final ValueChanged<List<int>>? onHoverEntityId;
  final ValueChanged<ComposerPinModel>? onPin;
  final ValueChanged<ComposerPinModel?>? onHoverPin;
  final ComposerPinModel Function(ComposerPinModel pin)? resolvePin;

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  late bool _open;
  final Stopwatch _elapsed = Stopwatch();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _open = false;
    if (widget.live) _armClock();
  }

  @override
  void didUpdateWidget(_ThinkingBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live && !widget.live) {
      _elapsed.stop();
      _tick?.cancel();
      _tick = null;
    } else if (!oldWidget.live && widget.live) {
      _armClock();
    }
  }

  void _armClock() {
    _elapsed.start();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _title(AppLocalizations l10n) {
    final seconds = _elapsed.elapsed.inSeconds;
    if (seconds <= 0) return l10n.thinking;
    return l10n.thinking_for(seconds);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: FanCadTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: const Key('assistant-thinking-card'),
              onTap: () => setState(() => _open = !_open),
              onSecondaryTap: widget.onCopy,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title(context.l10n),
                    style: tokens.bodyStyle.copyWith(color: tokens.textMuted),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: FanCadTokens.iconSmall,
                    color: tokens.textMuted,
                  ),
                  if (widget.live) ...[
                    const SizedBox(width: FanCadTokens.space2),
                    const _StreamingCaret(),
                  ],
                ],
              ),
            ),
          ),
          if (_open) ...[
            const SizedBox(height: FanCadTokens.space2),
            AssistantMarkdown(
              text: widget.text,
              onEntityId: widget.onEntityId == null
                  ? null
                  : (id) => widget.onEntityId!([id]),
              onHoverEntityId: widget.onHoverEntityId == null
                  ? null
                  : (id) =>
                        widget.onHoverEntityId!(id == null ? const [] : [id]),
              onPin: widget.onPin,
              onHoverPin: widget.onHoverPin,
              resolvePin: widget.resolvePin,
            ),
          ],
        ],
      ),
    );
  }
}

class _AssistantBlock extends StatelessWidget {
  const _AssistantBlock({
    required this.text,
    required this.onCopy,
    this.onEntityId,
    this.onHoverEntityId,
    this.onPin,
    this.onHoverPin,
    this.resolvePin,
    this.live = false,
  });

  final String text;
  final VoidCallback onCopy;
  final ValueChanged<List<int>>? onEntityId;
  final ValueChanged<List<int>>? onHoverEntityId;
  final ValueChanged<ComposerPinModel>? onPin;
  final ValueChanged<ComposerPinModel?>? onHoverPin;
  final ComposerPinModel Function(ComposerPinModel pin)? resolvePin;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FanCadTokens.space4),
      child: GestureDetector(
        onSecondaryTap: onCopy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (text.isNotEmpty)
              AssistantMarkdown(
                text: text,
                onEntityId: onEntityId == null
                    ? null
                    : (id) => onEntityId!([id]),
                onHoverEntityId: onHoverEntityId == null
                    ? null
                    : (id) => onHoverEntityId!(id == null ? const [] : [id]),
                onPin: onPin,
                onHoverPin: onHoverPin,
                resolvePin: resolvePin,
              ),
            if (live) const _StreamingCaret(),
          ],
        ),
      ),
    );
  }
}

class _WorkingLine extends StatelessWidget {
  const _WorkingLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: FanCadTokens.space3),
      child: Row(
        children: [
          const _StreamingCaret(),
          const SizedBox(width: FanCadTokens.space2),
          Text(label, style: tokens.labelStyle.copyWith(color: tokens.accent)),
        ],
      ),
    );
  }
}

class _StreamingCaret extends StatefulWidget {
  const _StreamingCaret();

  @override
  State<_StreamingCaret> createState() => _StreamingCaretState();
}

class _StreamingCaretState extends State<_StreamingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return FadeTransition(
      opacity: _pulse,
      child: Container(
        width: 7,
        height: 13,
        decoration: BoxDecoration(
          color: tokens.accent,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _ToolCard extends StatefulWidget {
  const _ToolCard({
    required this.receipt,
    required this.onCopy,
    required this.onFlash,
    required this.onPin,
  });

  final AssistantReceiptModel receipt;
  final VoidCallback onCopy;
  final VoidCallback onFlash;
  final VoidCallback onPin;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final receipt = widget.receipt;
    final dot = receipt.isError
        ? tokens.danger
        : receipt.isOk
        ? tokens.success
        : tokens.warning;
    final verb = receipt.count > 1
        ? '${receipt.verb} ×${receipt.count}'
        : receipt.verb;
    return Padding(
      padding: const EdgeInsets.only(bottom: FanCadTokens.space2),
      child: Material(
        color: tokens.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
          side: BorderSide(color: tokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                widget.onFlash();
                setState(() => _open = !_open);
              },
              onSecondaryTap: widget.onCopy,
              borderRadius: BorderRadius.circular(FanCadTokens.radius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FanCadTokens.space3,
                  vertical: FanCadTokens.space2,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: FanCadTokens.space2),
                    Text(
                      verb,
                      style: tokens.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: receipt.isError ? tokens.danger : tokens.text,
                      ),
                    ),
                    if (receipt.summary.isNotEmpty) ...[
                      const SizedBox(width: FanCadTokens.space2),
                      Expanded(
                        child: Text(
                          receipt.summary,
                          style: tokens.labelStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    ShellIconButton(
                      key: const Key('assistant-receipt-pin'),
                      icon: Icons.add_comment_outlined,
                      tooltip: context.l10n.pin_into_chat,
                      iconSize: FanCadTokens.iconSmall,
                      onPressed: widget.onPin,
                    ),
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: FanCadTokens.iconSmall,
                      color: tokens.textFaint,
                    ),
                  ],
                ),
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FanCadTokens.space3,
                  0,
                  FanCadTokens.space3,
                  FanCadTokens.space3,
                ),
                child: SelectableText(
                  receipt.raw,
                  style: tokens.monoStyle.copyWith(
                    fontSize: 11,
                    height: 1.4,
                    color: tokens.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.pending,
    required this.onAccept,
    required this.onReject,
    required this.onFlash,
    required this.onPin,
  });

  final PendingChangeSet pending;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onFlash;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final title = pending.calls.length == 1
        ? l10n.allow_one_change(
            pending.commands.isNotEmpty
                ? pending.commands.first.title
                : pending.calls.first.name,
          )
        : l10n.allow_n_changes(pending.calls.length);
    return Padding(
      padding: const EdgeInsets.only(bottom: FanCadTokens.space2),
      child: Material(
        key: const Key('assistant-approval-card'),
        color: tokens.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
          side: BorderSide(color: tokens.accent.withValues(alpha: 0.55)),
        ),
        child: GestureDetector(
          onTap: onFlash,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FanCadTokens.space3,
              FanCadTokens.space2,
              FanCadTokens.space3,
              FanCadTokens.space2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: FanCadTokens.space2),
                    Expanded(
                      child: Text(
                        title,
                        style: tokens.bodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ShellIconButton(
                      key: const Key('assistant-approval-pin'),
                      icon: Icons.add_comment_outlined,
                      tooltip: l10n.pin_into_chat,
                      iconSize: FanCadTokens.iconSmall,
                      onPressed: onPin,
                    ),
                  ],
                ),
                const SizedBox(height: FanCadTokens.space2),
                for (final line in pending.groupedTitles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(line, style: tokens.labelStyle),
                  ),
                if (pending.highlightIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.affects_n_objects(pending.highlightIds.length),
                      style: tokens.labelStyle.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ),
                const SizedBox(height: FanCadTokens.space2),
                Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      key: const Key('assistant-approval-cancel'),
                      onPressed: onReject,
                      child: Text(l10n.cancel, style: tokens.bodyStyle),
                    ),
                    const SizedBox(width: FanCadTokens.space1),
                    FilledButton(
                      key: const Key('assistant-approval-continue'),
                      onPressed: onAccept,
                      child: Text(l10n.continue_action),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AskCard extends StatefulWidget {
  const _AskCard({
    required this.question,
    required this.onSubmit,
    required this.onCancel,
    this.onFlashPin,
    this.onHoverPin,
    this.onHoverPins,
    this.resolvePin,
  });

  final SessionQuestion question;
  final void Function(List<SessionAskOption> selected, String custom) onSubmit;
  final VoidCallback onCancel;
  final ValueChanged<ComposerPinModel>? onFlashPin;
  final ValueChanged<ComposerPinModel?>? onHoverPin;
  final ValueChanged<List<ComposerPinModel>>? onHoverPins;
  final ComposerPinModel Function(ComposerPinModel pin)? resolvePin;

  @override
  State<_AskCard> createState() => _AskCardState();
}

class _AskCardState extends State<_AskCard> {
  final TextEditingController _custom = TextEditingController();
  final FocusNode _customFocus = FocusNode();
  final Set<String> _picked = {};

  bool get _multiple => widget.question.multiple;

  String get _customLetter => askOptionLetter(widget.question.options.length);

  @override
  void initState() {
    super.initState();
    _customFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _customFocus.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _toggle(SessionAskOption option) {
    setState(() {
      if (_multiple) {
        if (!_picked.add(option.id)) _picked.remove(option.id);
        return;
      }
      _picked
        ..clear()
        ..add(option.id);
      _custom.clear();
    });
  }

  void _focusCustom() {
    setState(() {
      if (!_multiple) _picked.clear();
    });
    _customFocus.requestFocus();
  }

  void _submit() {
    if (!_canSubmit) return;
    final selected = [
      for (final option in widget.question.options)
        if (_picked.contains(option.id)) option,
    ];
    widget.onSubmit(selected, _custom.text);
  }

  bool get _canSubmit {
    if (_custom.text.trim().isNotEmpty) return true;
    return _picked.isNotEmpty;
  }

  bool get _customSelected =>
      _customFocus.hasFocus || _custom.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final question = widget.question;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
        const SingleActivator(LogicalKeyboardKey.enter): _submit,
      },
      child: Focus(
        autofocus: true,
        child: Material(
          key: const Key('assistant-ask-card'),
          color: tokens.surfaceOverlay,
          elevation: 3,
          shadowColor: tokens.shadow,
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
              border: Border.all(color: tokens.borderStrong),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FanCadTokens.space3,
                FanCadTokens.space3,
                FanCadTokens.space3,
                FanCadTokens.space2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: FanCadTokens.iconSmall,
                        color: tokens.textMuted,
                      ),
                      const SizedBox(width: FanCadTokens.space2),
                      Text(
                        l10n.ask_questions,
                        style: tokens.bodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FanCadTokens.space3),
                  PinAwareText(
                    text: '1. ${question.question}',
                    style: tokens.bodyStyle.copyWith(
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                    onFlash: widget.onFlashPin,
                    onHover: widget.onHoverPin,
                    resolve: widget.resolvePin,
                  ),
                  const SizedBox(height: FanCadTokens.space3),
                  for (var i = 0; i < question.options.length; i++)
                    _AskOptionRow(
                      option: question.options[i],
                      letter: askOptionLetter(i),
                      selected: _picked.contains(question.options[i].id),
                      onTap: () => _toggle(question.options[i]),
                      onFlashPin: widget.onFlashPin,
                      onHoverPins: widget.onHoverPins,
                      resolvePin: widget.resolvePin,
                    ),
                  if (question.allowCustom)
                    _AskCustomRow(
                      letter: _customLetter,
                      selected: _customSelected,
                      controller: _custom,
                      focusNode: _customFocus,
                      hint: l10n.ask_other,
                      onTap: _focusCustom,
                      onChanged: (_) => setState(() {
                        if (!_multiple && _custom.text.trim().isNotEmpty) {
                          _picked.clear();
                        }
                      }),
                      onSubmitted: (_) => _submit(),
                    ),
                  const SizedBox(height: FanCadTokens.space2),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        key: const Key('assistant-ask-cancel'),
                        onPressed: widget.onCancel,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: l10n.ask_skip,
                                style: tokens.bodyStyle,
                              ),
                              TextSpan(
                                text: ' Esc',
                                style: tokens.labelStyle.copyWith(
                                  color: tokens.textFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: FanCadTokens.space1),
                      FilledButton(
                        key: const Key('assistant-ask-submit'),
                        onPressed: _canSubmit ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _canSubmit
                              ? tokens.warning
                              : tokens.border,
                          foregroundColor: tokens.canvas,
                          disabledForegroundColor: tokens.textFaint,
                          padding: const EdgeInsets.symmetric(
                            horizontal: FanCadTokens.space3,
                            vertical: FanCadTokens.space1,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(l10n.continue_action),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AskOptionRow extends StatelessWidget {
  const _AskOptionRow({
    required this.option,
    required this.letter,
    required this.selected,
    required this.onTap,
    this.onFlashPin,
    this.onHoverPins,
    this.resolvePin,
  });

  final SessionAskOption option;
  final String letter;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<ComposerPinModel>? onFlashPin;
  final ValueChanged<List<ComposerPinModel>>? onHoverPins;
  final ComposerPinModel Function(ComposerPinModel pin)? resolvePin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverPins?.call(parseComposerPins(option.label)),
      onExit: (_) => onHoverPins?.call(const []),
      child: InkWell(
        key: Key('assistant-ask-${option.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FanCadTokens.space1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AskLetter(letter: letter, selected: selected),
              const SizedBox(width: FanCadTokens.space2),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: PinAwareText(
                    text: option.label,
                    style: tokens.bodyStyle.copyWith(height: 1.4),
                    onFlash: onFlashPin,
                    resolve: resolvePin,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AskCustomRow extends StatelessWidget {
  const _AskCustomRow({
    required this.letter,
    required this.selected,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onTap,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String letter;
  final bool selected;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FanCadTokens.space1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AskLetter(letter: letter, selected: selected),
            const SizedBox(width: FanCadTokens.space2),
            Expanded(
              child: TextField(
                key: const Key('assistant-ask-custom'),
                controller: controller,
                focusNode: focusNode,
                style: tokens.bodyStyle.copyWith(height: 1.4),
                cursorColor: tokens.accent,
                cursorWidth: 1.5,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  hintText: hint,
                  hintStyle: tokens.bodyStyle.copyWith(
                    color: tokens.textFaint,
                    height: 1.4,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 1),
                ),
                onTap: onTap,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AskLetter extends StatelessWidget {
  const _AskLetter({required this.letter, required this.selected});

  final String letter;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: selected ? tokens.warning : Colors.transparent,
        borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
        border: Border.all(color: selected ? tokens.warning : tokens.border),
      ),
      child: Text(
        letter,
        style: tokens.labelStyle.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
          color: selected ? tokens.canvas : tokens.textMuted,
        ),
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.canSend,
    required this.busy,
    required this.hint,
    required this.tokens,
    required this.usage,
    required this.pins,
    required this.workspace,
    required this.onChanged,
    required this.onSend,
    required this.onStop,
    required this.onPaste,
    required this.onPinSelection,
    required this.onPinDrawing,
    required this.onRemovePin,
    required this.onOpenSettings,
    this.ask,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool canSend;
  final bool busy;
  final String hint;
  final FanCadTokens tokens;
  final LlmUsage? usage;
  final List<ComposerPinModel> pins;
  final Workspace workspace;
  final Widget? ask;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onPaste;
  final VoidCallback onPinSelection;
  final ValueChanged<String> onPinDrawing;
  final ValueChanged<int> onRemovePin;
  final VoidCallback onOpenSettings;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  bool _escaped = false;
  bool _open = false;
  int _highlighted = 0;
  String _query = '';
  String _lastText = '';
  final OverlayPortalController _mentionOverlay = OverlayPortalController();
  final OverlayPortalController _askOverlay = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onText);
    _bindRemoveMention(widget.controller);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fillMissingMentionTokens();
    });
  }

  @override
  void didUpdateWidget(covariant _Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      _bindRemoveMention(oldWidget.controller, bind: false);
      widget.controller.addListener(_onText);
      _bindRemoveMention(widget.controller);
      _lastText = widget.controller.text;
    }
    if (oldWidget.pins.length != widget.pins.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fillMissingMentionTokens();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _bindRemoveMention(widget.controller, bind: false);
    super.dispose();
  }

  void _bindRemoveMention(
    TextEditingController controller, {
    bool bind = true,
  }) {
    if (controller is! _MentionTextController) return;
    controller.onRemoveMention = bind ? _removeMention : null;
  }

  void _removeMention(int index) {
    final controller = widget.controller;
    final indexes = composerMentionTokenIndexes(controller.text);
    if (index < 0 || index >= indexes.length) return;
    final at = indexes[index];
    final next = controller.text.replaceRange(at, at + 1, '');
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at),
    );
    _onComposerChanged(next);
  }

  void _onText() {
    final mention = composerAtMentionAt(
      widget.controller.text,
      widget.controller.selection.baseOffset,
    );
    if (mention == null) {
      if (_escaped || _open) {
        setState(() {
          _escaped = false;
          _open = false;
          _query = '';
          _highlighted = 0;
        });
      }
      return;
    }
    if (_escaped) return;
    if (_open && mention.query == _query) return;
    setState(() {
      _open = true;
      if (mention.query != _query) _highlighted = 0;
      _query = mention.query;
    });
  }

  ComposerAtMentionModel? get _mention {
    if (!_open || _escaped) return null;
    return composerAtMentionAt(
      widget.controller.text,
      widget.controller.selection.baseOffset,
    );
  }

  List<DocumentSession> get _matches {
    final mention = _mention;
    if (mention == null) return const [];
    return filterDrawingMentions([
      for (final id in widget.workspace.sessionIds)
        ?widget.workspace.session(id),
    ], mention.query);
  }

  bool get _pickerOpen => _mention != null && widget.ask == null;

  void _insertAt() {
    if (!widget.enabled) return;
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    final from = start < end ? start : end;
    final to = start < end ? end : start;
    final mention = composerAtMentionAt(text, to);
    if (mention != null) {
      setState(() {
        _escaped = false;
        _open = true;
        _query = mention.query;
        _highlighted = 0;
      });
      return;
    }
    final prefix = from > 0 && text[from - 1].trim().isNotEmpty ? ' @' : '@';
    final next = text.replaceRange(from, to, prefix);
    final cursor = from + prefix.length;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor),
    );
    widget.onChanged(next);
    _lastText = next;
  }

  void _onComposerChanged(String value) {
    widget.onChanged(value);
    final removed = deletedMentionIndexes(_lastText, value);
    _lastText = value;
    for (final index in removed.reversed) {
      widget.onRemovePin(index);
    }
  }

  void _fillMissingMentionTokens() {
    final missing =
        widget.pins.length - composerMentionTokenCount(widget.controller.text);
    if (missing <= 0) return;
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset.clamp(0, text.length);
    final inserted = composerMentionToken * missing;
    final next = text.replaceRange(cursor, cursor, inserted);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor + inserted.length),
    );
    _lastText = next;
    widget.onChanged(next);
  }

  void _pick(DocumentSession session) {
    final id = session.id;
    if (id.isEmpty) return;
    final controller = widget.controller;
    final mention = composerAtMentionAt(
      controller.text,
      controller.selection.baseOffset,
    );
    if (mention != null) {
      final next = controller.text.replaceRange(
        mention.start,
        mention.end,
        composerMentionToken,
      );
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: mention.start + 1),
      );
      _lastText = next;
      widget.onChanged(next);
    }
    _escaped = false;
    _open = false;
    _query = '';
    _highlighted = 0;
    _mentionOverlay.hide();
    widget.onPinDrawing(id);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final paste =
        event.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed);
    if (paste) {
      widget.onPaste();
      return KeyEventResult.ignored;
    }
    if (_pickerOpen) {
      final matches = _matches;
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _escaped = true);
        _mentionOverlay.hide();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (matches.isEmpty) return KeyEventResult.handled;
        setState(() => _highlighted = (_highlighted + 1) % matches.length);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (matches.isEmpty) return KeyEventResult.handled;
        setState(
          () => _highlighted =
              (_highlighted - 1 + matches.length) % matches.length,
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        if (matches.isNotEmpty) {
          final index = _highlighted.clamp(0, matches.length - 1);
          _pick(matches[index]);
        }
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (widget.canSend) widget.onSend();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final matches = _matches;
    final pickerOpen = _pickerOpen;
    final highlighted = matches.isEmpty
        ? 0
        : _highlighted.clamp(0, matches.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.ask != null) {
        _askOverlay.show();
      } else {
        _askOverlay.hide();
      }
      if (pickerOpen) {
        _mentionOverlay.show();
      } else {
        _mentionOverlay.hide();
      }
    });
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        assistantPromptInset,
        FanCadTokens.space2,
        assistantPromptInset,
        assistantPromptInset,
      ),
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _askOverlay,
        overlayChildBuilder: (context, info) {
          final ask = widget.ask;
          if (ask == null) return const SizedBox.shrink();
          final cardRect = MatrixUtils.transformRect(
            info.childPaintTransform,
            Offset.zero & info.childSize,
          );
          return Stack(
            children: [
              Positioned(
                left: cardRect.left,
                width: cardRect.width,
                bottom:
                    info.overlaySize.height -
                    cardRect.top +
                    FanCadTokens.space2,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (info.overlaySize.height * 0.5).clamp(
                      160.0,
                      420.0,
                    ),
                  ),
                  child: SingleChildScrollView(child: ask),
                ),
              ),
            ],
          );
        },
        child: OverlayPortal.overlayChildLayoutBuilder(
          controller: _mentionOverlay,
          overlayChildBuilder: (context, info) {
            final cardRect = MatrixUtils.transformRect(
              info.childPaintTransform,
              Offset.zero & info.childSize,
            );
            return Stack(
              children: [
                Positioned(
                  left: cardRect.left,
                  width: cardRect.width,
                  bottom:
                      info.overlaySize.height -
                      cardRect.top +
                      FanCadTokens.space2,
                  child: _DrawingMentionPopup(
                    matches: matches,
                    highlighted: highlighted,
                    onHighlight: (index) =>
                        setState(() => _highlighted = index),
                    onPick: _pick,
                  ),
                ),
              ],
            );
          },
          child: Container(
            key: const Key('assistant-composer-card'),
            padding: const EdgeInsets.fromLTRB(
              FanCadTokens.space2,
              FanCadTokens.space3,
              FanCadTokens.space2,
              FanCadTokens.space2,
            ),
            decoration: BoxDecoration(
              color: assistantPromptFill(tokens),
              borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
              border: Border.all(color: tokens.borderStrong),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Focus(
                  onKeyEvent: _onKey,
                  child: TextField(
                    controller: widget.controller,
                    enabled: widget.enabled,
                    minLines: 2,
                    maxLines: 5,
                    style: tokens.bodyStyle.copyWith(height: 1.45),
                    cursorColor: tokens.accent,
                    cursorWidth: 1.5,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintText: widget.hint,
                      hintStyle: tokens.bodyStyle.copyWith(
                        color: tokens.textFaint,
                      ),
                    ),
                    onChanged: _onComposerChanged,
                  ),
                ),
                const SizedBox(height: FanCadTokens.space2),
                Row(
                  children: [
                    ShellIconButton(
                      key: const Key('assistant-open-settings'),
                      icon: Icons.settings_outlined,
                      tooltip: context.l10n.open_settings,
                      size: 24,
                      onPressed: widget.onOpenSettings,
                    ),
                    const SizedBox(width: FanCadTokens.space1),
                    ShellIconButton(
                      key: const Key('assistant-mention-drawing'),
                      icon: Icons.alternate_email,
                      tooltip: context.l10n.mention_drawing,
                      size: 24,
                      onPressed: widget.enabled ? _insertAt : null,
                    ),
                    const SizedBox(width: FanCadTokens.space1),
                    ShellIconButton(
                      key: const Key('assistant-pin-selection'),
                      icon: Icons.tag,
                      tooltip:
                          '${context.l10n.pin_selection}  ${shellShortcut('U', shift: true)}',
                      size: 24,
                      onPressed: widget.enabled ? widget.onPinSelection : null,
                    ),
                    const Spacer(),
                    AssistantContextMeter(usage: widget.usage),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: FanCadTokens.space2,
                        right: FanCadTokens.space1,
                      ),
                      child: _SendStopButton(
                        busy: widget.busy,
                        canSend: widget.canSend,
                        onSend: widget.onSend,
                        onStop: widget.onStop,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawingMentionPopup extends StatelessWidget {
  const _DrawingMentionPopup({
    required this.matches,
    required this.highlighted,
    required this.onHighlight,
    required this.onPick,
  });

  final List<DocumentSession> matches;
  final int highlighted;
  final ValueChanged<int> onHighlight;
  final ValueChanged<DocumentSession> onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return Material(
      color: tokens.surfaceOverlay,
      elevation: 3,
      shadowColor: tokens.shadow,
      borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
      child: Container(
        key: const Key('assistant-mention-list'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          border: Border.all(color: tokens.borderStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (matches.isEmpty)
              ShellRow(
                key: const Key('assistant-mention-empty'),
                height: FanCadTokens.rowHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: FanCadTokens.space3,
                ),
                child: Text(
                  l10n.no_open_drawings,
                  style: tokens.bodyStyle.copyWith(
                    fontSize: 12,
                    color: tokens.textMuted,
                  ),
                ),
              )
            else
              for (var i = 0; i < matches.length; i++)
                _DrawingMentionRow(
                  drawing: matches[i],
                  isHighlighted: i == highlighted,
                  onHover: () => onHighlight(i),
                  onTap: () => onPick(matches[i]),
                ),
          ],
        ),
      ),
    );
  }
}

class _DrawingMentionRow extends StatelessWidget {
  const _DrawingMentionRow({
    required this.drawing,
    required this.isHighlighted,
    required this.onHover,
    required this.onTap,
  });

  final DocumentSession drawing;
  final bool isHighlighted;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final id = drawing.id;
    final title = drawing.title.isEmpty ? id : drawing.title;
    final path = (drawing.filePath ?? '').trim();
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: ShellRow(
        key: Key('assistant-mention-row-$id'),
        isSelected: isHighlighted,
        onTap: onTap,
        height: FanCadTokens.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: tokens.bodyStyle.copyWith(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (path.isNotEmpty) ...[
              const SizedBox(width: FanCadTokens.space3),
              Expanded(
                child: Text(
                  path,
                  style: tokens.labelStyle.copyWith(fontSize: 10.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MentionTextController extends TextEditingController {
  _MentionTextController({super.text});

  List<ComposerPinModel> pins = const [];
  ValueChanged<ComposerPinModel>? onFlashPin;
  ValueChanged<ComposerPinModel?>? onHoverPin;
  ValueChanged<int>? onRemoveMention;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (!text.contains(composerMentionToken)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final children = <InlineSpan>[];
    var pinIndex = 0;
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) != 0xFFFC) continue;
      if (i > start) {
        children.add(TextSpan(text: text.substring(start, i), style: style));
      }
      final pin = pinIndex < pins.length ? pins[pinIndex] : null;
      final index = pinIndex;
      pinIndex++;
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ObjectPinChip(
            key: ValueKey<int>(index),
            index: index,
            pin: pin,
            removable: true,
            onFlash: pin == null ? null : () => onFlashPin?.call(pin),
            onHover: (hovered) => onHoverPin?.call(hovered ? pin : null),
            onRemove: () => onRemoveMention?.call(index),
          ),
        ),
      );
      start = i + 1;
    }
    if (start < text.length) {
      children.add(TextSpan(text: text.substring(start), style: style));
    }
    return TextSpan(style: style, children: children);
  }
}

class _SendStopButton extends StatelessWidget {
  const _SendStopButton({
    required this.busy,
    required this.canSend,
    required this.onSend,
    required this.onStop,
  });

  final bool busy;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = busy || canSend;
    return Tooltip(
      message: busy ? context.l10n.stop : context.l10n.send_enter,
      child: Material(
        key: Key(busy ? 'assistant-composer-stop' : 'assistant-composer-send'),
        color: enabled ? tokens.text : tokens.border,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? onStop : (canSend ? onSend : null),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Icon(
              busy ? Icons.stop : Icons.arrow_upward,
              size: FanCadTokens.iconMedium,
              color: enabled ? tokens.surface : tokens.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Composer ring for leftover token usage. Empty until the first `usage`.
class AssistantContextMeter extends StatelessWidget {
  const AssistantContextMeter({super.key, this.usage});

  final LlmUsage? usage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final used = usage?.promptTokens ?? 0;
    final fraction = usage == null
        ? 0.0
        : (used / LlmUsage.contextWindowTokens).clamp(0.0, 1.0);
    final tooltip = usage == null
        ? context.l10n.context_waiting
        : context.l10n.context_used(
            formatAssistantTokens(used),
            formatAssistantTokens(LlmUsage.contextWindowTokens),
          );
    return Tooltip(
      message: tooltip,
      child: Transform.translate(
        offset: const Offset(0, 1),
        child: SizedBox(
          key: const Key('assistant-composer-context'),
          width: 24,
          height: 24,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: CustomPaint(
              painter: _ContextRingPainter(
                fraction: fraction,
                track: tokens.borderStrong,
                fill: tokens.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextRingPainter extends CustomPainter {
  const _ContextRingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 1.5;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    if (fraction <= 0) return;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5707963267948966,
      6.283185307179586 * fraction,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ContextRingPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.track != track ||
        oldDelegate.fill != fill;
  }
}
