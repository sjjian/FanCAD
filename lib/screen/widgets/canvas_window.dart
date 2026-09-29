import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'hairline.dart';
import 'tokens.dart';

/// A floating window parked on the CAD canvas.
///
/// Drop it in a [Stack] that fills the drawing. Drag the title to move,
/// resize from any edge or corner, and stay inside [bounds]. When [origin]
/// moves with pan/zoom, the window keeps the same corner the user last
/// dragged to.
class FanCadCanvasWindow extends StatefulWidget {
  const FanCadCanvasWindow({
    super.key,
    required this.title,
    required this.origin,
    required this.bounds,
    required this.child,
    this.footer,
    this.onClose,
    this.onBarrierTap,
    this.closeTooltip,
    this.initialSize = const Size(300, 232),
    this.minSize = const Size(260, 200),
    this.maxSize,
    this.margin = 8,
    this.name = 'canvas-window',
  });

  final String title;

  /// Screen-space point the window is parked on.
  final Offset origin;

  /// Canvas size. Move and resize clamp to this rect inset by [margin].
  final Size bounds;

  /// Expanding body under the title bar.
  final Widget child;

  /// Optional strip under a hairline, typically a confirm row.
  final Widget? footer;

  final VoidCallback? onClose;

  /// Tap on the canvas around the window. Null skips the barrier.
  final VoidCallback? onBarrierTap;

  final String? closeTooltip;
  final Size initialSize;
  final Size minSize;

  /// Largest size the user can drag the window to. Null grows to [bounds].
  final Size? maxSize;
  final double margin;

  /// Prefix for widget keys (`$name-card`, `$name-resize-se`, …).
  /// Must be unique among [FanCadCanvasWindow]s on the same canvas.
  final String name;

  @override
  State<FanCadCanvasWindow> createState() => _FanCadCanvasWindowState();
}

class _FanCadCanvasWindowState extends State<FanCadCanvasWindow> {
  static const _resizeFrame = 8.0;
  static const _resizeCorner = 24.0;
  static const _headerHeight = FanCadTokens.tabBarHeight;
  static final _mountedNames = <String>{};

  late double _width;
  late double _height;
  bool _moving = false;

  /// Card top-left relative to [FanCadCanvasWindow.origin], so pan/zoom still
  /// follows while a resize keeps the opposite corner. Header drag updates
  /// this offset and stays inside the canvas.
  late Offset _offsetFromOrigin;

  @override
  void initState() {
    super.initState();
    _width = _fit(
      widget.initialSize.width,
      widget.minSize.width,
      _roomWidth,
      widget.maxSize?.width,
    );
    _height = _fit(
      widget.initialSize.height,
      widget.minSize.height,
      _roomHeight,
      widget.maxSize?.height,
    );
    _parkNearOrigin();
    _registerName(widget.name);
  }

  @override
  void didUpdateWidget(FanCadCanvasWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      _unregisterName(oldWidget.name);
      _registerName(widget.name);
    }
    if (oldWidget.bounds != widget.bounds ||
        oldWidget.minSize != widget.minSize ||
        oldWidget.maxSize != widget.maxSize ||
        oldWidget.margin != widget.margin) {
      _clampToBounds();
    }
  }

  @override
  void dispose() {
    _unregisterName(widget.name);
    super.dispose();
  }

  Key _key(String suffix) => Key('${widget.name}-$suffix');

  void _registerName(String name) {
    assert(() {
      if (!_mountedNames.add(name)) {
        throw FlutterError(
          'FanCadCanvasWindow name "$name" is already on this canvas. '
          'Pass a unique name for each window.',
        );
      }
      return true;
    }());
  }

  void _unregisterName(String name) {
    assert(() {
      _mountedNames.remove(name);
      return true;
    }());
  }

  void _parkNearOrigin() {
    final origin = widget.origin;
    final bounds = widget.bounds;
    final margin = widget.margin;
    var left = origin.dx;
    var top = origin.dy;
    if (left + _width > bounds.width - margin) {
      left = origin.dx - _width;
    }
    if (top + _height > bounds.height - margin) {
      top = origin.dy - _height;
    }
    _offsetFromOrigin = Offset(left - origin.dx, top - origin.dy);
    _clampToBounds();
  }

  double get _roomWidth =>
      math.max(widget.minSize.width, widget.bounds.width - 2 * widget.margin);

  double get _roomHeight =>
      math.max(widget.minSize.height, widget.bounds.height - 2 * widget.margin);

  /// [room] is how far the canvas edge allows. [cap] can stop sooner.
  double _fit(double value, double min, double room, double? cap) {
    final limited = cap == null ? room : math.min(room, cap);
    return value.clamp(min, math.max(min, limited));
  }

  void _clampToBounds() {
    final bounds = widget.bounds;
    final margin = widget.margin;
    final origin = widget.origin;
    _width = _fit(
      _width,
      widget.minSize.width,
      _roomWidth,
      widget.maxSize?.width,
    );
    _height = _fit(
      _height,
      widget.minSize.height,
      _roomHeight,
      widget.maxSize?.height,
    );
    final left = (origin.dx + _offsetFromOrigin.dx).clamp(
      margin,
      math.max(margin, bounds.width - _width - margin),
    );
    final top = (origin.dy + _offsetFromOrigin.dy).clamp(
      margin,
      math.max(margin, bounds.height - _height - margin),
    );
    _offsetFromOrigin = Offset(left - origin.dx, top - origin.dy);
  }

  void _resize(_ResizeSide side, Offset delta, Offset origin) {
    final bounds = widget.bounds;
    final margin = widget.margin;
    final current = _offsetFromOrigin;
    var left = origin.dx + current.dx;
    var top = origin.dy + current.dy;
    var width = _width;
    var height = _height;
    final right = left + width;
    final bottom = top + height;
    final minW = widget.minSize.width;
    final minH = widget.minSize.height;

    if (side.right) {
      width = _fit(
        width + delta.dx,
        minW,
        math.max(minW, bounds.width - left - margin),
        widget.maxSize?.width,
      );
    }
    if (side.bottom) {
      height = _fit(
        height + delta.dy,
        minH,
        math.max(minH, bounds.height - top - margin),
        widget.maxSize?.height,
      );
    }
    if (side.left) {
      width = _fit(
        width - delta.dx,
        minW,
        math.max(minW, right - margin),
        widget.maxSize?.width,
      );
      left = right - width;
    }
    if (side.top) {
      height = _fit(
        height - delta.dy,
        minH,
        math.max(minH, bottom - margin),
        widget.maxSize?.height,
      );
      top = bottom - height;
    }

    setState(() {
      _width = width;
      _height = height;
      _offsetFromOrigin = Offset(left - origin.dx, top - origin.dy);
    });
  }

  /// Resize chrome sits outside the clipped card so the rounded corners
  /// still change the cursor and stay draggable.
  List<Widget> _edgeHandles(Offset origin) {
    const edge = _resizeFrame;
    const corner = _resizeCorner;
    Widget handle(_ResizeSide side, MouseCursor cursor, String suffix) {
      return _ResizeHandle(
        key: _key(suffix),
        cursor: cursor,
        onDrag: (details) => _resize(side, details.delta, origin),
      );
    }

    return [
      Positioned(
        left: corner,
        top: 0,
        right: corner,
        height: edge,
        child: handle(_ResizeSide.n, SystemMouseCursors.resizeRow, 'resize-n'),
      ),
      Positioned(
        left: corner,
        bottom: 0,
        right: corner,
        height: edge,
        child: handle(_ResizeSide.s, SystemMouseCursors.resizeRow, 'resize-s'),
      ),
      Positioned(
        left: 0,
        top: corner,
        bottom: corner,
        width: edge,
        child: handle(
          _ResizeSide.w,
          SystemMouseCursors.resizeColumn,
          'resize-w',
        ),
      ),
      Positioned(
        right: 0,
        top: corner,
        bottom: corner,
        width: edge,
        child: handle(
          _ResizeSide.e,
          SystemMouseCursors.resizeColumn,
          'resize-e',
        ),
      ),
      Positioned(
        left: 0,
        top: 0,
        width: corner,
        height: corner,
        child: handle(
          _ResizeSide.nw,
          SystemMouseCursors.resizeUpLeft,
          'resize-nw',
        ),
      ),
      _neHandle(origin),
      Positioned(
        left: 0,
        bottom: 0,
        width: corner,
        height: corner,
        child: handle(
          _ResizeSide.sw,
          SystemMouseCursors.resizeDownLeft,
          'resize-sw',
        ),
      ),
      Positioned(
        right: 0,
        bottom: 0,
        width: corner,
        height: corner,
        child: handle(
          _ResizeSide.se,
          SystemMouseCursors.resizeDownRight,
          'resize-se',
        ),
      ),
    ];
  }

  /// Close sits in the north-east corner. Keep that handle on the outside
  /// frame so a click on close does not start a resize.
  Widget _neHandle(Offset origin) {
    const corner = _resizeCorner;
    void onDrag(DragUpdateDetails details) {
      _resize(_ResizeSide.ne, details.delta, origin);
    }

    if (widget.onClose == null) {
      return Positioned(
        right: 0,
        top: 0,
        width: corner,
        height: corner,
        child: _ResizeHandle(
          key: _key('resize-ne'),
          cursor: SystemMouseCursors.resizeUpRight,
          onDrag: onDrag,
        ),
      );
    }

    return Positioned(
      right: 0,
      top: 0,
      width: corner,
      height: corner,
      child: Stack(
        key: _key('resize-ne'),
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: _resizeFrame,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUpRight,
              onDrag: onDrag,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _resizeFrame,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUpRight,
              onDrag: onDrag,
            ),
          ),
        ],
      ),
    );
  }

  void _move(DragUpdateDetails details, Offset origin) {
    final bounds = widget.bounds;
    final margin = widget.margin;
    final current = _offsetFromOrigin;
    final left = (origin.dx + current.dx + details.delta.dx).clamp(
      margin,
      math.max(margin, bounds.width - _width - margin),
    );
    final top = (origin.dy + current.dy + details.delta.dy).clamp(
      margin,
      math.max(margin, bounds.height - _height - margin),
    );
    setState(() {
      _offsetFromOrigin = Offset(left - origin.dx, top - origin.dy);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final origin = widget.origin;
    final left = origin.dx + _offsetFromOrigin.dx;
    final top = origin.dy + _offsetFromOrigin.dy;
    final closeTooltip = widget.closeTooltip ?? context.l10n.close;

    return Positioned.fill(
      child: Stack(
        children: [
          if (widget.onBarrierTap != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onBarrierTap,
              ),
            ),
          Positioned(
            left: left - _resizeFrame,
            top: top - _resizeFrame,
            child: SizedBox(
              width: _width + _resizeFrame * 2,
              height: _height + _resizeFrame * 2,
              child: Stack(
                children: [
                  Positioned(
                    left: _resizeFrame,
                    top: _resizeFrame,
                    child: Material(
                      color: tokens.surfaceOverlay,
                      elevation: 3,
                      shadowColor: tokens.shadow,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          FanCadTokens.radiusLarge,
                        ),
                        side: BorderSide(color: tokens.borderStrong),
                      ),
                      child: SizedBox(
                        key: _key('card'),
                        width: _width,
                        height: _height,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: _headerHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: MouseRegion(
                                      cursor: _moving
                                          ? SystemMouseCursors.grabbing
                                          : SystemMouseCursors.grab,
                                      child: GestureDetector(
                                        key: _key('move'),
                                        behavior: HitTestBehavior.opaque,
                                        onPanStart: (_) =>
                                            setState(() => _moving = true),
                                        onPanUpdate: (details) =>
                                            _move(details, origin),
                                        onPanEnd: (_) =>
                                            setState(() => _moving = false),
                                        onPanCancel: () =>
                                            setState(() => _moving = false),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: FanCadTokens.space3,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              widget.title,
                                              style: tokens.bodyStyle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.onClose != null)
                                    _CornerClose(
                                      tooltip: closeTooltip,
                                      onPressed: widget.onClose!,
                                      closeKey: _key('close'),
                                      height: _headerHeight,
                                    ),
                                ],
                              ),
                            ),
                            const FanCadHairline(strong: false),
                            Expanded(child: widget.child),
                            if (widget.footer != null) ...[
                              const FanCadHairline(strong: false),
                              widget.footer!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  ..._edgeHandles(origin),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerClose extends StatefulWidget {
  const _CornerClose({
    required this.tooltip,
    required this.onPressed,
    required this.closeKey,
    required this.height,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Key closeKey;
  final double height;

  @override
  State<_CornerClose> createState() => _CornerCloseState();
}

class _CornerCloseState extends State<_CornerClose> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          key: widget.closeKey,
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: ColoredBox(
            color: _hovered ? tokens.danger : Colors.transparent,
            child: SizedBox(
              width: 36,
              height: widget.height,
              child: Icon(
                Icons.close,
                size: FanCadTokens.iconMedium,
                color: _hovered ? tokens.accentText : tokens.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResizeSide {
  const _ResizeSide._(this.left, this.top, this.right, this.bottom);

  final bool left;
  final bool top;
  final bool right;
  final bool bottom;

  static const n = _ResizeSide._(false, true, false, false);
  static const s = _ResizeSide._(false, false, false, true);
  static const e = _ResizeSide._(false, false, true, false);
  static const w = _ResizeSide._(true, false, false, false);
  static const ne = _ResizeSide._(false, true, true, false);
  static const nw = _ResizeSide._(true, true, false, false);
  static const se = _ResizeSide._(false, false, true, true);
  static const sw = _ResizeSide._(true, false, false, true);
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({super.key, required this.cursor, required this.onDrag});

  final MouseCursor cursor;
  final GestureDragUpdateCallback onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: true,
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onDrag,
        child: const SizedBox.expand(),
      ),
    );
  }
}
