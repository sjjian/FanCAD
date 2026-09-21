import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../l10n/l10n.dart';
import '../../models/workspace.dart';
import '../../services/plugin.dart';
import '../../services/plugin_editor.dart';
import '../../services/workspace.dart';
import '../theme/tokens.dart';
import '../workbench/shell_widgets.dart';

/// A small source editor for one extension file.
///
/// The AI authoring loop writes files and reloads them; this panel is how a
/// person reviews what was written without leaving the application. Saving
/// goes through `plugins.write` so the same path a model uses is the path a
/// person uses, including the reload that follows.
class PluginEditorPanel extends ConsumerStatefulWidget {
  const PluginEditorPanel({
    super.key,
    required this.workspace,
  });

  final Workspace workspace;

  @override
  ConsumerState<PluginEditorPanel> createState() => _PluginEditorPanelState();
}

class _PluginEditorPanelState extends ConsumerState<PluginEditorPanel> {
  final TextEditingController _body = TextEditingController();
  String? _pluginId;
  String _relative = 'main.js';
  String? _error;
  bool _dirty = false;
  int _seenRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _consumeTarget();
    });
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  void _consumeTarget() {
    final editor = ref.read(pluginEditorNotifierProvider);
    final request = editor.request;
    final target = editor.target;
    if (target == null || request == _seenRequest) return;
    _seenRequest = request;
    unawaited(_switchTo(target.id, target.relative));
  }

  Future<void> _switchTo(String id, String relative) async {
    if (!await _confirmLeave()) return;
    await _open(id, relative);
  }

  /// Leaving a dirty buffer used to just load the next file over it.
  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    if (!mounted) return false;
    final tokens = context.tokens;
    final choice = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => AlertDialog(
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
      ),
    );
    if (choice == 'save') {
      await _save();
      return !_dirty;
    }
    return choice == 'discard';
  }

  Future<void> _open(String id, String relative) async {
    final store = ref.read(pluginNotifierProvider);
    if (store.directory.isEmpty) return;
    PluginRefModel? handle;
    for (final plugin in store.plugins) {
      if (plugin.id == id) {
        handle = plugin;
        break;
      }
    }
    if (handle == null) {
      setState(() => _error = context.l10n.plugin_not_installed(id));
      return;
    }
    final file = File(p.join(handle.directory, relative));
    if (!file.existsSync()) {
      setState(() => _error = context.l10n.no_such_file(relative));
      return;
    }
    _body.text = await file.readAsString();
    if (!mounted) return;
    setState(() {
      _pluginId = id;
      _relative = relative;
      _error = null;
      _dirty = false;
    });
  }

  Future<void> _save() async {
    final id = _pluginId;
    if (id == null || !_dirty) return;
    final result = await widget.workspace.runHeadless(
      'plugins.write',
      args: {'id': id, 'path': _relative, 'content': _body.text},
    );
    if (!mounted) return;
    setState(() {
      _dirty = !result.isOk;
      _error = result.isOk ? null : result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      pluginEditorNotifierProvider.select((s) => s.request),
      (_, _) => _consumeTarget(),
    );
    final tokens = context.tokens;
    final store = ref.watch(
      pluginNotifierProvider.select(
        (s) => (directory: s.directory, plugins: s.plugins, epoch: s.epoch),
      ),
    );
    final plugins = store.plugins;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            PanelHeader(
              title: context.l10n.re_editor,
              actions: [
                ShellIconButton(
                  icon: Icons.save_outlined,
                  tooltip: _pluginId == null
                      ? context.l10n.nothing_to_save
                      : _dirty
                      ? '${context.l10n.save_and_reload}  ${shellShortcut('S')}'
                      : context.l10n.saved,
                  enabled: _pluginId != null && _dirty,
                  isActive: _dirty,
                  onPressed: _save,
                ),
              ],
            ),
            Container(
              height: FanCadTokens.statusBarHeight,
              padding: const EdgeInsets.symmetric(
                horizontal: FanCadTokens.space3,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ShellMenuButton<String>(
                      placement: ShellMenuPlacement.down,
                      onSelected: (id) {
                        unawaited(
                          _switchTo(
                            id,
                            () {
                              for (final plugin in plugins) {
                                if (plugin.id == id) return plugin.entryPoint;
                              }
                              return 'main.js';
                            }(),
                          ),
                        );
                      },
                      itemBuilder: (context) => [
                        for (final handle in plugins)
                          shellMenuItem(
                            context,
                            value: handle.id,
                            label: handle.name.isEmpty
                                ? handle.id
                                : handle.name,
                            checked: handle.id == _pluginId,
                          ),
                      ],
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              () {
                                final current = plugins
                                    .where((handle) => handle.id == _pluginId)
                                    .firstOrNull;
                                if (current == null) {
                                  return context.l10n.extension;
                                }
                                return current.name.isEmpty
                                    ? current.id
                                    : current.name;
                              }(),
                              style: tokens.bodyStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.expand_more,
                            size: FanCadTokens.iconSmall,
                            color: tokens.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: FanCadTokens.space2),
                  Text(
                    _dirty ? '$_relative •' : _relative,
                    style: tokens.monoStyle.copyWith(
                      fontSize: 10.5,
                      color: _dirty ? tokens.accent : tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
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
                  border: Border.all(
                    color: tokens.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _error!,
                  style: tokens.labelStyle.copyWith(color: tokens.danger),
                ),
              ),
            Expanded(
              child: _editorBody(tokens, store.directory.isNotEmpty, plugins),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editorBody(
    FanCadTokens tokens,
    bool available,
    List<PluginRefModel> plugins,
  ) {
    if (!available) {
      return ShellEmpty(message: context.l10n.editor_unavailable);
    }
    if (plugins.isEmpty) {
      return ShellEmpty(
        message: context.l10n.create_extension_first,
        actionLabel: context.l10n.create_extension,
        onAction: () => widget.workspace.run('plugins.scaffold'),
      );
    }
    if (_pluginId == null) {
      return ShellEmpty(message: context.l10n.choose_extension);
    }
    return TextField(
      controller: _body,
      maxLines: null,
      expands: true,
      style: tokens.monoStyle.copyWith(fontSize: 12),
      cursorColor: tokens.accent,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(FanCadTokens.space3),
      ),
      onChanged: (_) {
        if (!_dirty) setState(() => _dirty = true);
      },
    );
  }
}
