import 'dart:convert';
import 'dart:io';

import 'package:fancad_extension/fancad_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ScriptRunner quickJsRunner({
    PluginCallHandler? onCall,
    Duration timeout = const Duration(seconds: 30),
  }) {
    _linkQuickJsForTests();
    final runner = ScriptRunner(
      openTransport: () => LocalTransport(
        engineFactory: ({required memoryLimit, required stackSize}) =>
            EngineRegistry.production().create(
              EngineRuntimes.quickjs,
              memoryLimit: memoryLimit,
              stackSize: stackSize,
            ),
      ),
      onCall: onCall ?? (_, _, _) async => null,
      timeout: timeout,
    );
    addTearDown(runner.dispose);
    return runner;
  }

  test('header comment, top-level await, and return evaluate', () async {
    final runner = quickJsRunner();

    Future<Object?> run(String source) async {
      final result = await runner.run(source);
      if (!result.isOk) throw StateError(result.message);
      return result.data?['value'];
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
    final thrown = await runner.run('throw new Error("nope")');
    expect(thrown.isFailed, isTrue);
    expect(thrown.message, contains('nope'));
  });

  test('each run gets its own engine and its own args', () async {
    final runner = quickJsRunner();

    final first = await runner.run(
      'globalThis.leak = 1; return fancad.args.n * 2;',
      args: {'n': 21},
    );
    expect(first.data?['value'], 42);

    final second = await runner.run('return typeof globalThis.leak;');
    expect(second.data?['value'], 'undefined');
    expect(runner.isBusy, isFalse);
  });

  test('host calls carry the run scope and return to the script', () async {
    final seen = <(String, String, Object?)>[];
    final runner = quickJsRunner(
      onCall: (scope, method, params) async {
        seen.add((scope, method, params['command']));
        return {
          'status': 'ok',
          'data': {'echo': params['args']},
        };
      },
    );

    final result = await runner.run('''
const reply = await fancad.commands.execute("test.echo", { x: 1 });
return reply;
''');
    expect(result.isOk, isTrue, reason: result.message);
    expect(seen, hasLength(1));
    expect(seen.single.$1, startsWith('run-'));
    expect(seen.single.$2, HostMethod.executeCommand);
    expect(seen.single.$3, 'test.echo');
  });

  test(
    'a run that never finishes times out and the next run starts fresh',
    () async {
      final runner = quickJsRunner(timeout: const Duration(milliseconds: 300));

      final stuck = await runner.run('await new Promise(() => {});');
      expect(stuck.isFailed, isTrue);
      expect(runner.isBusy, isFalse);

      final next = await runner.run('return 7;');
      expect(next.data?['value'], 7);
    },
  );
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
