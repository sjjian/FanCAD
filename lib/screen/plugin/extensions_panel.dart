import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/plugin.dart';
import '../../services/plugin.dart';
import '../../services/workspace.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';

/// The extensions manager.
///
/// Its real job is making failure legible. An extension that would not load, or
/// that threw on its last invocation, says so here with the message it produced,
/// because the alternative — a command that silently does nothing — is the worst
/// possible outcome of a plugin system.
class ExtensionsPanel extends ConsumerStatefulWidget {
  const ExtensionsPanel({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<ExtensionsPanel> createState() => _ExtensionsPanelState();
}

Future<void> _openFolder(Workspace workspace, String path) async {
  try {
    await Directory(path).create(recursive: true);
    if (Platform.isMacOS) {
      await Process.start('open', [path]);
    } else if (Platform.isWindows) {
      await Process.start('explorer', [path]);
    } else {
      await Process.start('xdg-open', [path]);
    }
  } catch (error) {
    workspace.notify(
      lookupAppLocalizations(const Locale('en')).could_not_open(path, '$error'),
      isError: true,
    );
  }
}

class _ExtensionsPanelState extends ConsumerState<ExtensionsPanel> {
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(
      pluginNotifierProvider.select(
        (s) => (directory: s.directory, plugins: s.plugins, epoch: s.epoch),
      ),
    );
    final available = store.directory.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          title: context.l10n.extensions,
          actions: [
            if (store.directory.isNotEmpty)
              FanCadIconButton(
                icon: Icons.folder_open_outlined,
                tooltip: context.l10n.open_extensions_folder,
                onPressed: () => _openFolder(widget.workspace, store.directory),
              ),
            if (available)
              FanCadIconButton(
                icon: Icons.add,
                tooltip: context.l10n.create_extension,
                onPressed: () => widget.workspace.run('plugins.scaffold'),
              ),
            if (available)
              FanCadIconButton(
                icon: Icons.refresh,
                tooltip: context.l10n.reload_all_extensions,
                onPressed: () => widget.workspace.run('plugins.reload'),
              ),
          ],
        ),
        Expanded(
          child: !available
              ? FanCadEmpty(message: context.l10n.extensions_unavailable)
              : Column(
                  children: [
                    Expanded(child: _buildList(context, store.plugins)),
                    _ExtensionFooter(plugins: store.plugins),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, List<PluginRefModel> plugins) {
    if (plugins.isEmpty) {
      return FanCadEmpty(
        message: context.l10n.no_extensions_installed,
        actionLabel: context.l10n.create_extension,
        onAction: () => widget.workspace.run('plugins.scaffold'),
      );
    }
    final failedId = plugins
        .where((plugin) => plugin.state == 'failed')
        .map((plugin) => plugin.id)
        .firstOrNull;
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: plugins.length,
      itemBuilder: (context, index) {
        final handle = plugins[index];
        final expanded = _expanded ?? failedId;
        return _ExtensionTile(
          handle: handle,
          isExpanded: expanded == handle.id,
          onToggle: () => setState(
            () => _expanded = expanded == handle.id ? '' : handle.id,
          ),
          onReload: () =>
              widget.workspace.run('plugins.reload', args: {'id': handle.id}),
          onEdit: () =>
              widget.workspace.run('plugins.edit', args: {'id': handle.id}),
          onRunCommand: (id) => widget.workspace.run(id),
          onCopied: (text) =>
              widget.workspace.notify(context.l10n.copied_text(text)),
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
    required this.onEdit,
    required this.onRunCommand,
    required this.onCopied,
    required this.onSetEnabled,
  });

  final PluginRefModel handle;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onReload;
  final VoidCallback onEdit;
  final ValueChanged<String> onRunCommand;
  final ValueChanged<String> onCopied;
  final ValueChanged<bool> onSetEnabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDisabled = handle.state == 'disabled';
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
                    child: FanCadDot(
                      color: switch (handle.state) {
                        'active' => tokens.success,
                        'activating' => tokens.accent,
                        'failed' => tokens.danger,
                        _ => tokens.textMuted,
                      },
                      tooltip: _stateLabel(context.l10n, handle.state),
                    ),
                  ),
                  const SizedBox(width: FanCadTokens.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          handle.name,
                          style: tokens.bodyStyle.copyWith(
                            color: isDisabled ? tokens.textMuted : tokens.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${handle.id}  ${handle.version}',
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
                  FanCadIconButton(
                    icon: Icons.code,
                    tooltip: context.l10n.edit_source,
                    onPressed: onEdit,
                  ),
                  FanCadIconButton(
                    icon: isDisabled
                        ? Icons.play_arrow_outlined
                        : Icons.pause_outlined,
                    tooltip: isDisabled
                        ? context.l10n.enable_extension
                        : context.l10n.disable_extension,
                    onPressed: () => onSetEnabled(isDisabled),
                  ),
                  FanCadIconButton(
                    icon: Icons.refresh,
                    tooltip: context.l10n.reload,
                    onPressed: onReload,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            _Details(
              handle: handle,
              onRunCommand: onRunCommand,
              onCopied: onCopied,
            ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.handle,
    required this.onRunCommand,
    required this.onCopied,
  });

  final PluginRefModel handle;
  final ValueChanged<String> onRunCommand;
  final ValueChanged<String> onCopied;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      color: tokens.surfaceRaised,
      padding: const EdgeInsets.only(bottom: FanCadTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (handle.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FanCadTokens.space3,
                FanCadTokens.space2,
                FanCadTokens.space3,
                0,
              ),
              child: Text(handle.description, style: tokens.labelStyle),
            ),
          _Row(
            label: context.l10n.state,
            value: _stateLabel(context.l10n, handle.state),
          ),
          if (handle.directory.isNotEmpty)
            _Row(
              label: context.l10n.folder,
              value: handle.directory,
              copyText: handle.directory,
              onCopied: onCopied,
            ),
          _Row(
            label: context.l10n.permissions,
            value: handle.permissions.isEmpty
                ? 'none'
                : handle.permissions.join(', '),
          ),
          if (handle.commands.isNotEmpty)
            PanelSection(
              title: context.l10n.commands,
              children: [
                for (final command in handle.commands)
                  PropertyRow(
                    label: command.title,
                    value: Text(command.id),
                    isEditable: true,
                    onTap: () => onRunCommand(command.id),
                    copyText: command.id,
                    onCopied: onCopied,
                  ),
              ],
            ),
          if (handle.log.isNotEmpty)
            PanelSection(
              title: context.l10n.log,
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
  const _Row({
    required this.label,
    required this.value,
    this.copyText,
    this.onCopied,
  });

  final String label;
  final String value;
  final String? copyText;
  final ValueChanged<String>? onCopied;

  @override
  Widget build(BuildContext context) => PropertyRow(
    label: label,
    value: Text(
      value,
      style: context.tokens.bodyStyle,
      overflow: TextOverflow.ellipsis,
    ),
    copyText: copyText ?? value,
    onCopied: onCopied,
  );
}

String _stateLabel(AppLocalizations l10n, String state) => switch (state) {
  'active' => l10n.plugin_running,
  'activating' => l10n.plugin_starting,
  'failed' => l10n.plugin_failed,
  'disabled' => l10n.plugin_disabled,
  _ => l10n.plugin_installed,
};

class _ExtensionFooter extends StatelessWidget {
  const _ExtensionFooter({required this.plugins});

  final List<PluginRefModel> plugins;

  @override
  Widget build(BuildContext context) {
    final failed = plugins.where((plugin) => plugin.state == 'failed').length;
    final running = plugins.where((plugin) => plugin.state == 'active').length;
    return Container(
      height: FanCadTokens.statusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.tokens.border)),
      ),
      child: Text(
        [
          '${plugins.length} extension${plugins.length == 1 ? '' : 's'}',
          if (running > 0) '$running running',
          if (failed > 0) '$failed failed',
        ].join(' · '),
        style: context.tokens.labelStyle,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
