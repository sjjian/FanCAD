import 'package:flutter/material.dart';

import '../../services/composer_pin.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';

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

  final ComposerPin? pin;
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
    final label = pin == null
        ? '…'
        : pin.kind == ComposerPinKind.entity
        ? context.l10n.objects_count(pin.ids.length)
        : pin.drawingName;
    final kindIcon = pin?.kind == ComposerPinKind.entity
        ? Icons.category_outlined
        : Icons.insert_drive_file_outlined;
    final showRemove = widget.removable && _hovered;
    return Padding(
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onFlash,
                child: Text(
                  label,
                  style: tokens.labelStyle.copyWith(
                    fontSize: 12,
                    color: tokens.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Turns `@objects` / `@drawing` tags in a sentence into [ObjectPinChip]s.
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
  final ValueChanged<ComposerPin>? onFlash;
  final ValueChanged<ComposerPin?>? onHover;
  final ComposerPin Function(ComposerPin pin)? resolve;

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
            if (span.pin != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ObjectPinChip(
                  pin: resolve?.call(span.pin!) ?? span.pin,
                  onFlash: onFlash == null ? null : () => onFlash!(span.pin!),
                  onHover: onHover == null
                      ? null
                      : (hovered) => onHover!(hovered ? span.pin : null),
                ),
              )
            else if ((span.text ?? '').isNotEmpty)
              TextSpan(text: span.text),
        ],
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
