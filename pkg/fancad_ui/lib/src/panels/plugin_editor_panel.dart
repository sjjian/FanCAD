import 'dart:io';

import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _open(String id, String relative) async {
    final host = widget.host;
    if (host == null) return;
    final handle = host.plugin(id);
    if (handle == null) {
      setState(() => _error = '$id is not installed');
      return;
    }
    final file = File(p.join(handle.manifest.directory, relative));
    if (!file.existsSync()) {
      setState(() => _error = 'No such file: $relative');
      return;
    }
    _body.text = await file.readAsString();
    setState(() {
      _pluginId = id;
      _relative = relative;
      _error = null;
      _dirty = false;
    });
  }

  Future<void> _save() async {
    final id = _pluginId;
    if (id == null) return;
    final result = await widget.workspace.runHeadless(
      'plugins.write',
      args: {'id': id, 'path': _relative, 'content': _body.text},
    );
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
    return Column(
      children: [
        PanelHeader(
          title: 'Re-Editor',
          actions: [
            ShellIconButton(
              icon: Icons.save_outlined,
              tooltip: 'Save and reload',
              onPressed: _pluginId == null ? null : _save,
            ),
          ],
        ),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _pluginId != null &&
                            plugins.any((handle) => handle.id == _pluginId)
                        ? _pluginId
                        : null,
                    hint: Text('Extension', style: tokens.labelStyle),
                    isExpanded: true,
                    style: tokens.bodyStyle,
                    dropdownColor: tokens.surfaceOverlay,
                    items: [
                      for (final handle in plugins)
                        DropdownMenuItem(
                          value: handle.id,
                          child: Text(handle.id, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) _open(id, 'main.js');
                    },
                  ),
                ),
              ),
              const SizedBox(width: FanCadTokens.space2),
              Text(
                _dirty ? '$_relative •' : _relative,
                style: tokens.monoStyle.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(FanCadTokens.space2),
            child: Text(
              _error!,
              style: tokens.labelStyle.copyWith(color: tokens.danger),
            ),
          ),
        Expanded(
          child: TextField(
            controller: _body,
            maxLines: null,
            expands: true,
            style: tokens.monoStyle.copyWith(fontSize: 12),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(FanCadTokens.space3),
            ),
            onChanged: (_) {
              if (!_dirty) setState(() => _dirty = true);
            },
          ),
        ),
      ],
    );
  }
}
