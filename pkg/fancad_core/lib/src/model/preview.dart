import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../geometry/vector.dart';

/// A shape drawn as feedback while a command is running.
///
/// Lives in the kernel rather than in the renderer because commands describe
/// their own feedback, and a command must not have to depend on Flutter to say
/// "draw a rubber band from here to the cursor". Coordinates are always drawing
/// coordinates; turning them into pixels is the viewport's job.
@immutable
sealed class OverlayShape {
  const OverlayShape();
}

/// A rubber-band line, for example from the last picked point to the cursor.
class OverlayLine extends OverlayShape {
  const OverlayLine(this.from, this.to, {this.dashed = true});

  final Vec2 from;
  final Vec2 to;
  final bool dashed;
}

/// A polyline preview, such as the segments of a polyline being drawn.
class OverlayPolyline extends OverlayShape {
  const OverlayPolyline(this.points, {this.closed = false, this.dashed = false});

  final List<Vec2> points;
  final bool closed;
  final bool dashed;
}

/// A circle or arc preview.
class OverlayArc extends OverlayShape {
  const OverlayArc({
    required this.center,
    required this.radius,
    this.startAngle = 0,
    this.sweep = math.pi * 2,
  });

  final Vec2 center;
  final double radius;
  final double startAngle;
  final double sweep;
}

/// A selection or zoom rectangle. [crossing] draws the dashed style AutoCAD
/// uses for a crossing window, as opposed to a solid enclosing window.
class OverlayRect extends OverlayShape {
  const OverlayRect(this.from, this.to, {this.crossing = false});

  final Vec2 from;
  final Vec2 to;
  final bool crossing;
}

/// A tracking guide, drawn to the edges of the viewport.
class OverlayTrackingLine extends OverlayShape {
  const OverlayTrackingLine(this.origin, this.angle, {this.label = ''});

  final Vec2 origin;
  final double angle;
  final String label;
}

/// The kind of snap that was found, which decides the marker glyph.
enum SnapMarkerKind {
  endpoint,
  midpoint,
  center,
  quadrant,
  intersection,
  perpendicular,
  tangent,
  nearest,
  node,
  extension,
  grid,
}

/// A resolved snap, ready to be shown to the user.
@immutable
class SnapMarker {
  const SnapMarker({
    required this.kind,
    required this.point,
    this.entityId,
    this.direction,
  });

  final SnapMarkerKind kind;
  final Vec2 point;
  final int? entityId;

  /// Set for perpendicular and tangent snaps, where the marker is oriented.
  final Vec2? direction;

  String get label => switch (kind) {
    SnapMarkerKind.endpoint => 'Endpoint',
    SnapMarkerKind.midpoint => 'Midpoint',
    SnapMarkerKind.center => 'Center',
    SnapMarkerKind.quadrant => 'Quadrant',
    SnapMarkerKind.intersection => 'Intersection',
    SnapMarkerKind.perpendicular => 'Perpendicular',
    SnapMarkerKind.tangent => 'Tangent',
    SnapMarkerKind.nearest => 'Nearest',
    SnapMarkerKind.node => 'Node',
    SnapMarkerKind.extension => 'Extension',
    SnapMarkerKind.grid => 'Grid',
  };
}

/// Builds live feedback for the current cursor position.
///
/// A command installs one of these while it is waiting for a point, so the
/// preview is a pure function of "what has been collected so far" plus "where
/// the cursor is now" rather than mutable state the command has to keep in sync.
typedef PreviewBuilder = List<OverlayShape> Function(Vec2 cursor);
