import 'package:flutter/material.dart';

import '../../models/command_line.dart';
import 'tokens.dart';

/// A transparent drag mask over a pane seam.
///
/// The widget is the full grab target. The parent overlays it so a leftover
/// gutter cannot steal the canvas, and so the mask wins hit tests.
class FanCadSplitter extends StatefulWidget {
  const FanCadSplitter({
    super.key,
    required this.axis,
    required this.onDrag,
    this.onDragEnd,
    this.onDoubleTap,
    this.thickness = 1,
    this.hitSize = CommandLineLayout.splitterHit,
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
    double hitSize = CommandLineLayout.splitterHit,
  }) => seam - (hitSize ~/ 2).toDouble();

  @override
  State<FanCadSplitter> createState() => _FanCadSplitterState();
}

/// Live width of one [FanCadSplit] pane.
///
/// Listeners see each drag step. The split does not store the width anywhere
/// else; the owner reads [extent] when the gesture ends and persists it.
class FanCadSplitController extends ChangeNotifier {
  FanCadSplitController({
    required double extent,
    required this.minExtent,
    required this.maxExtent,
  }) : _extent = extent.clamp(minExtent, maxExtent);

  final double minExtent;
  final double maxExtent;

  double _extent;

  double get extent => _extent;

  set extent(double value) {
    final next = value.clamp(minExtent, maxExtent);
    if (next == _extent) return;
    _extent = next;
    notifyListeners();
  }

  /// Moves the fixed pane by [delta] logical pixels.
  void applyDelta(double delta) => extent = _extent + delta;
}

/// Two panes and an overlay sash. The fixed pane is [first], unless [reverse].
///
/// A drag writes [controller] and passes [first] and [second] through
/// unchanged, so the panes are not rebuilt on each move. [onDragEnd] tells the
/// owner the gesture finished; this widget does not persist the width.
class FanCadSplit extends StatelessWidget {
  const FanCadSplit({
    super.key,
    required this.controller,
    required this.first,
    required this.second,
    this.reverse = false,
    this.onDragEnd,
    this.onDoubleTap,
    this.handleKey,
    this.tooltip,
  });

  final FanCadSplitController controller;
  final Widget first;
  final Widget second;

  /// The fixed pane is [second], on the trailing edge.
  final bool reverse;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDoubleTap;
  final Key? handleKey;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final slots = child! as _SplitChildren;
        final extent = controller.extent;
        return LayoutBuilder(
          builder: (context, constraints) {
            final fixed = SizedBox(width: extent, child: slots.fixed);
            final flex = Expanded(child: slots.flex);
            final seam = reverse ? constraints.maxWidth - extent : extent;
            final handle = FanCadSplitter(
              key: handleKey,
              axis: Axis.vertical,
              onDrag: (delta) =>
                  controller.applyDelta(reverse ? -delta : delta),
              onDragEnd: onDragEnd,
              onDoubleTap: onDoubleTap,
            );
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                children: [
                  Row(children: reverse ? [flex, fixed] : [fixed, flex]),
                  Positioned(
                    left: FanCadSplitter.overlayOrigin(seam),
                    top: 0,
                    bottom: 0,
                    width: CommandLineLayout.splitterHit,
                    child: tooltip == null
                        ? handle
                        : Tooltip(
                            message: tooltip,
                            waitDuration: const Duration(milliseconds: 500),
                            child: handle,
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
      child: _SplitChildren(
        fixed: reverse ? second : first,
        flex: reverse ? first : second,
      ),
    );
  }
}

/// Carries the two panes in [ListenableBuilder]'s child slot.
class _SplitChildren extends StatelessWidget {
  const _SplitChildren({required this.fixed, required this.flex});

  final Widget fixed;
  final Widget flex;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FanCadSplitterState extends State<FanCadSplitter> {
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
                      : tokens.borderMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
