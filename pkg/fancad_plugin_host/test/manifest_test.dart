import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('manifest parsing', () {
    test('reads a complete manifest', () {
      final manifest = PluginManifest.parse('''
      {
        "id": "acme.tools",
        "name": "Acme Tools",
        "version": "1.2.0",
        "publisher": "acme",
        "main": "index.js",
        "engines": { "fancad": "^0.1.0" },
        "activationEvents": ["onCommand:acme.grid", "onStartup"],
        "permissions": ["document.read", "document.write", "commands"],
        "contributes": {
          "commands": [
            {
              "id": "acme.grid",
              "title": "Draw Grid",
              "category": "Acme",
              "description": "Draws a rectangular grid of lines.",
              "aliases": ["GRID"],
              "risk": "edit",
              "keybinding": "ctrl+alt+g",
              "params": [
                { "name": "origin", "type": "point", "required": true },
                { "name": "spacing", "type": "number", "default": 10 },
                {
                  "name": "style",
                  "type": "choice",
                  "options": ["solid", "dashed"]
                }
              ]
            }
          ],
          "panels": [
            { "id": "acme.panel", "title": "Acme", "location": "sidebar" }
          ],
          "menus": {
            "canvas/context": [
              { "command": "acme.grid", "group": "1_draw", "order": 5 }
            ]
          },
          "keybindings": [
            { "command": "acme.grid", "key": "ctrl+alt+g" }
          ]
        }
      }
      ''');

      expect(manifest.id, 'acme.tools');
      expect(manifest.version, '1.2.0');
      expect(manifest.entryPoint, 'index.js');
      expect(manifest.hostConstraint, '^0.1.0');
      expect(manifest.activatesAtStartup, isTrue);
      expect(manifest.activatesOnCommand('acme.grid'), isTrue);
      expect(manifest.has(PluginPermission.documentWrite), isTrue);
      expect(manifest.has(PluginPermission.network), isFalse);

      final command = manifest.commands.single;
      expect(command.title, 'Draw Grid');
      expect(command.aliases, ['GRID']);
      expect(command.params.map((p) => p.type), [
        ParamType.point,
        ParamType.number,
        ParamType.choice,
      ]);
      expect(command.params[0].required, isTrue);
      expect(command.params[1].required, isFalse);
      expect(command.params[2].options, ['solid', 'dashed']);

      expect(manifest.panels.single.location, PanelLocation.sidebar);
      expect(manifest.menus.single.menu, 'canvas/context');
      expect(manifest.keybindings.single.key, 'ctrl+alt+g');
    });

    test('applies defaults for a minimal manifest', () {
      final manifest = PluginManifest.parse('{"id": "tiny"}');
      expect(manifest.name, 'tiny');
      expect(manifest.entryPoint, 'main.js');
      expect(manifest.version, '0.0.0');
      expect(manifest.permissions, isEmpty);
      expect(manifest.commands, isEmpty);
      expect(manifest.activatesAtStartup, isFalse);
    });

    test('a missing id is rejected', () {
      expect(
        () => PluginManifest.parse('{"name": "no id"}'),
        throwsA(isA<ManifestException>()),
      );
    });

    test('malformed JSON names the file', () {
      expect(
        () => PluginManifest.parse('{ oops', path: '/tmp/x.json'),
        throwsA(
          isA<ManifestException>().having(
            (error) => error.path,
            'path',
            '/tmp/x.json',
          ),
        ),
      );
    });

    test('an unknown permission is rejected rather than ignored', () {
      expect(
        () => PluginManifest.parse(
          '{"id": "x", "permissions": ["launch.missiles"]}',
        ),
        throwsA(
          isA<ManifestException>().having(
            (error) => error.message,
            'message',
            contains('launch.missiles'),
          ),
        ),
      );
    });

    test('an unknown activation event is rejected', () {
      expect(
        () => PluginManifest.parse(
          '{"id": "x", "activationEvents": ["whenever"]}',
        ),
        throwsA(isA<ManifestException>()),
      );
    });

    test('duplicate command ids are rejected', () {
      expect(
        () => PluginManifest.parse('''
        {
          "id": "x",
          "contributes": {
            "commands": [{"id": "a", "title": "A"}, {"id": "a", "title": "B"}]
          }
        }
        '''),
        throwsA(
          isA<ManifestException>().having(
            (error) => error.message,
            'message',
            contains('duplicate'),
          ),
        ),
      );
    });

    test('a choice parameter without options is rejected', () {
      expect(
        () => PluginManifest.parse('''
        {
          "id": "x",
          "contributes": {
            "commands": [{
              "id": "a", "title": "A",
              "params": [{"name": "mode", "type": "choice"}]
            }]
          }
        }
        '''),
        throwsA(
          isA<ManifestException>().having(
            (error) => error.message,
            'message',
            contains('options'),
          ),
        ),
      );
    });

    test('an unknown parameter type is rejected', () {
      expect(
        () => PluginManifest.parse('''
        {
          "id": "x",
          "contributes": {
            "commands": [{
              "id": "a", "title": "A",
              "params": [{"name": "p", "type": "hologram"}]
            }]
          }
        }
        '''),
        throwsA(isA<ManifestException>()),
      );
    });

    test('a contribution becomes a registry descriptor', () {
      final manifest = PluginManifest.parse('''
      {
        "id": "acme.tools",
        "contributes": {
          "commands": [{
            "id": "acme.grid", "title": "Grid", "aliases": ["GR"],
            "risk": "destructive", "aiExposure": "approvalRequired"
          }]
        }
      }
      ''');
      final descriptor = manifest.commands.single.toDescriptor(
        extensionId: manifest.id,
        handler: (context) async => const CommandResult.ok(),
      );
      expect(descriptor.id, 'acme.grid');
      expect(descriptor.extensionId, 'acme.tools');
      expect(descriptor.isBuiltIn, isFalse);
      expect(descriptor.risk, CommandRisk.destructive);
      expect(descriptor.aiExposure, AiExposure.approvalRequired);
      expect(descriptor.aliases, ['GR']);
    });

    test('round trips through JSON', () {
      const source = '''
      {
        "id": "acme.tools",
        "name": "Acme",
        "version": "2.0.0",
        "permissions": ["document.read"],
        "activationEvents": ["onStartup"],
        "contributes": {
          "commands": [{"id": "a.b", "title": "AB"}],
          "panels": [{"id": "p", "title": "P", "location": "panel"}]
        }
      }
      ''';
      final original = PluginManifest.parse(source);
      final again = PluginManifest.fromJson(original.toJson());
      expect(again.id, original.id);
      expect(again.version, original.version);
      expect(again.permissions, original.permissions);
      expect(again.activation.map((e) => e.wireName), ['onStartup']);
      expect(again.commands.single.id, 'a.b');
      expect(again.panels.single.location, PanelLocation.panel);
    });
  });

  group('activation events', () {
    test('parses the supported forms', () {
      expect(ActivationEvent.parse('*')!.kind, ActivationKind.always);
      expect(ActivationEvent.parse('onStartup')!.kind, ActivationKind.startup);
      final onCommand = ActivationEvent.parse('onCommand:draw.line')!;
      expect(onCommand.kind, ActivationKind.command);
      expect(onCommand.argument, 'draw.line');
      expect(ActivationEvent.parse('onFileOpen:.dwg')!.argument, '.dwg');
      expect(ActivationEvent.parse('nonsense'), isNull);
    });

    test('every event survives a serialise/parse round trip', () {
      const events = [
        ActivationEvent(ActivationKind.always),
        ActivationEvent(ActivationKind.startup),
        ActivationEvent(ActivationKind.command, 'draw.line'),
        ActivationEvent(ActivationKind.fileOpen, '.dwg'),
        ActivationEvent(ActivationKind.view, 'acme.panel'),
        ActivationEvent(ActivationKind.language, 'javascript'),
      ];
      for (final event in events) {
        final again = ActivationEvent.parse(event.wireName);
        expect(again, isNotNull, reason: event.wireName);
        expect(again!.kind, event.kind);
        expect(again.argument, event.argument);
      }
    });
  });

  group('permissions', () {
    test('accepts both spellings of the file permissions', () {
      expect(PluginPermission.parse('fs.read'), PluginPermission.fileRead);
      expect(PluginPermission.parse('file.read'), PluginPermission.fileRead);
      expect(PluginPermission.parse('document.write'),
          PluginPermission.documentWrite);
      expect(PluginPermission.parse('telepathy'), isNull);
    });

    test('wire names round trip', () {
      for (final permission in PluginPermission.values) {
        expect(PluginPermission.parse(permission.wireName), permission);
      }
    });
  });
}
