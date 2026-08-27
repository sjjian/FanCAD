import 'package:meta/meta.dart';

/// How a path should be written, given what this build can actually do.
@immutable
class SavePlan {
  const SavePlan({
    required this.targetPath,
    required this.format,
    this.fallbackPath,
    this.reason = '',
    this.dwgVersion = 2000,
  });

  final String targetPath;
  final SaveFormat format;
  final String? fallbackPath;
  final String reason;
  final int dwgVersion;

  bool get usedFallback => fallbackPath != null;
}

enum SaveFormat { dxf, dwg, fcb }

/// The file that was actually written.
class SaveOutcome {
  const SaveOutcome({required this.plan, required this.path});

  final SavePlan plan;
  final String path;

  bool get usedFallback => plan.usedFallback;
}

/// Chooses a writable format for a path.
///
/// DWG writing depends on LibreDWG and is only trustworthy for r2000/r2004.
/// When it is unavailable the plan falls back to DXF next to the requested
/// file and says so, rather than silently writing nothing.
class SaveStrategy {
  const SaveStrategy({
    this.canWriteDwg = false,
    this.canWriteDxf = true,
  });

  final bool canWriteDwg;
  final bool canWriteDxf;

  SavePlan plan(String path) {
    final target = path.trim();
    final extension = _extension(target);
    switch (extension) {
      case 'dxf':
        return SavePlan(
          targetPath: target,
          format: SaveFormat.dxf,
          reason: canWriteDxf ? '' : 'DXF writer unavailable',
        );
      case 'fcb':
        return SavePlan(targetPath: target, format: SaveFormat.fcb);
      case 'dwg':
        if (canWriteDwg) {
          return SavePlan(
            targetPath: target,
            format: SaveFormat.dwg,
            dwgVersion: 2000,
          );
        }
        final dxf = '${_withoutExtension(target)}.dxf';
        return SavePlan(
          targetPath: dxf,
          format: SaveFormat.dxf,
          fallbackPath: dxf,
          reason: 'This build cannot write DWG; saving DXF instead.',
        );
      default:
        final fcb = '${_withoutExtension(target)}.fcb';
        return SavePlan(
          targetPath: fcb,
          format: SaveFormat.fcb,
          fallbackPath: fcb,
          reason: 'Unknown extension .$extension; saving FanCAD FCB instead.',
        );
    }
  }

  /// Extension of the last path segment, so a dotted parent folder is ignored.
  static String _extension(String path) {
    final name = _fileName(path);
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  static String _withoutExtension(String path) {
    final name = _fileName(path);
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return path;
    return '${path.substring(0, path.length - name.length)}${name.substring(0, dot)}';
  }

  static String _fileName(String path) {
    final slash = path.lastIndexOf('/');
    final back = path.lastIndexOf(r'\');
    final sep = slash > back ? slash : back;
    return sep < 0 ? path : path.substring(sep + 1);
  }
}
