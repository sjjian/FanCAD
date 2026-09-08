import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workspace.dart';

late Headless app;

Workspace get workspace => app.workspace;

Future<CommandResult> run(String id, [Map<String, Object?> args = const {}]) =>
    app.run(id, args);

void main() {
  setUp(() {
    app = Headless();
  });

  group('registry contract', () {
    test('every alias resolves to its command', () {
      for (final descriptor in workspace.commands.all) {
        for (final alias in descriptor.aliases) {
          expect(
            workspace.commands.find(alias)?.id,
            descriptor.id,
            reason: 'alias "$alias" should resolve to ${descriptor.id}',
          );
        }
      }
    });

    test('every command exposes a valid tool schema', () {
      for (final descriptor in workspace.commands.all) {
        final schema = descriptor.toolSchema();
        expect(schema['type'], 'object');
        expect(schema['properties'], isA<Map<String, Object?>>());
        // A tool name with a dot in it is rejected by some providers, so the
        // normalisation has to actually happen.
        expect(descriptor.toolName, isNot(contains('.')));
      }
    });

    test('an unknown command fails rather than throwing', () async {
      final result = await run('does.not.exist');
      expect(result.status, CommandStatus.failed);
    });
  });
}
