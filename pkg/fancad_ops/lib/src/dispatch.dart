import 'catalog.dart';
import 'encode.dart';
import 'request.dart';

/// The single entry: discover by `list`/`help`, then `run`.
class OpsDispatcher {
  OpsDispatcher(this.catalog);

  final OperationCatalog catalog;

  Future<Map<String, Object?>> dispatch(OpsRequest request) async {
    switch (request.action) {
      case OpsAction.list:
        return _list(request.path);
      case OpsAction.help:
        return _help(request.path);
      case OpsAction.schema:
        return _schema(request.path);
      case OpsAction.run:
        return _run(request);
    }
  }

  Map<String, Object?> _list(String path) {
    if (path.trim().isEmpty) return _groups();
    final operation = catalog.find(path);
    if (operation != null) {
      return ok({'path': operation.id, 'operations': [operation.summaryJson()]});
    }
    final group = catalog.inGroup(path);
    if (group.isNotEmpty) {
      return ok({
        'path': path.trim(),
        'operations': [for (final item in group) item.summaryJson()],
      });
    }
    return _unknown(path);
  }

  Map<String, Object?> _help(String path) {
    if (path.trim().isEmpty) return _groups();
    final operation = catalog.find(path);
    if (operation != null) {
      return ok(operation.helpJson());
    }
    final group = catalog.inGroup(path);
    if (group.isNotEmpty) {
      return ok({
        'path': path.trim(),
        'operations': [for (final item in group) item.summaryJson()],
        'hint': 'Call help with a command id, for example ${group.first.id}.',
      });
    }
    return _unknown(path);
  }

  Map<String, Object?> _schema(String path) {
    if (path.trim().isEmpty) {
      return failed('schema requires a command path, for example draw.line.');
    }
    final operation = catalog.find(path);
    if (operation == null) return _unknown(path);
    return ok({'id': operation.id, 'schema': operation.schema()});
  }

  Future<Map<String, Object?>> _run(OpsRequest request) async {
    if (!request.hasPath) {
      return failed(
        'run requires a path. Call help with no path to see groups.',
      );
    }
    final operation = catalog.find(request.path);
    if (operation == null) return _unknown(request.path);
    try {
      return await operation.execute(request.args);
    } catch (error) {
      return failed('$error');
    }
  }

  Map<String, Object?> _groups() {
    final groups = catalog.groups();
    return ok({
      'groups': [for (final group in groups) group.toJson()],
      'hint':
          'Call help with a group path (for example draw), then help with a '
          'command id, then run.',
    });
  }

  Map<String, Object?> _unknown(String path) {
    final groups = [for (final group in catalog.groups()) group.id];
    final known = groups.isEmpty ? 'none' : groups.join(', ');
    return failed('Unknown path: $path. Known groups: $known.');
  }
}

/// Entity ids a `run` is about to touch, used to highlight a preview.
List<int> highlightIdsOf(Map<String, Object?> arguments) {
  final ids = <int>{};
  for (final key in const ['ids', 'id', 'target', 'selection']) {
    _collectIds(arguments[key], ids);
  }
  return ids.toList();
}

void _collectIds(Object? value, Set<int> into) {
  if (value is int) {
    into.add(value);
  } else if (value is num) {
    into.add(value.toInt());
  } else if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) into.add(parsed);
  } else if (value is List) {
    for (final item in value) {
      _collectIds(item, into);
    }
  } else if (value is Map) {
    final id = value['id'];
    if (id != null) _collectIds(id, into);
  }
}
