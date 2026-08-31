/// Lenient map decode. JSON and socket payloads arrive as `Map<dynamic, ...>`.
Map<String, Object?> asObjectMap(Object? raw) {
  if (raw is Map<String, Object?>) return raw;
  if (raw is Map) {
    return {for (final entry in raw.entries) '${entry.key}': entry.value};
  }
  return {};
}
