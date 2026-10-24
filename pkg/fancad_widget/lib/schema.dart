/// A view tree a plugin asked the shell to draw.
///
/// The catalog is closed on purpose. A plugin composes these nodes; the shell
/// turns them into Flutter. There is no channel for an arbitrary widget.
///
/// This library stays free of Flutter so a plugin isolate can validate a tree
/// without loading the widget catalog or the renderer.
class ViewTreeException implements Exception {
  const ViewTreeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Node types the shell knows how to paint.
const viewNodeTypes = {
  'column',
  'row',
  'scroll',
  'padding',
  'spacer',
  'divider',
  'expanded',
  'text',
  'icon',
  'image',
  'button',
  'textField',
  'numberField',
  'checkbox',
  'dropdown',
  'slider',
  'layerPicker',
  'colorField',
  'entityChip',
  'preview',
  'viewer',
};

const _layoutTypes = {'column', 'row', 'scroll', 'padding', 'expanded'};

/// Checks [raw] and returns a tree the shell can render without looking back
/// at the script.
///
/// Every node needs a stable [id] so a text field keeps its focus when the
/// plugin replaces the tree. Ids are unique within the tree.
Map<String, Object?> parseViewTree(Object? raw) {
  final seen = <String>{};
  final node = _node(raw, 'view', seen);
  return node;
}

Map<String, Object?> _node(Object? raw, String where, Set<String> seen) {
  if (raw is! Map) {
    throw ViewTreeException('$where: expected an object');
  }
  final json = Map<String, Object?>.from(raw);
  final type = json['type'];
  if (type is! String || !viewNodeTypes.contains(type)) {
    throw ViewTreeException('$where.type: unknown node "$type"');
  }
  final id = json['id'];
  if (id is! String || id.trim().isEmpty) {
    throw ViewTreeException('$where.id: every node needs a stable id');
  }
  if (!seen.add(id)) {
    throw ViewTreeException('$where.id: "$id" is used more than once');
  }
  final props = _props(json);
  if (type == 'image') _checkAsset(props['asset'], '$where.asset');
  if (type == 'viewer') {
    final canvas = props['canvas'];
    if (canvas is! String || canvas.trim().isEmpty) {
      throw ViewTreeException('$where.canvas: a viewer needs a canvas id');
    }
  }
  final children = <Map<String, Object?>>[];
  final rawChildren = json['children'];
  if (rawChildren != null) {
    if (rawChildren is! List) {
      throw ViewTreeException('$where.children: expected an array');
    }
    // The shell stores every node with a children array, so a leaf comes
    // back as []. That is the same as omitting the key. A non-empty list on
    // a leaf is still an error.
    if (rawChildren.isNotEmpty && !_layoutTypes.contains(type)) {
      throw ViewTreeException('$where: $type cannot have children');
    }
    for (final (index, child) in rawChildren.indexed) {
      children.add(_node(child, '$where.children[$index]', seen));
    }
  } else if (_layoutTypes.contains(type) &&
      type != 'spacer' &&
      type != 'divider') {
    // spacer and divider are not layout types. column/row/scroll/padding/
    // expanded may be empty; an empty column is a blank panel, not an error.
  }
  return {'type': type, 'id': id, 'props': props, 'children': children};
}

Map<String, Object?> _props(Map<String, Object?> json) {
  final nested = json['props'];
  if (nested is Map) return Map<String, Object?>.from(nested);
  const reserved = {'type', 'id', 'children', 'props'};
  return {
    for (final entry in json.entries)
      if (!reserved.contains(entry.key)) entry.key: entry.value,
  };
}

void _checkAsset(Object? asset, String where) {
  if (asset is! String || asset.trim().isEmpty) {
    throw ViewTreeException('$where: image needs an asset path');
  }
  final normalized = asset.replaceAll('\\', '/');
  if (normalized.startsWith('/') || normalized.contains('..')) {
    throw ViewTreeException('$where: asset must stay inside the plugin folder');
  }
}
