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

/// Caches flattened geometry, keyed by entity and level of detail.
///
/// Tessellating a spline or recursing into a nested block reference is far more
/// expensive than the arithmetic to draw the result, and while the user pans,
/// the same entities are re-emitted every frame at the same zoom. Caching that
/// work is the difference between a smooth pan and a stuttering one.
///
/// Two decisions keep the cache from becoming a memory leak. Tolerance is
/// bucketed to powers of two, so a continuous zoom produces a bounded number
/// of variants rather than one per frame. And cheap entities are never cached
/// at all: a two-point line costs less to re-emit than to look up.
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

  /// Whether caching [entity] is likely to pay for itself.
  ///
  /// Curves and block references are worth caching; straight geometry is not.
  static bool isWorthCaching(CadEntity entity) => switch (entity.kind) {
    EntityKind.circle ||
    EntityKind.arc ||
    EntityKind.ellipse ||
    EntityKind.spline ||
    EntityKind.insert ||
    EntityKind.hatch ||
    EntityKind.dimension ||
    EntityKind.mtext => true,
    EntityKind.polyline => entity is PolylineEntity &&
        (entity.hasBulges || entity.vertexCount > 16),
    _ => false,
  };

  /// Quantises tolerance so a smooth zoom reuses cache entries.
  ///
  /// The exponent is the level-of-detail band; adjacent bands differ by a
  /// factor of two in chord error, which is imperceptible mid-pan.
  static int toleranceBucket(double tolerance) {
    if (!tolerance.isFinite || tolerance <= 0) return 0;
    return (math.log(tolerance) / math.ln2).floor();
  }

  /// Geometry for [entity] at [bucket], emitting it through [emit] on a miss.
  List<CachedPrimitive> obtain(
    CadEntity entity,
    int bucket,
    void Function(RecordingSink sink) emit,
  ) {
    final key = _CacheKey(entity.id, bucket);
    final existing = _entries.remove(key);
    if (existing != null) {
      // Re-inserting moves the entry to the most-recently-used end.
      _entries[key] = existing;
      _hits++;
      return existing;
    }

    _misses++;
    final sink = RecordingSink();
    emit(sink);
    final primitives = sink.primitives;
    final weight = sink.weight;

    _entries[key] = primitives;
    _weights[key] = weight;
    _totalWeight += weight;
    _evict();
    return primitives;
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
  const _CacheKey(this.entityId, this.bucket);

  final int entityId;
  final int bucket;

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      other.entityId == entityId &&
      other.bucket == bucket;

  @override
  int get hashCode => Object.hash(entityId, bucket);
}
