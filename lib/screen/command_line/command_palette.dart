import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../commands/keybindings.dart';
import '../../l10n/l10n.dart';
import '../../services/workspace.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';

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
  final GlobalKey<_PaletteResultsState> _resultsKey = GlobalKey();

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
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
        _resultsKey.currentState?.move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _resultsKey.currentState?.move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _resultsKey.currentState?.accept();
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
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
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
                        color: tokens.shadow,
                        blurRadius: 20,
                        offset: const Offset(0, 6),
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
                        child: FanCadTextField(
                          controller: _query,
                          focusNode: _focus,
                          autofocus: true,
                          hintText: context.l10n.search_commands,
                          style: tokens.bodyStyle.copyWith(fontSize: 14),
                          suffix: ListenableBuilder(
                            listenable: _query,
                            builder: (context, _) => _query.text.isEmpty
                                ? const SizedBox.shrink()
                                : FanCadIconButton(
                                    icon: Icons.close,
                                    size: 20,
                                    iconSize: FanCadTokens.iconSmall,
                                    tooltip: context.l10n.clear_search,
                                    onPressed: _query.clear,
                                  ),
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
                      _PaletteResults(
                        key: _resultsKey,
                        query: _query,
                        workspace: widget.workspace,
                        onAccept: (descriptor) {
                          widget.onDismiss();
                          widget.workspace.run(descriptor.id);
                        },
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

/// Matches under the palette field. Search waits one frame so the typed
/// character paints before the list walks the registry.
class _PaletteResults extends StatefulWidget {
  const _PaletteResults({
    super.key,
    required this.query,
    required this.workspace,
    required this.onAccept,
  });

  final TextEditingController query;
  final Workspace workspace;
  final ValueChanged<CommandDescriptor> onAccept;

  @override
  State<_PaletteResults> createState() => _PaletteResultsState();
}

class _PaletteResultsState extends State<_PaletteResults> {
  final ScrollController _scroll = ScrollController();
  List<CommandDescriptor> _matches = const [];
  int _highlighted = 0;
  bool _scheduled = false;

  static const double _rowHeight = 44;

  @override
  void initState() {
    super.initState();
    widget.query.addListener(_schedule);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recompute();
    });
  }

  @override
  void didUpdateWidget(_PaletteResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      oldWidget.query.removeListener(_schedule);
      widget.query.addListener(_schedule);
    }
  }

  @override
  void dispose() {
    widget.query.removeListener(_schedule);
    _scroll.dispose();
    super.dispose();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _recompute();
    });
  }

  void _recompute() {
    final text = widget.query.text;
    var matches = searchCommandsLocalized(
      widget.workspace.commands,
      text,
      context.l10n,
      limit: 60,
    );
    final lastId = widget.workspace.commands.lastCommandId;
    if (text.trim().isEmpty && lastId != null) {
      final last = widget.workspace.commands.find(lastId);
      if (last != null) {
        matches = [last, ...matches.where((each) => each.id != lastId)];
      }
    }
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
    // Keep the highlighted row on screen; without this, arrowing past the
    // bottom silently moves a selection the user cannot see.
    final target = _highlighted * _rowHeight;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (target < position.pixels) {
      _scroll.jumpTo(target);
    } else if (target + _rowHeight >
        position.pixels + position.viewportDimension) {
      _scroll.jumpTo(
        (target + _rowHeight - position.viewportDimension).clamp(
          0.0,
          position.maxScrollExtent,
        ),
      );
    }
  }

  void accept() {
    if (_matches.isEmpty) return;
    widget.onAccept(_matches[_highlighted]);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final query = widget.query.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                        query.isEmpty
                            ? context.l10n.start_typing_command
                            : context.l10n.no_commands_match(query),
                        style: tokens.bodyStyle,
                      ),
                      const SizedBox(height: FanCadTokens.space2),
                      Text(
                        context.l10n.try_alias_or_category,
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
                        query.isEmpty &&
                        _matches[index].id ==
                            widget.workspace.commands.lastCommandId,
                    isHighlighted: index == _highlighted,
                    onHover: () {
                      if (_highlighted == index) return;
                      setState(() => _highlighted = index);
                    },
                    onTap: () {
                      setState(() => _highlighted = index);
                      accept();
                    },
                  ),
                ),
        ),
        Container(
          height: FanCadTokens.statusBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space4),
          decoration: BoxDecoration(
            color: tokens.surfaceRaised,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Text(
                context.l10n.commandCount(_matches.length),
                style: tokens.labelStyle,
              ),
              const Spacer(),
              Text(context.l10n.palette_hints, style: tokens.labelStyle),
            ],
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
    final l10n = context.l10n;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: FanCadRow(
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
                        l10n.commandTitle(descriptor.id, descriptor.title),
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
                        FanCadBadge(text: l10n.last_badge),
                      ],
                      if (!descriptor.isBuiltIn) ...[
                        const SizedBox(width: FanCadTokens.space2),
                        FanCadBadge(text: descriptor.extensionId),
                      ],
                    ],
                  ),
                  if (descriptor.description.isNotEmpty)
                    Text(
                      l10n.commandDescription(
                        descriptor.id,
                        descriptor.description,
                      ),
                      style: tokens.labelStyle.copyWith(fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              l10n.commandCategory(descriptor.category),
              style: tokens.labelStyle,
            ),
            if (descriptor.defaultKeybinding != null) ...[
              const SizedBox(width: FanCadTokens.space3),
              Text(
                formatKeybinding(descriptor.defaultKeybinding!),
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
