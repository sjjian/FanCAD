import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter/material.dart';

import '../state/workspace.dart';
import '../theme/tokens.dart';
import '../workbench/shell_widgets.dart';

/// The extensions manager.
///
/// Its real job is making failure legible. An extension that would not load, or
/// that threw on its last invocation, says so here with the message it produced,
/// because the alternative — a command that silently does nothing — is the worst
/// possible outcome of a plugin system.
class ExtensionsPanel extends StatefulWidget {
  const ExtensionsPanel({
    super.key,
    required this.workspace,
    required this.host,
  });

  final Workspace workspace;
  final PluginHost? host;

  @override
  State<ExtensionsPanel> createState() => _ExtensionsPanelState();
}

class _ExtensionsPanelState extends State<ExtensionsPanel> {
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          title: 'Extensions',
          actions: [
            if (host != null)
              ShellIconButton(
                icon: Icons.add,
                tooltip: 'Create extension',
                onPressed: () => widget.workspace.run('plugins.scaffold'),
              ),
            if (host != null)
              ShellIconButton(
                icon: Icons.refresh,
                tooltip: 'Reload all extensions',
                onPressed: () => widget.workspace.run('plugins.reload'),
              ),
          ],
        ),
        Expanded(
          child: host == null
              ? const _PanelMessage(
                  'Extensions are unavailable: no extensions folder was '
                  'configured for this session.',
                )
              : StreamBuilder<PluginHost>(
                  stream: host.changes,
                  builder: (context, _) => _buildList(context, host),
                ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, PluginHost host) {
    final plugins = host.plugins;
    if (plugins.isEmpty) {
      return const _PanelMessage(
        'No extensions are installed. Use Create Extension to write one, or '
        'drop a folder containing fancad.plugin.json into the extensions '
        'directory.',
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: plugins.length,
      itemBuilder: (context, index) {
        final handle = plugins[index];
        return _ExtensionTile(
          handle: handle,
          isExpanded: _expanded == handle.id,
          onToggle: () => setState(
            () => _expanded = _expanded == handle.id ? null : handle.id,
          ),
          onReload: () =>
              widget.workspace.run('plugins.reload', args: {'id': handle.id}),
          onSetEnabled: (value) => widget.workspace.run(
            value ? 'plugins.enable' : 'plugins.disable',
            args: {'id': handle.id},
          ),
        );
      },
    );
  }
}

class _ExtensionTile extends StatelessWidget {
  const _ExtensionTile({
    required this.handle,
    required this.isExpanded,
    required this.onToggle,
    required this.onReload,
    required this.onSetEnabled,
  });

  final PluginHandle handle;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onReload;
  final ValueChanged<bool> onSetEnabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDisabled = handle.state == PluginState.disabled;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FanCadTokens.space3,
                vertical: FanCadTokens.space2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _StateDot(state: handle.state, tokens: tokens),
                  ),
                  const SizedBox(width: FanCadTokens.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          handle.manifest.name,
                          style: tokens.bodyStyle.copyWith(
                            color: isDisabled
                                ? tokens.textMuted
                                : tokens.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${handle.id}  ${handle.manifest.version}',
                          style: tokens.labelStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (handle.error != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: FanCadTokens.space1,
                            ),
                            child: Text(
                              handle.error!,
                              style: tokens.labelStyle.copyWith(
                                color: tokens.danger,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ShellIconButton(
                    icon: isDisabled ? Icons.play_arrow : Icons.block,
                    tooltip: isDisabled ? 'Enable' : 'Disable',
                    onPressed: () => onSetEnabled(isDisabled),
                  ),
                  ShellIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Reload',
                    onPressed: onReload,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) _Details(handle: handle),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.handle});

  final PluginHandle handle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final manifest = handle.manifest;
    return Container(
      color: tokens.surfaceRaised,
      padding: const EdgeInsets.only(bottom: FanCadTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (manifest.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FanCadTokens.space3,
                FanCadTokens.space2,
                FanCadTokens.space3,
                0,
              ),
              child: Text(manifest.description, style: tokens.labelStyle),
            ),
          _Row(label: 'State', value: handle.state.name),
          if (manifest.directory.isNotEmpty)
            _Row(label: 'Folder', value: manifest.directory),
          _Row(
            label: 'Permissions',
            value: manifest.permissions.isEmpty
                ? 'none'
                : manifest.permissions
                    .map((permission) => permission.wireName)
                    .join(', '),
          ),
          if (manifest.commands.isNotEmpty)
            PanelSection(
              title: 'Commands',
              children: [
                for (final command in manifest.commands)
                  _Row(label: command.title, value: command.id),
              ],
            ),
          if (handle.log.isNotEmpty)
            PanelSection(
              title: 'Log',
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: FanCadTokens.space3,
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // Newest last matches the command history pane, so the
                      // interesting line is where the eye already is.
                      for (final line in handle.log)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(line, style: tokens.monoStyle),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A label and a plain string, the shape most of this panel needs.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => PropertyRow(
    label: label,
    value: Text(
      value,
      style: context.tokens.bodyStyle,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _StateDot extends StatelessWidget {
  const _StateDot({required this.state, required this.tokens});

  final PluginState state;
  final FanCadTokens tokens;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      PluginState.active => tokens.success,
      PluginState.activating => tokens.accent,
      PluginState.failed => tokens.danger,
      PluginState.disabled => tokens.textMuted,
      PluginState.installed => tokens.textMuted,
    };
    return Tooltip(
      message: state.name,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(FanCadTokens.space4),
      child: Text(message, style: tokens.labelStyle),
    );
  }
}
