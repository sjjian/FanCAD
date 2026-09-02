import 'package:fancad_ai/fancad_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/assistant_chat.dart';
import '../../models/assistant_profile.dart';
import '../../services/ai_controller.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import '../workbench/shell_widgets.dart';
import 'assistant_markdown.dart';
import 'assistant_receipt.dart';

/// The assistant chat pane.
///
/// Cursor-shaped: a transcript of user blocks, streamed markdown, tool
/// cards and in-thread approval cards, with the composer at the bottom.
/// Edits ask in the chat, not behind a window-wide dialog.

/// Empty space under the last leftover so the thread does not sit on the composer.
double assistantTranscriptTail(double viewportHeight) {
  if (viewportHeight <= 0) return FanCadTokens.space5;
  return (viewportHeight * 0.4).clamp(96.0, 320.0);
}

class AiPanel extends StatefulWidget {
  const AiPanel({super.key, required this.controller});

  final AiController controller;

  @override
  State<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<AiPanel> {
  final ScrollController _scroll = ScrollController();
  late final TextEditingController _input;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.controller.draft);
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(AiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
      _syncDraft();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    _syncDraft();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.maxScrollExtent - position.pixels < 80) {
        _scroll.jumpTo(position.maxScrollExtent);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final controller = widget.controller;
    final messages = controller.messages;
    final entries = groupAssistantLog(messages);
    final busy = controller.isBusy;
    final pending = controller.pendingApproval;
    final showWorking =
        pending == null &&
        assistantPanelShowsWorking(busy: busy, messages: messages);
    final showCaret = assistantPanelShowsCaret(busy: busy, messages: messages);
    final canSend =
        !busy && controller.isConfigured && controller.draft.trim().isNotEmpty;
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
          child: messages.isEmpty && !busy && pending == null
              ? _EmptyAssistant(
                  configured: controller.isConfigured,
                  onUsePrompt: (prompt) {
                    controller.setDraft(prompt);
                    _syncDraft();
                  },
                  onOpenSettings: () =>
                      controller.workspace.revealPanel('preferences:assistant'),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(
                        FanCadTokens.space3,
                        FanCadTokens.space3,
                        FanCadTokens.space3,
                        assistantTranscriptTail(constraints.maxHeight),
                      ),
                      itemCount:
                          entries.length +
                          (showWorking ? 1 : 0) +
                          (pending != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < entries.length) {
                          final entry = entries[index];
                          final live = busy && index == entries.length - 1;
                          return switch (entry) {
                            AssistantLogMessage(:final message)
                                when message.role == ChatRole.user =>
                              _UserBlock(
                                text: message.text,
                                onCopy: () => _copy(message.text),
                              ),
                            AssistantLogMessage(:final message)
                                when message.role == ChatRole.reasoning =>
                              _ThinkingBlock(
                                text: message.text,
                                live: live && showWorking == false,
                                onCopy: () => _copy(message.text),
                              ),
                            AssistantLogMessage(:final message)
                                when message.role == ChatRole.assistant =>
                              _AssistantBlock(
                                text: message.text,
                                live: live && showCaret,
                                onCopy: () => _copy(message.text),
                              ),
                            AssistantLogReceipt(:final receipt) => _ToolCard(
                              receipt: receipt,
                              onCopy: () => _copy(receipt.raw),
                            ),
                            AssistantLogMessage() => const SizedBox.shrink(),
                          };
                        }
                        if (showWorking && index == entries.length) {
                          return _WorkingLine(label: context.l10n.working);
                        }
                        return _ApprovalCard(
                          pending: pending!,
                          onAccept: controller.acceptPending,
                          onReject: controller.rejectPending,
                        );
                      },
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
          hint: busy ? context.l10n.ask_follow_up : context.l10n.ask_assistant,
          tokens: tokens,
          profile: controller.activeProfile,
          profiles: controller.profiles,
          usage: controller.lastUsage,
          onChanged: controller.setDraft,
          onSend: _send,
          onStop: controller.stop,
          onSelectProfile: controller.selectProfile,
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

  final List<AssistantChat> chats;
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

  final AssistantChat chat;
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
    return ListView(
      padding: const EdgeInsets.all(FanCadTokens.space4),
      children: [
        Text(
          configured
              ? l10n.assistant_empty_configured
              : l10n.assistant_empty_unconfigured,
          style: tokens.bodyStyle.copyWith(height: 1.45),
        ),
        if (!configured) ...[
          const SizedBox(height: FanCadTokens.space4),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onOpenSettings,
              child: Text(l10n.open_settings),
            ),
          ),
        ],
        if (configured) ...[
          const SizedBox(height: FanCadTokens.space4),
          Text(l10n.try_section, style: tokens.sectionTitleStyle),
          const SizedBox(height: FanCadTokens.space2),
          for (final prompt in prompts)
            Padding(
              padding: const EdgeInsets.only(bottom: FanCadTokens.space2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.surfaceRaised,
                  borderRadius: BorderRadius.circular(FanCadTokens.radius),
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
    );
  }
}

class _UserBlock extends StatelessWidget {
  const _UserBlock({required this.text, required this.onCopy});

  final String text;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: FanCadTokens.space4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Tooltip(
          message: context.l10n.click_to_copy,
          waitDuration: const Duration(milliseconds: 600),
          child: GestureDetector(
            onSecondaryTap: onCopy,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FanCadTokens.space3,
                  vertical: FanCadTokens.space2,
                ),
                decoration: BoxDecoration(
                  color: tokens.selection,
                  borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
                ),
                child: Text(
                  text,
                  style: tokens.bodyStyle.copyWith(height: 1.45),
                ),
              ),
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
  });

  final String text;
  final VoidCallback onCopy;
  final bool live;

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      key: const Key('assistant-thinking-card'),
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
              onTap: () => setState(() => _open = !_open),
              onSecondaryTap: widget.onCopy,
              borderRadius: BorderRadius.circular(FanCadTokens.radius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FanCadTokens.space3,
                  vertical: FanCadTokens.space2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: FanCadTokens.iconSmall,
                      color: tokens.textMuted,
                    ),
                    const SizedBox(width: FanCadTokens.space2),
                    Expanded(
                      child: Text(
                        context.l10n.thinking,
                        style: tokens.bodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tokens.textMuted,
                        ),
                      ),
                    ),
                    if (widget.live) const _StreamingCaret(),
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
                  widget.text,
                  style: tokens.bodyStyle.copyWith(
                    height: 1.45,
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

class _AssistantBlock extends StatelessWidget {
  const _AssistantBlock({
    required this.text,
    required this.onCopy,
    this.live = false,
  });

  final String text;
  final VoidCallback onCopy;
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
            if (text.isNotEmpty) AssistantMarkdown(text: text),
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
  const _ToolCard({required this.receipt, required this.onCopy});

  final AssistantReceipt receipt;
  final VoidCallback onCopy;

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
              onTap: () => setState(() => _open = !_open),
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
  });

  final PendingChangeSet pending;
  final VoidCallback onAccept;
  final VoidCallback onReject;

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
                    style: tokens.labelStyle.copyWith(color: tokens.textMuted),
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
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.canSend,
    required this.busy,
    required this.hint,
    required this.tokens,
    required this.profile,
    required this.profiles,
    required this.usage,
    required this.onChanged,
    required this.onSend,
    required this.onStop,
    required this.onSelectProfile,
    required this.onOpenSettings,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool canSend;
  final bool busy;
  final String hint;
  final FanCadTokens tokens;
  final AssistantProfile profile;
  final List<AssistantProfile> profiles;
  final LlmUsage? usage;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onOpenSettings;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (canSend) onSend();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FanCadTokens.space3,
        FanCadTokens.space2,
        FanCadTokens.space3,
        FanCadTokens.space3,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          FanCadTokens.space3,
          FanCadTokens.space3,
          FanCadTokens.space3,
          FanCadTokens.space2,
        ),
        decoration: BoxDecoration(
          color: tokens.surfaceRaised,
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          border: Border.all(color: tokens.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Focus(
              onKeyEvent: _onKey,
              child: TextField(
                controller: controller,
                enabled: enabled,
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
                  hintText: hint,
                  hintStyle: tokens.bodyStyle.copyWith(color: tokens.textFaint),
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(height: FanCadTokens.space2),
            Row(
              children: [
                _ProfilePicker(
                  profile: profile,
                  profiles: profiles,
                  enabled: enabled && !busy,
                  onSelect: onSelectProfile,
                ),
                ShellIconButton(
                  key: const Key('assistant-open-settings'),
                  icon: Icons.settings_outlined,
                  tooltip: context.l10n.click_to_change_model,
                  iconSize: FanCadTokens.iconSmall,
                  onPressed: onOpenSettings,
                ),
                const Spacer(),
                AssistantContextMeter(usage: usage),
                const SizedBox(width: FanCadTokens.space2),
                _SendStopButton(
                  busy: busy,
                  canSend: canSend,
                  onSend: onSend,
                  onStop: onStop,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePicker extends StatelessWidget {
  const _ProfilePicker({
    required this.profile,
    required this.profiles,
    required this.enabled,
    required this.onSelect,
  });

  final AssistantProfile profile;
  final List<AssistantProfile> profiles;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ShellMenuButton<String>(
      key: const Key('assistant-composer-model'),
      tooltip: context.l10n.click_to_change_model,
      enabled: enabled,
      placement: ShellMenuPlacement.up,
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final item in profiles)
          shellMenuItem(
            context,
            key: Key('assistant-profile-${item.id}'),
            value: item.id,
            label: item.displayName,
            checked: item.id == profile.id,
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FanCadTokens.space1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                profile.displayName,
                style: tokens.monoStyle.copyWith(
                  fontSize: 11,
                  color: enabled ? tokens.textMuted : tokens.textFaint,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_more,
              size: FanCadTokens.iconSmall,
              color: enabled ? tokens.textMuted : tokens.textFaint,
            ),
          ],
        ),
      ),
    );
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
        color: enabled ? tokens.text : tokens.surfaceOverlay,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? onStop : (canSend ? onSend : null),
          child: SizedBox(
            width: 26,
            height: 26,
            child: Icon(
              busy ? Icons.stop : Icons.arrow_upward,
              size: 14,
              color: enabled ? tokens.surface : tokens.textFaint,
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
      child: SizedBox(
        key: const Key('assistant-composer-context'),
        width: 18,
        height: 18,
        child: CustomPaint(
          painter: _ContextRingPainter(
            fraction: fraction,
            track: tokens.borderStrong,
            fill: tokens.accent,
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
