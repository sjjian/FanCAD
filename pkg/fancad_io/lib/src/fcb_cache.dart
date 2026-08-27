import 'dart:io';
import 'dart:typed_data';

/// A disk cache of FCB buffers, keyed by source file identity.
///
/// Parsing a large DWG is the slowest step in opening a drawing, and it is
/// entirely deterministic, so the second open of an unchanged file should not
/// pay for it. The cache stores the exact bytes the native parser produced,
/// which means a cache hit skips both the parse and the FFI transfer.
class FcbCache {
  FcbCache({required this.directory, this.maxTotalBytes = 512 * 1024 * 1024});

  final Directory directory;

  /// Cached entries are evicted oldest-first once the directory exceeds this.
  final int maxTotalBytes;

  static const String _extension = '.fcb';

  /// Identity of a source file: path, size and modification time. A content
  /// hash would be more precise but would require reading the whole file,
  /// which defeats the purpose of the cache.
  static String keyFor(String sourcePath, {required int fcbVersion}) {
    final file = File(sourcePath);
    final stat = file.statSync();
    return _hash(
      '$fcbVersion|'
      '${file.absolute.path}|'
      '${stat.size}|'
      '${stat.modified.microsecondsSinceEpoch}',
    );
  }

  File _fileFor(String key) =>
      File('${directory.path}${Platform.pathSeparator}$key$_extension');

  Uint8List? read(String key) {
    final file = _fileFor(key);
    if (!file.existsSync()) return null;
    try {
      final bytes = file.readAsBytesSync();
      // Touch the entry so eviction is least-recently-used rather than
      // least-recently-written.
      file.setLastAccessedSync(DateTime.now());
      return bytes;
    } on FileSystemException {
      return null;
    }
  }

  void write(String key, Uint8List bytes) {
    try {
      directory.createSync(recursive: true);
      // Write to a temporary name first so a crash mid-write cannot leave a
      // truncated buffer that would later be decoded as a valid cache hit.
      final temporary = File('${_fileFor(key).path}.tmp');
      temporary.writeAsBytesSync(bytes, flush: true);
      temporary.renameSync(_fileFor(key).path);
      _evictIfNeeded();
    } on FileSystemException {
      // A cache is an optimisation; failing to populate it is not an error.
    }
  }

  void clear() {
    if (!directory.existsSync()) return;
    for (final entry in directory.listSync()) {
      if (entry is File && entry.path.endsWith(_extension)) {
        try {
          entry.deleteSync();
        } on FileSystemException {
          continue;
        }
      }
    }
  }

  int get totalBytes {
    if (!directory.existsSync()) return 0;
    var total = 0;
    for (final entry in directory.listSync()) {
      if (entry is File && entry.path.endsWith(_extension)) {
        total += entry.lengthSync();
      }
    }
    return total;
  }

  void _evictIfNeeded() {
    if (!directory.existsSync()) return;
    final files = [
      for (final entry in directory.listSync())
        if (entry is File && entry.path.endsWith(_extension)) entry,
    ];
    var total = 0;
    for (final file in files) {
      total += file.lengthSync();
    }
    if (total <= maxTotalBytes) return;

    files.sort(
      (a, b) => a.statSync().accessed.compareTo(b.statSync().accessed),
    );
    for (final file in files) {
      if (total <= maxTotalBytes) break;
      final size = file.lengthSync();
      try {
        file.deleteSync();
        total -= size;
      } on FileSystemException {
        continue;
      }
    }
  }

  /// FNV-1a, rendered as hex. A cryptographic digest is unnecessary here: the
  /// key only needs to be a stable, collision-unlikely file name.
  static String _hash(String input) {
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    const mask = 0xFFFFFFFFFFFFFFFF;
    for (final unit in input.codeUnits) {
      hash = (hash ^ unit) & mask;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
