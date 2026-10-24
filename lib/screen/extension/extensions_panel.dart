import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../commands/extension/header.dart';
import '../../commands/extension/paths.dart';
import '../../l10n/l10n.dart';
import '../../services/extension.dart';
import '../../services/workspace.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';
import 'extension_editor.dart';

/// Saved extensions. One row is one `.js` file. Tapping the row opens it. The
/// configure menu enables, disables, or deletes it. A disabled extension stays in
/// the list and leaves the command line. The last failure stays on the row
/// until the next run.
class ExtensionsPanel extends ConsumerStatefulWidget {
  const ExtensionsPanel({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<ExtensionsPanel> createState() => _ExtensionsPanelState();
}

class _ExtensionsPanelState extends ConsumerState<ExtensionsPanel> {
  List<({String name, String? description, String? error, bool enabled})>
  _entries = const [];

  /// Why the last list, create or delete failed. The rows stay as they were.
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload());
    });
  }

  Future<void> _reload() async {
    final result = await widget.workspace.runHeadless('extensions.list');
    if (!mounted) return;
    if (!result.isOk) {
      final error = context.l10n.extension_list_failed(result.message);
      setState(() => _error = error);
      return;
    }
    final raw = result.data?['extensions'];
    final scripts =
        <({String name, String? description, String? error, bool enabled})>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final name = item['name'];
        if (name is! String || name.isEmpty) continue;
        scripts.add((
          name: name,
          description: _text(item['description']),
          error: _text(item['error']),
          enabled: item['enabled'] != false,
        ));
      }
    }
    setState(() {
      _entries = scripts;
      _error = null;
    });
  }

  String? _text(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(extensionNotifierProvider.select((model) => model.epoch), (
      _,
      _,
    ) {
      unawaited(_reload());
    });
    final directory = ref.watch(
      extensionNotifierProvider.select((model) => model.directory),
    );
    final available = directory.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          title: context.l10n.extensions,
          actions: [
            if (available)
              FanCadIconButton(
                icon: Icons.folder_open_outlined,
                tooltip: context.l10n.open_extensions_folder,
                onPressed: () => _openExtensionsFolder(
                  widget.workspace,
                  directory,
                  context.l10n,
                ),
              ),
            if (available)
              FanCadIconButton(
                icon: Icons.add,
                tooltip: context.l10n.new_extension,
                onPressed: () => unawaited(_create()),
              ),
          ],
        ),
        if (_error != null)
          Padding(
            key: const Key('extensions-error'),
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space3,
              vertical: FanCadTokens.space1,
            ),
            child: Text(
              _error!,
              style: context.tokens.labelStyle.copyWith(
                color: context.tokens.danger,
              ),
            ),
          ),
        Expanded(
          child: !available
              ? FanCadEmpty(message: context.l10n.extensions_unavailable)
              : _entries.isEmpty
              ? FanCadEmpty(
                  message: context.l10n.no_extensions,
                  actionLabel: context.l10n.new_extension,
                  onAction: () => unawaited(_create()),
                )
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final script = _entries[index];
                    return _ExtensionRow(
                      name: script.name,
                      description: script.description,
                      error: script.error,
                      enabled: script.enabled,
                      onOpen: () => unawaited(_edit(script.name)),
                      onEnable: (enabled) => ref
                          .read(extensionNotifierProvider.notifier)
                          .setEnabled(script.name, enabled),
                      onDelete: () => unawaited(_delete(script.name)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final raw = await _askName(context);
    if (raw == null || raw.trim().isEmpty || !mounted) return;
    final name = extensionStem(raw) ?? raw.trim();
    final l10n = context.l10n;
    if (_entries.any((entry) => entry.name == name)) {
      setState(() => _error = l10n.extension_exists(name));
      return;
    }
    final result = await widget.workspace.run(
      'extensions.write',
      args: {'name': name, 'content': extensionTemplate},
    );
    if (!mounted) return;
    if (!result.isOk) {
      setState(
        () => _error = l10n.extension_create_failed(name, result.message),
      );
      return;
    }
    setState(() => _error = null);
    await _edit(name);
  }

  Future<void> _delete(String name) async {
    final l10n = context.l10n;
    final result = await widget.workspace.run(
      'extensions.delete',
      args: {'name': name},
    );
    if (!mounted || result.isOk) return;
    setState(() => _error = l10n.extension_delete_failed(name, result.message));
  }

  Future<void> _edit(String name) async {
    await showExtensionEditor(context, name: name, workspace: widget.workspace);
  }
}

enum _ExtensionMenuAction { enable, disable, delete }

class _ExtensionRow extends StatefulWidget {
  const _ExtensionRow({
    required this.name,
    required this.description,
    required this.error,
    required this.enabled,
    required this.onOpen,
    required this.onEnable,
    required this.onDelete,
  });

  final String name;
  final String? description;
  final String? error;
  final bool enabled;
  final VoidCallback onOpen;
  final ValueChanged<bool> onEnable;
  final VoidCallback onDelete;

  @override
  State<_ExtensionRow> createState() => _ExtensionRowState();
}

class _ExtensionRowState extends State<_ExtensionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final titleColor = widget.enabled ? tokens.text : tokens.textMuted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: Container(
          decoration: BoxDecoration(
            color: _hovered ? tokens.hover : Colors.transparent,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          padding: const EdgeInsets.fromLTRB(
            FanCadTokens.space3,
            FanCadTokens.space2,
            FanCadTokens.space1,
            FanCadTokens.space2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: tokens.bodyStyle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!widget.enabled) ...[
                      const SizedBox(height: FanCadTokens.space1),
                      Text(l10n.extension_disabled, style: tokens.labelStyle),
                    ],
                    if (widget.description != null) ...[
                      const SizedBox(height: FanCadTokens.space1),
                      Text(
                        widget.description!,
                        style: tokens.labelStyle.copyWith(color: titleColor),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (widget.error != null) ...[
                      const SizedBox(height: FanCadTokens.space1),
                      Text(
                        widget.error!,
                        style: tokens.labelStyle.copyWith(color: tokens.danger),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              FanCadMenuButton<_ExtensionMenuAction>(
                key: Key('extension-configure-${widget.name}'),
                tooltip: l10n.configure_extension,
                placement: FanCadMenuPlacement.auto,
                onSelected: (action) {
                  switch (action) {
                    case _ExtensionMenuAction.enable:
                      widget.onEnable(true);
                    case _ExtensionMenuAction.disable:
                      widget.onEnable(false);
                    case _ExtensionMenuAction.delete:
                      widget.onDelete();
                  }
                },
                itemBuilder: (context) => [
                  if (!widget.enabled)
                    fanCadMenuItem(
                      context,
                      value: _ExtensionMenuAction.enable,
                      label: l10n.enable_extension,
                      icon: Icons.play_arrow_outlined,
                    ),
                  if (widget.enabled)
                    fanCadMenuItem(
                      context,
                      value: _ExtensionMenuAction.disable,
                      label: l10n.disable_extension,
                      icon: Icons.pause_outlined,
                    ),
                  fanCadMenuItem(
                    context,
                    value: _ExtensionMenuAction.delete,
                    label: l10n.delete_extension,
                    icon: Icons.delete_outline,
                  ),
                ],
                child: const _ExtensionGear(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtensionGear extends StatefulWidget {
  const _ExtensionGear();

  @override
  State<_ExtensionGear> createState() => _ExtensionGearState();
}

class _ExtensionGearState extends State<_ExtensionGear> {
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

Future<String?> _askName(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _NameDialog(),
  );
}

/// Owns its field controller, so the field outlives the dialog's exit
/// animation instead of rebuilding with a disposed controller.
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.tokens.surfaceOverlay,
      title: Text(context.l10n.new_extension),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: context.l10n.prompt_extension_name,
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

Future<void> _openExtensionsFolder(
  Workspace workspace,
  String path,
  AppLocalizations l10n,
) async {
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
    workspace.notify(l10n.could_not_open(path, '$error'), isError: true);
  }
}
