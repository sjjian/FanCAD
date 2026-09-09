import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves [relative] inside [directory], refusing anything that escapes.
///
/// A plugin id and a path both arrive from a model in the authoring loop, so
/// `../../.zshrc` has to be rejected here rather than trusted.
File? resolveInside(String directory, String relative) {
  if (relative.trim().isEmpty) return null;
  if (p.isAbsolute(relative)) return null;
  final root = p.normalize(p.absolute(directory));
  final resolved = p.normalize(p.join(root, relative));
  if (!p.isWithin(root, resolved)) return null;
  return File(resolved);
}

bool isSafeSegment(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value);
