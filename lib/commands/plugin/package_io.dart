import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Copies or unpacks a plugin into [destination], refusing paths that escape.
///
/// [source] is either a directory that contains `fancad.plugin.json` or a
/// `.fancadplugin` / `.zip` archive of that directory. The manifest may sit at
/// the root or one folder down, which is how a zip of a plugin folder arrives.
Future<Directory> stagePlugin(String source, String destination) async {
  final root = Directory(destination);
  if (root.existsSync()) {
    throw StateError('destination already exists');
  }
  await root.create(recursive: true);
  final from = FileSystemEntity.typeSync(source);
  if (from == FileSystemEntityType.directory) {
    await _copyTree(Directory(source), root);
  } else if (from == FileSystemEntityType.file) {
    await _unzip(File(source), root);
  } else {
    throw StateError('not a folder or a plugin package');
  }
  final manifest = _findManifest(root);
  if (manifest == null) {
    await root.delete(recursive: true);
    throw StateError('no fancad.plugin.json in the package');
  }
  return manifest;
}

Future<void> zipPlugin(Directory source, File destination) async {
  final archive = Archive();
  final root = p.normalize(source.absolute.path);
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative = p.relative(entity.path, from: root);
    if (!_inside(root, entity.path)) {
      throw StateError('refusing to pack $relative');
    }
    final bytes = await entity.readAsBytes();
    archive.addFile(
      ArchiveFile(relative.replaceAll('\\', '/'), bytes.length, bytes),
    );
  }
  final encoded = ZipEncoder().encode(archive);
  await destination.parent.create(recursive: true);
  await destination.writeAsBytes(encoded);
}

Future<void> _copyTree(Directory source, Directory destination) async {
  final root = p.normalize(source.absolute.path);
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    if (!_inside(root, entity.path)) {
      throw StateError('refusing to copy a path that leaves the plugin');
    }
    final relative = p.relative(entity.path, from: root);
    final target = p.join(destination.path, relative);
    if (entity is Directory) {
      await Directory(target).create(recursive: true);
    } else if (entity is File) {
      await File(target).parent.create(recursive: true);
      await entity.copy(target);
    }
  }
}

Future<void> _unzip(File archiveFile, Directory destination) async {
  final root = p.normalize(destination.absolute.path);
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(await archiveFile.readAsBytes());
  } on Object {
    throw StateError('not a plugin package');
  }
  for (final file in archive) {
    final name = file.name.replaceAll('\\', '/');
    if (name.startsWith('/') || name.contains('..')) {
      throw StateError('refusing a package path that leaves the plugin');
    }
    final target = p.normalize(p.join(root, name));
    if (!_inside(root, target) && target != root) {
      throw StateError('refusing a package path that leaves the plugin');
    }
    if (!file.isFile) {
      await Directory(target).create(recursive: true);
      continue;
    }
    final out = File(target);
    await out.parent.create(recursive: true);
    await out.writeAsBytes(file.content);
  }
}

Directory? _findManifest(Directory root) {
  final direct = File(p.join(root.path, 'fancad.plugin.json'));
  if (direct.existsSync()) return root;
  final children = root.listSync().whereType<Directory>().toList();
  if (children.length != 1) return null;
  final nested = File(p.join(children.single.path, 'fancad.plugin.json'));
  if (nested.existsSync()) return children.single;
  return null;
}

bool _inside(String root, String path) {
  final resolved = p.normalize(p.absolute(path));
  return resolved == root || p.isWithin(root, resolved);
}
