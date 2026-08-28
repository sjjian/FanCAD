import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../widgets/shell_field.dart';
import 'command_line_model.dart';

/// Polar distance / angle fields that follow the cursor during a point prompt.
///
/// The locks live on [ToolController.dynamicInput]. This widget only edits
/// them, submits the resulting point, and stays out of the command handlers.
class DynamicInputHud extends StatefulWidget {
  const DynamicInputHud({
    super.key,
    required this.tools,
    required this.viewport,
    required this.prompt,
    required this.distanceFocus,
    required this.angleFocus,
  });

  final ToolController tools;
  final CadViewport viewport;
  final String prompt;
  final FocusNode distanceFocus;
  final FocusNode angleFocus;

  static bool isTypeInCharacter(String? character) {
    if (character == null || character.isEmpty) return false;
    final code = character.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        character == '.' ||
        character == '-' ||
        character == '<';
  }

  @override
  State<DynamicInputHud> createState() => DynamicInputHudState();
}

class DynamicInputHudState extends State<DynamicInputHud> {
  final TextEditingController _distance = TextEditingController();
  final TextEditingController _angle = TextEditingController();
  bool _distanceDirty = false;
  bool _angleDirty = false;
  bool _syncing = false;

  ToolController get _tools => widget.tools;
  DynamicInput get _dyn => _tools.dynamicInput;

  bool get hasFieldFocus =>
      widget.distanceFocus.hasFocus || widget.angleFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    _tools.addListener(_syncFromCursor);
    widget.distanceFocus.addListener(_onFocus);
    widget.angleFocus.addListener(_onFocus);
    _syncFromCursor(rebuild: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!hasFieldFocus) widget.distanceFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _tools.removeListener(_syncFromCursor);
    widget.distanceFocus.removeListener(_onFocus);
    widget.angleFocus.removeListener(_onFocus);
    _distance.dispose();
    _angle.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    if (widget.distanceFocus.hasFocus) {
      _dyn.focusedField = DynamicInputField.distance;
      if (!_distanceDirty) _selectAll(_distance);
    } else if (widget.angleFocus.hasFocus) {
      _dyn.focusedField = DynamicInputField.angle;
      if (!_angleDirty) _selectAll(_angle);
    }
    setState(() {});
  }

  void takeTyping(String character) {
    final intoAngle = character == '<';
    final node = intoAngle ? widget.angleFocus : widget.distanceFocus;
    final field = intoAngle ? DynamicInputField.angle : DynamicInputField.distance;
    _dyn.focusedField = field;
    node.requestFocus();
    if (intoAngle) {
      _angleDirty = true;
      _setText(_angle, character == '<' ? '' : character);
    } else {
      _distanceDirty = true;
      _setText(_distance, character);
    }
    setState(() {});
  }

  void _syncFromCursor({bool rebuild = true}) {
    if (!mounted) return;
    final base = _tools.activeTool?.basePoint;
    final cursor = _tools.cursor;
    if (base == null || cursor == null) return;
    _syncing = true;
    if (!_distanceDirty) {
      _setLiveText(
        _distance,
        DynamicInput.formatNumber(_dyn.distanceOf(base, cursor)),
      );
    }
    if (!_angleDirty) {
      final degrees =
          normalizeAngle(_dyn.angleOf(base, cursor)) * 180 / math.pi;
      _setLiveText(_angle, DynamicInput.formatNumber(degrees));
    }
    _syncing = false;
    if (rebuild) setState(() {});
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text == value &&
        controller.selection == TextSelection.collapsed(offset: value.length)) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  /// Live readouts stay fully selected so the first keystroke replaces them.
  void _setLiveText(TextEditingController controller, String value) {
    final selection = TextSelection(baseOffset: 0, extentOffset: value.length);
    if (controller.text == value && controller.selection == selection) return;
    controller.value = TextEditingValue(text: value, selection: selection);
  }

  void _selectAll(TextEditingController controller) {
    final text = controller.text;
    if (text.isEmpty) return;
    final selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    if (controller.selection == selection) return;
    controller.selection = selection;
  }

  double? _parseDistance() => CoordinateParser.parseDistance(_distance.text);

  double? _parseAngle() {
    var text = _angle.text.trim();
    if (text.startsWith('<')) text = text.substring(1).trim();
    if (text.endsWith('°')) text = text.substring(0, text.length - 1).trim();
    return CoordinateParser.parseAngle(text);
  }

  void _cycle({required bool reverse}) {
    final current = widget.distanceFocus.hasFocus
        ? DynamicInputField.distance
        : DynamicInputField.angle;
    _lockCurrentIfValid(current);
    final next = reverse
        ? (current == DynamicInputField.distance
              ? DynamicInputField.angle
              : DynamicInputField.distance)
        : (current == DynamicInputField.distance
              ? DynamicInputField.angle
              : DynamicInputField.distance);
    _dyn.focusedField = next;
    if (next == DynamicInputField.distance) {
      _distanceDirty = false;
      widget.distanceFocus.requestFocus();
      _selectAll(_distance);
    } else {
      _angleDirty = false;
      widget.angleFocus.requestFocus();
      _selectAll(_angle);
    }
    _tools.applyDynamicLocks();
  }

  void _lockCurrentIfValid(DynamicInputField field) {
    if (field == DynamicInputField.distance) {
      final value = _parseDistance();
      if (value != null) {
        _dyn.lockedDistance = value;
        _distanceDirty = false;
      }
      return;
    }
    final value = _parseAngle();
    if (value != null) {
      _dyn.lockedAngle = value;
      _angleDirty = false;
    }
  }

  void _submit({required DynamicInputField field}) {
    final base = _tools.activeTool?.basePoint;
    final cursor = _tools.cursor;
    if (base == null || cursor == null) return;

    final typedDistance = field == DynamicInputField.distance
        ? _parseDistance()
        : null;
    final typedAngle = field == DynamicInputField.angle ? _parseAngle() : null;
    if (typedDistance != null) _dyn.lockedDistance = typedDistance;
    if (typedAngle != null) _dyn.lockedAngle = typedAngle;

    final distance = _dyn.lockedDistance ?? _dyn.distanceOf(base, cursor);
    final angle = _dyn.lockedAngle ?? _dyn.angleOf(base, cursor);
    final point = (_dyn.lockedDistance != null || _dyn.lockedAngle != null)
        ? base + Vec2.polar(angle, distance)
        : cursor;
    _tools.acceptDynamicPoint(point);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _cycle(reverse: HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cursor = _tools.cursor;
    if (!_tools.showDynamicInput || cursor == null) {
      return const SizedBox.shrink();
    }

    final screen = widget.viewport.toScreen(cursor);
    const gap = 18.0;
    const width = 280.0;
    final maxX = widget.viewport.size.width;
    final maxY = widget.viewport.size.height;
    var left = screen.dx + gap;
    var top = screen.dy + gap;
    if (left + width > maxX - 8) left = screen.dx - width - 8;
    if (left < 8) left = 8;
    if (top + 40 > maxY - 8) top = screen.dy - 48;
    if (top < 8) top = 8;

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: tokens.surfaceOverlay.withValues(alpha: 0.94),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
        child: Container(
          key: const Key('dynamic-input-hud'),
          padding: const EdgeInsets.symmetric(
            horizontal: FanCadTokens.space2,
            vertical: FanCadTokens.space1,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
            border: Border.all(color: tokens.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.prompt.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Padding(
                    padding: const EdgeInsets.only(right: FanCadTokens.space2),
                    child: Text(
                      widget.prompt,
                      style: tokens.labelStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              _Field(
                key: const Key('dynamic-input-distance'),
                width: 72,
                controller: _distance,
                focusNode: widget.distanceFocus,
                locked: _dyn.lockedDistance != null,
                tokens: tokens,
                onKey: _onKey,
                onChanged: (value) {
                  if (_syncing) return;
                  _distanceDirty = true;
                  _dyn.lockedDistance = CoordinateParser.parseDistance(value);
                  _tools.applyDynamicLocks();
                },
                onSubmitted: (_) =>
                    _submit(field: DynamicInputField.distance),
              ),
              const SizedBox(width: FanCadTokens.space1),
              _Field(
                key: const Key('dynamic-input-angle'),
                width: 80,
                controller: _angle,
                focusNode: widget.angleFocus,
                locked: _dyn.lockedAngle != null,
                tokens: tokens,
                prefix: '< ',
                suffix: '°',
                onKey: _onKey,
                onChanged: (value) {
                  if (_syncing) return;
                  _angleDirty = true;
                  _dyn.lockedAngle = _parseAngle();
                  _tools.applyDynamicLocks();
                },
                onSubmitted: (_) => _submit(field: DynamicInputField.angle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.width,
    required this.controller,
    required this.focusNode,
    required this.locked,
    required this.tokens,
    required this.onKey,
    required this.onChanged,
    required this.onSubmitted,
    this.prefix,
    this.suffix,
  });

  final double width;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool locked;
  final FanCadTokens tokens;
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKey;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    return Focus(
      onKeyEvent: onKey,
      child: Container(
        width: width,
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space1),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: focused ? tokens.accent.withValues(alpha: 0.28) : tokens.surfaceRaised,
          borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          border: Border.all(
            color: locked || focused ? tokens.accent : tokens.border,
          ),
        ),
        child: ShellTextField(
          controller: controller,
          focusNode: focusNode,
          style: tokens.monoStyle.copyWith(fontSize: 11),
          prefix: prefix == null
              ? null
              : Text(prefix!, style: tokens.monoStyle.copyWith(fontSize: 11)),
          suffix: suffix == null
              ? null
              : Text(suffix!, style: tokens.monoStyle.copyWith(fontSize: 11)),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}
