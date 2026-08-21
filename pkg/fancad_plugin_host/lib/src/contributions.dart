import 'dart:async';

import 'package:fancad_core/fancad_core.dart';

import 'manifest.dart';

/// The non-command contributions the shell renders.
///
/// Commands live in [CommandRegistry] because they are the same thing whether a
/// built-in or a plugin declares them. Panels, menus and keybindings need their
/// own home, and they need the same property: unregistering has to be exact, so
/// unloading a plugin leaves nothing behind.
class ContributionRegistry {
  final Map<String, _OwnedPanel> _panels = {};
  final List<_OwnedMenuItem> _menuItems = [];
  final List<_OwnedKeybinding> _keybindings = [];
  final StreamController<void> _changes =
      StreamController<void>.broadcast(sync: true);

  /// Fires when contributions change, so the shell can rebuild its chrome.
  Stream<void> get changes => _changes.stream;

  Iterable<PanelContribution> get panels =>
      _panels.values.map((owned) => owned.panel);

  /// Panels for one location, in declaration order.
  List<PanelContribution> panelsAt(PanelLocation location) {
    final result = [
      for (final owned in _panels.values)
        if (owned.panel.location == location) owned.panel,
    ];
    result.sort((a, b) => a.order.compareTo(b.order));
    return result;
  }

  /// Menu items for one menu id, grouped and ordered.
  List<MenuContribution> menu(String menuId) {
    final items = [
      for (final owned in _menuItems)
        if (owned.item.menu == menuId) owned.item,
    ];
    items.sort((a, b) {
      final byGroup = a.group.compareTo(b.group);
      return byGroup != 0 ? byGroup : a.order.compareTo(b.order);
    });
    return items;
  }

  Iterable<KeybindingContribution> get keybindings =>
      _keybindings.map((owned) => owned.binding);

  /// The plugin that owns [panelId], for routing a panel's render request.
  String? ownerOfPanel(String panelId) => _panels[panelId]?.extensionId;

  /// Registers everything [manifest] declares. Disposing the result removes it.
  Disposable registerAll(PluginManifest manifest) {
    for (final panel in manifest.panels) {
      final existing = _panels[panel.id];
      if (existing != null) {
        throw StateError(
          'panel "${panel.id}" is already contributed by '
          '${existing.extensionId}',
        );
      }
      _panels[panel.id] = _OwnedPanel(manifest.id, panel);
    }
    for (final item in manifest.menus) {
      _menuItems.add(_OwnedMenuItem(manifest.id, item));
    }
    for (final binding in manifest.keybindings) {
      _keybindings.add(_OwnedKeybinding(manifest.id, binding));
    }
    _changes.add(null);
    return Disposable.callback(() => _removeAll(manifest.id));
  }

  void _removeAll(String extensionId) {
    _panels.removeWhere((_, owned) => owned.extensionId == extensionId);
    _menuItems.removeWhere((owned) => owned.extensionId == extensionId);
    _keybindings.removeWhere((owned) => owned.extensionId == extensionId);
    _changes.add(null);
  }

  void dispose() {
    _panels.clear();
    _menuItems.clear();
    _keybindings.clear();
    _changes.close();
  }
}

class _OwnedPanel {
  const _OwnedPanel(this.extensionId, this.panel);
  final String extensionId;
  final PanelContribution panel;
}

class _OwnedMenuItem {
  const _OwnedMenuItem(this.extensionId, this.item);
  final String extensionId;
  final MenuContribution item;
}

class _OwnedKeybinding {
  const _OwnedKeybinding(this.extensionId, this.binding);
  final String extensionId;
  final KeybindingContribution binding;
}
