import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/workspace.dart';
import '../theme/tokens.dart';
import 'shell_widgets.dart';

/// The command palette.
///
/// Every registered command appears here, built-in and plugin alike, with no
/// separate registration step. That is the payoff of the single registry: a
/// plugin that adds a command gets a palette entry, a command-line verb and an
/// AI tool from one declaration.
class CommandPalette extends StatefulWidget {
  const CommandPalette({
    super.key,
    required this.workspace,
    required this.onDismiss,
  });

  final Workspace workspace;
  final VoidCallback onDismiss;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  List<CommandDescriptor> _matches = const [];
  int _highlighted = 0;

  static const double _rowHeight = 44;

  @override
  void initState() {
    super.initState();
    _recompute('');
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _recompute(String text) {
    setState(() {
      var matches = widget.workspace.commands.search(text, limit: 60);
      final lastId = widget.workspace.commands.lastCommandId;
      if (text.trim().isEmpty && lastId != null) {
        final last = widget.workspace.commands.find(lastId);
        if (last != null) {
          matches = [
            last,
            ...matches.where((each) => each.id != lastId),
          ];
        }
      }
      _matches = matches;
      _highlighted = 0;
    });
  }

  void _move(int delta) {
    if (_matches.isEmpty) return;
    setState(() {
      _highlighted = (_highlighted + delta).clamp(0, _matches.length - 1);
    });
    // Keep the highlighted row on screen; without this, arrowing past the
    // bottom silently moves a selection the user cannot see.
    final target = _highlighted * _rowHeight;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (target < position.pixels) {
      _scroll.jumpTo(target);
    } else if (target + _rowHeight > position.pixels + position.viewportDimension) {
      _scroll.jumpTo(
        (target + _rowHeight - position.viewportDimension).clamp(
          0,
          position.maxScrollExtent,
        ),
      );
    }
  }

  void _accept() {
    if (_matches.isEmpty) return;
    final descriptor = _matches[_highlighted];
    widget.onDismiss();
    widget.workspace.run(descriptor.id);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onDismiss();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _accept();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Stack(
      children: [
        // A dismiss layer rather than a modal route, so the canvas underneath
        // stays live and the palette never blocks a running command.
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),
        Positioned(
          top: 72,
          left: 0,
          right: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Focus(
                onKeyEvent: _onKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.surfaceOverlay,
                    borderRadius: BorderRadius.circular(
                      FanCadTokens.radiusLarge,
                    ),
                    border: Border.all(color: tokens.borderStrong),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(
                          horizontal: FanCadTokens.space4,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: tokens.border),
                          ),
                        ),
                        child: ShellTextField(
                          controller: _query,
                          focusNode: _focus,
                          autofocus: true,
                          hintText: 'Search commands, aliases or categories',
                          style: tokens.bodyStyle.copyWith(fontSize: 14),
                          onChanged: _recompute,
                          suffix: _query.text.isEmpty
                              ? null
                              : ShellIconButton(
                                  icon: Icons.close,
                                  size: 20,
                                  iconSize: FanCadTokens.iconSmall,
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _query.clear();
                                    _recompute('');
                                  },
                                ),
                          prefix: Padding(
                            padding: const EdgeInsets.only(
                              right: FanCadTokens.space2,
                            ),
                            child: Icon(
                              Icons.search,
                              size: 16,
                              color: tokens.textMuted,
                            ),
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 396),
                        child: _matches.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: FanCadTokens.space4,
                                  vertical: FanCadTokens.space5,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _query.text.trim().isEmpty
                                          ? 'Start typing to find a command.'
                                          : 'No commands match “${_query.text.trim()}”.',
                                      style: tokens.bodyStyle,
                                    ),
                                    const SizedBox(height: FanCadTokens.space2),
                                    Text(
                                      'Try an alias such as L, C or M, or a category like Draw.',
                                      style: tokens.labelStyle,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scroll,
                                shrinkWrap: true,
                                itemExtent: _rowHeight,
                                itemCount: _matches.length,
                                itemBuilder: (context, index) => _PaletteRow(
                                  descriptor: _matches[index],
                                  isLastUsed:
                                      index == 0 &&
                                      _query.text.trim().isEmpty &&
                                      _matches[index].id ==
                                          widget.workspace.commands.lastCommandId,
                                  isHighlighted: index == _highlighted,
                                  onHover: () {
                                    if (_highlighted == index) return;
                                    setState(() => _highlighted = index);
                                  },
                                  onTap: () {
                                    setState(() => _highlighted = index);
                                    _accept();
                                  },
                                ),
                              ),
                      ),
                      Container(
                        height: FanCadTokens.statusBarHeight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: FanCadTokens.space4,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceRaised,
                          border: Border(
                            top: BorderSide(color: tokens.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${_matches.length} command${_matches.length == 1 ? '' : 's'}',
                              style: tokens.labelStyle,
                            ),
                            const Spacer(),
                            Text(
                              '↑↓  move   Enter  run   Esc  close',
                              style: tokens.monoStyle.copyWith(
                                fontSize: 10.5,
                                color: tokens.textFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.descriptor,
    required this.isHighlighted,
    required this.onTap,
    required this.onHover,
    this.isLastUsed = false,
  });

  final CommandDescriptor descriptor;
  final bool isHighlighted;
  final bool isLastUsed;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: ShellRow(
        isSelected: isHighlighted,
        onTap: onTap,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        descriptor.title,
                        style: tokens.bodyStyle.copyWith(fontSize: 13),
                      ),
                      if (descriptor.aliases.isNotEmpty) ...[
                        const SizedBox(width: FanCadTokens.space2),
                        Text(
                          descriptor.aliases.first.toUpperCase(),
                          style: tokens.monoStyle.copyWith(
                            fontSize: 10.5,
                            color: tokens.textFaint,
                          ),
                        ),
                      ],
                      if (isLastUsed) ...[
                        const SizedBox(width: FanCadTokens.space2),
                        const _Badge(text: 'Last'),
                      ],
                      if (!descriptor.isBuiltIn) ...[
                        const SizedBox(width: FanCadTokens.space2),
                        _Badge(text: descriptor.extensionId),
                      ],
                    ],
                  ),
                  if (descriptor.description.isNotEmpty)
                    Text(
                      descriptor.description,
                      style: tokens.labelStyle.copyWith(fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(descriptor.category, style: tokens.labelStyle),
            if (descriptor.defaultKeybinding != null) ...[
              const SizedBox(width: FanCadTokens.space3),
              Text(
                descriptor.defaultKeybinding!.toUpperCase(),
                style: tokens.monoStyle.copyWith(
                  fontSize: 10.5,
                  color: tokens.textFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: tokens.labelStyle.copyWith(
          fontSize: 9.5,
          color: tokens.accent,
        ),
      ),
    );
  }
}
