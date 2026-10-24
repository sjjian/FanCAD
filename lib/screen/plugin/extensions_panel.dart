import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

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
///
/// Each row leads with the description. Lifecycle actions sit in the configure
/// menu. Details and source open in their own windows, so the list stays a list.
class ExtensionsPanel extends ConsumerWidget {
  const ExtensionsPanel({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onPressed: () => _openFolder(workspace, store.directory),
              ),
            if (available)
              FanCadIconButton(
                icon: Icons.file_download_outlined,
                tooltip: context.l10n.import_extension,
                onPressed: () => workspace.run('plugins.import'),
              ),
            if (available)
              FanCadIconButton(
                icon: Icons.add,
                tooltip: context.l10n.create_extension,
                onPressed: () => workspace.run('plugins.scaffold'),
              ),
            if (available)
              FanCadIconButton(
                icon: Icons.refresh,
                tooltip: context.l10n.reload_all_extensions,
                onPressed: () => workspace.run('plugins.reload'),
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
        onAction: () => workspace.run('plugins.scaffold'),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: plugins.length,
      itemBuilder: (context, index) {
        final handle = plugins[index];
        return _ExtensionTile(
          key: ValueKey(handle.id),
          workspace: workspace,
          handle: handle,
        );
      },
    );
  }
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

enum _ExtensionAction {
  details,
  source,
  toggleEnabled,
  toggleRunning,
  reload,
  export,
  delete,
}

class _ExtensionTile extends StatefulWidget {
  const _ExtensionTile({
    super.key,
    required this.workspace,
    required this.handle,
  });

  final Workspace workspace;
  final PluginRefModel handle;

  @override
  State<_ExtensionTile> createState() => _ExtensionTileState();
}

class _ExtensionTileState extends State<_ExtensionTile> {
  bool _hovered = false;

  PluginRefModel get handle => widget.handle;

  void _openDetails() {
    _showPluginDialog(
      context,
      _DetailsDialog(pluginId: handle.id, workspace: widget.workspace),
    );
  }

  void _openSource() {
    _showPluginDialog(
      context,
      _SourceDialog(pluginId: handle.id, workspace: widget.workspace),
    );
  }

  void _run(_ExtensionAction action) {
    final id = handle.id;
    switch (action) {
      case _ExtensionAction.details:
        _openDetails();
      case _ExtensionAction.source:
        _openSource();
      case _ExtensionAction.toggleEnabled:
        widget.workspace.run(
          handle.state == 'disabled' ? 'plugins.enable' : 'plugins.disable',
          args: {'id': id},
        );
      case _ExtensionAction.toggleRunning:
        widget.workspace.run(
          handle.state == 'active' ? 'plugins.stop' : 'plugins.start',
          args: {'id': id},
        );
      case _ExtensionAction.reload:
        widget.workspace.run('plugins.reload', args: {'id': id});
      case _ExtensionAction.export:
        widget.workspace.run('plugins.export', args: {'id': id});
      case _ExtensionAction.delete:
        widget.workspace.run('plugins.delete', args: {'id': id});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final isDisabled = handle.state == 'disabled';
    final title = _pluginTitle(handle);
    final titleColor = isDisabled ? tokens.textMuted : tokens.text;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: _hovered ? tokens.hover : Colors.transparent,
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openDetails,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FanCadTokens.space3,
                    FanCadTokens.space2,
                    FanCadTokens.space2,
                    FanCadTokens.space2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: FanCadDot(
                          color: switch (handle.state) {
                            'active' => tokens.success,
                            'activating' => tokens.accent,
                            'failed' => tokens.danger,
                            _ => tokens.textMuted,
                          },
                          tooltip: _stateLabel(l10n, handle.state),
                        ),
                      ),
                      const SizedBox(width: FanCadTokens.space2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: tokens.bodyStyle.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (handle.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                handle.description,
                                style: tokens.bodyStyle.copyWith(
                                  color: titleColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              handle.name.isEmpty
                                  ? handle.version
                                  : '${handle.id}  ${handle.version}',
                              style: tokens.labelStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (handle.error != null) ...[
                              const SizedBox(height: FanCadTokens.space1),
                              Text(
                                handle.error!,
                                style: tokens.labelStyle.copyWith(
                                  color: tokens.danger,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: FanCadTokens.space1),
              child: _ConfigureButton(handle: handle, onSelected: _run),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigureButton extends StatelessWidget {
  const _ConfigureButton({required this.handle, required this.onSelected});

  final PluginRefModel handle;
  final ValueChanged<_ExtensionAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final disabled = handle.state == 'disabled';
    final running = handle.state == 'active';
    return FanCadMenuButton<_ExtensionAction>(
      tooltip: l10n.configure_extension,
      placement: FanCadMenuPlacement.auto,
      onSelected: onSelected,
      itemBuilder: (context) => [
        fanCadMenuItem(
          context,
          value: _ExtensionAction.details,
          label: l10n.extension_details,
          icon: Icons.info_outline,
        ),
        fanCadMenuItem(
          context,
          value: _ExtensionAction.source,
          label: l10n.edit_source,
          icon: Icons.code,
        ),
        const PopupMenuDivider(),
        fanCadMenuItem(
          context,
          value: _ExtensionAction.toggleEnabled,
          label: disabled ? l10n.enable_extension : l10n.disable_extension,
          icon: disabled ? Icons.play_arrow_outlined : Icons.pause_outlined,
        ),
        if (!disabled)
          fanCadMenuItem(
            context,
            value: _ExtensionAction.toggleRunning,
            label: running ? l10n.stop_extension : l10n.start_extension,
            icon: running
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline,
          ),
        fanCadMenuItem(
          context,
          value: _ExtensionAction.reload,
          label: l10n.reload,
          icon: Icons.refresh,
        ),
        fanCadMenuItem(
          context,
          value: _ExtensionAction.export,
          label: l10n.export_extension,
          icon: Icons.file_upload_outlined,
        ),
        const PopupMenuDivider(),
        fanCadMenuItem(
          context,
          value: _ExtensionAction.delete,
          label: l10n.delete_extension,
          icon: Icons.delete_outline,
        ),
      ],
      child: const _GearIcon(),
    );
  }
}

class _GearIcon extends StatefulWidget {
  const _GearIcon();

  @override
  State<_GearIcon> createState() => _GearIconState();
}

class _GearIconState extends State<_GearIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hovered ? tokens.pressed : Colors.transparent,
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
        ),
        child: Icon(
          Icons.settings_outlined,
          size: FanCadTokens.iconMedium,
          color: _hovered ? tokens.text : tokens.textMuted,
        ),
      ),
    );
  }
}

Future<void> _showPluginDialog(BuildContext context, Widget child) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => child,
  );
}

/// A draggable window on the same chrome as settings.
class _ExtensionWindow extends StatelessWidget {
  const _ExtensionWindow({
    required this.name,
    required this.title,
    required this.size,
    required this.minSize,
    required this.child,
    this.onClose,
  });

  final String name;
  final String title;
  final Size size;
  final Size minSize;
  final Widget child;

  /// When set, the corner and the dimmed area call this instead of popping.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Size(constraints.maxWidth, constraints.maxHeight);
        if (!bounds.isFinite || bounds.isEmpty) {
          return const SizedBox.shrink();
        }
        void close() {
          final custom = onClose;
          if (custom != null) {
            custom();
            return;
          }
          final navigator = Navigator.maybeOf(context);
          if (navigator != null && navigator.canPop()) navigator.pop();
        }

        return SizedBox.expand(
          child: Stack(
            children: [
              FanCadCanvasWindow(
                name: name,
                title: title,
                origin: Offset(
                  (bounds.width - size.width) / 2,
                  (bounds.height - size.height) / 2,
                ),
                bounds: bounds,
                initialSize: size,
                minSize: minSize,
                closeTooltip: context.l10n.close,
                onClose: close,
                onBarrierTap: close,
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

PluginRefModel? _watchPlugin(WidgetRef ref, String id) {
  return ref.watch(
    pluginNotifierProvider.select((model) {
      for (final plugin in model.plugins) {
        if (plugin.id == id) return plugin;
      }
      return null;
    }),
  );
}

class _DetailsDialog extends ConsumerWidget {
  const _DetailsDialog({required this.pluginId, required this.workspace});

  final String pluginId;
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handle = _watchPlugin(ref, pluginId);
    final title = handle == null
        ? context.l10n.extension_details
        : _pluginTitle(handle);
    return _ExtensionWindow(
      name: 'extension-details-$pluginId',
      title: title,
      size: const Size(440, 520),
      minSize: const Size(320, 280),
      child: handle == null
          ? FanCadEmpty(message: context.l10n.plugin_not_installed(pluginId))
          : _DetailsBody(handle: handle, workspace: workspace),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.handle, required this.workspace});

  final PluginRefModel handle;
  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.only(
        top: FanCadTokens.space2,
        bottom: FanCadTokens.space3,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
          child: Text(
            '${handle.id}  ${handle.version}',
            style: tokens.labelStyle,
          ),
        ),
        if (handle.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FanCadTokens.space3,
              FanCadTokens.space2,
              FanCadTokens.space3,
              0,
            ),
            child: Text(handle.description, style: tokens.bodyStyle),
          ),
        if (handle.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FanCadTokens.space3,
              FanCadTokens.space2,
              FanCadTokens.space3,
              0,
            ),
            child: Text(
              handle.error!,
              style: tokens.bodyStyle.copyWith(color: tokens.danger),
            ),
          ),
        _Row(label: l10n.state, value: _stateLabel(l10n, handle.state)),
        if (handle.directory.isNotEmpty)
          _Row(
            label: l10n.folder,
            value: handle.directory,
            copyText: handle.directory,
            onCopied: (text) => workspace.notify(l10n.copied_text(text)),
          ),
        _Row(
          label: l10n.permissions,
          value: handle.permissions.isEmpty
              ? 'none'
              : handle.permissions.join(', '),
        ),
        if (handle.commands.isNotEmpty)
          PanelSection(
            title: l10n.commands,
            children: [
              for (final command in handle.commands)
                PropertyRow(
                  label: command.title,
                  value: Text(command.id),
                  isEditable: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(workspace.run(command.id));
                  },
                  copyText: command.id,
                  onCopied: (text) => workspace.notify(l10n.copied_text(text)),
                ),
            ],
          ),
        if (handle.log.isNotEmpty)
          PanelSection(
            title: l10n.log,
            children: [
              // Newest last matches the command history pane, so the
              // interesting line is where the eye already is.
              for (final line in handle.log)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FanCadTokens.space3,
                    0,
                    FanCadTokens.space3,
                    2,
                  ),
                  child: Text(line, style: tokens.monoStyle),
                ),
            ],
          ),
      ],
    );
  }
}

class _SourceDialog extends ConsumerStatefulWidget {
  const _SourceDialog({required this.pluginId, required this.workspace});

  final String pluginId;
  final Workspace workspace;

  @override
  ConsumerState<_SourceDialog> createState() => _SourceDialogState();
}

class _SourceDialogState extends ConsumerState<_SourceDialog> {
  final TextEditingController _body = TextEditingController();
  String _directory = '';
  String _relative = '';
  List<String> _files = const [];
  String? _error;
  bool _dirty = false;
  bool _opened = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = ref.read(pluginNotifierProvider);
    PluginRefModel? handle;
    for (final plugin in store.plugins) {
      if (plugin.id == widget.pluginId) {
        handle = plugin;
        break;
      }
    }
    if (!mounted) return;
    if (handle == null) {
      setState(
        () => _error = context.l10n.plugin_not_installed(widget.pluginId),
      );
      return;
    }
    _directory = handle.directory;
    final files = _extensionSourceFiles(handle.directory);
    if (!mounted) return;
    setState(() => _files = files);
    await _read(handle.entryPoint);
  }

  Future<void> _select(String relative) async {
    if (relative == _relative) return;
    if (!await _confirmLeave()) return;
    if (!mounted) return;
    await _read(relative);
  }

  Future<void> _read(String relative) async {
    final file = File(p.join(_directory, relative));
    if (!file.existsSync()) {
      _applyText('');
      if (!mounted) return;
      setState(() {
        _relative = relative;
        _error = context.l10n.no_such_file(relative);
        _dirty = false;
        _opened = false;
      });
      return;
    }
    try {
      final text = file.readAsStringSync();
      if (!mounted) return;
      _applyText(text);
      setState(() {
        _relative = relative;
        _error = null;
        _dirty = false;
        _opened = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _relative = relative;
        _error = '$error';
        _dirty = false;
        _opened = false;
      });
    }
  }

  void _applyText(String text) {
    _applying = true;
    _body.text = text;
    _applying = false;
  }

  Future<void> _save() async {
    if (!_opened || !_dirty) return;
    final result = await widget.workspace.runHeadless(
      'plugins.write',
      args: {'id': widget.pluginId, 'path': _relative, 'content': _body.text},
    );
    if (!mounted) return;
    final reloadError = result.data?['error'];
    final String? error;
    if (!result.isOk) {
      error = result.message;
    } else if (reloadError is String && reloadError.isNotEmpty) {
      error = reloadError;
    } else {
      error = null;
    }
    setState(() {
      _dirty = !result.isOk;
      _error = error;
    });
  }

  /// Closing drops unsaved edits, so ask first.
  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    if (!mounted) return false;
    final choice = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) {
        final tokens = context.tokens;
        return AlertDialog(
          backgroundColor: tokens.surfaceOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
            side: BorderSide(color: tokens.borderStrong),
          ),
          title: Text(
            context.l10n.unsaved_editor_changes,
            style: tokens.bodyStyle.copyWith(fontSize: 15),
          ),
          content: Text(
            context.l10n.editor_file_dirty(_relative),
            style: tokens.labelStyle,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text(context.l10n.cancel, style: tokens.bodyStyle),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: Text(
                context.l10n.dont_save,
                style: tokens.bodyStyle.copyWith(color: tokens.danger),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    );
    if (choice == 'save') {
      await _save();
      return !_dirty;
    }
    return choice == 'discard';
  }

  Future<void> _requestClose() async {
    if (!await _confirmLeave()) return;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final handle = _watchPlugin(ref, widget.pluginId);
    final titleName = handle == null ? widget.pluginId : _pluginTitle(handle);
    final relative = _relative.isEmpty ? (handle?.entryPoint ?? '') : _relative;
    return _ExtensionWindow(
      name: 'extension-source-${widget.pluginId}',
      title: '${context.l10n.extension_source} · $titleName',
      size: const Size(640, 520),
      minSize: const Size(420, 320),
      onClose: () => unawaited(_requestClose()),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        },
        child: Focus(
          autofocus: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_files.isNotEmpty) _fileList(tokens),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: FanCadTokens.statusBarHeight,
                      padding: const EdgeInsets.only(left: FanCadTokens.space3),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: tokens.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _dirty ? '$relative •' : relative,
                              style: tokens.monoStyle.copyWith(
                                fontSize: 10.5,
                                color: _dirty
                                    ? tokens.accent
                                    : tokens.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          FanCadIconButton(
                            icon: Icons.save_outlined,
                            tooltip: !_opened
                                ? context.l10n.nothing_to_save
                                : _dirty
                                ? '${context.l10n.save_and_reload}  ${fanCadShortcut('S')}'
                                : context.l10n.saved,
                            enabled: _opened && _dirty,
                            isActive: _dirty,
                            onPressed: _save,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _editorBody(tokens)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileList(FanCadTokens tokens) {
    return SizedBox(
      width: 168,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: tokens.border)),
        ),
        child: ListView.builder(
          itemCount: _files.length,
          itemBuilder: (context, index) {
            final file = _files[index];
            final selected = file == _relative;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_select(file)),
              child: Container(
                color: selected ? tokens.selection : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: FanCadTokens.space2,
                  vertical: FanCadTokens.space1,
                ),
                child: Text(
                  file,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.monoStyle.copyWith(
                    fontSize: 11,
                    color: selected ? tokens.accent : tokens.text,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _editorBody(FanCadTokens tokens) {
    if (!_opened) {
      if (_error == null) return const SizedBox.shrink();
      return FanCadEmpty(message: _error!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(FanCadTokens.space2),
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space3,
              vertical: FanCadTokens.space2,
            ),
            decoration: BoxDecoration(
              color: tokens.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(FanCadTokens.radius),
              border: Border.all(color: tokens.danger.withValues(alpha: 0.4)),
            ),
            child: Text(
              _error!,
              style: tokens.labelStyle.copyWith(color: tokens.danger),
            ),
          ),
        Expanded(
          child: TextField(
            controller: _body,
            autofocus: true,
            maxLines: null,
            expands: true,
            style: tokens.monoStyle.copyWith(fontSize: 12),
            cursorColor: tokens.accent,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(FanCadTokens.space3),
            ),
            onChanged: (_) {
              if (_applying) return;
              if (!_dirty || _error != null) {
                setState(() {
                  _dirty = true;
                  _error = null;
                });
              }
            },
          ),
        ),
      ],
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

String _pluginTitle(PluginRefModel handle) =>
    handle.name.isEmpty ? handle.id : handle.name;

/// `.js` and `.json` under [directory]. Directories whose name starts with
/// `.` are skipped, and a symlink is not followed out of the folder.
List<String> _extensionSourceFiles(String directory) {
  if (directory.isEmpty) return const [];
  final root = Directory(directory);
  if (!root.existsSync()) return const [];
  final found = <String>[];
  void walk(Directory dir) {
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException {
      return;
    }
    for (final entity in entries) {
      final name = p.basename(entity.path);
      if (name.isEmpty) continue;
      if (entity is Directory) {
        if (name.startsWith('.')) continue;
        walk(entity);
        continue;
      }
      if (entity is! File) continue;
      final extension = p.extension(name).toLowerCase();
      if (extension != '.js' && extension != '.json') continue;
      found.add(p.relative(entity.path, from: root.path));
    }
  }

  walk(root);
  found.sort();
  return found;
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
