import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../commands/edit/helpers.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import '../widgets/shell_canvas_window.dart';
import '../widgets/shell_hairline.dart';
import '../widgets/shell_icon_button.dart';
import '../widgets/shell_menu.dart';

const _aciSwatches = [1, 2, 3, 4, 5, 6, 7];
const _chipHeight = 22.0;
const _styleChipWidth = 108.0;
const _colorChipWidth = 92.0;
const _numberFieldWidth = 44.0;

/// A floating card parked at the double-click.
class TextEditOverlay extends StatefulWidget {
  const TextEditOverlay({
    super.key,
    required this.entity,
    required this.viewport,
    this.styleNames = const [],
    this.document,
    this.anchor,
    required this.onCommit,
    this.onPreview,
    required this.onCancel,
  });

  final CadEntity entity;
  final CadViewport viewport;

  /// Drawing text styles, used by the style menu.
  final List<String> styleNames;

  /// Needed so a dimension field can read the `*D` note instead of the
  /// stored measurement.
  final CadDocument? document;

  /// World point under the double-click. The card's top-left sits here so
  /// it lines up with the cursor instead of the CAD insertion.
  final Vec2? anchor;
  final ValueChanged<TextEditCommit> onCommit;

  /// Live editor state, so the CAD entity can follow before save.
  final ValueChanged<TextEditCommit>? onPreview;
  final VoidCallback onCancel;

  @override
  State<TextEditOverlay> createState() => _TextEditOverlayState();
}

class _TextEditOverlayState extends State<TextEditOverlay> {
  late final TextEditingController _controller;
  late final TextEditingController _height;
  late final TextEditingController _rotation;
  late final TextEditingController _columnWidth;
  late final TextEditingController _widthFactor;
  late final TextEditingController _oblique;
  late final FocusNode _focus;
  late final bool _multiline;
  late final bool _canHeight;
  late final bool _canRotation;
  late final bool _canStyle;
  late final bool _canColumnWidth;
  late final bool _canWidthFactor;
  late final bool _canOblique;
  late final bool _canJustify;
  late final String? _initialJustify;
  late final String? _initialStyle;
  late CadColor _color;
  String? _justify;
  String? _style;
  late String _checkpoint;
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  var _applyingHistory = false;

  @override
  void initState() {
    super.initState();
    final entity = widget.entity;
    _multiline = textEditPlacementOf(entity)?.multiline ?? false;
    _canHeight = textHeightOf(entity) != null;
    _canRotation = textRotationOf(entity, document: widget.document) != null;
    _canStyle = textStyleNameOf(entity) != null;
    _canColumnWidth = textColumnWidthOf(entity) != null;
    _canWidthFactor = textWidthFactorOf(entity) != null;
    _canOblique = textObliqueOf(entity) != null;
    _canJustify = textJustifyKeyOf(entity) != null;
    _initialJustify = textJustifyKeyOf(entity);
    _initialStyle = textStyleNameOf(entity);
    _justify = _initialJustify;
    _style = _initialStyle;
    _color = entity.props.color;
    _controller = TextEditingController(
      text: textEditFieldValue(entity, document: widget.document),
    );
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _height = TextEditingController(text: _numberOrEmpty(textHeightOf(entity)));
    _rotation = TextEditingController(
      text: _numberOrEmpty(
        _degreesOf(textRotationOf(entity, document: widget.document)),
      ),
    );
    _columnWidth = TextEditingController(
      text: _numberOrEmpty(textColumnWidthOf(entity)),
    );
    _widthFactor = TextEditingController(
      text: _numberOrEmpty(textWidthFactorOf(entity)),
    );
    _oblique = TextEditingController(
      text: _numberOrEmpty(_degreesOf(textObliqueOf(entity))),
    );
    _checkpoint = _controller.text;
    _controller.addListener(_onContentsChanged);
    _height.addListener(_emitPreview);
    _rotation.addListener(_emitPreview);
    _columnWidth.addListener(_emitPreview);
    _widthFactor.addListener(_emitPreview);
    _oblique.addListener(_emitPreview);
    _focus = FocusNode(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        if (!_multiline && event.logicalKey == LogicalKeyboardKey.enter) {
          _commit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onContentsChanged);
    _height.removeListener(_emitPreview);
    _rotation.removeListener(_emitPreview);
    _columnWidth.removeListener(_emitPreview);
    _widthFactor.removeListener(_emitPreview);
    _oblique.removeListener(_emitPreview);
    _controller.dispose();
    _height.dispose();
    _rotation.dispose();
    _columnWidth.dispose();
    _widthFactor.dispose();
    _oblique.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<String> get _styles {
    final names = <String>[];
    for (final name in widget.styleNames) {
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
    }
    final current = _style;
    if (current != null && current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }
    return names;
  }

  bool get _hasFormatRow =>
      _canJustify || _canColumnWidth || _canWidthFactor || _canOblique;

  String get _hAlign =>
      _justify != null && _justify!.length > 1 ? _justify![1] : 'l';

  String get _vAlign =>
      _justify != null && _justify!.isNotEmpty ? _justify![0] : 'b';

  void _onContentsChanged() {
    if (_applyingHistory) return;
    final text = _controller.text;
    if (text == _checkpoint) return;
    _undoStack.add(_checkpoint);
    _checkpoint = text;
    _redoStack.clear();
    setState(() {});
    _emitPreview();
  }

  void _restoreContents(String text) {
    _applyingHistory = true;
    _checkpoint = text;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _applyingHistory = false;
    setState(() {});
    _emitPreview();
  }

  void _undoContents() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_controller.text);
    _restoreContents(_undoStack.removeLast());
  }

  void _redoContents() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_controller.text);
    _restoreContents(_redoStack.removeLast());
  }

  void _setHAlign(String col) {
    final row = _justify != null && _justify!.isNotEmpty
        ? _justify![0]
        : (_multiline ? 't' : 'b');
    setState(() => _justify = '$row$col');
    _emitPreview();
  }

  void _setVAlign(String row) {
    final col = _justify != null && _justify!.length > 1 ? _justify![1] : 'l';
    setState(() => _justify = '$row$col');
    _emitPreview();
  }

  void _setStyle(String name) {
    setState(() => _style = name);
    _emitPreview();
  }

  void _setColor(CadColor color) {
    setState(() => _color = color);
    _emitPreview();
  }

  TextEditCommit _liveCommit() => TextEditCommit(
    field: _controller.text,
    height: _liveNumber(_height, _canHeight),
    color: _color,
    justify: _justify,
    width: _liveNumber(_columnWidth, _canColumnWidth),
    rotation: _liveNumber(_rotation, _canRotation),
    style: _style,
    widthFactor: _liveNumber(_widthFactor, _canWidthFactor),
    oblique: _liveNumber(_oblique, _canOblique),
  );

  double? _liveNumber(TextEditingController controller, bool allowed) {
    if (!allowed) return null;
    return double.tryParse(controller.text.trim());
  }

  void _emitPreview() {
    widget.onPreview?.call(_liveCommit());
  }

  void _commit() {
    widget.onCommit(
      TextEditCommit(
        field: _controller.text,
        height: _changedNumber(_height, textHeightOf(widget.entity)),
        color: _color != widget.entity.props.color ? _color : null,
        justify: _justify != null && _justify != _initialJustify
            ? _justify
            : null,
        width: _changedNumber(_columnWidth, textColumnWidthOf(widget.entity)),
        rotation: _changedNumber(
          _rotation,
          _degreesOf(textRotationOf(widget.entity, document: widget.document)),
        ),
        style: _canStyle && _style != null && _style != _initialStyle
            ? _style
            : null,
        widthFactor: _changedNumber(
          _widthFactor,
          textWidthFactorOf(widget.entity),
        ),
        oblique: _changedNumber(
          _oblique,
          _degreesOf(textObliqueOf(widget.entity)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final placement = textEditPlacementOf(widget.entity);
    if (placement == null) return const SizedBox.shrink();
    final tokens = context.tokens;
    final l10n = context.l10n;
    final viewport = widget.viewport;
    final origin = viewport.toScreen(widget.anchor ?? placement.origin);
    final toolbarHeight =
        FanCadTokens.filterBarHeight +
        (_hasFormatRow ? FanCadTokens.filterBarHeight : 0) +
        FanCadTokens.space1 * 2;
    final noteHeight = _multiline ? 120.0 : 88.0;

    return ShellCanvasWindow(
      title: l10n.edit_text_object_window(widget.entity.displayId),
      origin: origin,
      bounds: viewport.size,
      initialSize: Size(
        520,
        FanCadTokens.tabBarHeight + toolbarHeight + noteHeight + 1,
      ),
      minSize: const Size(380, 200),
      onClose: widget.onCancel,
      onBarrierTap: _commit,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _commit,
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _commit,
        },
        child: Shortcuts(
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.escape):
                const _CancelTextIntent(),
            if (!_multiline)
              const SingleActivator(LogicalKeyboardKey.enter):
                  const _CommitTextIntent(),
          },
          child: Actions(
            actions: {
              _CancelTextIntent: CallbackAction<_CancelTextIntent>(
                onInvoke: (_) {
                  widget.onCancel();
                  return null;
                },
              ),
              _CommitTextIntent: CallbackAction<_CommitTextIntent>(
                onInvoke: (_) {
                  _commit();
                  return null;
                },
              ),
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: tokens.surfaceRaised,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: FanCadTokens.space1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _toolbarLine(
                          leading: [
                            _historyCluster(l10n),
                            if (_canStyle) _styleChip(tokens, l10n),
                            _colorChip(tokens, l10n),
                            if (_canHeight)
                              _iconField(
                                key: const Key('text-edit-height'),
                                icon: Icons.format_size,
                                tooltip: l10n.height,
                                controller: _height,
                                tokens: tokens,
                              ),
                            if (_canRotation)
                              _iconField(
                                key: const Key('text-edit-rotation'),
                                icon: Icons.rotate_right,
                                tooltip: l10n.rotation,
                                controller: _rotation,
                                tokens: tokens,
                              ),
                          ],
                        ),
                        if (_hasFormatRow)
                          _toolbarLine(
                            leading: [
                              if (_canJustify) _justifyGroup(tokens, l10n),
                              if (_canColumnWidth)
                                _iconField(
                                  key: const Key('text-edit-width'),
                                  icon: Icons.wrap_text,
                                  tooltip: l10n.column_width,
                                  controller: _columnWidth,
                                  tokens: tokens,
                                ),
                              if (_canOblique)
                                _iconField(
                                  key: const Key('text-edit-oblique'),
                                  icon: Icons.format_italic,
                                  tooltip: l10n.oblique,
                                  controller: _oblique,
                                  tokens: tokens,
                                ),
                              if (_canWidthFactor)
                                _iconField(
                                  key: const Key('text-edit-width-factor'),
                                  icon: Icons.text_fields,
                                  tooltip: l10n.width_factor,
                                  controller: _widthFactor,
                                  tokens: tokens,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const ShellHairline(strong: false),
                Expanded(
                  child: TextField(
                    key: const Key('text-edit-field'),
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlign: TextAlign.left,
                    textAlignVertical: TextAlignVertical.top,
                    style: tokens.bodyStyle,
                    cursorColor: tokens.accent,
                    cursorWidth: 1.5,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(
                        FanCadTokens.space1,
                        FanCadTokens.space2,
                        FanCadTokens.space1,
                        FanCadTokens.space2,
                      ),
                    ),
                    onSubmitted: (_) => _commit(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyCluster(AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShellIconButton(
          key: const Key('text-edit-save'),
          icon: Icons.save_outlined,
          tooltip: l10n.save,
          size: 24,
          onPressed: _commit,
        ),
        _itemGap(),
        ShellIconButton(
          key: const Key('text-edit-undo'),
          icon: Icons.undo,
          tooltip: l10n.undo,
          size: 24,
          enabled: _undoStack.isNotEmpty,
          onPressed: _undoContents,
        ),
        _itemGap(),
        ShellIconButton(
          key: const Key('text-edit-redo'),
          icon: Icons.redo,
          tooltip: l10n.redo,
          size: 24,
          enabled: _redoStack.isNotEmpty,
          onPressed: _redoContents,
        ),
      ],
    );
  }

  Widget _toolbarLine({required List<Widget> leading}) {
    return SizedBox(
      height: FanCadTokens.filterBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space1),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < leading.length; i++) ...[
                if (i > 0) _itemGap(),
                leading[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemGap() => const SizedBox(width: FanCadTokens.space1);

  Widget _chip({required Widget child, double? width}) {
    final tokens = context.tokens;
    return Container(
      width: width,
      height: _chipHeight,
      padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space1),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
      ),
      child: child,
    );
  }

  Widget _styleChip(FanCadTokens tokens, AppLocalizations l10n) {
    final styles = _styles;
    final label = Text(
      _style ?? '',
      style: tokens.monoStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (styles.isEmpty) {
      return _chip(
        width: _styleChipWidth,
        child: Align(
          alignment: Alignment.centerLeft,
          child: KeyedSubtree(key: const Key('text-edit-style'), child: label),
        ),
      );
    }
    return ShellMenuButton<String>(
      key: const Key('text-edit-style'),
      placement: ShellMenuPlacement.down,
      tooltip: l10n.style,
      onSelected: (name) => _setStyle(name),
      itemBuilder: (context) => [
        for (final name in styles)
          shellMenuItem(
            context,
            value: name,
            label: name,
            checked: name == _style,
          ),
      ],
      child: _chip(
        width: _styleChipWidth,
        child: Row(
          children: [
            Expanded(child: label),
            Icon(
              Icons.expand_more,
              size: FanCadTokens.iconSmall,
              color: tokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorChip(FanCadTokens tokens, AppLocalizations l10n) {
    final palette = tokens.isDark ? AciPalette.dark : AciPalette.light;
    final swatch = _color.isInherited
        ? tokens.textFaint
        : palette.colorOf(_color);
    return ShellMenuButton<CadColor>(
      key: const Key('text-edit-color'),
      placement: ShellMenuPlacement.down,
      tooltip: l10n.colour,
      onSelected: (color) => _setColor(color),
      itemBuilder: (context) => [
        shellMenuItem(
          context,
          value: const CadColor.byLayer(),
          label: l10n.by_layer,
          checked: _color.kind == ColorKind.byLayer,
        ),
        for (final index in _aciSwatches)
          shellMenuItem(
            context,
            value: CadColor.indexed(index),
            label: '$index',
            checked: _color.kind == ColorKind.indexed && _color.value == index,
            leading: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: palette.colorOf(CadColor.indexed(index)),
                border: Border.all(color: tokens.border),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
      child: _chip(
        width: _colorChipWidth,
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: swatch,
                border: Border.all(color: tokens.border),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: FanCadTokens.space1),
            Expanded(
              child: Text(
                _colorCaption(l10n),
                style: tokens.monoStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_more,
              size: FanCadTokens.iconSmall,
              color: tokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  String _colorCaption(AppLocalizations l10n) => switch (_color.kind) {
    ColorKind.byLayer => l10n.by_layer,
    ColorKind.byBlock => l10n.by_block,
    ColorKind.indexed => '${_color.value}',
    ColorKind.trueColor => '#${_color.value.toRadixString(16).padLeft(6, '0')}',
  };

  Widget _iconField({
    required Key key,
    required IconData icon,
    required String tooltip,
    required TextEditingController controller,
    required FanCadTokens tokens,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: _chip(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: FanCadTokens.iconSmall, color: tokens.textMuted),
            const SizedBox(width: FanCadTokens.space1),
            SizedBox(
              width: _numberFieldWidth,
              child: TextField(
                key: key,
                controller: controller,
                style: tokens.monoStyle,
                cursorColor: tokens.accent,
                cursorWidth: 1.5,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _commit(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _justifyGroup(FanCadTokens tokens, AppLocalizations l10n) {
    final buttons = [
      _alignButton(
        Icons.format_align_left,
        l10n.justify,
        _hAlign == 'l',
        () => _setHAlign('l'),
      ),
      _alignButton(
        Icons.format_align_center,
        l10n.justify,
        _hAlign == 'c',
        () => _setHAlign('c'),
      ),
      _alignButton(
        Icons.format_align_right,
        l10n.justify,
        _hAlign == 'r',
        () => _setHAlign('r'),
      ),
      _alignButton(
        Icons.vertical_align_top,
        l10n.justify,
        _vAlign == 't',
        () => _setVAlign('t'),
      ),
      _alignButton(
        Icons.vertical_align_center,
        l10n.justify,
        _vAlign == 'm',
        () => _setVAlign('m'),
      ),
      _alignButton(
        Icons.vertical_align_bottom,
        l10n.justify,
        _vAlign == 'b',
        () => _setVAlign('b'),
      ),
    ];
    return Row(
      key: const Key('text-edit-justify'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) _itemGap(),
          buttons[i],
        ],
      ],
    );
  }

  Widget _alignButton(
    IconData icon,
    String tooltip,
    bool active,
    VoidCallback onPressed,
  ) {
    return ShellIconButton(
      icon: icon,
      tooltip: tooltip,
      isActive: active,
      showActiveBar: true,
      size: 24,
      iconSize: FanCadTokens.iconSmall,
      onPressed: onPressed,
    );
  }
}

class _CancelTextIntent extends Intent {
  const _CancelTextIntent();
}

class _CommitTextIntent extends Intent {
  const _CommitTextIntent();
}

double? _degreesOf(double? radians) =>
    radians == null ? null : radians * 180 / math.pi;

String _numberOrEmpty(double? value) => value == null ? '' : _numberText(value);

String _numberText(double value) {
  final text = value.toStringAsFixed(4);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

double? _changedNumber(TextEditingController controller, double? current) {
  if (current == null) return null;
  final parsed = double.tryParse(controller.text.trim());
  if (parsed == null) return null;
  if ((parsed - current).abs() < 1e-9) return null;
  return parsed;
}
