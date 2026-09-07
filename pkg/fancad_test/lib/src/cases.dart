import 'dart:async';

import 'package:test/test.dart';

/// Registers one [test] per row so a failure names the case.
///
/// Rows with a `name` field (records or objects) use that string. Pass [name]
/// when the row type has no such field.
void eachCase<C>(
  Iterable<C> rows,
  FutureOr<void> Function(C row) body, {
  String Function(C row)? name,
  Timeout? timeout,
}) {
  var index = 0;
  for (final row in rows) {
    final label = name?.call(row) ?? _caseName(row) ?? 'case $index';
    index += 1;
    test(label, () => body(row), timeout: timeout);
  }
}

/// Same as [eachCase], with the test name as the map key.
void eachNamed<V>(
  Map<String, V> rows,
  FutureOr<void> Function(V value) body, {
  Timeout? timeout,
}) {
  for (final entry in rows.entries) {
    test(entry.key, () => body(entry.value), timeout: timeout);
  }
}

String? _caseName(Object? row) {
  try {
    final value = (row as dynamic).name;
    if (value is String && value.isNotEmpty) return value;
  } catch (_) {}
  return null;
}
