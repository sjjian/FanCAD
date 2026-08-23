import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    tab.onGeometryInvalidated = (change) =>
        _canvasKey.currentState?.applyDocumentChange(change);
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
      final selected = tab.selection.isNotEmpty;
      final hasHidden = tab.document.activeEntities.any(
        (entity) => !entity.props.visible,
      );
      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          global.dx,
          global.dy,
          global.dx + 1,
          global.dy + 1,
        ),
        items: [
          const PopupMenuItem(
            value: 'view.zoomExtents',
            child: Text('Zoom Extents'),
          ),
          const PopupMenuItem(value: 'view.zoomIn', child: Text('Zoom In')),
          const PopupMenuItem(value: 'view.zoomOut', child: Text('Zoom Out')),
          const PopupMenuItem(
            value: 'view.zoomWindow',
            child: Text('Zoom Window'),
          ),
          if (selected)
            const PopupMenuItem(
              value: 'view.zoomSelected',
              child: Text('Zoom to Selection'),
            ),
          const PopupMenuDivider(),
          if (selected)
            const PopupMenuItem(value: 'edit.erase', child: Text('Erase'))
          else
            const PopupMenuItem(value: 'select.all', child: Text('Select All')),
          if (selected)
            const PopupMenuItem(
              value: 'select.none',
              child: Text('Deselect All'),
            ),
          if (selected)
            const PopupMenuItem(
              value: 'view.isolateObjects',
              child: Text('Isolate'),
            ),
          if (selected)
            const PopupMenuItem(
              value: 'view.hideObjects',
              child: Text('Hide'),
            ),
          PopupMenuItem(
            value: 'view.unisolateObjects',
            enabled: hasHidden,
            child: const Text('Unisolate'),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'edit.undo',
            enabled: tab.history.canUndo,
            child: const Text('Undo'),
          ),
          PopupMenuItem(
            value: 'edit.redo',
            enabled: tab.history.canRedo,
            child: const Text('Redo'),
          ),
        ],
      ).then((id) {
        if (id != null && mounted) widget.workspace.run(id);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tab = widget.tab;
    final overlay = tab.tools.buildOverlay();
    final pending = widget.workspace.pendingHighlightIds;
    final effectiveOverlay = pending.isEmpty
        ? overlay
        : overlay.copyWith(
            highlightedIds: [...overlay.highlightedIds, ...pending],
          );
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
        child: Stack(
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
                border: Border.all(
                  color: tokens.accent.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
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
                      label: 'Cancel',
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
