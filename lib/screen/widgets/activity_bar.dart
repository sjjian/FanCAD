import 'package:flutter/material.dart';

import '../../commands/keybindings.dart';
import '../../l10n/l10n.dart';
import 'icon_button.dart';
import 'tokens.dart';

/// The vertical strip of view switchers on the left.
class ActivityBar extends StatelessWidget {
  const ActivityBar({
    super.key,
    required this.activeViewId,
    required this.onSelect,
    required this.onOpenSettings,
  });

  final String activeViewId;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpenSettings;

  static const List<({String id, IconData icon, IconData activeIcon})>
  _views = [
    (id: 'layers', icon: Icons.layers_outlined, activeIcon: Icons.layers),
    (id: 'properties', icon: Icons.tune_outlined, activeIcon: Icons.tune),
    (
      id: 'layouts',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
    ),
    (id: 'history', icon: Icons.history_outlined, activeIcon: Icons.history),
    (id: 'commands', icon: Icons.terminal_outlined, activeIcon: Icons.terminal),
    // plugins / editor stay off the strip until the extension UI is designed.
  ];

  ({String label, String hint}) _copy(AppLocalizations l10n, String id) {
    return switch (id) {
      'layers' => (label: l10n.layers, hint: l10n.view_layers_hint),
      'properties' => (label: l10n.properties, hint: l10n.view_properties_hint),
      'layouts' => (label: l10n.layouts, hint: l10n.view_layouts_hint),
      'history' => (label: l10n.command_history, hint: l10n.view_history_hint),
      'commands' => (label: l10n.commands, hint: l10n.view_commands_hint),
      'plugins' => (label: l10n.extensions, hint: l10n.view_extensions_hint),
      _ => (label: l10n.re_editor, hint: l10n.view_editor_hint),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return Container(
      width: FanCadTokens.activityBarWidth,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(right: BorderSide(color: tokens.borderMuted)),
      ),
      child: Column(
        children: [
          const SizedBox(height: FanCadTokens.space2),
          for (final view in _views)
            Padding(
              padding: const EdgeInsets.only(bottom: FanCadTokens.space1),
              child: FanCadIconButton(
                key: Key('activity-${view.id}'),
                icon: activeViewId == view.id ? view.activeIcon : view.icon,
                tooltip: () {
                  final copy = _copy(l10n, view.id);
                  return activeViewId == view.id
                      ? '${l10n.hide_view(copy.label)}\n${copy.hint}'
                      : '${copy.label}\n${copy.hint}';
                }(),
                size: FanCadTokens.activityBarWidth - FanCadTokens.space3,
                iconSize: 22,
                isActive: activeViewId == view.id,
                showActiveBar: true,
                onPressed: () => onSelect(view.id),
              ),
            ),
          const Spacer(),
          FanCadIconButton(
            key: const Key('activity-preferences'),
            icon: Icons.settings_outlined,
            tooltip:
                '${l10n.settings}\n${l10n.settings_tooltip}  ${formatKeybinding('ctrl+,')}',
            size: FanCadTokens.activityBarWidth - FanCadTokens.space3,
            iconSize: 22,
            onPressed: onOpenSettings,
          ),
          const SizedBox(height: FanCadTokens.space1),
          FanCadIconButton(
            icon: Icons.menu,
            tooltip: activeViewId.isEmpty
                ? '${l10n.show_sidebar}  ${formatKeybinding('ctrl+b')}'
                : '${l10n.hide_sidebar}  ${formatKeybinding('ctrl+b')}',
            size: FanCadTokens.activityBarWidth - FanCadTokens.space3,
            iconSize: 22,
            onPressed: () =>
                onSelect(activeViewId.isEmpty ? _views.first.id : activeViewId),
          ),
          const SizedBox(height: FanCadTokens.space2),
        ],
      ),
    );
  }
}
