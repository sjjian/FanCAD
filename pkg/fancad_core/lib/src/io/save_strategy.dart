import 'package:meta/meta.dart';

/// How a path should be written, given what this build can actually do.
@immutable
class SavePlan {
  const SavePlan({
    required this.targetPath,
    required this.format,
    this.fallbackPath,
    this.reason = '',
  });

  final String targetPath;
  final SaveFormat format;
  final String? fallbackPath;
  final String reason;

  bool get usedFallback => fallbackPath != null;
}

enum SaveFormat { dxf, dwg }

/// Chooses a writable format for a path.
///
/// When this document has objects the DWG writer cannot represent, the plan
/// falls back to DXF next to the requested file and says so, rather than
/// silently writing nothing.
class SaveStrategy {
  const SaveStrategy({
    this.canWriteDwg = false,
    this.dwgFallbackReason =
        'This drawing cannot be written as DWG; saving DXF instead.',
  });

  final bool canWriteDwg;
  final String dwgFallbackReason;

  SavePlan plan(String path) {
    final target = path.trim();
    final extension = _extension(target);
    switch (extension) {
      case 'dxf':
        return SavePlan(targetPath: target, format: SaveFormat.dxf);
      case 'dwg':
        if (canWriteDwg) {
          return SavePlan(targetPath: target, format: SaveFormat.dwg);
        }
        final dxf = '${_withoutExtension(target)}.dxf';
        return SavePlan(
          targetPath: dxf,
          format: SaveFormat.dxf,
          fallbackPath: dxf,
          reason: dwgFallbackReason,
        );
      default:
        final dxf = '${_withoutExtension(target)}.dxf';
        return SavePlan(
          targetPath: dxf,
          format: SaveFormat.dxf,
          fallbackPath: dxf,
          reason: 'Unsupported extension .$extension; saving DXF instead.',
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
