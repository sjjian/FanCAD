import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';

/// What a [CachedPrimitive] holds.
enum PrimitiveKind { polyline, fill, point, text, image }

/// One flattened primitive together with the style it resolved to.
class CachedPrimitive {
  CachedPrimitive.polyline(this.xy, this.style, {this.closed = false})
    : kind = PrimitiveKind.polyline,
      holes = const [],
      text = null,
      image = null;

  CachedPrimitive.fill(this.xy, this.style, {this.holes = const []})
    : kind = PrimitiveKind.fill,
      closed = true,
      text = null,
      image = null;

  CachedPrimitive.point(double x, double y, this.style)
    : kind = PrimitiveKind.point,
      xy = Float64List.fromList([x, y]),
      closed = false,
      holes = const [],
      text = null,
      image = null;

  CachedPrimitive.text(this.text, this.style)
    : kind = PrimitiveKind.text,
      xy = _empty,
      closed = false,
      holes = const [],
      image = null;

  CachedPrimitive.image(this.image, this.style)
    : kind = PrimitiveKind.image,
      xy = _empty,
      closed = false,
      holes = const [],
      text = null;

  static final Float64List _empty = Float64List(0);

  final PrimitiveKind kind;

  /// Interleaved world coordinates.
  final Float64List xy;
  final bool closed;
  final List<Float64List> holes;
  final TextGeometry? text;
  final ImageGeometry? image;
  final ResolvedStyle style;

  /// Rough memory cost in doubles, used for the cache budget.
  int get weight {
    var total = xy.length + 4;
    for (final hole in holes) {
      total += hole.length;
    }
    if (text != null) total += text!.text.length ~/ 4 + 8;
    return total;
  }
}

/// Records everything an entity emits so it can be replayed later.
class RecordingSink implements GeometrySink {
  final List<CachedPrimitive> primitives = [];

  int get weight {
    var total = 0;
    for (final primitive in primitives) {
      total += primitive.weight;
    }
    return total;
  }

  @override
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false}) {
    if (xy.length < 4) return;
    primitives.add(CachedPrimitive.polyline(xy, style, closed: closed));
  }

  @override
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  }) {
    primitives.add(CachedPrimitive.fill(xy, style, holes: holes));
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    primitives.add(CachedPrimitive.point(x, y, style));
  }

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    primitives.add(CachedPrimitive.text(geometry, style));
  }

  @override
  void image(ImageGeometry geometry, ResolvedStyle style) {
    primitives.add(CachedPrimitive.image(geometry, style));
  }
}

/// Replays cached world primitives onto any [GeometrySink].
void replayCachedPrimitives(
  GeometrySink sink,
  List<CachedPrimitive> primitives,
) {
  for (final primitive in primitives) {
    switch (primitive.kind) {
      case PrimitiveKind.polyline:
        sink.polyline(primitive.xy, primitive.style, closed: primitive.closed);
      case PrimitiveKind.fill:
        sink.fill(primitive.xy, primitive.style, holes: primitive.holes);
      case PrimitiveKind.point:
        sink.point(primitive.xy[0], primitive.xy[1], primitive.style);
      case PrimitiveKind.text:
        sink.text(primitive.text!, primitive.style);
      case PrimitiveKind.image:
        sink.image(primitive.image!, primitive.style);
    }
  }
}

/// Forwards every primitive to two sinks so a cache miss can paint and
/// record in one emit.
class TeeSink implements GeometrySink {
  TeeSink(this.first, this.second);

  final GeometrySink first;
  final GeometrySink second;

  @override
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false}) {
    first.polyline(xy, style, closed: closed);
    second.polyline(xy, style, closed: closed);
  }

  @override
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  }) {
    first.fill(xy, style, holes: holes);
    second.fill(xy, style, holes: holes);
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    first.point(x, y, style);
    second.point(x, y, style);
  }

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    first.text(geometry, style);
    second.text(geometry, style);
  }

  @override
  void image(ImageGeometry geometry, ResolvedStyle style) {
    first.image(geometry, style);
    second.image(geometry, style);
  }
}

/// Caches flattened geometry, keyed by entity, tessellation tolerance and
/// collapse size.
///
/// Flattening a spline or walking a nested block is far more expensive than
/// drawing the result. A pan never comes through here: it replays a recorded
/// picture. This cache pays off on a settled rebuild, and on hover / pick /
/// selection outlines that re-emit the same entities the drawing already
/// flattened.
///
/// Two decisions keep the cache from becoming a memory leak. Tolerance and
/// [EmitContext.minExtent] are bucketed to powers of two, so a continuous zoom
/// produces a bounded number of variants rather than one per frame. Recordings
/// cheaper than a short polyline are not retained: looking them up costs more
/// than emitting them. Hover uses `minExtent` 0 so it does not replay the
/// drawing's collapsed insert.
class TessellationCache {
  TessellationCache({this.budget = 8 * 1000 * 1000});

  /// Maximum retained size, counted in doubles. The default is roughly 64 MB,
  /// which holds a few hundred thousand tessellated curves.
  final int budget;

  final LinkedHashMap<_CacheKey, List<CachedPrimitive>> _entries =
      LinkedHashMap();
  final Map<_CacheKey, int> _weights = {};
  int _totalWeight = 0;
  int _hits = 0;
  int _misses = 0;

  int get entryCount => _entries.length;
  int get totalWeight => _totalWeight;
  int get hits => _hits;
  int get misses => _misses;

  double get hitRate {
    final total = _hits + _misses;
    return total == 0 ? 0 : _hits / total;
  }

  /// Geometry lighter than this is cheaper to re-emit than to look up.
  ///
  /// A two-point line weighs 8. Anything heavier (a tessellated curve, a
  /// filled ring, a nested block) is retained.
  static const int minStoreWeight = 9;

  /// Quantises tolerance so a smooth zoom reuses cache entries.
  ///
  /// The exponent is the level-of-detail band; adjacent bands differ by a
  /// factor of two in chord error, which is imperceptible mid-pan.
  static int toleranceBucket(double tolerance) {
    if (!tolerance.isFinite || tolerance <= 0) return 0;
    return (math.log(tolerance) / math.ln2).floor();
  }

  /// Collapse-size band for [minExtent]. Zero (and non-finite) share one slot
  /// so hover outlines that keep every member stay distinct from a zoomed-out
  /// drawing that collapsed the same insert to a point.
  static int extentBucket(double minExtent) {
    if (!minExtent.isFinite || minExtent <= 0) return 0;
    return (math.log(minExtent) / math.ln2).floor();
  }

  /// Geometry for [entity] at [bucket] and [minExtent], emitting it through
  /// [emit] on a miss.
  List<CachedPrimitive> obtain(
    CadEntity entity,
    int bucket,
    void Function(RecordingSink sink) emit, {
    double minExtent = 0,
  }) {
    final existing = lookup(entity, bucket, minExtent: minExtent);
    if (existing != null) return existing;

    final sink = RecordingSink();
    emit(sink);
    remember(entity, bucket, sink, minExtent: minExtent);
    return sink.primitives;
  }

  List<CachedPrimitive>? lookup(
    CadEntity entity,
    int bucket, {
    double minExtent = 0,
  }) {
    final key = _CacheKey(
      entity.id,
      bucket,
      extentBucket(minExtent),
    );
    final existing = _entries.remove(key);
    if (existing == null) {
      _misses++;
      return null;
    }
    _entries[key] = existing;
    _hits++;
    return existing;
  }

  /// Stores [recorder] when it is heavy enough to repay a lookup.
  void remember(
    CadEntity entity,
    int bucket,
    RecordingSink recorder, {
    double minExtent = 0,
  }) {
    final weight = recorder.weight;
    if (weight < minStoreWeight) return;
    final key = _CacheKey(
      entity.id,
      bucket,
      extentBucket(minExtent),
    );
    if (_entries.containsKey(key)) {
      _totalWeight -= _weights.remove(key) ?? 0;
      _entries.remove(key);
    }
    _entries[key] = recorder.primitives;
    _weights[key] = weight;
    _totalWeight += weight;
    _evict();
  }

  /// Drops cached geometry for specific entities, after an edit.
  void invalidate(Iterable<int> entityIds) {
    final ids = entityIds.toSet();
    if (ids.isEmpty) return;
    _entries.removeWhere((key, value) {
      if (!ids.contains(key.entityId)) return false;
      _totalWeight -= _weights.remove(key) ?? 0;
      return true;
    });
  }

  void clear() {
    _entries.clear();
    _weights.clear();
    _totalWeight = 0;
  }

  void resetStatistics() {
    _hits = 0;
    _misses = 0;
  }

  void _evict() {
    while (_totalWeight > budget && _entries.isNotEmpty) {
      final oldest = _entries.keys.first;
      _entries.remove(oldest);
      _totalWeight -= _weights.remove(oldest) ?? 0;
    }
  }

  @override
  String toString() =>
      'TessellationCache($entryCount entries, '
      '${(_totalWeight * 8 / 1024 / 1024).toStringAsFixed(1)} MB, '
      'hit rate ${(hitRate * 100).toStringAsFixed(0)}%)';
}

/// Staleness is handled by explicit invalidation rather than by a version in
/// the key: [DocumentChange] already reports exactly which entities moved, and
/// a document-wide version would throw away every unrelated entry on every
/// edit.
class _CacheKey {
  const _CacheKey(this.entityId, this.bucket, this.extentBucket);

  final int entityId;
  final int bucket;
  final int extentBucket;

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      other.entityId == entityId &&
      other.bucket == bucket &&
      other.extentBucket == extentBucket;

  @override
  int get hashCode => Object.hash(entityId, bucket, extentBucket);
}
