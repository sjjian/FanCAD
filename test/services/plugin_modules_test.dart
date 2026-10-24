import 'dart:convert';
import 'dart:io';

import 'package:fancad/commands/extension/commands.dart';
import 'package:fancad_extension/fancad_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('require stays inside the extension folder', () async {
    final parent = await Directory.systemTemp.createTemp('fancad-mod');
    addTearDown(() => parent.delete(recursive: true));
    final root = Directory(p.join(parent.path, 'ext'))..createSync();
    File(p.join(root.path, 'main.js')).writeAsStringSync('');
    File(p.join(root.path, 'data.json')).writeAsStringSync('{"name":"ada"}');
    final outside = File(p.join(parent.path, 'secret.js'))
      ..writeAsStringSync('exports.leaked = true;\n');
    Link(p.join(root.path, 'sneak.js')).createSync(outside.path);

    final from = p.join(root.path, 'main.js');
    final data = jsonDecode(
      pluginModuleReply(
        root: root.path,
        fromFile: from,
        specifier: './data.json',
      ),
    );
    expect(data['kind'], 'json');
    expect(data['source'], '{"name":"ada"}');

    final bare = jsonDecode(
      pluginModuleReply(root: root.path, fromFile: from, specifier: 'lodash'),
    );
    expect(bare['error'], contains('relative path'));

    final escaped = jsonDecode(
      pluginModuleReply(
        root: root.path,
        fromFile: from,
        specifier: '../secret.js',
      ),
    );
    expect(escaped['error'], contains('outside'));

    final linked = jsonDecode(
      pluginModuleReply(
        root: root.path,
        fromFile: from,
        specifier: './sneak.js',
      ),
    );
    expect(linked['error'], contains('outside'));

    final missing = jsonDecode(
      pluginModuleReply(root: '', fromFile: from, specifier: './data.json'),
    );
    expect(missing['error'], 'this extension has no folder');
  });

  test('a plugin can require nested files and still define activate', () async {
    _linkQuickJsForTests();
    final root = await Directory.systemTemp.createTemp('fancad-plug');
    addTearDown(() => root.delete(recursive: true));
    Directory(p.join(root.path, 'lib')).createSync();
    File(p.join(root.path, 'data.json')).writeAsStringSync('{"name":"ada"}');
    File(
      p.join(root.path, 'lib', 'extra.js'),
    ).writeAsStringSync('exports.prefix = "hi ";\n');
    File(p.join(root.path, 'lib', 'util.js')).writeAsStringSync('''
const extra = require("./extra.js");
exports.greet = function (name) { return extra.prefix + name; };
''');
    File(p.join(root.path, 'a.js')).writeAsStringSync('''
exports.name = "a";
const b = require("./b.js");
exports.other = b.name;
exports.back = b.back;
''');
    File(p.join(root.path, 'b.js')).writeAsStringSync('''
exports.name = "b";
const a = require("./a.js");
exports.back = a.name;
''');
    final main = '''
const util = require("./lib/util.js");
const data = require("./data.json");
const parts = require("./a.js");
globalThis.loaded = util.greet(data.name);
globalThis.cycle = parts.name + parts.other + parts.back;
function activate() { globalThis.activated = true; }
''';

    final runtime = PluginRuntime(
      engines: EngineRegistry.production(),
      callHost: (_, _, _) async => null,
    );
    addTearDown(() async {
      if (runtime.isLoaded('demo')) await runtime.unload('demo');
    });
    await runtime.load(
      PluginManifest(
        id: 'demo',
        name: 'demo',
        version: '0.1.0',
        entryPoint: 'main.js',
        directory: root.path,
      ),
      main,
    );
    expect((await runtime.evaluate('demo', 'loaded'))['value'], 'hi ada');
    expect((await runtime.evaluate('demo', 'cycle'))['value'], 'aba');
    expect((await runtime.evaluate('demo', 'activated'))['value'], true);

    await expectLater(
      runtime.load(
        PluginManifest(
          id: 'loose',
          name: 'loose',
          version: '0.1.0',
          entryPoint: 'main.js',
          directory: root.path,
        ),
        'require("lodash")',
      ),
      throwsA(
        isA<RpcException>().having(
          (error) => error.message,
          'message',
          contains('relative path'),
        ),
      ),
    );
  });

  test('header comment, top-level await, and return evaluate', () async {
    _linkQuickJsForTests();
    final runtime = PluginRuntime(
      engines: EngineRegistry.production(),
      callHost: (_, _, _) async => null,
    );
    addTearDown(runtime.disposeAll);
    await runtime.load(
      PluginManifest(
        id: 'scratch',
        name: 'scratch',
        version: '0.0.0',
        entryPoint: 'scratch.js',
      ),
      'void 0;\n',
    );

    Future<Object?> run(String source) async {
      Object? value;
      final programs = extensionPrograms(source);
      for (var i = 0; i < programs.length; i++) {
        try {
          value = (await runtime.evaluate('scratch', programs[i]))['value'];
        } on RpcException catch (error) {
          final retry =
              i + 1 < programs.length &&
              error.message.startsWith('SyntaxError');
          if (retry) continue;
          rethrow;
        }
        final failure = extensionFailure(value);
        if (failure != null) {
          throw RpcException(RpcErrorCode.pluginError, failure);
        }
        return extensionValue(value);
      }
      return value;
    }

    expect(await run('1 + 1'), 2);
    expect(
      await run('''
/**
 * description: probe3
 */
const a = 1 + 2;
a * 10;
'''),
      isNull,
    );
    expect(
      await run('''
/**
 * description: probe
 */
await Promise.resolve(1);
'''),
      isNull,
    );
    expect(
      await run('''
/**
 * description: circles
 */
return { created: 1 };
'''),
      {'created': 1},
    );
    await expectLater(
      run('throw new Error("nope")'),
      throwsA(
        isA<RpcException>().having(
          (error) => error.message,
          'message',
          contains('nope'),
        ),
      ),
    );
  });
}

/// `flutter test` only finds the QuickJS bridge under `packages/`. The
/// published package keeps the library in `macos/Frameworks`, so the test
/// points the search path at it and removes the link afterwards.
void _linkQuickJsForTests() {
  const name = 'libquickjs_c_bridge_plugin.dylib';
  final destDir = Directory('packages/quickjs_engine/native/build');
  final dest = File(p.join(destDir.path, name));
  if (dest.existsSync()) return;
  final source = _quickJsBridge();
  if (source == null) {
    throw StateError('quickjs bridge library was not found');
  }
  destDir.createSync(recursive: true);
  Link(dest.path).createSync(source);
  addTearDown(() async {
    if (dest.existsSync()) dest.deleteSync();
    var dir = destDir;
    while (p.basename(dir.path) != 'packages') {
      if (dir.listSync().isEmpty) dir.deleteSync();
      dir = dir.parent;
    }
    if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
  });
}

String? _quickJsBridge() {
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, Object?>;
  for (final pkg in config['packages']! as List) {
    final entry = pkg as Map<String, Object?>;
    if (entry['name'] != 'quickjs_engine') continue;
    final rootUri = entry['rootUri']! as String;
    final root = rootUri.startsWith('file:')
        ? Uri.parse(rootUri).toFilePath()
        : p.normalize(p.join('.dart_tool', rootUri));
    final lib = File(
      p.join(root, 'macos', 'Frameworks', 'libquickjs_c_bridge_plugin.dylib'),
    );
    if (lib.existsSync()) return lib.path;
  }
  return null;
}
