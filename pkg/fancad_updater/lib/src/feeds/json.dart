import '../release.dart';

/// Tolerant readers for the two release JSON shapes.
///
/// A missing or retyped field must degrade to a blank value, not throw: the
/// updater is talking to a service it does not control.
String? stringField(Map<Object?, Object?> json, String key) {
  final value = json[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

DateTime? dateField(Map<Object?, Object?> json, String key) =>
    DateTime.tryParse(stringField(json, key) ?? '');

bool boolField(Map<Object?, Object?> json, String key) => json[key] == true;

int? intField(Map<Object?, Object?> json, String key) {
  final value = json[key];
  return value is num ? value.toInt() : null;
}

/// Drops the leading `v` both services sometimes add to a tag.
String normaliseTag(String tag) {
  final trimmed = tag.trim();
  return trimmed.startsWith('v') || trimmed.startsWith('V')
      ? trimmed.substring(1)
      : trimmed;
}

List<ReleaseAsset> assetList(Object? raw) {
  if (raw is! List<Object?>) return const [];
  final assets = <ReleaseAsset>[];
  for (final item in raw) {
    if (item is! Map<Object?, Object?>) continue;
    final name = stringField(item, 'name');
    final url = stringField(item, 'browser_download_url');
    if (name == null || url == null) continue;
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme) continue;
    assets.add(
      ReleaseAsset(name: name, url: parsed, size: intField(item, 'size')),
    );
  }
  return List.unmodifiable(assets);
}
