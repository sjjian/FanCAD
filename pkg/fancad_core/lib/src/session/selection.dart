import 'dart:async';

/// The current selection set for one document.
///
/// Selection is intentionally *not* stored on entities. Keeping it in a side
/// structure means selecting a thousand entities costs one set insertion each
/// instead of a thousand entity replacements and a thousand undo patches.
class SelectionSet {
  SelectionSet();

  final Set<int> _ids = <int>{};
  final StreamController<Set<int>> _controller =
      StreamController<Set<int>>.broadcast(sync: true);

  /// Grip index currently being dragged, keyed by entity id. Populated by the
  /// grip editing tool.
  final Map<int, int> activeGrips = {};

  Stream<Set<int>> get changes => _controller.stream;

  Set<int> get ids => Set.unmodifiable(_ids);
  int get length => _ids.length;
  bool get isEmpty => _ids.isEmpty;
  bool get isNotEmpty => _ids.isNotEmpty;
  bool get isSingle => _ids.length == 1;

  /// The only selected id, or null when the selection is not a single entity.
  int? get single => _ids.length == 1 ? _ids.first : null;

  bool contains(int id) => _ids.contains(id);

  bool add(int id) {
    if (!_ids.add(id)) return false;
    _notify();
    return true;
  }

  int addAll(Iterable<int> ids) {
    final before = _ids.length;
    _ids.addAll(ids);
    if (_ids.length == before) return 0;
    _notify();
    return _ids.length - before;
  }

  bool remove(int id) {
    if (!_ids.remove(id)) return false;
    activeGrips.remove(id);
    _notify();
    return true;
  }

  int removeAll(Iterable<int> ids) {
    var count = 0;
    for (final id in ids) {
      if (_ids.remove(id)) {
        activeGrips.remove(id);
        count++;
      }
    }
    if (count > 0) _notify();
    return count;
  }

  bool toggle(int id) {
    final added = _ids.contains(id) ? !_ids.remove(id) : _ids.add(id);
    _notify();
    return added;
  }

  void replace(Iterable<int> ids) {
    final next = ids.toSet();
    if (next.length == _ids.length && _ids.containsAll(next)) return;
    _ids
      ..clear()
      ..addAll(next);
    activeGrips.removeWhere((id, _) => !_ids.contains(id));
    _notify();
  }

  void clear() {
    if (_ids.isEmpty && activeGrips.isEmpty) return;
    _ids.clear();
    activeGrips.clear();
    _notify();
  }

  /// Drops ids that no longer exist, called after entities are erased.
  void prune(bool Function(int id) exists) {
    final stale = _ids.where((id) => !exists(id)).toList();
    if (stale.isEmpty) return;
    removeAll(stale);
  }

  void _notify() {
    if (!_controller.isClosed) _controller.add(ids);
  }

  void dispose() {
    _controller.close();
  }

  @override
  String toString() => 'SelectionSet(${_ids.length})';
}
