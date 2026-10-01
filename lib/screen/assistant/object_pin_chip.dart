import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/assistant.dart';
import '../widgets/file_name.dart';
import '../widgets/tokens.dart';

/// The drawing on screen, so a region chip can say it belongs elsewhere.
class AssistantDrawingScope extends InheritedWidget {
  const AssistantDrawingScope({
    super.key,
    required this.drawingId,
    required super.child,
  });

  final String? drawingId;

  static String? idOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AssistantDrawingScope>()
        ?.drawingId;
  }

  @override
  bool updateShouldNotify(AssistantDrawingScope oldWidget) =>
      drawingId != oldWidget.drawingId;
}

/// Shared object/drawing pin chip: composer can delete, transcript only flashes.
class ObjectPinChip extends StatefulWidget {
  const ObjectPinChip({
    super.key,
    required this.pin,
    this.index = 0,
    this.removable = false,
    this.onFlash,
    this.onHover,
    this.onRemove,
  });

  final ComposerPinModel? pin;
  final int index;
  final bool removable;
  final VoidCallback? onFlash;
  final ValueChanged<bool>? onHover;
  final VoidCallback? onRemove;

  @override
  State<ObjectPinChip> createState() => _ObjectPinChipState();
}

class _ObjectPinChipState extends State<ObjectPinChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final pin = widget.pin;
    final labelStyle = tokens.labelStyle.copyWith(
      fontSize: 12,
      color: tokens.text,
    );
    final label = switch (pin?.kind) {
      ComposerPinKind.drawing => Tooltip(
        message: pin!.drawingName,
        child: FileName(
          name: pin.drawingName,
          maxWidth: double.infinity,
          style: labelStyle,
        ),
      ),
      ComposerPinKind.bbox => Text(
        _bboxSize(pin!),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: labelStyle,
      ),
      ComposerPinKind.entity || null => Text(
        pin == null ? '…' : context.l10n.objects_count(pin.ids.length),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: labelStyle,
      ),
    };
    final kindIcon = switch (pin?.kind) {
      ComposerPinKind.drawing => Icons.insert_drive_file_outlined,
      ComposerPinKind.bbox => Icons.crop_free,
      ComposerPinKind.entity || null => Icons.category_outlined,
    };
    final showRemove = widget.removable && _hovered;
    final otherDrawing = _otherDrawingTooltip(context, pin);
    final chip = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hovered = true);
          widget.onHover?.call(true);
        },
        onExit: (_) {
          setState(() => _hovered = false);
          widget.onHover?.call(false);
        },
        child: Container(
          key: widget.removable
              ? Key('assistant-pin-${widget.index}')
              : const Key('assistant-pin-chip'),
          padding: const EdgeInsets.fromLTRB(5, 1, 6, 1),
          decoration: BoxDecoration(
            color: tokens.selection,
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
            border: Border.all(color: tokens.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: showRemove
                    ? () {
                        widget.onHover?.call(false);
                        widget.onRemove?.call();
                      }
                    : widget.onFlash,
                child: Icon(
                  key: showRemove
                      ? Key('assistant-pin-remove-${widget.index}')
                      : null,
                  showRemove ? Icons.close : kindIcon,
                  size: 12,
                  color: tokens.accent,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onFlash,
                  child: label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (otherDrawing == null) return chip;
    return Tooltip(
      message: otherDrawing,
      waitDuration: Duration.zero,
      child: chip,
    );
  }

  /// A region on another drawing stays off this canvas. The chip says so
  /// while the pointer is over it.
  String? _otherDrawingTooltip(BuildContext context, ComposerPinModel? pin) {
    if (pin?.kind != ComposerPinKind.bbox) return null;
    final activeId = AssistantDrawingScope.idOf(context);
    if (activeId == null || pin!.tabId == activeId) return null;
    final titled = pin.tabTitle.trim();
    if (titled.isEmpty) return context.l10n.bbox_other_drawing;
    return context.l10n.bbox_other_drawing_named(titled);
  }
}

/// Turns `@objects` / `@drawing` / `@bbox` tags in a sentence into chips.
class PinAwareText extends StatelessWidget {
  const PinAwareText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.onFlash,
    this.onHover,
    this.resolve,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final ValueChanged<ComposerPinModel>? onFlash;
  final ValueChanged<ComposerPinModel?>? onHover;
  final ComposerPinModel Function(ComposerPinModel pin)? resolve;

  @override
  Widget build(BuildContext context) {
    if (!composerPinTextHasTags(text)) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    final spans = splitComposerPinSpans(text);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final span in spans)
            switch (span) {
              ComposerPinChipModel(:final pin) => WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ObjectPinChip(
                  pin: resolve?.call(pin) ?? pin,
                  onFlash: onFlash == null ? null : () => onFlash!(pin),
                  onHover: onHover == null
                      ? null
                      : (hovered) => onHover!(hovered ? pin : null),
                ),
              ),
              ComposerPinTextModel(:final text) when text.isNotEmpty =>
                TextSpan(text: text),
              ComposerPinTextModel() => const TextSpan(),
            },
        ],
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

String _bboxSize(ComposerPinModel pin) {
  return '${_bboxMeasure((pin.x2 - pin.x1).abs())} × ${_bboxMeasure((pin.y2 - pin.y1).abs())}';
}

String _bboxMeasure(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 1e-6) return rounded.toInt().toString();
  return value.toStringAsFixed(1);
}
