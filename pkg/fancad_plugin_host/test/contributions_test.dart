import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';

PluginManifest manifest({
  required String id,
  List<PanelContribution> panels = const [],
  List<MenuContribution> menus = const [],
  List<KeybindingContribution> keybindings = const [],
}) => PluginManifest(
  id: id,
  name: id,
  version: '1.0.0',
  entryPoint: 'main.js',
  panels: panels,
  menus: menus,
  keybindings: keybindings,
);

void main() {
  group('ContributionRegistry', () {
    test('sorts panels in one location by order', () {
      final registry = ContributionRegistry();
      addTearDown(registry.dispose);
      registry.registerAll(
        manifest(
          id: 'acme',
          panels: const [
            PanelContribution(id: 'late', title: 'Late', order: 40),
            PanelContribution(id: 'early', title: 'Early', order: 10),
            PanelContribution(
              id: 'bottom',
              title: 'Bottom',
              location: PanelLocation.panel,
              order: 1,
            ),
          ],
        ),
      );

      expect(
        registry.panelsAt(PanelLocation.sidebar).map((panel) => panel.id),
        ['early', 'late'],
      );
      expect(registry.panelsAt(PanelLocation.panel).single.id, 'bottom');
      expect(registry.ownerOfPanel('early'), 'acme');
      expect(registry.ownerOfPanel('missing'), isNull);
    });

    test('sorts a menu by group then order', () {
      final registry = ContributionRegistry();
      addTearDown(registry.dispose);
      registry.registerAll(
        manifest(
          id: 'acme',
          menus: const [
            MenuContribution(
              menu: 'canvas/context',
              commandId: 'b',
              group: '2_edit',
              order: 1,
            ),
            MenuContribution(
              menu: 'canvas/context',
              commandId: 'a2',
              group: '1_draw',
              order: 20,
            ),
            MenuContribution(
              menu: 'canvas/context',
              commandId: 'a1',
              group: '1_draw',
              order: 5,
            ),
            MenuContribution(menu: 'titlebar/tools', commandId: 'other'),
          ],
        ),
      );

      expect(registry.menu('canvas/context').map((item) => item.commandId), [
        'a1',
        'a2',
        'b',
      ]);
      expect(registry.menu('titlebar/tools').single.commandId, 'other');
      expect(registry.menu('missing'), isEmpty);
    });

    test('unregistering one plugin leaves the others behind', () {
      final registry = ContributionRegistry();
      addTearDown(registry.dispose);
      final first = registry.registerAll(
        manifest(
          id: 'alpha',
          panels: const [PanelContribution(id: 'alpha.panel', title: 'A')],
          menus: const [
            MenuContribution(menu: 'canvas/context', commandId: 'alpha.run'),
          ],
          keybindings: const [
            KeybindingContribution(commandId: 'alpha.run', key: 'ctrl+1'),
          ],
        ),
      );
      registry.registerAll(
        manifest(
          id: 'beta',
          panels: const [PanelContribution(id: 'beta.panel', title: 'B')],
          menus: const [
            MenuContribution(menu: 'canvas/context', commandId: 'beta.run'),
          ],
          keybindings: const [
            KeybindingContribution(commandId: 'beta.run', key: 'ctrl+2'),
          ],
        ),
      );

      first.dispose();

      expect(registry.panels.map((panel) => panel.id), ['beta.panel']);
      expect(registry.ownerOfPanel('alpha.panel'), isNull);
      expect(registry.menu('canvas/context').map((item) => item.commandId), [
        'beta.run',
      ]);
      expect(registry.keybindings.map((binding) => binding.commandId), [
        'beta.run',
      ]);
    });

    test('refuses a panel id another plugin already owns', () {
      final registry = ContributionRegistry();
      addTearDown(registry.dispose);
      registry.registerAll(
        manifest(
          id: 'alpha',
          panels: const [PanelContribution(id: 'shared', title: 'A')],
        ),
      );

      expect(
        () => registry.registerAll(
          manifest(
            id: 'beta',
            panels: const [PanelContribution(id: 'shared', title: 'B')],
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('alpha'),
          ),
        ),
      );
    });

    test('notifies the shell when contributions appear or vanish', () {
      final registry = ContributionRegistry();
      addTearDown(registry.dispose);
      var ticks = 0;
      registry.changes.listen((_) => ticks++);

      final handle = registry.registerAll(
        manifest(
          id: 'acme',
          panels: const [PanelContribution(id: 'acme.panel', title: 'Acme')],
        ),
      );
      expect(ticks, 1);

      handle.dispose();
      expect(ticks, 2);
      expect(registry.panels, isEmpty);
    });
  });
}
