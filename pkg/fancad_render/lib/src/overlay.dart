import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/painting.dart';
import 'package:meta/meta.dart';

import 'picking.dart';
import 'viewport.dart';

/// Everything drawn on top of the drawing: selection, grips, previews, snaps.
///
/// Kept separate from [RenderScene] because it changes on every mouse move
/// while the drawing underneath does not. Two layers, two repaint rates.
@immutable
class OverlayModel {
  const OverlayModel({
    this.selectedIds = const [],
    this.highlightedIds = const [],
    this.grips = const [],
    this.hotGripIndex = -1,
    this.shapes = const [],
    this.snap,
    this.cursor,
    this.showCrosshair = true,
  });

  static const OverlayModel empty = OverlayModel();

  final List<int> selectedIds;

  /// Entities under the cursor, or entities an AI change is about to touch.
  /// Drawn dashed, same as [selectedIds], not as a solid glow.
  final List<int> highlightedIds;

  final List<Vec2> grips;

  /// The grip the cursor is over, drawn filled rather than hollow.
  final int hotGripIndex;

  final List<OverlayShape> shapes;
  final SnapMarker? snap;
  final Vec2? cursor;
  final bool showCrosshair;

  bool get isEmpty =>
      selectedIds.isEmpty &&
      highlightedIds.isEmpty &&
      grips.isEmpty &&
      shapes.isEmpty &&
      snap == null &&
      cursor == null;

  OverlayModel copyWith({
    List<int>? selectedIds,
    List<int>? highlightedIds,
    List<Vec2>? grips,
    int? hotGripIndex,
    List<OverlayShape>? shapes,
    SnapMarker? snap,
    bool clearSnap = false,
    Vec2? cursor,
    bool clearCursor = false,
    bool? showCrosshair,
  }) => OverlayModel(
    selectedIds: selectedIds ?? this.selectedIds,
    highlightedIds: highlightedIds ?? this.highlightedIds,
    grips: grips ?? this.grips,
    hotGripIndex: hotGripIndex ?? this.hotGripIndex,
    shapes: shapes ?? this.shapes,
    snap: clearSnap ? null : (snap ?? this.snap),
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    showCrosshair: showCrosshair ?? this.showCrosshair,
  );
}

/// The colours and sizes of the overlay.
@immutable
class OverlayTheme {
  const OverlayTheme({
    this.selection = const ui.Color(0xFF3B9DFF),
    this.highlight = const ui.Color(0xFF7CD4FF),
    this.grip = const ui.Color(0xFF3B9DFF),
    this.hotGrip = const ui.Color(0xFFFF9F3B),
    this.snap = const ui.Color(0xFFFFD166),
    this.preview = const ui.Color(0xFFE0E0E0),
    this.tracking = const ui.Color(0xFF6BE38F),
    this.crosshair = const ui.Color(0x66FFFFFF),
    this.selectionStroke = const ui.Color(0xFFFFFFFF),
    this.selectionMask = const ui.Color(0xFF1B1D21),
    this.gripSize = 7,
    this.snapSize = 9,
    this.crosshairSize = 14,
  });

  final ui.Color selection;
  final ui.Color highlight;
  final ui.Color grip;
  final ui.Color hotGrip;
  final ui.Color snap;
  final ui.Color preview;
  final ui.Color tracking;
  final ui.Color crosshair;

  /// Selected entities are redrawn dashed in this colour, after the original
  /// solid stroke is covered by [selectionMask].
  final ui.Color selectionStroke;
  final ui.Color selectionMask;

  /// Grip and marker sizes in logical pixels, so they stay constant on screen.
  final double gripSize;
  final double snapSize;
  final double crosshairSize;

  /// Covers the original solid stroke with the canvas colour and picks a
  /// dash colour that stays readable on it.
  OverlayTheme withCanvas(ui.Color canvas) {
    final dark = canvas.computeLuminance() < 0.5;
    return OverlayTheme(
      selection: selection,
      highlight: highlight,
      grip: grip,
      hotGrip: hotGrip,
      snap: snap,
      tracking: tracking,
      crosshair: crosshair,
      preview: dark
          ? const ui.Color(0xFFFFFFFF)
          : const ui.Color(0xFF000000),
      selectionStroke: dark
          ? const ui.Color(0xFFFFFFFF)
          : const ui.Color(0xFF000000),
      selectionMask: canvas,
      gripSize: gripSize,
      snapSize: snapSize,
      crosshairSize: crosshairSize,
    );
  }
}

/// Draws an [OverlayModel].
class OverlayPainter {
  OverlayPainter({this.theme = const OverlayTheme()});

  final OverlayTheme theme;

  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..isAntiAlias = true;
  final Paint _fill = Paint()..isAntiAlias = true;

  void paint(
    ui.Canvas canvas,
    OverlayModel model,
    CadViewport viewport,
    CadDocument document,
  ) {
    if (!viewport.isUsable) return;

    if (model.highlightedIds.isNotEmpty) {
      _paintEntityOutlines(
        canvas,
        model.highlightedIds,
        viewport,
        document,
        theme.selectionStroke,
        1.2,
        dashed: true,
      );
    }
    if (model.selectedIds.isNotEmpty) {
      _paintEntityOutlines(
        canvas,
        model.selectedIds,
        viewport,
        document,
        theme.selectionStroke,
        1.2,
        dashed: true,
      );
    }

    for (final shape in model.shapes) {
      _paintShape(canvas, shape, viewport);
    }

    for (var i = 0; i < model.grips.length; i++) {
      _paintGrip(
        canvas,
        viewport.toScreen(model.grips[i]),
        hot: i == model.hotGripIndex,
      );
    }

    final snap = model.snap;
    if (snap != null) _paintSnap(canvas, snap, viewport);

    final cursor = model.cursor;
    if (cursor != null && model.showCrosshair) {
      _paintCrosshair(canvas, viewport.toScreen(cursor), viewport);
    }
  }

  /// Re-emits the selected entities and strokes them on top of the drawing.
  ///
  /// Re-emitting rather than caching an outline is deliberate: hover and
  /// selection change constantly and a stale outline is worse than a slightly
  /// more expensive one. Both are drawn dashed, like AutoCAD, so the original
  /// solid stroke is covered first and the dashes sit in its place rather than
  /// on top of a second colour.
  void _paintEntityOutlines(
    ui.Canvas canvas,
    List<int> ids,
    CadViewport viewport,
    CadDocument document,
    ui.Color color,
    double width, {
    bool dashed = false,
  }) {
    final sink = _OutlineSink(viewport);
    Picker.emitInActiveLayout(
      document,
      ids,
      sink,
      tolerance: viewport.tolerance,
      visible: viewport.visibleBounds,
    );
    if (sink.length == 0) return;
    final solid = Float32List.sublistView(sink.buffer, 0, sink.length);
    if (dashed) {
      _stroke
        ..color = theme.selectionMask
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawRawPoints(ui.PointMode.lines, solid, _stroke);
    }
    final points = dashed ? dashOutline(solid) : solid;
    if (points.isEmpty) return;
    _stroke
      ..color = color
      ..strokeWidth = width
      ..strokeCap = dashed ? StrokeCap.butt : StrokeCap.round
      ..isAntiAlias = !dashed;
    canvas.drawRawPoints(ui.PointMode.lines, points, _stroke);
    _stroke.isAntiAlias = true;
    _stroke.strokeCap = StrokeCap.butt;
  }

  void _paintShape(ui.Canvas canvas, OverlayShape shape, CadViewport view) {
    _stroke
      ..color = theme.preview
      ..strokeWidth = 1;
    switch (shape) {
      case OverlayLine(:final from, :final to, :final dashed):
        _line(canvas, view.toScreen(from), view.toScreen(to), dashed: dashed);
      case OverlayPolyline(:final points, :final closed, :final dashed):
        if (points.length < 2) return;
        for (var i = 0; i + 1 < points.length; i++) {
          _line(
            canvas,
            view.toScreen(points[i]),
            view.toScreen(points[i + 1]),
            dashed: dashed,
          );
        }
        if (closed && points.length > 2) {
          _line(
            canvas,
            view.toScreen(points.last),
            view.toScreen(points.first),
            dashed: dashed,
          );
        }
      case OverlayArc(:final center, :final radius, :final startAngle, :final sweep):
        final screenCenter = view.toScreen(center);
        final screenRadius = radius * view.scale;
        if (screenRadius <= 0.5) return;
        canvas.drawArc(
          ui.Rect.fromCircle(center: screenCenter, radius: screenRadius),
          // Screen Y is inverted, so the sweep direction flips.
          -startAngle,
          -sweep,
          false,
          _stroke,
        );
      case OverlayRect(:final from, :final to, :final crossing):
        final a = view.toScreen(from);
        final b = view.toScreen(to);
        final rect = ui.Rect.fromPoints(a, b);
        _fill.color = (crossing ? theme.tracking : theme.selection).withValues(
          alpha: 0.12,
        );
        canvas.drawRect(rect, _fill);
        _stroke.color = crossing ? theme.tracking : theme.selection;
        if (crossing) {
          _dashedRect(canvas, rect);
        } else {
          canvas.drawRect(rect, _stroke);
        }
      case OverlayPoint(:final at):
        _paintSnap(
          canvas,
          SnapMarker(kind: SnapMarkerKind.node, point: at),
          view,
        );
        _stroke
          ..color = theme.preview
          ..strokeWidth = 1;
      case OverlayTrackingLine(:final origin, :final angle):
        final screenOrigin = view.toScreen(origin);
        final reach = view.size.width + view.size.height;
        final dx = math.cos(angle) * reach;
        final dy = -math.sin(angle) * reach;
        _stroke.color = theme.tracking.withValues(alpha: 0.7);
        _line(
          canvas,
          screenOrigin.translate(-dx, -dy),
          screenOrigin.translate(dx, dy),
          dashed: true,
        );
    }
  }

  void _line(
    ui.Canvas canvas,
    ui.Offset a,
    ui.Offset b, {
    bool dashed = false,
  }) {
    if (!dashed) {
      canvas.drawLine(a, b, _stroke);
      return;
    }
    const on = 6.0;
    const off = 4.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final direction = (b - a) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + on, total);
      canvas.drawLine(
        a + direction * travelled,
        a + direction * end,
        _stroke,
      );
      travelled = end + off;
    }
  }

  void _dashedRect(ui.Canvas canvas, ui.Rect rect) {
    _line(canvas, rect.topLeft, rect.topRight, dashed: true);
    _line(canvas, rect.topRight, rect.bottomRight, dashed: true);
    _line(canvas, rect.bottomRight, rect.bottomLeft, dashed: true);
    _line(canvas, rect.bottomLeft, rect.topLeft, dashed: true);
  }

  void _paintGrip(ui.Canvas canvas, ui.Offset at, {required bool hot}) {
    final rect = ui.Rect.fromCenter(
      center: at,
      width: theme.gripSize,
      height: theme.gripSize,
    );
    _fill.color = hot ? theme.hotGrip : theme.grip;
    canvas.drawRect(rect, _fill);
  }

  /// Snap markers use the glyph shapes CAD users already read fluently: a
  /// square for an endpoint, a triangle for a midpoint, a circle for a centre.
  void _paintSnap(ui.Canvas canvas, SnapMarker marker, CadViewport view) {
    final at = view.toScreen(marker.point);
    final size = theme.snapSize;
    final half = size / 2;
    _stroke
      ..color = theme.snap
      ..strokeWidth = 1.6;

    switch (marker.kind) {
      case SnapMarkerKind.endpoint:
        canvas.drawRect(
          ui.Rect.fromCenter(center: at, width: size, height: size),
          _stroke,
        );
      case SnapMarkerKind.midpoint:
        final path = ui.Path()
          ..moveTo(at.dx, at.dy - half)
          ..lineTo(at.dx + half, at.dy + half)
          ..lineTo(at.dx - half, at.dy + half)
          ..close();
        canvas.drawPath(path, _stroke);
      case SnapMarkerKind.center:
        canvas.drawCircle(at, half, _stroke);
      case SnapMarkerKind.quadrant:
        final path = ui.Path()
          ..moveTo(at.dx, at.dy - half)
          ..lineTo(at.dx + half, at.dy)
          ..lineTo(at.dx, at.dy + half)
          ..lineTo(at.dx - half, at.dy)
          ..close();
        canvas.drawPath(path, _stroke);
      case SnapMarkerKind.intersection:
        canvas
          ..drawLine(
            at.translate(-half, -half),
            at.translate(half, half),
            _stroke,
          )
          ..drawLine(
            at.translate(half, -half),
            at.translate(-half, half),
            _stroke,
          );
      case SnapMarkerKind.perpendicular:
        canvas
          ..drawLine(at.translate(-half, -half), at.translate(-half, half), _stroke)
          ..drawLine(at.translate(-half, half), at.translate(half, half), _stroke)
          ..drawLine(at.translate(0, half), at.translate(0, 0), _stroke)
          ..drawLine(at.translate(0, 0), at.translate(half, 0), _stroke);
      case SnapMarkerKind.tangent:
        canvas
          ..drawCircle(at.translate(0, half * 0.3), half * 0.7, _stroke)
          ..drawLine(
            at.translate(-half, -half),
            at.translate(half, -half),
            _stroke,
          );
      case SnapMarkerKind.node:
        canvas
          ..drawCircle(at, half, _stroke)
          ..drawLine(at.translate(-half, 0), at.translate(half, 0), _stroke)
          ..drawLine(at.translate(0, -half), at.translate(0, half), _stroke);
      case SnapMarkerKind.nearest:
        final path = ui.Path()
          ..moveTo(at.dx - half, at.dy + half)
          ..lineTo(at.dx, at.dy - half)
          ..lineTo(at.dx + half, at.dy + half);
        canvas.drawPath(path, _stroke);
      case SnapMarkerKind.extension:
        for (var i = 0; i < 3; i++) {
          final x = at.dx - half + i * half;
          canvas.drawLine(
            ui.Offset(x, at.dy),
            ui.Offset(x + half * 0.5, at.dy),
            _stroke,
          );
        }
      case SnapMarkerKind.grid:
        canvas
          ..drawLine(at.translate(-half, 0), at.translate(half, 0), _stroke)
          ..drawLine(at.translate(0, -half), at.translate(0, half), _stroke);
    }
  }

  void _paintCrosshair(ui.Canvas canvas, ui.Offset at, CadViewport view) {
    _stroke
      ..color = theme.crosshair
      ..strokeWidth = 1;
    final reach = theme.crosshairSize;
    canvas
      ..drawLine(at.translate(-reach, 0), at.translate(reach, 0), _stroke)
      ..drawLine(at.translate(0, -reach), at.translate(0, reach), _stroke)
      ..drawRect(
        ui.Rect.fromCenter(center: at, width: reach * 0.7, height: reach * 0.7),
        _stroke,
      );
  }
}

/// Turns solid screen-space segments into a short dash pattern.
///
/// Dash lengths are in pixels so the selected look stays the same at every
/// zoom, which is what the user is reading, not the drawing units.
@visibleForTesting
Float32List dashOutline(
  Float32List src, {
  double on = 4,
  double off = 3,
}) {
  if (src.length < 4 || on <= 0) return src;
  var buffer = Float32List(src.length * 2);
  var length = 0;

  void add(double x0, double y0, double x1, double y1) {
    if (length + 4 > buffer.length) {
      buffer = Float32List(buffer.length * 2)..setRange(0, length, buffer);
    }
    buffer[length++] = x0;
    buffer[length++] = y0;
    buffer[length++] = x1;
    buffer[length++] = y1;
  }

  for (var i = 0; i + 3 < src.length; i += 4) {
    final x0 = src[i];
    final y0 = src[i + 1];
    final x1 = src[i + 2];
    final y1 = src[i + 3];
    final dx = x1 - x0;
    final dy = y1 - y0;
    final total = math.sqrt(dx * dx + dy * dy);
    if (total <= 0) continue;
    final ux = dx / total;
    final uy = dy / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + on, total);
      add(
        x0 + ux * travelled,
        y0 + uy * travelled,
        x0 + ux * end,
        y0 + uy * end,
      );
      travelled = end + off;
    }
  }
  return Float32List.sublistView(buffer, 0, length);
}

/// Collects screen-space segments for the selection outline.
class _OutlineSink implements GeometrySink {
  _OutlineSink(this.viewport);

  final CadViewport viewport;
  Float32List buffer = Float32List(512);
  int length = 0;

  bool get isEmpty => length == 0;

  void _add(double x0, double y0, double x1, double y1) {
    if (length + 4 > buffer.length) {
      buffer = Float32List(buffer.length * 2)..setRange(0, length, buffer);
    }
    buffer[length++] = x0;
    buffer[length++] = y0;
    buffer[length++] = x1;
    buffer[length++] = y1;
  }

  @override
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false}) {
    final count = xy.length ~/ 2;
    if (count < 2) return;
    for (var i = 0; i + 1 < count; i++) {
      final a = viewport.toScreen(Vec2(xy[i * 2], xy[i * 2 + 1]));
      final b = viewport.toScreen(Vec2(xy[(i + 1) * 2], xy[(i + 1) * 2 + 1]));
      _add(a.dx, a.dy, b.dx, b.dy);
    }
    if (closed && count > 2) {
      final a = viewport.toScreen(
        Vec2(xy[(count - 1) * 2], xy[(count - 1) * 2 + 1]),
      );
      final b = viewport.toScreen(Vec2(xy[0], xy[1]));
      _add(a.dx, a.dy, b.dx, b.dy);
    }
  }

  @override
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  }) {
    polyline(xy, style, closed: true);
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    final at = viewport.toScreen(Vec2(x, y));
    _add(at.dx - 3, at.dy, at.dx + 3, at.dy);
    _add(at.dx, at.dy - 3, at.dx, at.dy + 3);
  }

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    final box = geometry.estimatedBounds();
    if (box.isEmpty) return;
    final corners = [
      viewport.toScreen(Vec2(box.minX, box.minY)),
      viewport.toScreen(Vec2(box.maxX, box.minY)),
      viewport.toScreen(Vec2(box.maxX, box.maxY)),
      viewport.toScreen(Vec2(box.minX, box.maxY)),
    ];
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % corners.length];
      _add(a.dx, a.dy, b.dx, b.dy);
    }
  }

  @override
  void image(ImageGeometry geometry, ResolvedStyle style) {
    final corners = geometry.corners;
    for (var i = 0; i < corners.length; i++) {
      final a = viewport.toScreen(corners[i]);
      final b = viewport.toScreen(corners[(i + 1) % corners.length]);
      _add(a.dx, a.dy, b.dx, b.dy);
    }
  }
}
