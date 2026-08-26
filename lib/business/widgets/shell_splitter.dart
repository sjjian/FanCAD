import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A transparent drag mask over a pane seam.
///
/// The widget is the full grab target. The parent overlays it so a leftover
/// gutter cannot steal the canvas, and so the mask wins hit tests.
class ShellSplitter extends StatefulWidget {
  const ShellSplitter({
    super.key,
    required this.axis,
    required this.onDrag,
    this.onDragEnd,
    this.onDoubleTap,
    this.thickness = 1,
    this.hitSize = FanCadTokens.splitterHit,
    this.strong = false,
  });

  /// The axis the splitter runs along; a vertical splitter resizes horizontally.
  final Axis axis;

  final void Function(double delta) onDrag;
  final VoidCallback? onDragEnd;

  /// A double-click snaps the pane to a remembered large or small size.
  final VoidCallback? onDoubleTap;
  final double thickness;
  final double hitSize;

  /// A harder rule, used where two similar surfaces would otherwise merge.
  final bool strong;

  /// Overlay origin so the 1px hairline sits on [seam], not a half-pixel.
  static double overlayOrigin(
    double seam, {
    double hitSize = FanCadTokens.splitterHit,
  }) => seam - (hitSize ~/ 2).toDouble();

  @override
  State<ShellSplitter> createState() => _ShellSplitterState();
}

class _ShellSplitterState extends State<ShellSplitter> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isVertical = widget.axis == Axis.vertical;
    return SizedBox(
      width: isVertical ? widget.hitSize : null,
      height: isVertical ? null : widget.hitSize,
      child: MouseRegion(
        cursor: isVertical
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        onEnter: (_) => setState(() => _active = true),
        onExit: (_) => setState(() => _active = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onDoubleTap,
          onHorizontalDragUpdate: isVertical
              ? (details) => widget.onDrag(details.delta.dx)
              : null,
          onHorizontalDragEnd: isVertical
              ? (_) => widget.onDragEnd?.call()
              : null,
          onVerticalDragUpdate: isVertical
              ? null
              : (details) => widget.onDrag(details.delta.dy),
          onVerticalDragEnd: isVertical
              ? null
              : (_) => widget.onDragEnd?.call(),
          child: Stack(
            children: [
              const ColoredBox(
                color: Colors.transparent,
                child: SizedBox.expand(),
              ),
              Positioned(
                left: isVertical
                    ? ((widget.hitSize - widget.thickness) ~/ 2).toDouble()
                    : 0,
                top: isVertical
                    ? 0
                    : ((widget.hitSize - widget.thickness) ~/ 2).toDouble(),
                width: isVertical ? widget.thickness : null,
                height: isVertical ? null : widget.thickness,
                right: isVertical ? null : 0,
                bottom: isVertical ? 0 : null,
                child: ColoredBox(
                  color: _active
                      ? tokens.accent
                      : widget.strong
                      ? tokens.borderStrong
                      : tokens.border,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
