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

    test('every former workbench chord lives on its descriptor', () {
      const expected = <String, List<String>>{
        'file.new': ['ctrl+n'],
        'file.open': ['ctrl+o'],
        'file.save': ['ctrl+s'],
        'file.saveAs': ['ctrl+shift+s'],
        'file.close': ['ctrl+w'],
        'edit.undo': ['ctrl+z'],
        'edit.redo': ['ctrl+shift+z'],
        'select.all': ['ctrl+a'],
        'select.none': ['ctrl+shift+a'],
        'edit.copyClip': ['ctrl+c'],
        'edit.copyBase': ['ctrl+shift+c'],
        'edit.pasteClip': ['ctrl+v'],
        'edit.pasteBlock': ['ctrl+shift+v'],
        'edit.cutClip': ['ctrl+x'],
        'view.zoomExtents': ['ctrl+shift+e', 'home'],
        'view.isolateObjects': ['ctrl+shift+i'],
        'view.hideObjects': ['ctrl+shift+h'],
        'view.unisolateObjects': ['ctrl+shift+u'],
        'view.zoomIn': ['ctrl+=', 'ctrl+numpadadd'],
        'view.zoomOut': ['ctrl+-', 'ctrl+numpadsubtract'],
        'workbench.preferences': ['ctrl+,'],
      };
      for (final entry in expected.entries) {
        final descriptor = workspace.commands.find(entry.key);
        expect(descriptor, isNotNull, reason: entry.key);
        expect(descriptor!.keybindings, entry.value, reason: entry.key);
        for (final spec in descriptor.keybindings) {
          expect(
            parseKeybinding(spec),
            isNotEmpty,
            reason: '${descriptor.id} keybinding "$spec"',
          );
        }
      }
    });
  });
}
