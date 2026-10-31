import 'dart:io';

import 'sha256.dart';

/// Hashes a file without loading it into memory.
Future<String> sha256OfFile(File file) async {
  final digest = Sha256();
  await for (final chunk in file.openRead()) {
    digest.add(chunk);
  }
  return digest.close();
}
