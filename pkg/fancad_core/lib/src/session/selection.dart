import 'dart:async';

/// The current selection set for one document.
///
/// Selection is intentionally *not* stored on entities. Keeping it in a side
/// structure means selecting a thousand entities costs one set insertion each
/// instead of a thousand entity replacements and a thousand undo patches.
class SelectionSet {
  SelectionSet();

  final Set<int> _ids = <int>{};
  final Set<int> _viewports = <int>{};
  final StreamController<Set<int>> _controller =
      StreamController<Set<int>>.broadcast(sync: true);

  /// Grip index currently being dragged, keyed by entity id. Populated by the
  /// grip editing tool.
  final Map<int, int> activeGrips = {};

  Stream<Set<int>> get changes => _controller.stream;

  Set<int> get ids => Set.unmodifiable(_ids);

  /// Indices into [Layout.viewports] of the active paper tab.
  Set<int> get viewportIndices => Set.unmodifiable(_viewports);

  int get length => _ids.length;
  bool get isEmpty => _ids.isEmpty && _viewports.isEmpty;
  bool get isNotEmpty => !isEmpty;
  bool get isSingle => _ids.length == 1;

  /// The only selected id, or null when the selection is not a single entity.
  int? get single => _ids.length == 1 ? _ids.first : null;

  bool contains(int id) => _ids.contains(id);

  bool add(int id) {
    final cleared = _viewports.isNotEmpty;
    _viewports.clear();
    if (!_ids.add(id) && !cleared) return false;
    _notify();
    return true;
  }

  int addAll(Iterable<int> ids) {
    final cleared = _viewports.isNotEmpty;
    final before = _ids.length;
    _viewports.clear();
    _ids.addAll(ids);
    if (_ids.length == before && !cleared) return 0;
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
    _viewports.clear();
    final added = _ids.contains(id) ? !_ids.remove(id) : _ids.add(id);
    _notify();
    return added;
  }

  void replace(Iterable<int> ids) {
    final next = ids.toSet();
    if (next.length == _ids.length &&
        _ids.containsAll(next) &&
        _viewports.isEmpty) {
      return;
    }
    _ids
      ..clear()
      ..addAll(next);
    _viewports.clear();
    activeGrips.removeWhere((id, _) => !_ids.contains(id));
    _notify();
  }

  /// Selects paper-space viewport windows. Entity selection is cleared.
  void selectViewports(Iterable<int> indices) {
    final next = indices.toSet();
    if (next.length == _viewports.length &&
        _viewports.containsAll(next) &&
        _ids.isEmpty) {
      return;
    }
    _ids.clear();
    activeGrips.clear();
    _viewports
      ..clear()
      ..addAll(next);
    _notify();
  }

  void clear() {
    if (_ids.isEmpty && activeGrips.isEmpty && _viewports.isEmpty) return;
    _ids.clear();
    _viewports.clear();
    activeGrips.clear();
    _notify();
  }

  /// Drops ids that no longer exist, called after entities are erased.
  void prune(bool Function(int id) exists) {
    final stale = _ids.where((id) => !exists(id)).toList();
    if (stale.isEmpty) return;
    removeAll(stale);
  }

  /// Drops viewport indices that are no longer on the active layout.
  void pruneViewports(int viewportCount) {
    final stale = _viewports.where((index) => index < 0 || index >= viewportCount).toList();
    if (stale.isEmpty) return;
    for (final index in stale) {
      _viewports.remove(index);
    }
    _notify();
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
