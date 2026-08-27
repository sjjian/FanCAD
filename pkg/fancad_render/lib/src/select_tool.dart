import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'picking.dart';
import 'snap.dart';
import 'tool.dart';

/// The tool that runs when no command is active.
///
/// It does three jobs that in AutoCAD are also fused into the idle state:
/// picking, window selection, and grip editing. Fusing them matters because the
/// user does not think of them as different modes — they click, and the right
/// thing happens based on what was under the cursor.
class SelectionTool extends CadTool {
  SelectionTool();

  @override
  String get id => 'select';

  int? _hovered;

  /// Set while dragging a selection window.
  Vec2? _windowStart;
  Vec2? _windowEnd;

  /// Set while dragging a grip: which entity, which grip, and where it started.
  int? _gripEntity;
  int? _gripLayoutViewport;
  int _gripIndex = -1;
  Vec2? _gripOrigin;
  Vec2? _gripTarget;
  PaperViewport? _gripViewport;

  /// The grip under the cursor, drawn filled so the user knows it is live.
  int _hotGrip = -1;

  bool get isEditingGrip => _gripEntity != null || _gripLayoutViewport != null;

  @override
  String get promptText => isEditingGrip
      ? 'Specify stretch point:'
      : 'Select objects or specify a command:';

  // Snapping while merely hovering is noise, but a grip drag is a real edit and
  // needs the same precision as drawing does.
  @override
  bool get wantsSnap => isEditingGrip;

  @override
  Vec2? get basePoint => _gripOrigin;

  @override
  Set<int> get snapExclusions => {?_gripEntity};

  @override
  void onActivate(ToolHost host) {
    _reset();
  }

  void _reset() {
    _windowStart = null;
    _windowEnd = null;
    _gripEntity = null;
    _gripLayoutViewport = null;
    _gripIndex = -1;
    _gripOrigin = null;
    _gripTarget = null;
    _gripViewport = null;
  }

  @override
  void onMove(ToolHost host, Vec2 point, SnapResult snap) {
    final grip = host.picker.pickGripAmong(
      host.document,
      host.selection.ids,
      host.viewport,
      point,
      viewportIndices: host.selection.viewportIndices,
    );
    if (grip != null) {
      _hotGrip = _gripOrdinalOf(host, grip);
      _hovered = null;
      return;
    }
    _hotGrip = -1;
    _hovered = host.picker
        .pickTopmost(host.document, host.viewport, point)
        ?.entityId;
  }

  @override
  bool onClick(
    ToolHost host,
    Vec2 point,
    SnapResult snap,
    PointerDownEvent event,
  ) {
    // A click on a grip of an already selected entity starts a stretch rather
    // than changing the selection.
    final grip = host.picker.pickGripAmong(
      host.document,
      host.selection.ids,
      host.viewport,
      point,
      viewportIndices: host.selection.viewportIndices,
    );
    if (grip != null && !isEditingGrip) {
      _gripEntity = grip.isViewportFrame ? null : grip.entityId;
      _gripLayoutViewport = grip.viewportIndex;
      _gripIndex = grip.gripIndex;
      _gripOrigin = grip.paperPoint;
      _gripTarget = grip.paperPoint;
      _gripViewport = grip.viewport;
      host.prompt(promptText);
      return true;
    }

    // A second click while stretching commits it, so a grip edit can be done
    // as click-move-click as well as by dragging.
    if (isEditingGrip) {
      _commitGrip(host, point);
      return true;
    }

    final frame = host.picker.pickViewportFrame(
      host.document,
      host.viewport,
      point,
    );
    if (frame != null) {
      host.selection.selectViewports([frame]);
      host.prompt('Selected viewport');
      return true;
    }

    final hit = host.picker.pickTopmost(host.document, host.viewport, point);
    final additive =
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (hit == null) {
      if (!additive) host.selection.clear();
      return true;
    }
    if (additive) {
      host.selection.toggle(hit.entityId);
    } else {
      host.selection.replace([hit.entityId]);
    }
    _describeSelection(host);
    return true;
  }

  @override
  void onDragStart(ToolHost host, Vec2 point, SnapResult snap) {
    if (isEditingGrip) return;
    _windowStart = point;
    _windowEnd = point;
  }

  @override
  void onDragUpdate(ToolHost host, Vec2 point, SnapResult snap) {
    if (isEditingGrip) {
      _gripTarget = point;
      return;
    }
    _windowEnd = point;
  }

  @override
  void onDragEnd(ToolHost host, Vec2 point, SnapResult snap) {
    if (isEditingGrip) {
      _commitGrip(host, point);
      return;
    }
    final start = _windowStart;
    _windowStart = null;
    _windowEnd = null;
    if (start == null) return;
    if (start.distanceTo(point) < host.viewport.pixelsToWorld(3)) return;

    final crossing = point.x < start.x;
    final found = host.picker.pickWindow(
      host.document,
      host.viewport,
      Bounds2.fromCorners(start, point),
      crossing: crossing,
    );
    final additive =
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (additive) {
      host.selection.addAll(found);
    } else {
      host.selection.replace(found);
    }
    _describeSelection(host);
  }

  void _commitGrip(ToolHost host, Vec2 point) {
    final id = _gripEntity;
    final viewportIndex = _gripLayoutViewport;
    final index = _gripIndex;
    final modelPoint = _toEntityPoint(point);
    _gripEntity = null;
    _gripLayoutViewport = null;
    _gripIndex = -1;
    _gripOrigin = null;
    _gripTarget = null;
    _gripViewport = null;
    if (index < 0) return;
    if (viewportIndex != null) {
      final layout = host.document.activeLayout;
      if (viewportIndex < 0 || viewportIndex >= layout.viewports.length) {
        return;
      }
      final moved = layout.viewports[viewportIndex].withGrip(index, point);
      host.session.edit('Stretch viewport', (transaction) {
        final next = [...layout.viewports];
        next[viewportIndex] = moved;
        transaction.putLayout(layout.copyWith(viewports: next));
      });
      host.prompt(promptText);
      return;
    }
    if (id == null) return;
    final entity = host.document.entity(id);
    if (entity == null) return;
    host.session.edit('Stretch', (transaction) {
      transaction.moveGrip(id, index, modelPoint);
    });
    host.prompt(promptText);
  }

  @override
  bool onKey(ToolHost host, LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      final viewports = host.selection.viewportIndices.toList()..sort();
      if (viewports.isNotEmpty) {
        final layout = host.document.activeLayout;
        host.session.edit('Erase viewport', (transaction) {
          final next = [...layout.viewports];
          for (final index in viewports.reversed) {
            if (index >= 0 && index < next.length) next.removeAt(index);
          }
          transaction.putLayout(layout.copyWith(viewports: next));
        });
        host.selection.clear();
        return true;
      }
      final ids = host.selection.ids.toList();
      if (ids.isEmpty) return false;
      final committed = host.session.edit('Erase', (transaction) {
        transaction.eraseAll(ids);
      });
      if (committed != null) {
        host.write('Erased ${committed.change.removed.length} object(s).');
      }
      host.selection.clear();
      return true;
    }
    return false;
  }

  @override
  bool get hasCancellableGesture {
    if (_windowStart != null) return true;
    if (!isEditingGrip) return false;
    final origin = _gripOrigin;
    final target = _gripTarget;
    // A grip click that has not moved yet is not a stretch. Escape should
    // drop the selection, not just leave stretch mode.
    return origin != null && target != null && origin.distanceTo(target) > 1e-9;
  }

  @override
  void onCancelGesture(ToolHost host) => _reset();

  @override
  void onCancel(ToolHost host) {
    _reset();
    host.selection.clear();
  }

  @override
  List<int> buildHighlights(ToolHost host) {
    final hovered = _hovered;
    if (hovered == null || host.selection.contains(hovered)) return const [];
    return [hovered];
  }

  @override
  List<OverlayShape> buildPreview(ToolHost host) {
    final viewportIndex = _gripLayoutViewport;
    final target = _gripTarget;
    if (viewportIndex != null && target != null && _gripIndex >= 0) {
      final layout = host.document.activeLayout;
      if (viewportIndex >= 0 && viewportIndex < layout.viewports.length) {
        final moved = layout.viewports[viewportIndex].withGrip(
          _gripIndex,
          target,
        );
        final box = moved.paperBounds;
        return [
          OverlayPolyline([
            Vec2(box.minX, box.minY),
            Vec2(box.maxX, box.minY),
            Vec2(box.maxX, box.maxY),
            Vec2(box.minX, box.maxY),
          ], closed: true),
        ];
      }
    }

    final id = _gripEntity;
    if (id != null && target != null && _gripIndex >= 0) {
      // Show the entity as it would be after the stretch, so the user is
      // committing to something they have already seen.
      final entity = host.document.entity(id);
      if (entity != null) {
        final moved = entity.withGrip(_gripIndex, _toEntityPoint(target));
        final sink = PolylineSink();
        final through = _gripViewport;
        final scale = through?.scale.abs() ?? 1;
        moved.emit(
          host.document.emitContext(
            tolerance: scale < 1e-12
                ? host.viewport.tolerance
                : host.viewport.tolerance / scale,
            clip: through?.modelWindow,
            transform: through?.modelToPaper() ?? const Mat3.identity(),
          ),
          sink,
        );
        return [
          for (var i = 0; i < sink.polylines.length; i++)
            OverlayPolyline(
              _toPoints(sink.polylines[i]),
              closed: sink.closedFlags[i],
            ),
        ];
      }
    }

    final start = _windowStart;
    final end = _windowEnd;
    if (start == null || end == null) return const [];
    return [OverlayRect(start, end, crossing: end.x < start.x)];
  }

  void _describeSelection(ToolHost host) {
    if (host.selection.viewportIndices.isNotEmpty) {
      host.prompt('Selected viewport');
      return;
    }
    final count = host.selection.length;
    if (count == 0) return;
    if (count == 1) {
      final entity = host.document.entity(host.selection.single!);
      if (entity != null) {
        host.prompt(
          'Selected ${entity.kind.name} on layer ${entity.props.layer}',
        );
        return;
      }
    }
    host.prompt('$count objects selected');
  }

  Vec2 _toEntityPoint(Vec2 paper) {
    final inverse = _gripViewport?.paperToModel();
    return inverse?.transform(paper) ?? paper;
  }

  /// Grips are drawn as one flat list, including one copy per paper window
  /// that shows a model-space entity, so the hot index is that list's index.
  int _gripOrdinalOf(ToolHost host, GripHit hit) {
    final grips = [
      ...host.picker.displayGrips(host.document, host.selection.ids),
      ...host.picker.displayViewportGrips(
        host.document,
        host.selection.viewportIndices,
      ),
    ];
    for (var i = 0; i < grips.length; i++) {
      final grip = grips[i];
      if (grip.entityId == hit.entityId &&
          grip.gripIndex == hit.gripIndex &&
          grip.viewportIndex == hit.viewportIndex &&
          identical(grip.viewport, hit.viewport)) {
        return i;
      }
    }
    return -1;
  }

  @override
  int get hotGripIndex => _hotGrip;

  static List<Vec2> _toPoints(List<double> xy) => [
    for (var i = 0; i + 1 < xy.length; i += 2) Vec2(xy[i], xy[i + 1]),
  ];
}
