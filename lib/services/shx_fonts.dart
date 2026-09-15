import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:path/path.dart' as p;

/// Discovers SHX files on disk and builds the table the scene builder strokes.
///
/// Core never searches the filesystem. The host only reads `FANCAD_FONT_PATH`
/// and fonts that travel with the drawing — not another CAD install.
class ShxFontCatalog {
  static const envPath = 'FANCAD_FONT_PATH';

  /// Folders checked from first to last. A later file of the same family
  /// wins, so a `fonts/` next to the drawing overrides `FANCAD_FONT_PATH`.
  static List<String> searchDirectories({
    String? drawingPath,
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final dirs = <String>[];
    void add(String? path) {
      final trimmed = path?.trim() ?? '';
      if (trimmed.isEmpty) return;
      if (!dirs.contains(trimmed)) dirs.add(trimmed);
    }

    final extra = env[envPath];
    if (extra != null && extra.isNotEmpty) {
      final sep = Platform.isWindows ? ';' : ':';
      for (final part in extra.split(sep)) {
        add(part);
      }
    }

    final drawing = drawingPath?.trim() ?? '';
    if (drawing.isNotEmpty) {
      final dir = p.dirname(drawing);
      add(dir);
      add(p.join(dir, 'fonts'));
    }
    return dirs;
  }

  /// Parses every `.shx` in [directories], or the default search path.
  ///
  /// Empty or truncated files are skipped. Does not throw: a missing font
  /// must not prevent a drawing from opening.
  static ShxFontTable load({
    String? drawingPath,
    Map<String, String>? environment,
    Iterable<String>? directories,
  }) {
    final byFamily = <String, ShxFont>{};
    final dirs =
        directories ??
        searchDirectories(drawingPath: drawingPath, environment: environment);
    for (final dir in dirs) {
      final folder = Directory(dir);
      if (!folder.existsSync()) continue;
      try {
        for (final entity in folder.listSync(followLinks: false)) {
          if (entity is! File) continue;
          if (!entity.path.toLowerCase().endsWith('.shx')) continue;
          try {
            final font = ShxFont.parse(entity.readAsBytesSync());
            if (font.isEmpty) continue;
            final family = ShxFontTable.normalizeFamily(
              p.basename(entity.path),
            );
            if (family.isEmpty) continue;
            byFamily[family] = font;
          } catch (_) {}
        }
      } catch (_) {}
    }
    return ShxFontTable(byFamily);
  }
}
