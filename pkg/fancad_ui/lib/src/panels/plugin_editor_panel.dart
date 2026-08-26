import 'dart:async';
import 'dart:io';

import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../l10n/l10n.dart';
import '../state/workspace.dart';
import '../theme/tokens.dart';
import '../workbench/shell_widgets.dart';

/// A small source editor for one extension file.
///
/// The AI authoring loop writes files and reloads them; this panel is how a
/// person reviews what was written without leaving the application. Saving
/// goes through `plugins.write` so the same path a model uses is the path a
/// person uses, including the reload that follows.
class PluginEditorPanel extends StatefulWidget {
  const PluginEditorPanel({
    super.key,
    required this.workspace,
    required this.host,
  });

  final Workspace workspace;
  final PluginHost? host;

  @override
  State<PluginEditorPanel> createState() => _PluginEditorPanelState();
}

class _PluginEditorPanelState extends State<PluginEditorPanel> {
  final TextEditingController _body = TextEditingController();
  String? _pluginId;
  String _relative = 'main.js';
  String? _error;
  bool _dirty = false;
  int _seenRequest = 0;

  @override
  void initState() {
    super.initState();
    widget.workspace.addListener(_onWorkspace);
    _consumeTarget();
  }

  @override
  void didUpdateWidget(PluginEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != widget.workspace) {
      oldWidget.workspace.removeListener(_onWorkspace);
      widget.workspace.addListener(_onWorkspace);
      _consumeTarget();
    }
  }

  @override
  void dispose() {
    widget.workspace.removeListener(_onWorkspace);
    _body.dispose();
    super.dispose();
  }

  void _onWorkspace() {
    if (!mounted) return;
    _consumeTarget();
  }

  void _consumeTarget() {
    final request = widget.workspace.pluginEditorRequest;
    final target = widget.workspace.pluginEditorTarget;
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
    final host = widget.host;
    if (host == null) return;
    final handle = host.plugin(id);
    if (handle == null) {
      setState(() => _error = context.l10n.plugin_not_installed(id));
      return;
    }
    final file = File(p.join(handle.manifest.directory, relative));
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
    final tokens = context.tokens;
    final host = widget.host;
    final plugins = host?.plugins ?? const [];
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
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value:
                            _pluginId != null &&
                                plugins.any((handle) => handle.id == _pluginId)
                            ? _pluginId
                            : null,
                        hint: Text(context.l10n.extension, style: tokens.labelStyle),
                        isExpanded: true,
                        style: tokens.bodyStyle,
                        dropdownColor: tokens.surfaceOverlay,
                        items: [
                          for (final handle in plugins)
                            DropdownMenuItem(
                              value: handle.id,
                              child: Text(
                                handle.manifest.name.isEmpty
                                    ? handle.id
                                    : handle.manifest.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          if (id == null) return;
                          unawaited(
                            _switchTo(
                              id,
                              host?.plugin(id)?.manifest.entryPoint ??
                                  'main.js',
                            ),
                          );
                        },
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
            Expanded(child: _editorBody(tokens, plugins)),
          ],
        ),
      ),
    );
  }

  Widget _editorBody(FanCadTokens tokens, List<PluginHandle> plugins) {
    if (widget.host == null) {
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

