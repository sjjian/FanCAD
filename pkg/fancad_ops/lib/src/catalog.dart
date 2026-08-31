import 'operation.dart';

/// Live union of [OperationProvider]s plus any extra registrations.
///
/// Providers are queried on each lookup so a plugin unload is visible on the
/// next `list` without a rebuild.
class OperationCatalog {
  final List<OperationProvider> _providers = [];
  final Map<String, Operation> _extra = {};

  void addProvider(OperationProvider provider) => _providers.add(provider);

  void register(Operation operation) => _extra[operation.id] = operation;

  void unregister(String id) => _extra.remove(id);

  Iterable<Operation> get all sync* {
    final seen = <String>{};
    for (final operation in _extra.values) {
      if (seen.add(operation.id)) yield operation;
    }
    for (final provider in _providers) {
      for (final operation in provider.operations()) {
        if (seen.add(operation.id)) yield operation;
      }
    }
  }

  /// Resolves a dotted id or a command-line alias.
  Operation? find(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    for (final operation in all) {
      if (_matches(operation, trimmed)) return operation;
    }
    return null;
  }

  bool get isEmpty => all.isEmpty;

  List<Operation> inGroup(String group) {
    final key = group.trim().toLowerCase();
    final found = [
      for (final operation in all)
        if (operation.group.toLowerCase() == key) operation,
    ];
    found.sort((a, b) => a.id.compareTo(b.id));
    return found;
  }

  /// Groups currently contributed, sorted by id.
  List<OperationGroup> groups() {
    final buckets = <String, _GroupBucket>{};
    for (final operation in all) {
      final bucket = buckets.putIfAbsent(
        operation.group,
        () => _GroupBucket(operation.group, operation.groupTitle),
      );
      bucket.count += 1;
      if (bucket.title.isEmpty && operation.groupTitle.isNotEmpty) {
        bucket.title = operation.groupTitle;
      }
    }
    final groups = [
      for (final bucket in buckets.values)
        OperationGroup(
          id: bucket.id,
          title: bucket.title.isEmpty ? bucket.id : bucket.title,
          count: bucket.count,
        ),
    ]..sort((a, b) => a.id.compareTo(b.id));
    return groups;
  }
}

class _GroupBucket {
  _GroupBucket(this.id, this.title);

  final String id;
  String title;
  int count = 0;
}

/// A top-level `list` / `help` row.
class OperationGroup {
  const OperationGroup({
    required this.id,
    required this.title,
    required this.count,
  });

  final String id;
  final String title;
  final int count;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'count': count,
    'description': '$title operations. Call help with path=$id.',
  };
}

bool _matches(Operation operation, String path) {
  if (operation.id == path) return true;
  if (operation.id.toLowerCase() == path.toLowerCase()) return true;
  for (final alias in operation.aliases) {
    if (alias.toLowerCase() == path.toLowerCase()) return true;
  }
  return false;
}
