import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../state/document_tab.dart';
import '../state/workspace.dart';
import '../theme/tokens.dart';
import 'shell_widgets.dart';

/// The drawing area for one tab.
///
/// Thin on purpose: the canvas widget owns rendering and the tool controller owns
/// interaction, so all this does is connect them and make sure the keyboard ends
/// up at the command line. Anything more here would be logic that the headless
/// and AI paths could not reach.
class DocumentView extends StatefulWidget {
  const DocumentView({
    super.key,
    required this.workspace,
    required this.tab,
    required this.commandLineFocus,
  });

  final Workspace workspace;
  final DocumentTab tab;

  /// Typing anywhere over the canvas should land in the command line, so the
  /// canvas forwards focus rather than competing for it.
  final FocusNode commandLineFocus;

  @override
  State<DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends State<DocumentView> {
  final GlobalKey<CadCanvasState> _canvasKey = GlobalKey<CadCanvasState>();

  @override
  void initState() {
    super.initState();
    _bind(widget.tab);
  }

  @override
  void didUpdateWidget(DocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      oldWidget.tab.onGeometryInvalidated = null;
      _bind(widget.tab);
    }
  }

  @override
  void dispose() {
    widget.tab.onGeometryInvalidated = null;
    super.dispose();
  }

  /// Connects document changes to the canvas's tessellation cache.
  ///
  /// The canvas cannot listen to the document itself without knowing about
  /// sessions, and the tab cannot reach into the canvas's cache, so the tab
  /// exposes a hook and the view is what ties the knot.
  void _bind(DocumentTab tab) {
    tab.onGeometryInvalidated = (change) {
      final canvas = _canvasKey.currentState;
      if (canvas != null) {
        canvas.applyDocumentChange(change);
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _canvasKey.currentState?.applyDocumentChange(change);
      });
    };
  }

  /// Paper viewport interiors run VPMAX; a maximized model view runs VPMIN;
  /// everything else is zoom extents.
  void _onDoubleClick(Offset local) {
    final tab = widget.tab;
    final action = canvasDoubleClick(
      layout: tab.document.activeLayout,
      point: tab.viewport.viewport.toWorld(local),
      isMaximized: tab.session.maximizedLayoutName != null,
    );
    widget.workspace.run(action.id, args: action.args);
  }

  /// A click, not a drag. Deferred a frame so the pointer-up does not
  /// dismiss the menu as soon as it opens.
  void _openContextMenu(Offset local) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox) return;
      final global = box.localToGlobal(local);
      final tab = widget.tab;
      final tokens = context.tokens;
      final l10n = context.l10n;
      final selected = tab.selection.isNotEmpty;
      final hasHidden = tab.document.activeEntities.any(
        (entity) => !entity.props.visible,
      );
      final running = widget.workspace.runningCommand;
      final runningTitle = running == null
          ? null
          : () {
              final descriptor = widget.workspace.commands.find(running);
              if (descriptor == null) return running;
              return l10n.commandTitle(descriptor.id, descriptor.title);
            }();
      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          global.dx,
          global.dy,
          global.dx + 1,
          global.dy + 1,
        ),
        color: tokens.surfaceOverlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
          side: BorderSide(color: tokens.borderStrong),
        ),
        items: [
          if (runningTitle != null)
            _item('__cancel__', l10n.cancel_named(runningTitle), 'Esc', tokens),
          if (runningTitle != null) const PopupMenuDivider(),
          if (selected) ...[
            _item('__properties__', l10n.properties, null, tokens),
            _item('view.zoomSelected', l10n.zoom_to_selection, null, tokens),
            const PopupMenuDivider(),
            _item('edit.erase', l10n.erase, 'Del', tokens),
            _item('edit.move', l10n.move, 'M', tokens),
            _item('edit.copy', l10n.copy, 'CO', tokens),
            _item('view.isolateObjects', l10n.isolate, null, tokens),
            _item('view.hideObjects', l10n.hide, null, tokens),
            _item('select.none', l10n.deselect, null, tokens),
          ] else ...[
            _item('select.all', l10n.select_all, null, tokens),
            _item('view.zoomExtents', l10n.zoom_extents, null, tokens),
            _item('view.zoomWindow', l10n.zoom_window, null, tokens),
          ],
          PopupMenuItem(
            value: 'view.unisolateObjects',
            enabled: hasHidden,
            height: 32,
            child: _label(
              hasHidden ? l10n.show_hidden_objects : l10n.no_hidden_objects,
              null,
              tokens,
              enabled: hasHidden,
            ),
          ),
          const PopupMenuDivider(),
          _item(
            'edit.undo',
            tab.history.nextUndoLabel == null
                ? l10n.undo
                : l10n.undo_named(tab.history.nextUndoLabel!),
            shellShortcut('Z'),
            tokens,
            enabled: tab.history.canUndo,
          ),
          _item(
            'edit.redo',
            tab.history.nextRedoLabel == null
                ? l10n.redo
                : l10n.redo_named(tab.history.nextRedoLabel!),
            shellShortcut('Z', shift: true),
            tokens,
            enabled: tab.history.canRedo,
          ),
        ],
      ).then((id) {
        if (id == null || !mounted) return;
        if (id == '__cancel__') {
          widget.workspace.cancelActive();
          return;
        }
        if (id == '__properties__') {
          widget.workspace.revealPanel('properties');
          return;
        }
        widget.workspace.run(id);
      });
    });
  }

  PopupMenuItem<String> _item(
    String value,
    String label,
    String? shortcut,
    FanCadTokens tokens, {
    bool enabled = true,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      height: 32,
      child: _label(label, shortcut, tokens, enabled: enabled),
    );
  }

  Widget _label(
    String label,
    String? shortcut,
    FanCadTokens tokens, {
    bool enabled = true,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: tokens.bodyStyle.copyWith(
              color: enabled ? tokens.text : tokens.textFaint,
            ),
          ),
        ),
        if (shortcut != null)
          Text(shortcut, style: tokens.labelStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.tab,
      builder: (context, _) => _buildView(context),
    );
  }

  Widget _buildView(BuildContext context) {
    final tokens = context.tokens;
    final tab = widget.tab;
    final overlay = tab.tools.buildOverlay();
    final pending = widget.workspace.pendingHighlightIds;
    final effectiveOverlay = pending.isEmpty
        ? overlay
        : overlay.copyWith(
            highlightedIds: [...overlay.highlightedIds, ...pending],
          );
    var hiddenCount = 0;
    for (final entity in tab.document.activeEntities) {
      if (!entity.props.visible) hiddenCount += 1;
    }
    var hiddenLayers = 0;
    for (final layer in tab.document.layers.values) {
      if (!layer.visible) hiddenLayers += 1;
    }
    final currentLayer = tab.document.layer(tab.document.currentLayer);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.workspace.cancelActive();
          return KeyEventResult.handled;
        }
        // Delete on a selection is the one keystroke users expect to work
        // without the command line having focus.
        if ((event.logicalKey == LogicalKeyboardKey.delete ||
                event.logicalKey == LogicalKeyboardKey.backspace) &&
            tab.selection.isNotEmpty) {
          widget.workspace.run('edit.erase');
          return KeyEventResult.handled;
        }
        return tab.tools.handleKey(event.logicalKey)
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (_) => widget.commandLineFocus.requestFocus(),
        child: Column(
          children: [
            if (hiddenCount > 0)
              _VisibilityBanner(
                icon: Icons.visibility_off_outlined,
                message: hiddenCount == 1
                    ? context.l10n.one_object_hidden
                    : context.l10n.many_objects_hidden(hiddenCount),
                action: context.l10n.show_all,
                onShowAll: () =>
                    widget.workspace.run('view.unisolateObjects'),
              )
            else if (hiddenLayers > 0)
              _VisibilityBanner(
                icon: Icons.layers_outlined,
                message: hiddenLayers == 1
                    ? context.l10n.one_layer_off
                    : context.l10n.many_layers_off(hiddenLayers),
                action: context.l10n.show_all_layers,
                onShowAll: () => widget.workspace.run('layer.showAll'),
              )
            else if (currentLayer != null && currentLayer.locked)
              _VisibilityBanner(
                icon: Icons.lock_outline,
                message: context.l10n.current_layer_locked(currentLayer.name),
                action: context.l10n.unlock,
                onShowAll: () => widget.workspace.run(
                  'layer.toggleLock',
                  args: {'name': currentLayer.name},
                ),
              ),
            Expanded(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
            CadCanvas(
              key: _canvasKey,
              document: tab.document,
              controller: tab.viewport,
              inputHandler: tab.tools,
              overlay: effectiveOverlay,
              background: tokens.canvas,
              palette: tokens.isDark ? AciPalette.dark : AciPalette.light,
              showGrid: tab.showGrid,
              onSceneBuilt: tab.noteScene,
              onContextMenu: _openContextMenu,
              onDoubleClick: _onDoubleClick,
              onlyLayers: tab.isolatedLayers,
            ),
            ListenableBuilder(
              listenable: Listenable.merge([
                widget.workspace,
                widget.workspace.commandLine,
              ]),
              builder: (context, _) => _CanvasPromptHud(
                workspace: widget.workspace,
                onKeyword: (keyword) {
                  final remaining = widget.workspace.commandLine.submit(
                    keyword,
                  );
                  if (remaining != null) {
                    widget.workspace.submitCommandLine(remaining);
                  }
                },
                onCancel: widget.workspace.cancelActive,
              ),
            ),
            if (tab.document.entityCount == 0 &&
                !widget.workspace.isBusy &&
                !widget.workspace.commandLine.isAwaitingInput)
              _EmptyDrawingHint(
                onLine: () => widget.workspace.run('draw.line'),
                onRectangle: () => widget.workspace.run('draw.rectangle'),
                onCircle: () => widget.workspace.run('draw.circle'),
              ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Isolate, Hide and layer-off leave geometry in the file but off the
/// canvas. A strip here is the way back when the Layers panel is not open.
class _VisibilityBanner extends StatelessWidget {
  const _VisibilityBanner({
    required this.icon,
    required this.message,
    required this.action,
    required this.onShowAll,
  });

  final IconData icon;
  final String message;
  final String action;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.warning.withValues(alpha: tokens.isDark ? 0.16 : 0.12),
      child: Container(
        height: FanCadTokens.tabBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        child: Row(
          children: [
            Icon(icon, size: FanCadTokens.iconMedium, color: tokens.warning),
            const SizedBox(width: FanCadTokens.space2),
            Expanded(
              child: Text(
                message,
                style: tokens.bodyStyle.copyWith(color: tokens.text),
              ),
            ),
            TextButton(
              onPressed: onShowAll,
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the current prompt in the drawing, so a LINE or MOVE does not depend
/// on the user looking down at the command line.
class _CanvasPromptHud extends StatelessWidget {
  const _CanvasPromptHud({
    required this.workspace,
    required this.onKeyword,
    required this.onCancel,
  });

  final Workspace workspace;
  final ValueChanged<String> onKeyword;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final model = workspace.commandLine;
    if (!workspace.isBusy && !model.isAwaitingInput) {
      return const SizedBox.shrink();
    }
    final prompt = model.promptText;
    if (prompt.isEmpty) return const SizedBox.shrink();
    final keywords = model.pending?.keywords ?? const <String>[];
    final running = workspace.runningCommand;
    final title = running == null
        ? null
        : workspace.commands.find(running)?.title;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: FanCadTokens.space3),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Material(
            color: tokens.surfaceOverlay,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(FanCadTokens.radius),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: FanCadTokens.space3,
                vertical: FanCadTokens.space2,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FanCadTokens.radius),
                border: Border.all(color: tokens.borderStrong),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: FanCadTokens.iconMedium,
                    color: tokens.accent,
                  ),
                  const SizedBox(width: FanCadTokens.space2),
                  if (title != null) ...[
                    Text(
                      title,
                      style: tokens.labelStyle.copyWith(
                        color: tokens.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: FanCadTokens.space2),
                  ],
                  Expanded(
                    child: Text(
                      prompt,
                      style: tokens.bodyStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final keyword in keywords)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: FanCadTokens.space1,
                      ),
                      child: PromptKeywordChip(
                        label: keyword,
                        onPressed: () => onKeyword(keyword),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: FanCadTokens.space1),
                    child: PromptKeywordChip(
                      label: context.l10n.cancel,
                      muted: true,
                      onPressed: onCancel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// First-stroke hints on a new, empty drawing.
class _EmptyDrawingHint extends StatelessWidget {
  const _EmptyDrawingHint({
    required this.onLine,
    required this.onRectangle,
    required this.onCircle,
  });

  final VoidCallback onLine;
  final VoidCallback onRectangle;
  final VoidCallback onCircle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          color: tokens.surfaceOverlay.withValues(alpha: 0.94),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
            side: BorderSide(color: tokens.borderStrong),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FanCadTokens.space4,
              FanCadTokens.space4,
              FanCadTokens.space4,
              FanCadTokens.space3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.empty_drawing_title,
                  style: tokens.bodyStyle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: FanCadTokens.space1),
                Text(
                  context.l10n.empty_drawing_hint,
                  style: tokens.labelStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: FanCadTokens.space3),
                Wrap(
                  spacing: FanCadTokens.space2,
                  runSpacing: FanCadTokens.space2,
                  alignment: WrapAlignment.center,
                  children: [
                    PromptKeywordChip(label: context.l10n.line_alias, onPressed: onLine),
                    PromptKeywordChip(
                      label: context.l10n.rectangle_alias,
                      onPressed: onRectangle,
                    ),
                    PromptKeywordChip(label: context.l10n.circle_alias, onPressed: onCircle),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
