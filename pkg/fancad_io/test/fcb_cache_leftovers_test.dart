import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  test('a missing cache directory is empty rather than a failed open', () {
    final root = Directory.systemTemp.createTempSync('fancad-cache-missing');
    addTearDown(() => root.deleteSync(recursive: true));
    final cache = FcbCache(directory: Directory('${root.path}/nested'));

    expect(cache.totalBytes, 0);
    expect(cache.read('nope'), isNull);
    cache.clear();
    expect(Directory('${root.path}/nested').existsSync(), isFalse);
  });

  test('an import-revision bump cannot reuse a stale FCB buffer', () {
    final root = Directory.systemTemp.createTempSync('fancad-cache-rev');
    addTearDown(() => root.deleteSync(recursive: true));
    final source = File('${root.path}/a.dwg')..writeAsBytesSync([1, 2, 3]);
    final previous = FcbCache.keyFor(
      source.path,
      fcbVersion: fcbVersion,
      importRevision: 1,
    );
    final current = FcbCache.keyFor(
      source.path,
      fcbVersion: fcbVersion,
      importRevision: fcbImportRevision,
    );
    expect(current, isNot(previous));
  });

  test('clear drops cached buffers and ignores leftover scratch files', () {
    final dir = Directory.systemTemp.createTempSync('fancad-cache-clear');
    addTearDown(() => dir.deleteSync(recursive: true));
    final cache = FcbCache(directory: dir);

    cache.write('keep', Uint8List.fromList([1, 2, 3]));
    File('${dir.path}/scratch.tmp').writeAsBytesSync([9, 9]);
    File('${dir.path}/notes.txt').writeAsStringSync('not a cache entry');
    expect(cache.totalBytes, 3);

    cache.clear();
    expect(cache.read('keep'), isNull);
    expect(cache.totalBytes, 0);
    expect(File('${dir.path}/scratch.tmp').existsSync(), isTrue);
    expect(File('${dir.path}/notes.txt').existsSync(), isTrue);
  });
}
