import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/document_tab.dart';
import '../../services/workspace.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'dynamic_input_hud.dart';
import 'shell_widgets.dart';

/// The drawing area for one tab.
///
/// Thin on purpose: the canvas widget owns rendering and the tool controller owns
/// interaction, so all this does is connect them and route typing. A point
/// prompt with a base point sends keys to the cursor HUD; everything else
/// lands on the command line.
class DocumentView extends StatefulWidget {
  const DocumentView({
    super.key,
    required this.workspace,
    required this.tab,
    required this.commandLineFocus,
  });

  final Workspace workspace;
  final DocumentTab tab;

  /// Typing over the canvas lands here unless the dynamic-input HUD is up.
  final FocusNode commandLineFocus;

  @override
  State<DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends State<DocumentView> {
  final GlobalKey<CadCanvasState> _canvasKey = GlobalKey<CadCanvasState>();
  final GlobalKey<DynamicInputHudState> _dynHudKey =
      GlobalKey<DynamicInputHudState>();
  final FocusNode _dynDistanceFocus = FocusNode(debugLabel: 'dyn-distance');
  final FocusNode _dynAngleFocus = FocusNode(debugLabel: 'dyn-angle');

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
      oldWidget.tab.tools.onHudTypeIn = null;
      _bind(widget.tab);
    }
  }

  @override
  void dispose() {
    widget.tab.onGeometryInvalidated = null;
    widget.tab.tools.onHudTypeIn = null;
    _dynDistanceFocus.dispose();
    _dynAngleFocus.dispose();
    super.dispose();
  }

  /// Connects document changes to the canvas's tessellation cache.
  ///
  /// The canvas cannot listen to the document itself without knowing about
  /// sessions, and the tab cannot reach into the canvas's cache, so the tab
  /// exposes a hook and the view is what ties the knot.
  void _bind(DocumentTab tab) {
    tab.tools.onHudTypeIn = (character) {
      _dynHudKey.currentState?.takeTyping(character);
    };
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
      showShellMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          global.dx,
          global.dy,
          global.dx + 1,
          global.dy + 1,
        ),
        items: [
          if (runningTitle != null)
            shellMenuItem(
              context,
              value: '__cancel__',
              label: l10n.cancel_named(runningTitle),
              shortcut: 'Esc',
            ),
          if (runningTitle != null) const PopupMenuDivider(),
          if (selected) ...[
            shellMenuItem(
              context,
              value: '__properties__',
              label: l10n.properties,
            ),
            shellMenuItem(
              context,
              value: 'view.zoomSelected',
              label: l10n.zoom_to_selection,
            ),
            const PopupMenuDivider(),
            shellMenuItem(
              context,
              value: 'edit.erase',
              label: l10n.erase,
              shortcut: 'E',
            ),
            shellMenuItem(
              context,
              value: 'edit.move',
              label: l10n.move,
              shortcut: 'M',
            ),
            shellMenuItem(
              context,
              value: 'edit.copy',
              label: l10n.copy,
              shortcut: 'CO',
            ),
            shellMenuItem(
              context,
              value: 'view.isolateObjects',
              label: l10n.isolate,
            ),
            shellMenuItem(context, value: 'view.hideObjects', label: l10n.hide),
            shellMenuItem(context, value: 'select.none', label: l10n.deselect),
          ] else ...[
            shellMenuItem(context, value: 'select.all', label: l10n.select_all),
            shellMenuItem(
              context,
              value: 'view.zoomExtents',
              label: l10n.zoom_extents,
            ),
            shellMenuItem(
              context,
              value: 'view.zoomWindow',
              label: l10n.zoom_window,
            ),
          ],
          shellMenuItem(
            context,
            value: 'view.unisolateObjects',
            label: hasHidden
                ? l10n.show_hidden_objects
                : l10n.no_hidden_objects,
            enabled: hasHidden,
          ),
          const PopupMenuDivider(),
          shellMenuItem(
            context,
            value: 'edit.undo',
            label: tab.history.nextUndoLabel == null
                ? l10n.undo
                : l10n.undo_named(tab.history.nextUndoLabel!),
            shortcut: shellShortcut('Z'),
            enabled: tab.history.canUndo,
          ),
          shellMenuItem(
            context,
            value: 'edit.redo',
            label: tab.history.nextRedoLabel == null
                ? l10n.redo
                : l10n.redo_named(tab.history.nextRedoLabel!),
            shortcut: shellShortcut('Z', shift: true),
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
        if (tab.tools.showDynamicInput &&
            DynamicInputHud.isTypeInCharacter(event.character)) {
          final hud = _dynHudKey.currentState;
          if (hud != null && !hud.hasFieldFocus) {
            hud.takeTyping(event.character!);
            return KeyEventResult.handled;
          }
        }
        return tab.tools.handleKey(event.logicalKey)
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (_) {
          if (tab.tools.showDynamicInput) return;
          widget.commandLineFocus.requestFocus();
        },
        child: Column(
          children: [
            if (hiddenCount > 0)
              ShellBanner(
                tone: ShellTone.warning,
                icon: Icons.visibility_off_outlined,
                message: hiddenCount == 1
                    ? context.l10n.one_object_hidden
                    : context.l10n.many_objects_hidden(hiddenCount),
                action: context.l10n.show_all,
                onAction: () => widget.workspace.run('view.unisolateObjects'),
              )
            else if (hiddenLayers > 0)
              ShellBanner(
                tone: ShellTone.warning,
                icon: Icons.layers_outlined,
                message: hiddenLayers == 1
                    ? context.l10n.one_layer_off
                    : context.l10n.many_layers_off(hiddenLayers),
                action: context.l10n.show_all_layers,
                onAction: () => widget.workspace.run('layer.showAll'),
              )
            else if (currentLayer != null && currentLayer.locked)
              ShellBanner(
                tone: ShellTone.warning,
                icon: Icons.lock_outline,
                message: context.l10n.current_layer_locked(currentLayer.name),
                action: context.l10n.unlock,
                onAction: () => widget.workspace.run(
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
                  Positioned.fill(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        widget.workspace,
                        widget.workspace.commandLine,
                        tab.tools,
                        tab.viewport,
                      ]),
                      builder: (context, _) {
                        final prompt = widget.workspace.commandLine.promptText;
                        final toolPrompt =
                            tab.tools.activeTool?.promptText ?? '';
                        return Stack(
                          children: [
                            if (!tab.tools.showDynamicInput)
                              _CanvasPromptHud(
                                workspace: widget.workspace,
                                onKeyword: (keyword) {
                                  final remaining = widget.workspace.commandLine
                                      .submit(keyword);
                                  if (remaining != null) {
                                    widget.workspace.submitCommandLine(
                                      remaining,
                                    );
                                  }
                                },
                                onCancel: widget.workspace.cancelActive,
                              ),
                            if (tab.tools.showDynamicInput)
                              DynamicInputHud(
                                key: _dynHudKey,
                                tools: tab.tools,
                                viewport: tab.viewport.viewport,
                                prompt: prompt.isNotEmpty ? prompt : toolPrompt,
                                distanceFocus: _dynDistanceFocus,
                                angleFocus: _dynAngleFocus,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (tab.document.entityCount == 0 &&
                      !widget.workspace.isBusy &&
                      !widget.workspace.commandLine.isAwaitingInput)
                    const _EmptyDrawingHint(),
                ],
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
                      padding: const EdgeInsets.only(left: FanCadTokens.space1),
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

/// First-stroke hint on a new, empty drawing. Quiet text so it does not
/// compete with the canvas HUD.
class _EmptyDrawingHint extends StatelessWidget {
  const _EmptyDrawingHint();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.empty_drawing_title,
                style: tokens.dialogTitleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FanCadTokens.space1),
              Text(
                context.l10n.empty_drawing_hint,
                style: tokens.labelStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
