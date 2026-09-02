import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/workspace.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'command_line_model.dart';
import 'dynamic_input_hud.dart';
import 'shell_widgets.dart';

/// The command line on the canvas dock.
///
/// This is the component that decides whether the application feels like CAD.
/// The input keeps focus so typing a verb always works without clicking first,
/// and Escape always cancels whatever is running. The log lives in the left
/// sidebar, not stacked above this row.
class CommandLinePane extends StatefulWidget {
  const CommandLinePane({
    super.key,
    required this.workspace,
    required this.focusNode,
    required this.onOpenHistory,
    this.historyOpen = false,
  });

  final Workspace workspace;
  final VoidCallback onOpenHistory;
  final bool historyOpen;

  /// Owned by the workbench so that the canvas can hand focus back here after
  /// a click, which is what keeps typed input working mid-command.
  final FocusNode focusNode;

  @override
  State<CommandLinePane> createState() => _CommandLinePaneState();
}

class _CommandLinePaneState extends State<CommandLinePane> {
  final TextEditingController _input = TextEditingController();

  CommandLineController get _model => widget.workspace.commandLine;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
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
  }

  @override
  void dispose() {
    widget.focusNode.onKeyEvent = null;
    _model.removeListener(_onModelChanged);
    _input.dispose();
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
    setState(() {});
  }

  void _submit(String raw) {
    final remaining = _model.submit(raw);
    _input.clear();
    if (remaining == null) return;
    // Not consumed by a prompt, so it is a command to run. An empty line
    // repeats the previous command, which the workspace handles.
    widget.workspace.submitCommandLine(remaining);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
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
    return _buildInput(context.tokens);
  }

  Widget _buildInput(FanCadTokens tokens) {
    final prompt = _model.promptText;
    final keywords = _model.pending?.keywords ?? const <String>[];
    final awaiting = _model.isAwaitingInput;
    return Container(
      height: FanCadTokens.commandLineHeight,
      padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space2),
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
          ShellIconButton(
            key: const Key('command-open-history'),
            icon: Icons.history,
            tooltip: context.l10n.command_history,
            size: 20,
            iconSize: FanCadTokens.iconMedium,
            isActive: widget.historyOpen,
            onPressed: widget.onOpenHistory,
          ),
          _HistoryOverflow(
            enabled: _model.lines.isNotEmpty,
            onCopy: () {
              final text = [
                for (final line in _model.lines) line.text,
              ].join('\n');
              Clipboard.setData(ClipboardData(text: text));
              widget.workspace.notify(context.l10n.copied_history);
            },
            onClear: _model.clear,
          ),
          const SizedBox(width: FanCadTokens.space1),
          if (prompt.isNotEmpty)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: FanCadTokens.space2),
                child: Tooltip(
                  message: prompt,
                  waitDuration: const Duration(milliseconds: 500),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      prompt,
                      style: tokens.monoStyle.copyWith(
                        color: awaiting ? tokens.accent : tokens.textMuted,
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
                child: ShellTextField(
                  controller: _input,
                  focusNode: widget.focusNode,
                  hintText: awaiting
                      ? context.l10n.hint_click_or_type
                      : prompt.isEmpty
                      ? context.l10n.hint_type_command
                      : null,
                  onSubmitted: _submit,
                ),
              ),
            ),
          ),
          if (keywords.isNotEmpty || awaiting || widget.workspace.isBusy)
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
                    if (awaiting || widget.workspace.isBusy)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: FanCadTokens.space1,
                        ),
                        child: PromptKeywordChip(
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
        ],
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

  final HistoryLine line;
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
    required this.enabled,
    required this.onCopy,
    required this.onClear,
  });

  final bool enabled;
  final VoidCallback onCopy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ShellMenuButton<String>(
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
        shellMenuItem(
          context,
          value: 'copy',
          label: context.l10n.copy_history,
          enabled: enabled,
        ),
        shellMenuItem(
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
class CommandLogPanel extends StatefulWidget {
  const CommandLogPanel({super.key, required this.workspace});

  final Workspace workspace;

  @override
  State<CommandLogPanel> createState() => _CommandLogPanelState();
}

class _CommandLogPanelState extends State<CommandLogPanel> {
  final ScrollController _scroll = ScrollController();

  CommandLineController get _model => widget.workspace.commandLine;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
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
    final text = [for (final line in _model.lines) line.text].join('\n');
    Clipboard.setData(ClipboardData(text: text));
    widget.workspace.notify(context.l10n.copied_history);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lines = _model.lines;
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
