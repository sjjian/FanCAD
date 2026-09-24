import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/command_line.dart';
import '../../services/command_line.dart';
import '../../services/workspace.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';
import 'dynamic_input_hud.dart';

/// Ranked command matches shown above the canvas HUD while a verb is typed.
///
/// Listens to the command field's [TextEditingController]. The search runs
/// once on the next frame.
class CommandSuggest extends ConsumerStatefulWidget {
  const CommandSuggest({
    super.key,
    required this.input,
    required this.workspace,
    required this.onAccept,
  });

  final TextEditingController input;
  final Workspace workspace;
  final ValueChanged<CommandDescriptor> onAccept;

  /// Enough rows to scan, short enough that the drawing stays visible.
  static const int limit = 8;

  @override
  ConsumerState<CommandSuggest> createState() => CommandSuggestState();
}

class CommandSuggestState extends ConsumerState<CommandSuggest> {
  List<CommandDescriptor> _matches = const [];
  int _highlighted = 0;
  bool _scheduled = false;

  bool get isOpen => _matches.isNotEmpty;
  CommandDescriptor? get current => isOpen ? _matches[_highlighted] : null;

  @override
  void initState() {
    super.initState();
    widget.input.addListener(_schedule);
  }

  @override
  void didUpdateWidget(CommandSuggest oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input != widget.input) {
      oldWidget.input.removeListener(_schedule);
      widget.input.addListener(_schedule);
    }
  }

  @override
  void dispose() {
    widget.input.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    if (widget.input.text.trim().isEmpty) {
      _clear();
      return;
    }
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _search();
    });
  }

  void _clear() {
    if (_matches.isEmpty) return;
    setState(() {
      _matches = const [];
      _highlighted = 0;
    });
  }

  void _search() {
    final awaiting = ref.read(commandLineNotifierProvider).prompt != null;
    final query = widget.input.text;
    if (awaiting || query.trim().isEmpty) {
      if (_matches.isEmpty) return;
      setState(() {
        _matches = const [];
        _highlighted = 0;
      });
      return;
    }
    final matches = searchCommandsLocalized(
      widget.workspace.commands,
      query,
      context.l10n,
      limit: CommandSuggest.limit,
    );
    setState(() {
      _matches = matches;
      _highlighted = 0;
    });
  }

  void move(int delta) {
    if (_matches.isEmpty) return;
    setState(() {
      _highlighted = (_highlighted + delta).clamp(0, _matches.length - 1);
    });
  }

  void highlight(int index) {
    if (_matches.isEmpty) return;
    final next = index.clamp(0, _matches.length - 1);
    if (next == _highlighted) return;
    setState(() => _highlighted = next);
  }

  void accept() {
    final descriptor = current;
    if (descriptor == null) return;
    widget.onAccept(descriptor);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(commandLineNotifierProvider.select((s) => s.prompt != null), (
      _,
      _,
    ) {
      _schedule();
    });
    if (!isOpen) return const SizedBox.shrink();
    final tokens = context.tokens;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: tokens.surfaceOverlay,
          elevation: 3,
          shadowColor: tokens.shadow,
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          child: Container(
            key: const Key('canvas-command-suggest'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
              border: Border.all(color: tokens.borderStrong),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _matches.length; i++)
                  _CommandSuggestRow(
                    descriptor: _matches[i],
                    isHighlighted: i == _highlighted,
                    title: l10n.commandTitle(_matches[i].id, _matches[i].title),
                    onHover: () => highlight(i),
                    onTap: () {
                      highlight(i);
                      accept();
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FanCadTokens.space2),
      ],
    );
  }
}

/// The command line on the canvas dock.
///
/// This is the component that decides whether the application feels like CAD.
/// The input keeps focus so typing a verb always works without clicking first,
/// and Escape always cancels whatever is running. The log lives in the left
/// sidebar, not stacked above this row.
class CommandLinePane extends ConsumerStatefulWidget {
  const CommandLinePane({
    super.key,
    required this.workspace,
    required this.focusNode,
    required this.onOpenHistory,
    this.historyOpen = false,
    this.input,
    this.suggestKey,
  });

  final Workspace workspace;
  final VoidCallback onOpenHistory;
  final bool historyOpen;

  /// Owned by the workbench so that the canvas can hand focus back here after
  /// a click, which is what keeps typed input working mid-command.
  final FocusNode focusNode;

  /// Shared with [CommandSuggest] when the HUD shows matches above the field.
  final TextEditingController? input;

  final GlobalKey<CommandSuggestState>? suggestKey;

  @override
  ConsumerState<CommandLinePane> createState() => _CommandLinePaneState();
}

class _CommandLinePaneState extends ConsumerState<CommandLinePane> {
  TextEditingController? _ownedInput;

  TextEditingController get _input => widget.input ?? _ownedInput!;

  CommandSuggestState? get _suggest => widget.suggestKey?.currentState;

  CommandLineNotifier get _model => widget.workspace.commandLine;

  @override
  void initState() {
    super.initState();
    if (widget.input == null) _ownedInput = TextEditingController();
    // The canvas focuses this node, not the wrapping Focus widget, so Escape
    // has to be handled on the node that actually owns focus.
    widget.focusNode.onKeyEvent = _onKey;
  }

  @override
  void didUpdateWidget(CommandLinePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.onKeyEvent = null;
      widget.focusNode.onKeyEvent = _onKey;
    }
    if (widget.input == null && _ownedInput == null) {
      _ownedInput = TextEditingController();
    }
  }

  @override
  void dispose() {
    widget.focusNode.onKeyEvent = null;
    _ownedInput?.dispose();
    super.dispose();
  }

  void _onModelChanged() {
    if (!mounted) return;
    final offered = _model.takeOfferedInput();
    if (offered != null) {
      _setText(offered);
      if (widget.workspace.active?.tools.showDynamicInput != true) {
        widget.focusNode.requestFocus();
      }
    }
  }

  void _submit(String raw) {
    final remaining = _model.submit(raw);
    _input.clear();
    if (remaining == null) return;
    // Not consumed by a prompt, so it is a command to run. An empty line
    // repeats the previous command, which the workspace handles.
    widget.workspace.submitCommandLine(remaining);
  }

  void _acceptSuggest() {
    final descriptor = _suggest?.current;
    _input.clear();
    if (descriptor == null) return;
    widget.workspace.run(descriptor.id);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final suggestOpen = _suggest?.isOpen == true;
    if (suggestOpen) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          _suggest!.move(-1);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
          _suggest!.move(1);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.numpadEnter:
          if (event is KeyDownEvent) _acceptSuggest();
          return KeyEventResult.handled;
      }
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.workspace.cancelActive();
        _input.clear();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        final recalled = _model.recallPrevious();
        if (recalled == null) return KeyEventResult.ignored;
        _setText(recalled);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        final recalled = _model.recallNext();
        if (recalled == null) return KeyEventResult.ignored;
        _setText(recalled);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
        // Empty space finishes a prompt or repeats the last command, which
        // is the AutoCAD muscle memory. Space inside typed text stays a
        // character so aliases like "zoom window" still work.
        if (_input.text.isEmpty) {
          _submit('');
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      default:
        if (DynamicInputHud.isTypeInCharacter(event.character) &&
            widget.workspace.active?.tools.offerHudTypeIn(event.character!) ==
                true) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
    }
  }

  void _setText(String value) {
    _input
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(commandLineNotifierProvider.select((s) => s.offeredInput), (
      previous,
      next,
    ) {
      if (next == null) return;
      _onModelChanged();
    });
    final promptState = ref.watch(
      commandLineNotifierProvider.select((s) => (s.prompt, s.status)),
    );
    final running = ref.watch(
      workspaceNotifierProvider.select((s) => s.runningCommand),
    );
    return _buildInput(
      context.tokens,
      prompt: promptState.$1?.message ?? promptState.$2,
      keywords: promptState.$1?.keywords ?? const [],
      awaiting: promptState.$1 != null,
      running: running != null,
    );
  }

  Widget _buildInput(
    FanCadTokens tokens, {
    required String prompt,
    required List<String> keywords,
    required bool awaiting,
    required bool running,
  }) {
    return Container(
      height: CommandLineLayout.commandLineHeight,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: awaiting ? tokens.accent : Colors.transparent,
            width: awaiting ? 2 : 1,
          ),
        ),
      ),
      child: Row(
        children: [
          FanCadIconButton(
            key: const Key('command-open-history'),
            icon: Icons.history,
            tooltip: context.l10n.command_history,
            size: 20,
            iconSize: FanCadTokens.iconMedium,
            isActive: widget.historyOpen,
            onPressed: widget.onOpenHistory,
          ),
          _HistoryOverflow(
            onCopy: () {
              final text = [
                for (final line in ref.read(commandLineNotifierProvider).lines)
                  line.text,
              ].join('\n');
              Clipboard.setData(ClipboardData(text: text));
              widget.workspace.notify(context.l10n.copied_history);
            },
            onClear: _model.clear,
          ),
          const SizedBox(width: FanCadTokens.space1),
          Expanded(
            child: Row(
              children: [
                if (prompt.isNotEmpty)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: FanCadTokens.space2,
                      ),
                      child: Tooltip(
                        message: prompt,
                        waitDuration: const Duration(milliseconds: 500),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Text(
                            prompt,
                            style: tokens.monoStyle.copyWith(
                              color: awaiting
                                  ? tokens.accent
                                  : tokens.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape): () {
                        widget.workspace.cancelActive();
                        _input.clear();
                      },
                    },
                    child: Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: _onKey,
                      child: FanCadTextField(
                        controller: _input,
                        focusNode: widget.focusNode,
                        hintText: awaiting
                            ? context.l10n.hint_click_or_type
                            : prompt.isEmpty
                            ? context.l10n.hint_type_command
                            : null,
                        onSubmitted: (raw) {
                          if (_suggest?.isOpen == true) {
                            _acceptSuggest();
                            return;
                          }
                          // Enter on an open popup already cleared the field
                          // in [_onKey]; the text-input action still delivers
                          // the old string and must not parse it as a second
                          // command.
                          if (raw.isNotEmpty && _input.text.isEmpty) return;
                          _submit(raw);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (keywords.isNotEmpty || awaiting || running)
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final keyword in keywords.take(6))
                        Padding(
                          padding: const EdgeInsets.only(
                            left: FanCadTokens.space1,
                          ),
                          child: PromptKeywordChip(
                            label: keyword,
                            onPressed: () => _submit(keyword),
                          ),
                        ),
                      if (awaiting || running)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: FanCadTokens.space1,
                          ),
                          child: PromptKeywordChip(
                            key: const Key('command-prompt-cancel'),
                            label: context.l10n.cancel,
                            muted: true,
                            onPressed: () {
                              widget.workspace.cancelActive();
                              _input.clear();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommandSuggestRow extends StatelessWidget {
  const _CommandSuggestRow({
    required this.descriptor,
    required this.isHighlighted,
    required this.title,
    required this.onHover,
    required this.onTap,
  });

  final CommandDescriptor descriptor;
  final bool isHighlighted;
  final String title;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: FanCadRow(
        key: Key('canvas-command-suggest-row-${descriptor.id}'),
        isSelected: isHighlighted,
        onTap: onTap,
        height: FanCadTokens.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: tokens.bodyStyle.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (descriptor.description.isNotEmpty) ...[
                    const SizedBox(width: FanCadTokens.space2),
                    Expanded(
                      child: Text(
                        l10n.commandDescription(
                          descriptor.id,
                          descriptor.description,
                        ),
                        style: tokens.labelStyle.copyWith(fontSize: 10.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: FanCadTokens.space3),
            Expanded(
              child: descriptor.aliases.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      descriptor.aliases.first.toUpperCase(),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.monoStyle.copyWith(
                        fontSize: 10.5,
                        color: tokens.textFaint,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One command-history row. A click puts the text back in the input so a
/// previous verb or coordinate does not have to be retyped from memory.
class _HistoryLine extends StatefulWidget {
  const _HistoryLine({
    required this.line,
    required this.tokens,
    required this.onReuse,
  });

  final HistoryLineModel line;
  final FanCadTokens tokens;
  final VoidCallback onReuse;

  @override
  State<_HistoryLine> createState() => _HistoryLineState();
}

class _HistoryLineState extends State<_HistoryLine> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onReuse,
        child: ColoredBox(
          color: _hovered ? tokens.hover : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space1,
            ),
            child: Row(
              children: [
                if (_historyDot(widget.line.level, tokens) case final dot?) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: FanCadTokens.space1),
                ],
                Expanded(
                  child: Text(
                    widget.line.text,
                    style: tokens.monoStyle.copyWith(
                      fontSize: 11.5,
                      color: widget.line.level == HistoryLevel.prompt
                          ? tokens.text
                          : tokens.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color? _historyDot(HistoryLevel level, FanCadTokens tokens) => switch (level) {
  HistoryLevel.success => tokens.success,
  HistoryLevel.warning => tokens.warning,
  HistoryLevel.error => tokens.danger,
  HistoryLevel.normal || HistoryLevel.prompt => null,
};

/// Copy and clear sit behind one control so the input row can stay a command
/// line rather than a toolbar.
class _HistoryOverflow extends StatelessWidget {
  const _HistoryOverflow({
    required this.onCopy,
    required this.onClear,
    this.enabled = true,
  });

  final VoidCallback onCopy;
  final VoidCallback onClear;

  /// The command row leaves this on. The log panel passes its own line list.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return FanCadMenuButton<String>(
      tooltip: context.l10n.command_history,
      enabled: enabled,
      onSelected: (value) {
        switch (value) {
          case 'copy':
            onCopy();
          case 'clear':
            onClear();
        }
      },
      itemBuilder: (context) => [
        fanCadMenuItem(
          context,
          value: 'copy',
          label: context.l10n.copy_history,
          enabled: enabled,
        ),
        fanCadMenuItem(
          context,
          value: 'clear',
          label: context.l10n.clear_history,
          enabled: enabled,
        ),
      ],
      child: SizedBox(
        width: 20,
        height: 20,
        child: Icon(
          Icons.more_vert,
          size: FanCadTokens.iconSmall,
          color: enabled ? tokens.textMuted : tokens.textFaint,
        ),
      ),
    );
  }
}

/// The command log in the left sidebar.
///
/// The canvas dock only types; this panel is where a leftover LINE or an
/// import warning can be reread and clicked back into the input.
class CommandLogPanel extends ConsumerStatefulWidget {
  const CommandLogPanel({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<CommandLogPanel> createState() => _CommandLogPanelState();
}

class _CommandLogPanelState extends ConsumerState<CommandLogPanel> {
  final ScrollController _scroll = ScrollController();

  CommandLineNotifier get _model => widget.workspace.commandLine;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onModelChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.maxScrollExtent - position.pixels < 80) {
        _scroll.jumpTo(position.maxScrollExtent);
      }
    });
    setState(() {});
  }

  void _copy() {
    final text = [
      for (final line in ref.read(commandLineNotifierProvider).lines) line.text,
    ].join('\n');
    Clipboard.setData(ClipboardData(text: text));
    widget.workspace.notify(context.l10n.copied_history);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      commandLineNotifierProvider.select((s) => s.lines.length),
      (_, _) => _onModelChanged(),
    );
    ref.watch(commandLineNotifierProvider.select((s) => s.lines));
    final tokens = context.tokens;
    final lines = ref.read(commandLineNotifierProvider).lines;
    return Column(
      key: const Key('command-log-panel'),
      children: [
        PanelHeader(
          title: context.l10n.command_history,
          actions: [
            _HistoryOverflow(
              enabled: lines.isNotEmpty,
              onCopy: _copy,
              onClear: _model.clear,
            ),
          ],
        ),
        Expanded(
          child: lines.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(FanCadTokens.space4),
                  child: Text(
                    context.l10n.command_history_hint,
                    style: tokens.labelStyle,
                  ),
                )
              : Scrollbar(
                  controller: _scroll,
                  thickness: 6,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: FanCadTokens.space2,
                      vertical: FanCadTokens.space1,
                    ),
                    itemCount: lines.length,
                    itemExtent: 22,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return _HistoryLine(
                        line: line,
                        tokens: tokens,
                        onReuse: () => _model.offerInput(line.text.trim()),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// Window footer. Drawing telemetry lives on the canvas so this row can
/// stay a thin chrome strip.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      key: const Key('status-bar'),
      height: FanCadTokens.statusBarHeight,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.borderMuted)),
      ),
    );
  }
}
