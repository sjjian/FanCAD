import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/document_tab.dart';
import '../state/workspace.dart';
import '../theme/tokens.dart';

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
        child: CadCanvas(
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
          onDoubleClick: (_) => widget.workspace.run('view.zoomExtents'),
          onlyLayers: tab.isolatedLayers,
        ),
      ),
    );
  }
}
