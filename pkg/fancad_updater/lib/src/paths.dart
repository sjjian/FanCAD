import 'dart:io';

/// Minimal path helpers.
///
/// The package stays dependency free, so the few joins and dirnames the
/// updater needs are here instead of `package:path`. Both separators are
/// understood because a Windows path can reach one of these helpers while the
/// tests run on macOS.
String dirname(String path) {
  var end = path.length;
  while (end > 0 && (path[end - 1] == '/' || path[end - 1] == '\\')) {
    end--;
  }
  if (end == 0) return path.startsWith('/') ? '/' : '.';
  for (var index = end - 1; index >= 0; index--) {
    final unit = path[index];
    if (unit == '/' || unit == '\\') {
      if (index == 0) return unit;
      // Keep the drive root intact: dirname(r'C:\x.exe') is r'C:\'.
      if (index == 2 && path[1] == ':') return path.substring(0, 3);
      return path.substring(0, index);
    }
  }
  return '.';
}

String basename(String path) {
  var end = path.length;
  while (end > 0 && (path[end - 1] == '/' || path[end - 1] == '\\')) {
    end--;
  }
  if (end == 0) return path;
  for (var index = end - 1; index >= 0; index--) {
    final unit = path[index];
    if (unit == '/' || unit == '\\') return path.substring(index + 1, end);
  }
  return path.substring(0, end);
}

String joinPath(String first, String second) {
  if (first.isEmpty) return second;
  final separator = first.contains('\\') && !first.contains('/')
      ? '\\'
      : Platform.pathSeparator;
  return first.endsWith('/') || first.endsWith('\\')
      ? '$first$second'
      : '$first$separator$second';
}

/// A safe local file name for a release asset.
///
/// Asset names come from the network; a `../` in one must never escape the
/// updates directory.
String safeFileName(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll('..', '_')
      .trim();
  if (cleaned.isEmpty) return 'download';
  return cleaned;
}

/// Whether the updater could create a file next to [directory].
Future<bool> isDirectoryWritable(Directory directory) async {
  try {
    final probe = File(
      joinPath(
        directory.path,
        '.fancad-write-probe-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await probe.writeAsString('', flush: true);
    await probe.delete();
    return true;
  } on FileSystemException {
    return false;
  } on ArgumentError {
    return false;
  }
}
