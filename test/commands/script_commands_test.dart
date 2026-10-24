import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Headless app;
  late Directory root;
  late ScriptCommands scripts;

  setUp(() {
    root = tempDir(prefix: 'fancad-scripts');
    app = Headless();
    scripts = ScriptCommands(
      directory: root.path,
      runScript: (source, {required args}) async {
        if (source.contains('throw')) {
          return const CommandResult.failed('boom');
        }
        return CommandResult.ok(data: {'value': source.trim(), 'args': args});
      },
    );
    for (final descriptor in scripts.descriptors()) {
      app.workspace.commands.register(descriptor);
    }
    scripts.watch(app.workspace.commands);
  });

  Future<CommandResult> run(
    String id, [
    Map<String, Object?> args = const {},
  ]) => app.workspace.runHeadless(id, args: args);

  Future<CommandResult> invoke(
    String id, [
    Map<String, Object?> args = const {},
  ]) => app.workspace.runSavedScript(id, args: args);

  test('extensions.doc returns the writing guide', () async {
    final result = await run('extensions.doc');
    expect(result.status, CommandStatus.ok);
    expect(result.data!['guide'], extensionGuide);
    expect(result.data!['guide'], contains('fancad.commands.execute'));
    expect(result.data!['guide'], contains('param center: point'));
  });

  test(
    'write, list, read, run, and delete stay inside the scripts folder',
    () async {
      expect((await run('extensions.list')).data!['extensions'], isEmpty);

      final wrote = await run('extensions.write', {
        'name': 'polar',
        'content': '1 + 1\n',
      });
      expect(wrote.status, CommandStatus.ok);
      expect(File(p.join(root.path, 'polar.js')).readAsStringSync(), '1 + 1\n');

      final escaped = await run('extensions.write', {
        'name': '../secret',
        'content': 'nope',
      });
      expect(escaped.status, CommandStatus.failed);

      final listed = await run('extensions.list');
      expect(listed.data!['extensions'], [
        {'name': 'polar'},
      ]);

      final read = await run('extensions.read', {'name': 'polar.js'});
      expect(read.data!['content'], '1 + 1\n');
      expect(read.data!.containsKey('description'), isFalse);

      const noted = '''
/**
 * description: Arrays the selection
 *   around its center.
 * usage: Select objects, then run.
 */
1 + 1
''';
      final withNote = await run('extensions.write', {
        'name': 'noted',
        'content': noted,
      });
      expect(withNote.status, CommandStatus.ok);
      final notedList =
          (await run('extensions.list')).data!['extensions'] as List;
      expect(
        notedList.singleWhere((item) => (item as Map)['name'] == 'noted'),
        {
          'name': 'noted',
          'description': 'Arrays the selection around its center.',
          'usage': 'Select objects, then run.',
        },
      );
      final notedRead = await run('extensions.read', {'name': 'noted'});
      expect(
        notedRead.data!['description'],
        'Arrays the selection around its center.',
      );
      expect(notedRead.data!['usage'], 'Select objects, then run.');

      final blocked = await run('extension.polar');
      expect(blocked.status, CommandStatus.failed);
      expect(blocked.message, contains('runHeadless'));

      final ran = await invoke('polar');
      expect(ran.status, CommandStatus.ok);
      expect(ran.data!['value'], '1 + 1');
      expect(ran.data!['args'], isEmpty);

      final byId = await invoke('extension.polar');
      expect(byId.status, CommandStatus.ok);

      final inline = await run('extensions.run', {'source': 'throw'});
      expect(inline.status, CommandStatus.failed);
      expect(inline.message, 'boom');

      final named = await run('extensions.run', {'name': 'polar'});
      expect(named.status, CommandStatus.failed);

      await run('extensions.run', {'source': 'throw'});
      expect(
        (await run('extensions.list')).data!['extensions'],
        isNot(contains(containsPair('error', 'boom'))),
      );

      final bad = await run('extensions.write', {
        'name': 'bad',
        'content': 'throw',
      });
      expect(bad.status, CommandStatus.ok);
      final failed = await invoke('bad');
      expect(failed.message, 'boom');
      final after = (await run('extensions.list')).data!['extensions'] as List;
      expect(
        after.singleWhere((item) => (item as Map)['name'] == 'bad')['error'],
        'boom',
      );

      expect(
        (await run('extensions.delete', {'name': 'polar'})).status,
        CommandStatus.ok,
      );
      expect(File(p.join(root.path, 'polar.js')).existsSync(), isFalse);
    },
  );

  test('only the opening comment supplies description and usage', () {
    expect(
      scriptNote(
        '// description: Line form.\n// usage: Just run.\n1\n',
      ).description,
      'Line form.',
    );
    expect(
      scriptNote('// description: Line form.\n// usage: Just run.\n1\n').usage,
      'Just run.',
    );
    expect(
      scriptNote(
        'const x = 1;\n/**\n * description: hidden\n */\n',
      ).description,
      isNull,
    );
    expect(scriptNote('/**\n * description: \n * usage:\n */\n').usage, isNull);
    final noted = scriptNote('''
/**
 * description: Circles.
 * param center: point Centre
 * param count: integer = 3 How many
 * param nope: widget
 */
''');
    expect(noted.params.map((param) => param.name), ['center', 'count']);
    expect(noted.params.first.type, ParamType.point);
    expect(noted.params.first.required, isTrue);
    expect(noted.params.last.defaultValue, 3);
    expect(noted.params.last.required, isFalse);
    expect(noted.params.last.prompt, 'How many');
  });

  test('a saved script command asks only for missing parameters', () async {
    const source = '''
/**
 * description: Concentric circles.
 * param center: point Centre
 * param count: integer = 3 Count
 */
1
''';
    expect(
      (await run('extensions.write', {
        'name': 'rings',
        'content': source,
      })).status,
      CommandStatus.ok,
    );
    final listed = (await run('extensions.list')).data!['extensions'] as List;
    final rings =
        listed.singleWhere((item) => (item as Map)['name'] == 'rings') as Map;
    expect(rings['params'], [
      {'name': 'center', 'type': 'point', 'prompt': 'Centre', 'required': true},
      {
        'name': 'count',
        'type': 'integer',
        'prompt': 'Count',
        'required': false,
        'default': 3,
      },
    ]);

    final missing = await invoke('rings');
    expect(missing.status, CommandStatus.failed);
    expect(missing.message, contains('center'));

    final ran = await invoke('rings', {
      'center': [1, 2],
    });
    expect(ran.status, CommandStatus.ok);
    expect(ran.data!['args'], {
      'center': [1.0, 2.0],
      'count': 3,
    });
  });

  test('a disabled script leaves the command line and can come back', () async {
    expect(
      (await run('extensions.write', {
        'name': 'rings',
        'content': '1\n',
      })).status,
      CommandStatus.ok,
    );
    expect(app.workspace.commands.find('rings'), isNotNull);

    scripts.setEnabled('rings', false);
    expect(app.workspace.commands.find('rings'), isNull);
    expect(app.workspace.commands.find('extension.rings'), isNull);
    final listed = (await run('extensions.list')).data!['extensions'] as List;
    final rings =
        listed.singleWhere((item) => (item as Map)['name'] == 'rings') as Map;
    expect(rings['enabled'], isFalse);

    scripts.setEnabled('rings', true);
    expect(app.workspace.commands.find('extension.rings'), isNotNull);
    expect(scripts.disabled, isEmpty);
  });

  test('exec is not a command', () async {
    expect(app.workspace.commands.find('exec'), isNull);
    final result = await run('exec', {'source': '1 + 1'});
    expect(result.status, CommandStatus.failed);
    expect(result.message, contains('Unknown command'));
  });
}
