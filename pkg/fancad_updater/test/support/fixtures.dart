import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// Locates the package root so tests can read the committed fixtures without
/// depending on the directory `dart test` was started from.
Future<Directory> packageRoot() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:fancad_updater/fancad_updater.dart'),
  );
  if (uri == null) throw StateError('Cannot locate the package');
  return File.fromUri(uri).parent.parent;
}

Future<Uint8List> fixtureBytes(String name) async {
  final root = await packageRoot();
  return File('${root.path}/test/fixtures/$name').readAsBytes();
}

Future<String> fixtureText(String name) async {
  final root = await packageRoot();
  return File('${root.path}/test/fixtures/$name').readAsString();
}
