import 'package:meta/meta.dart';

import 'shx_font.dart';

/// Looks up a parsed SHX face by the STYLE `fontFamily`.
///
/// `txt`, `txt.shx` and `TXT.SHX` are the same key. The table only holds
/// fonts the caller already parsed; core does not search the disk.
@immutable
class ShxFontTable {
  const ShxFontTable([this._byFamily = const {}]);

  final Map<String, ShxFont> _byFamily;

  static const ShxFontTable empty = ShxFontTable();

  bool get isEmpty => _byFamily.isEmpty;

  /// The named face, or null when the table has no matching non-empty font.
  ShxFont? lookup(String family) {
    if (family.isEmpty || _byFamily.isEmpty) return null;
    final key = normalizeFamily(family);
    final direct = _byFamily[key] ?? _byFamily[family];
    if (direct != null) return direct.isEmpty ? null : direct;
    for (final entry in _byFamily.entries) {
      if (normalizeFamily(entry.key) == key) {
        return entry.value.isEmpty ? null : entry.value;
      }
    }
    return null;
  }

  static String normalizeFamily(String family) {
    var name = family.trim().toLowerCase();
    if (name.endsWith('.shx')) {
      name = name.substring(0, name.length - 4);
    }
    return name;
  }
}
