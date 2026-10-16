import 'dart:async';
import 'dart:math' as math;

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

/// Matches shown above the canvas HUD.
///
/// Command mode lists verbs. Search mode lists drawn text in the current
/// layout. Both listen to the command field and run once on the next frame.
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
  List<TextSearchHit> _textHits = const [];
  bool _textMode = false;
  bool _textEmpty = false;
  int _highlighted = 0;
  bool _scheduled = false;
  TextSearchSignal? _signal;
  final ScrollController _textScroll = ScrollController();

  bool get isOpen =>
      _textMode ? _textHits.isNotEmpty || _textEmpty : _matches.isNotEmpty;

  CommandDescriptor? get current =>
      !_textMode && _matches.isNotEmpty ? _matches[_highlighted] : null;

  TextSearchHit? get currentText {
    if (!_textMode || _textHits.isEmpty) return null;
    return _textHits[_highlighted.clamp(0, _textHits.length - 1)];
  }

  int get _rowCount => _textMode ? _textHits.length : _matches.length;

  @override
  void initState() {
    super.initState();
    widget.input.addListener(_schedule);
    _bind(widget.workspace.active);
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
    _signal?.removeListener(_onSignal);
    widget.input.removeListener(_schedule);
    _textScroll.dispose();
    super.dispose();
  }

  TextSearchSignal? _signalOf(DocumentTab? tab) {
    if (tab == null || tab.isStartPage) return null;
    return tab.textSearch;
  }

  void _bind(DocumentTab? tab) {
    final signal = _signalOf(tab);
    if (_signal == signal) return;
    _signal?.removeListener(_onSignal);
    _signal = signal;
    _signal?.addListener(_onSignal);
  }

  void _onSignal() {
    if (!mounted) return;
    _schedule();
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
    final searching = _signal?.open == true;
    if (_matches.isEmpty &&
        _textHits.isEmpty &&
        !_textEmpty &&
        _textMode == searching) {
      return;
    }
    setState(() {
      _matches = const [];
      _textHits = const [];
      _textEmpty = false;
      _textMode = searching;
      _highlighted = 0;
    });
  }

  void _search() {
    final tab = widget.workspace.active;
    if (tab != null && !tab.isStartPage && tab.textSearch.open) {
      _searchText(tab);
      return;
    }
    final awaiting = ref.read(commandLineNotifierProvider).prompt != null;
    final query = widget.input.text;
    if (awaiting || query.trim().isEmpty || textSearchCommand(query) != null) {
      _clear();
      return;
    }
    final matches = searchCommandsLocalized(
      widget.workspace.commands,
      query,
      context.l10n,
      limit: CommandSuggest.limit,
    );
    setState(() {
      _textMode = false;
      _textHits = const [];
      _textEmpty = false;
      _matches = matches;
      _highlighted = 0;
    });
  }

  void _searchText(DocumentTab tab) {
    final query = widget.input.text;
    if (query.trim().isEmpty) {
      _clear();
      return;
    }
    final filtered = filterTextSearchHits(textSearchHits(tab.document), query);
    setState(() {
      _textMode = true;
      _matches = const [];
      _textHits = filtered;
      _textEmpty = filtered.isEmpty;
      _highlighted = 0;
    });
    _reveal(0);
  }

  void move(int delta) {
    if (_rowCount == 0) return;
    final next = (_highlighted + delta).clamp(0, _rowCount - 1);
    setState(() => _highlighted = next);
    if (_textMode) _reveal(next);
  }

  /// Keeps the highlighted text row inside the eight-row window.
  void _reveal(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_textScroll.hasClients) return;
      final target = index * FanCadTokens.rowHeight;
      final start = _textScroll.offset;
      final view = _textScroll.position.viewportDimension;
      if (target < start) {
        _textScroll.jumpTo(target);
      } else if (target + FanCadTokens.rowHeight > start + view) {
        _textScroll.jumpTo(target + FanCadTokens.rowHeight - view);
      }
    });
  }

  void highlight(int index) {
    if (_rowCount == 0) return;
    final next = index.clamp(0, _rowCount - 1);
    if (next == _highlighted) return;
    setState(() => _highlighted = next);
  }

  void accept() {
    if (_textMode) {
      final hit = currentText;
      if (hit == null) return;
      _jumpToTextHit(ref, widget.workspace, hit);
      return;
    }
    final descriptor = current;
    if (descriptor == null) return;
    widget.onAccept(descriptor);
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = ref.watch(
      workspaceNotifierProvider.select((s) => s.activeSessionId),
    );
    ref.listen(workspaceNotifierProvider.select((s) => s.activeSessionId), (
      _,
      _,
    ) {
      _bind(widget.workspace.active);
      _search();
    });
    ref.listen(commandLineNotifierProvider.select((s) => s.prompt != null), (
      _,
      _,
    ) {
      _schedule();
    });
    if (sessionId != null) {
      ref.listen(
        documentTabNotifierProvider(sessionId).select((s) => s.contentEpoch),
        (_, _) {
          if (_signal?.open == true) _schedule();
        },
      );
    }
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_textMode) ...[
                  if (_textEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FanCadTokens.space3,
                        vertical: FanCadTokens.space2,
                      ),
                      child: Text(
                        l10n.find_text_empty,
                        key: const Key('canvas-text-suggest-empty'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.labelStyle.copyWith(
                          fontSize: 12,
                          color: tokens.textMuted,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      key: const Key('canvas-text-suggest-list'),
                      height:
                          math.min(_textHits.length, CommandSuggest.limit) *
                          FanCadTokens.rowHeight,
                      child: Scrollbar(
                        controller: _textScroll,
                        child: ListView.builder(
                          controller: _textScroll,
                          itemExtent: FanCadTokens.rowHeight,
                          itemCount: _textHits.length,
                          itemBuilder: (context, i) => _TextSuggestRow(
                            hit: _textHits[i],
                            index: i,
                            query: widget.input.text,
                            selected: i == _highlighted,
                            kindLabel: _textKindLabel(l10n, _textHits[i].kind),
                            onHover: () => highlight(i),
                            onTap: () {
                              highlight(i);
                              accept();
                            },
                          ),
                        ),
                      ),
                    ),
                ] else
                  for (var i = 0; i < _matches.length; i++)
                    _CommandSuggestRow(
                      descriptor: _matches[i],
                      isHighlighted: i == _highlighted,
                      title: l10n.commandTitle(
                        _matches[i].id,
                        _matches[i].title,
                      ),
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

void _jumpToTextHit(WidgetRef ref, Workspace workspace, TextSearchHit hit) {
  workspace.frameText(hit.bounds);
  final tab = workspace.active;
  if (tab == null) return;
  if (ref.read(workspaceNotifierProvider).runningCommand != null) {
    workspace.flashHighlights([hit.selectId]);
    return;
  }
  tab.selection.replace([hit.selectId]);
}

String _textKindLabel(AppLocalizations l10n, TextSearchKind kind) =>
    switch (kind) {
      TextSearchKind.text => l10n.text_kind_text,
      TextSearchKind.mtext => l10n.text_kind_mtext,
      TextSearchKind.attribute => l10n.text_kind_attribute,
      TextSearchKind.mleader => l10n.text_kind_mleader,
      TextSearchKind.dimension => l10n.text_kind_dimension,
    };

class _TextSuggestRow extends StatelessWidget {
  const _TextSuggestRow({
    required this.hit,
    required this.index,
    required this.query,
    required this.selected,
    required this.kindLabel,
    required this.onHover,
    required this.onTap,
  });

  final TextSearchHit hit;
  final int index;
  final String query;
  final bool selected;
  final String kindLabel;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final meta = [kindLabel, if (hit.layer.isNotEmpty) hit.layer].join(' · ');
    final tag = hit.tag;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: FanCadRow(
        key: Key('canvas-text-suggest-row-${hit.selectId}-$index'),
        isSelected: selected,
        onTap: onTap,
        height: FanCadTokens.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Flexible(child: _textSnippet(hit.text, query, tokens)),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(width: FanCadTokens.space2),
                    Expanded(
                      child: Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.labelStyle.copyWith(fontSize: 10.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: FanCadTokens.space3),
            Expanded(
              child: tag == null || tag.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      tag,
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

Widget _textSnippet(String text, String query, FanCadTokens tokens) {
  final display = text.replaceAll('\n', ' ');
  final needle = query.trim().toLowerCase();
  final at = needle.isEmpty ? -1 : display.toLowerCase().indexOf(needle);
  final style = tokens.bodyStyle.copyWith(fontSize: 12);
  if (at < 0) {
    return Text(
      display,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
  const wing = 28;
  var from = 0;
  var to = display.length;
  if (display.length > 64) {
    from = math.max(0, at - wing);
    to = math.min(display.length, at + needle.length + wing);
  }
  final pad = from > 0 ? 1 : 0;
  final slice = display.substring(from, to);
  final shownStart = at - from + pad;
  final prefix = from > 0 ? '…' : '';
  final suffix = to < display.length ? '…' : '';
  final body = '$prefix$slice$suffix';
  final end = shownStart + needle.length;
  return Text.rich(
    TextSpan(
      style: style,
      children: [
        TextSpan(text: body.substring(0, shownStart)),
        TextSpan(
          text: body.substring(shownStart, end),
          style: style.copyWith(
            color: tokens.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(text: body.substring(end)),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

/// The command line on the canvas dock.
///
/// This is the component that decides whether the application feels like CAD.
/// The input keeps focus so typing a verb always works without clicking first.
/// Escape cancels whatever is running, except in search mode, where it only
/// leaves the search. The log lives in the left sidebar, not stacked above
/// this row.
class CommandLinePane extends ConsumerStatefulWidget {
  const CommandLinePane({
    super.key,
    required this.workspace,
    required this.focusNode,
    this.input,
    this.suggestKey,
  });

  final Workspace workspace;

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
  TextSearchSignal? _signal;
  String? _seenSession;

  TextEditingController get _input => widget.input ?? _ownedInput!;

  CommandSuggestState? get _suggest => widget.suggestKey?.currentState;

  CommandLineNotifier get _model => widget.workspace.commandLine;

  bool get _searching => _signal?.open == true;

  @override
  void initState() {
    super.initState();
    if (widget.input == null) _ownedInput = TextEditingController();
    // The canvas focuses this node, not the wrapping Focus widget, so Escape
    // has to be handled on the node that actually owns focus.
    widget.focusNode.onKeyEvent = _onKey;
    _input.addListener(_onInput);
    _retarget(ref.read(workspaceNotifierProvider).activeSessionId);
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
    if (oldWidget.input != widget.input) {
      (oldWidget.input ?? _ownedInput)?.removeListener(_onInput);
      _input.addListener(_onInput);
    }
  }

  @override
  void dispose() {
    widget.focusNode.onKeyEvent = null;
    _signal?.removeListener(_onSearch);
    _input.removeListener(_onInput);
    _ownedInput?.dispose();
    super.dispose();
  }

  TextSearchSignal? _signalOf(DocumentTab? tab) {
    if (tab == null || tab.isStartPage) return null;
    return tab.textSearch;
  }

  void _retarget(String? sessionId) {
    final signal = _signalOf(widget.workspace.active);
    if (signal == _signal && sessionId == _seenSession) return;
    final leftSearch = _signal?.open == true;
    _signal?.removeListener(_onSearch);
    _signal = signal;
    _signal?.addListener(_onSearch);
    final sessionChanged = sessionId != _seenSession;
    _seenSession = sessionId;
    if (!sessionChanged) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _followTab(leftSearch: leftSearch);
    });
  }

  void _onSearch() {
    if (!mounted) return;
    final signal = _signal;
    if (signal == null || !signal.open) {
      if (_input.text.isNotEmpty) _input.clear();
      setState(() {});
      return;
    }
    _showQuery(signal.query, selectAll: true);
  }

  void _followTab({required bool leftSearch}) {
    final signal = _signal;
    if (signal != null && signal.open) {
      _showQuery(signal.query, selectAll: false);
      return;
    }
    // The field is shared. A search query must not stay behind as a command,
    // and a command typed on the previous drawing must not be wiped.
    if (leftSearch && _input.text.isNotEmpty) _input.clear();
    setState(() {});
  }

  void _showQuery(String query, {required bool selectAll}) {
    _input.value = TextEditingValue(
      text: query,
      selection: selectAll
          ? TextSelection(baseOffset: 0, extentOffset: query.length)
          : TextSelection.collapsed(offset: query.length),
    );
    widget.focusNode.requestFocus();
    setState(() {});
  }

  void _onInput() {
    final signal = _signal;
    if (signal == null || !signal.open) return;
    if (signal.query == _input.text) return;
    signal.rememberQuery(_input.text);
  }

  void _leaveSearch() {
    final tab = widget.workspace.active;
    if (tab != null && !tab.isStartPage) tab.textSearch.close();
    if (_input.text.isNotEmpty) _input.clear();
  }

  void _onEscape() {
    final tab = widget.workspace.active;
    if (tab != null && !tab.isStartPage && tab.textSearch.handleEscape()) {
      if (_input.text.isNotEmpty) _input.clear();
      return;
    }
    widget.workspace.cancelActive();
    _input.clear();
  }

  void _onModelChanged() {
    if (!mounted || _searching) return;
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
    if (_searching) {
      _suggest?.accept();
      return;
    }
    final typed = _input.text;
    if (textSearchCommand(typed) != null) {
      _submit(typed);
      return;
    }
    final descriptor = _suggest?.current;
    _input.clear();
    if (descriptor == null) return;
    widget.workspace.run(descriptor.id);
  }

  KeyEventResult _onSearchKey(KeyEvent event) {
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowDown:
        if (_suggest?.isOpen == true) {
          final delta = event.logicalKey == LogicalKeyboardKey.arrowUp ? -1 : 1;
          _suggest!.move(delta);
          final hit = _suggest!.currentText;
          if (hit != null) _jumpToTextHit(ref, widget.workspace, hit);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (event is KeyDownEvent) {
          final hit = _suggest?.currentText;
          if (hit != null) _jumpToTextHit(ref, widget.workspace, hit);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (event is KeyDownEvent) _onEscape();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  /// Search, a waiting prompt, or text already in the field wants the
  /// clipboard as characters. An empty idle line leaves Ctrl/Cmd+V for the
  /// drawing paste. The command field stays focused after a canvas click, so
  /// that empty line is how a drawing paste still starts.
  bool _fieldWantsTextPaste() {
    if (FocusManager.instance.primaryFocus != widget.focusNode) return false;
    if (_searching || _model.isAwaitingInput) return true;
    return _input.text.isNotEmpty;
  }

  bool _isPlainPaste(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyV) return false;
    final keys = HardwareKeyboard.instance;
    final primary = keys.isControlPressed || keys.isMetaPressed;
    return primary && !keys.isAltPressed && !keys.isShiftPressed;
  }

  Future<void> _pasteText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final raw = data?.text;
    if (raw == null || raw.isEmpty) return;
    final text = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', ' ')
        .trimRight();
    if (text.isEmpty) return;
    final value = _input.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final next = value.text.replaceRange(start, end, text);
    _input.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // The window binds this chord to the drawing paste. Handling it on the
    // focused field inserts the clipboard before that shortcut runs.
    if (_isPlainPaste(event) && _fieldWantsTextPaste()) {
      unawaited(_pasteText());
      return KeyEventResult.handled;
    }
    if (_searching) return _onSearchKey(event);
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
        _onEscape();
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
    ref.listen(
      workspaceNotifierProvider.select((s) => s.activeSessionId),
      (_, next) => _retarget(next),
    );
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
    final searching = _searching;
    return _buildInput(
      context.tokens,
      searching: searching,
      prompt: searching ? '' : promptState.$1?.message ?? promptState.$2,
      keywords: searching ? const [] : promptState.$1?.keywords ?? const [],
      awaiting: searching ? false : promptState.$1 != null,
      hint: promptState.$1 == null
          ? null
          : commandLineHint(context.l10n, promptState.$1!.kind),
      running: searching ? false : running != null,
    );
  }

  Widget _buildInput(
    FanCadTokens tokens, {
    required bool searching,
    required String prompt,
    required List<String> keywords,
    required bool awaiting,
    required String? hint,
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
          Tooltip(
            message: searching
                ? context.l10n.hud_mode_search
                : context.l10n.hud_mode_command,
            waitDuration: const Duration(milliseconds: 500),
            child: SizedBox(
              key: const Key('canvas-hud-mode'),
              width: 24,
              height: 24,
              child: Icon(
                searching ? Icons.search : Icons.terminal_outlined,
                size: FanCadTokens.iconMedium,
                color: tokens.textMuted,
              ),
            ),
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
                      const SingleActivator(LogicalKeyboardKey.escape):
                          _onEscape,
                    },
                    child: Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: _onKey,
                      child: FanCadTextField(
                        controller: _input,
                        focusNode: widget.focusNode,
                        hintText: searching
                            ? context.l10n.hint_search_text
                            : awaiting
                            ? hint
                            : prompt.isEmpty
                            ? context.l10n.hint_type_command
                            : null,
                        onSubmitted: (raw) {
                          if (_searching) {
                            final hit = _suggest?.currentText;
                            if (hit != null) {
                              _jumpToTextHit(ref, widget.workspace, hit);
                            }
                            return;
                          }
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
          FanCadIconButton(
            key: const Key('canvas-hud-mode-switch'),
            icon: Icons.swap_horiz,
            tooltip: searching
                ? context.l10n.hud_switch_to_command
                : context.l10n.hud_switch_to_search,
            size: 24,
            iconSize: FanCadTokens.iconMedium,
            onPressed: () {
              if (searching) {
                _leaveSearch();
                widget.focusNode.requestFocus();
                return;
              }
              final tab = widget.workspace.active;
              if (tab == null || tab.isStartPage) return;
              ref
                  .read(commandLineNotifierProvider.notifier)
                  .setPaletteOpen(false);
              tab.textSearch.request();
            },
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

/// Placeholder for a prompt, matched to the kind of answer it accepts.
String commandLineHint(AppLocalizations l10n, CommandPromptKind kind) =>
    switch (kind) {
      CommandPromptKind.point => l10n.hint_click_or_type,
      CommandPromptKind.measure => l10n.hint_click_or_number,
      CommandPromptKind.text => l10n.hint_type_text,
      CommandPromptKind.number => l10n.hint_type_number,
      CommandPromptKind.selection => l10n.hint_select_objects,
      CommandPromptKind.choice => l10n.hint_choose_option,
    };

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
