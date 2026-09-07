import 'dart:io';

import 'package:test/test.dart';

/// A unique temp directory deleted after the current test.
Directory tempDir({String prefix = 'fancad'}) {
  final directory = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
  return directory;
}
