import 'dart:typed_data';

/// Simplifies a screen-bound polyline with a Douglas-Peucker pass.
///
/// The result keeps every point whose distance from the chord between its kept
/// neighbours is at least [tolerance] in world units. Runs with only a handful
/// of points are returned untouched: the allocation would cost more than the
/// few segments it could remove.
Float64List simplifyPolyline(
  Float64List xy,
  double tolerance, {
  bool closed = false,
}) {
  final count = xy.length ~/ 2;
  if (count < 4 || !tolerance.isFinite || tolerance <= 0) return xy;
  final toleranceSquared = tolerance * tolerance;
  final keep = Uint8List(count);

  if (!closed) {
    keep[0] = 1;
    keep[count - 1] = 1;
    _rdp(xy, 0, count - 1, toleranceSquared, keep);
  } else {
    // A closed ring has no natural chord between two distinct endpoints.
    // Split it at the point farthest from the first vertex, so each half is a
    // normal open chain and both halves still meet at the split point.
    var split = 1;
    var farthest = -1.0;
    final x0 = xy[0];
    final y0 = xy[1];
    for (var i = 1; i < count; i++) {
      final dx = xy[i * 2] - x0;
      final dy = xy[i * 2 + 1] - y0;
      final distance = dx * dx + dy * dy;
      if (distance > farthest) {
        farthest = distance;
        split = i;
      }
    }
    if (split <= 0 || split >= count - 1) return xy;
    keep[0] = 1;
    keep[split] = 1;
    _rdp(xy, 0, split, toleranceSquared, keep);
    // The second half ends at the first vertex again; index count represents
    // that implicit endpoint without adding a duplicate vertex to the result.
    _rdp(xy, split, count, toleranceSquared, keep);
  }

  var kept = 0;
  for (var i = 0; i < count; i++) {
    if (keep[i] != 0) kept++;
  }
  if (kept < (closed ? 3 : 2) || kept == count) return xy;
  final out = Float64List(kept * 2);
  var at = 0;
  for (var i = 0; i < count; i++) {
    if (keep[i] == 0) continue;
    out[at++] = xy[i * 2];
    out[at++] = xy[i * 2 + 1];
  }
  return out;
}

void _rdp(
  Float64List xy,
  int first,
  int last,
  double toleranceSquared,
  Uint8List keep,
) {
  if (last <= first + 1) return;
  final ax = xy[(first % (xy.length ~/ 2)) * 2];
  final ay = xy[(first % (xy.length ~/ 2)) * 2 + 1];
  final lastIndex = last == xy.length ~/ 2 ? 0 : last;
  final bx = xy[lastIndex * 2];
  final by = xy[lastIndex * 2 + 1];
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  var best = -1.0;
  var bestIndex = -1;
  for (var i = first + 1; i < last; i++) {
    final px = xy[i * 2] - ax;
    final py = xy[i * 2 + 1] - ay;
    final double distance;
    if (lengthSquared <= 1e-24) {
      distance = px * px + py * py;
    } else {
      final cross = px * dy - py * dx;
      distance = cross * cross / lengthSquared;
    }
    if (distance > best) {
      best = distance;
      bestIndex = i;
    }
  }
  if (bestIndex < 0 || best <= toleranceSquared) return;
  keep[bestIndex] = 1;
  _rdp(xy, first, bestIndex, toleranceSquared, keep);
  _rdp(xy, bestIndex, last, toleranceSquared, keep);
}
