import 'dart:math' as math;

import '../geometry/bounds.dart';

/// A bulk-loaded R-tree with an incremental staging area.
///
/// Interactive editing and file loading have opposite access patterns: loading
/// inserts a million entities at once, editing touches a handful per frame. A
/// single structure that is good at both is hard to get right, so this index
/// keeps a packed, immutable R-tree for the bulk of the drawing and a small
/// linear staging list for recent edits, rebuilding once staging grows past a
/// fraction of the total. Queries consult both.
class SpatialIndex {
  SpatialIndex({this.nodeCapacity = 12});

  /// Maximum entries per packed node.
  final int nodeCapacity;

  final Map<int, Bounds2> _boxes = {};
  final Map<int, Bounds2> _staged = {};
  final Set<int> _removed = {};

  _Node? _root;

  int get length => _boxes.length;
  bool get isEmpty => _boxes.isEmpty;
  bool get isNotEmpty => _boxes.isNotEmpty;

  /// The number of staged entries that triggers a rebuild.
  int get _rebuildThreshold => math.max(64, _boxes.length >> 3);

  Bounds2 get bounds {
    var box = _root?.bounds ?? const Bounds2.empty();
    for (final staged in _staged.values) {
      box = box.union(staged);
    }
    // A rebuild is pending, so removed ids may still be inside the packed
    // root; recompute from scratch when that could overstate the extents.
    if (_removed.isEmpty) return box;
    var exact = const Bounds2.empty();
    for (final entry in _boxes.values) {
      if (_indexable(entry)) exact = exact.union(entry);
    }
    return exact;
  }

  Bounds2? boundsOf(int id) => _boxes[id];

  bool contains(int id) => _boxes.containsKey(id);

  void insert(int id, Bounds2 box) {
    if (!_indexable(box)) {
      // Still track it so queries by id work; a degenerate or NaN box
      // simply never matches a window query.
      _boxes[id] = box;
      _removed.remove(id);
      return;
    }
    _boxes[id] = box;
    _staged[id] = box;
    _removed.remove(id);
    if (_staged.length > _rebuildThreshold) rebuild();
  }

  void update(int id, Bounds2 box) {
    remove(id);
    insert(id, box);
  }

  void remove(int id) {
    if (!_boxes.containsKey(id)) return;
    _boxes.remove(id);
    if (_staged.remove(id) == null) {
      _removed.add(id);
      if (_removed.length > _rebuildThreshold) rebuild();
    }
  }

  void clear() {
    _boxes.clear();
    _staged.clear();
    _removed.clear();
    _root = null;
  }

  /// Replaces the whole index in one pass. Much cheaper than repeated inserts
  /// when a file is loaded or a layout is regenerated.
  void bulkLoad(Map<int, Bounds2> entries) {
    clear();
    _boxes.addAll(entries);
    rebuild();
  }

  /// Repacks the tree using a sort-tile-recursive layout.
  void rebuild() {
    _staged.clear();
    _removed.clear();
    _root = null;
    final entries = <_Node>[];
    for (final entry in _boxes.entries) {
      if (!_indexable(entry.value)) continue;
      entries.add(_Node.leaf(entry.key, entry.value));
    }
    if (entries.isEmpty) return;
    _root = _pack(entries);
  }

  _Node _pack(List<_Node> nodes) {
    var current = nodes;
    while (current.length > 1) {
      current = _packLevel(current);
    }
    return current.first;
  }

  List<_Node> _packLevel(List<_Node> nodes) {
    final total = nodes.length;
    final targetNodes = (total / nodeCapacity).ceil();
    final sliceCount = math.max(1, math.sqrt(targetNodes).ceil());
    final perSlice = (total / sliceCount).ceil();

    nodes.sort((a, b) => a.bounds.center.x.compareTo(b.bounds.center.x));

    final parents = <_Node>[];
    for (var start = 0; start < total; start += perSlice) {
      final end = math.min(start + perSlice, total);
      final slice = nodes.sublist(start, end)
        ..sort((a, b) => a.bounds.center.y.compareTo(b.bounds.center.y));
      for (var i = 0; i < slice.length; i += nodeCapacity) {
        final children = slice.sublist(
          i,
          math.min(i + nodeCapacity, slice.length),
        );
        parents.add(_Node.branch(children));
      }
    }
    return parents;
  }

  /// Ids whose bounding box intersects [query].
  List<int> search(Bounds2 query) {
    final result = <int>[];
    if (query.isEmpty) return result;
    final root = _root;
    if (root != null) {
      _searchNode(root, query, result);
    }
    for (final entry in _staged.entries) {
      if (_indexable(entry.value) && entry.value.intersects(query)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  void _searchNode(_Node node, Bounds2 query, List<int> result) {
    if (!node.bounds.intersects(query)) return;
    if (node.isLeaf) {
      final id = node.id;
      if (!_removed.contains(id) && !_staged.containsKey(id)) {
        result.add(id);
      }
      return;
    }
    for (final child in node.children) {
      _searchNode(child, query, result);
    }
  }

  /// Ids whose bounding box is fully inside [query]. Backs window selection,
  /// where AutoCAD requires full containment rather than intersection.
  List<int> searchContained(Bounds2 query) {
    final result = <int>[];
    for (final id in search(query)) {
      final box = _boxes[id];
      if (box != null && query.containsBox(box)) result.add(id);
    }
    return result;
  }

  /// Ids near a point, expanded by [tolerance]. The caller still has to run an
  /// exact geometric test; this only narrows the candidate set.
  List<int> searchPoint(double x, double y, double tolerance) =>
      search(Bounds2(x - tolerance, y - tolerance, x + tolerance, y + tolerance));

  /// Every id, including those with degenerate bounds.
  Iterable<int> get ids => _boxes.keys;

  /// Empty and NaN/Inf boxes stay in [_boxes] for id lookups, but they
  /// must not enter the packed tree: a single NaN leaf unions into a NaN
  /// root, and `intersects` then rejects every window.
  static bool _indexable(Bounds2 box) => box.isFinite && box.isNotEmpty;
}

class _Node {
  _Node.leaf(this.id, this.bounds) : children = const [];

  _Node.branch(this.children)
    : id = -1,
      bounds = children.fold(
        const Bounds2.empty(),
        (box, child) => box.union(child.bounds),
      );

  final int id;
  final Bounds2 bounds;
  final List<_Node> children;

  bool get isLeaf => children.isEmpty;
}
