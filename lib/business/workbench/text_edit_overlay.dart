import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../commands/edit/helpers.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import '../widgets/shell_canvas_window.dart';
import '../widgets/shell_icon_button.dart';

const _justifyCells = ['tl', 'tc', 'tr', 'ml', 'mc', 'mr', 'bl', 'bc', 'br'];

const _aciSwatches = [1, 2, 3, 4, 5, 6, 7];
const _labelWidth = 72.0;
const _fieldHeight = 40.0;
const _footerHeight = 32.0;

/// A HUD card parked at the double-click. Matching CAD font size and rotation
/// on top of the drawing jittered; a fixed 12px field at the cursor stays put.
class TextEditOverlay extends StatefulWidget {
  const TextEditOverlay({
    super.key,
    required this.entity,
    required this.viewport,
    this.anchor,
    required this.onCommit,
    required this.onCancel,
  });

  final CadEntity entity;
  final CadViewport viewport;

  /// World point under the double-click. The card's top-left sits here so
  /// it lines up with the cursor instead of the CAD insertion.
  final Vec2? anchor;
  final ValueChanged<TextEditCommit> onCommit;
  final VoidCallback onCancel;

  @override
  State<TextEditOverlay> createState() => _TextEditOverlayState();
}

class _TextEditOverlayState extends State<TextEditOverlay> {
  late final TextEditingController _controller;
  late final TextEditingController _height;
  late final FocusNode _focus;
  late final bool _multiline;
  late final bool _canHeight;
  late final bool _canJustify;
  late final String? _initialJustify;
  late CadColor _color;
  String? _justify;

  @override
  void initState() {
    super.initState();
    _multiline = textEditPlacementOf(widget.entity)?.multiline ?? false;
    _canHeight = textHeightOf(widget.entity) != null;
    _canJustify = textJustifyKeyOf(widget.entity) != null;
    _initialJustify = textJustifyKeyOf(widget.entity);
    _justify = _initialJustify;
    _color = widget.entity.props.color;
    _controller = TextEditingController(
      text: textEditFieldValue(widget.entity),
    );
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    final cap = textHeightOf(widget.entity);
    _height = TextEditingController(text: cap == null ? '' : _heightText(cap));
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
    _controller.dispose();
    _height.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = double.tryParse(_height.text.trim());
    final currentHeight = textHeightOf(widget.entity);
    widget.onCommit(
      TextEditCommit(
        field: _controller.text,
        height: _canHeight && parsed != null && parsed != currentHeight
            ? parsed
            : null,
        color: _color != widget.entity.props.color ? _color : null,
        justify: _justify != null && _justify != _initialJustify
            ? _justify
            : null,
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
    final contentsLabel = widget.entity is DimensionEntity
        ? l10n.text
        : l10n.contents;

    return ShellCanvasWindow(
      title: l10n.command_edit_text_object,
      origin: origin,
      bounds: viewport.size,
      initialSize: Size(300, _multiline ? 280 : 232),
      onClose: widget.onCancel,
      onBarrierTap: _commit,
      footer: SizedBox(
        height: _footerHeight,
        child: Padding(
          padding: const EdgeInsets.only(
            left: FanCadTokens.space2,
            right: FanCadTokens.space2,
          ),
          child: Row(
            children: [
              const Spacer(),
              ShellIconButton(
                key: const Key('text-edit-save'),
                icon: Icons.check,
                tooltip: l10n.save,
                onPressed: _commit,
              ),
            ],
          ),
        ),
      ),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FanCadTokens.space3,
              FanCadTokens.space3,
              FanCadTokens.space3,
              FanCadTokens.space2,
            ),
            child: Column(
              children: [
                _FormRow(
                  label: contentsLabel,
                  expand: true,
                  child: TextField(
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
                    decoration: _fieldDecoration(tokens),
                    onSubmitted: (_) => _commit(),
                  ),
                ),
                if (_canHeight) ...[
                  const SizedBox(height: FanCadTokens.space2),
                  _FormRow(
                    label: l10n.height,
                    child: TextField(
                      key: const Key('text-edit-height'),
                      controller: _height,
                      style: tokens.monoStyle,
                      cursorColor: tokens.accent,
                      cursorWidth: 1.5,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _fieldDecoration(tokens),
                    ),
                  ),
                ],
                const SizedBox(height: FanCadTokens.space2),
                _FormRow(
                  label: l10n.colour,
                  child: Row(
                    children: [
                      _ColorSwatch(
                        color: _color,
                        onColor: (color) => setState(() => _color = color),
                      ),
                      if (_canJustify) ...[
                        const Spacer(),
                        _JustifyGrid(
                          selected: _justify,
                          onSelected: (key) => setState(() => _justify = key),
                        ),
                      ],
                    ],
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

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.label,
    required this.child,
    this.expand = false,
  });

  final String label;
  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final row = Row(
      crossAxisAlignment: expand
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _labelWidth,
          child: Padding(
            padding: EdgeInsets.only(top: expand ? FanCadTokens.space2 : 0),
            child: Text(
              label,
              style: tokens.labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
    if (expand) return Expanded(child: row);
    return SizedBox(height: _fieldHeight, child: row);
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.onColor});

  final CadColor color;
  final ValueChanged<CadColor> onColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final palette = tokens.isDark ? AciPalette.dark : AciPalette.light;
    final swatch = color.isInherited
        ? tokens.textFaint
        : palette.colorOf(color);
    return PopupMenuButton<CadColor>(
      key: const Key('text-edit-color'),
      tooltip: context.l10n.colour,
      padding: EdgeInsets.zero,
      onSelected: onColor,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: const CadColor.byLayer(),
          child: Text(context.l10n.by_layer),
        ),
        for (final index in _aciSwatches)
          PopupMenuItem(
            value: CadColor.indexed(index),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette.colorOf(CadColor.indexed(index)),
                    border: Border.all(color: tokens.border),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: FanCadTokens.space2),
                Text('$index'),
              ],
            ),
          ),
      ],
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: swatch,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
        ),
      ),
    );
  }
}

class _JustifyGrid extends StatelessWidget {
  const _JustifyGrid({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      width: 54,
      height: 28,
      child: GridView.count(
        key: const Key('text-edit-justify'),
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final code in _justifyCells)
            GestureDetector(
              onTap: () => onSelected(code),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected == code ? tokens.accent : tokens.borderMuted,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CancelTextIntent extends Intent {
  const _CancelTextIntent();
}

class _CommitTextIntent extends Intent {
  const _CommitTextIntent();
}

String _heightText(double value) {
  final text = value.toStringAsFixed(4);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

InputDecoration _fieldDecoration(FanCadTokens tokens) {
  final radius = BorderRadius.circular(FanCadTokens.radius);
  final side = BorderSide(color: tokens.borderStrong);
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: tokens.surfaceRaised,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: FanCadTokens.space2,
      vertical: FanCadTokens.space2,
    ),
    border: OutlineInputBorder(borderRadius: radius, borderSide: side),
    enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: side),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: tokens.accent, width: 1.5),
    ),
  );
}
