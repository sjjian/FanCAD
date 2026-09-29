import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../commands/file/dialog.dart';
import '../../commands/pro/export.dart';
import '../../l10n/l10n.dart';
import '../../models/workspace.dart';
import '../../services/workspace.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';

/// Export options. Layers follow the layers panel, and the camera stays put.
class ExportPanel extends ConsumerWidget {
  const ExportPanel({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(
      workspaceNotifierProvider.select((state) {
        final session = state.active;
        if (session == null || session.isStartPage || !session.export.open) {
          return null;
        }
        return session.export;
      }),
    );
    final tab = workspace.active;
    if (preview == null || tab == null || tab.isStartPage) {
      return const SizedBox.shrink();
    }
    final sessionId = tab.session.id;
    ref.watch(
      documentTabNotifierProvider(
        sessionId,
      ).select((state) => state.contentEpoch),
    );
    ref.listen(
      documentTabNotifierProvider(
        sessionId,
      ).select((state) => state.selectionEpoch),
      (previous, next) => workspace.reframeExport(),
    );
    final l10n = context.l10n;
    final document = tab.document;
    final visible = _visibleLayerNames(tab);

    return Column(
      key: const Key('export-panel'),
      children: [
        PanelHeader(title: l10n.export_menu),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(FanCadTokens.space4),
            children: [
              SettingsLabeledRow(
                labelWidth: _labelWidth,
                label: l10n.export_format,
                child: SettingsDropdown<ExportFormat>(
                  key: const Key('export-format'),
                  height: FanCadTokens.rowHeight,
                  value: preview.format,
                  onChanged: (format) => workspace.updateExport(format: format),
                  options: [
                    for (final format in ExportFormat.values)
                      SettingsDropdownOption(
                        key: Key('export-format-${format.extension}'),
                        value: format,
                        label: format.label,
                      ),
                  ],
                ),
              ),
              const _ExportRule(),
              preview.scope == ExportScope.view
                  ? ListenableBuilder(
                      listenable: tab.viewport,
                      builder: (context, _) => _scopeField(
                        context,
                        preview,
                        _visibleText(workspace.describeView()['visible']),
                      ),
                    )
                  : _scopeField(
                      context,
                      preview,
                      preview.scope == ExportScope.window
                          ? (preview.window == null
                                ? l10n.export_scope_window_hint
                                : _windowText(preview.window!))
                          : null,
                    ),
              const _ExportRule(),
              _VisibleLayers(
                names: visible,
                total: document.layers.length,
                onEdit: () {
                  workspace.suspendExport();
                  workspace.revealPanel('layers');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scopeField(
    BuildContext context,
    ExportStateModel preview,
    String? tooltip,
  ) {
    final l10n = context.l10n;
    return SettingsLabeledRow(
      labelWidth: _labelWidth,
      label: l10n.export_scope,
      child: SettingsDropdown<ExportScope>(
        key: const Key('export-scope'),
        height: FanCadTokens.rowHeight,
        value: preview.scope,
        tooltip: tooltip,
        onChanged: (scope) => workspace.updateExport(scope: scope),
        options: [
          for (final scope in const [
            ExportScope.extents,
            ExportScope.view,
            ExportScope.window,
          ])
            SettingsDropdownOption(
              key: Key('export-scope-${scope.name}'),
              value: scope,
              label: _scopeLabel(l10n, scope),
            ),
        ],
      ),
    );
  }
}

Future<void> commitExport(
  BuildContext context,
  Workspace workspace,
  ExportStateModel preview,
) async {
  final tab = workspace.active;
  if (tab == null) return;
  if (preview.scope == ExportScope.selection && tab.session.selection.isEmpty) {
    workspace.notify(context.l10n.export_need_selection, isError: true);
    return;
  }
  final extension = preview.format.extension;
  final chosen = await saveFileDialog(
    suggestedName: plotSuggestedName(tab.title, extension),
    extensions: [extension],
    typeLabel: preview.format.label,
    uniformTypeIdentifiers: _uti(preview.format),
  );
  if (chosen == null) return;
  final window = preview.window;
  final args = <String, Object?>{
    'path': chosen,
    'format': extension,
    'scope': preview.scope.name,
    'layers': _visibleLayerNames(tab),
    if (preview.scope == ExportScope.window && window != null) ...{
      'corner1': [window.minX, window.minY],
      'corner2': [window.maxX, window.maxY],
    },
  };
  await workspace.run('print.export', args: args);
}

/// Short labels, so the outlined field keeps the rest of a narrow sidebar.
const _labelWidth = 72.0;

class _ExportRule extends StatelessWidget {
  const _ExportRule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: FanCadTokens.space3),
      child: FanCadHairline(strong: false),
    );
  }
}

/// Visible-layer count on the same line as the format and scope values.
class _VisibleLayers extends StatelessWidget {
  const _VisibleLayers({
    required this.names,
    required this.total,
    required this.onEdit,
  });

  final List<String> names;
  final int total;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SettingsLabeledRow(
      labelWidth: _labelWidth,
      label: context.l10n.layers,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: FanCadTokens.space2),
              child: Text(
                '${names.length}/$total',
                key: const Key('export-layer-count'),
                style: tokens.bodyStyle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          FanCadIconButton(
            key: const Key('export-edit-layers'),
            icon: Icons.open_in_new,
            tooltip: context.l10n.export_edit_layers,
            iconSize: FanCadTokens.iconSmall,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

List<String> _visibleLayerNames(DocumentTab tab) {
  final document = tab.document;
  final names = [
    for (final layer in document.layers.values)
      if (document.isLayerVisible(layer.name)) layer.name,
  ]..sort(_compareLayerNames);
  return names;
}

int _compareLayerNames(String a, String b) {
  final numberA = int.tryParse(a);
  final numberB = int.tryParse(b);
  if (numberA != null && numberB != null) return numberA.compareTo(numberB);
  return a.toLowerCase().compareTo(b.toLowerCase());
}

String _scopeLabel(AppLocalizations l10n, ExportScope scope) => switch (scope) {
  ExportScope.extents => l10n.export_scope_extents,
  ExportScope.view => l10n.export_scope_view,
  ExportScope.window => l10n.export_scope_window,
  ExportScope.selection => l10n.export_scope_selection,
};

String? _visibleText(Object? visible) {
  if (visible is! List || visible.length < 4) return null;
  final coords = <double>[];
  for (final item in visible.take(4)) {
    if (item is! num) return null;
    coords.add(item.toDouble());
  }
  return _windowText(
    ExportWindowModel(
      minX: coords[0],
      minY: coords[1],
      maxX: coords[2],
      maxY: coords[3],
    ),
  );
}

String _windowText(ExportWindowModel window) =>
    '${_cornerText(window.minX, window.minY)}\n'
    '${_cornerText(window.maxX, window.maxY)}';

String _cornerText(double x, double y) =>
    '${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}';

List<String> _uti(ExportFormat format) => switch (format) {
  ExportFormat.svg => const ['public.svg-image'],
  ExportFormat.pdf => const ['com.adobe.pdf'],
  ExportFormat.png => const ['public.png'],
  ExportFormat.jpg => const ['public.jpeg'],
};
