import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

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
  int _gripIndex = -1;
  Vec2? _gripOrigin;
  Vec2? _gripTarget;

  /// The grip under the cursor, drawn filled so the user knows it is live.
  int _hotGrip = -1;

  bool get isEditingGrip => _gripEntity != null;

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
    _gripIndex = -1;
    _gripOrigin = null;
    _gripTarget = null;
  }

  @override
  void onMove(ToolHost host, Vec2 point, SnapResult snap) {
    final grip = host.picker.pickGripAmong(
      host.document,
      host.selection.ids,
      host.viewport,
      point,
    );
    if (grip != null) {
      _hotGrip = _gripOrdinalOf(host, grip.$1, grip.$2);
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
    );
    if (grip != null && !isEditingGrip) {
      _gripEntity = grip.$1;
      _gripIndex = grip.$2;
      _gripOrigin = host.document.entity(grip.$1)?.grips()[grip.$2];
      _gripTarget = _gripOrigin;
      host.prompt(promptText);
      return true;
    }

    // A second click while stretching commits it, so a grip edit can be done
    // as click-move-click as well as by dragging.
    if (isEditingGrip) {
      _commitGrip(host, point);
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
    final index = _gripIndex;
    _gripEntity = null;
    _gripIndex = -1;
    _gripOrigin = null;
    _gripTarget = null;
    if (id == null || index < 0) return;
    final entity = host.document.entity(id);
    if (entity == null) return;
    host.session.edit('Stretch', (transaction) {
      transaction.moveGrip(id, index, point);
    });
    host.prompt(promptText);
  }

  @override
  bool onKey(ToolHost host, LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
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
  void onCancel(ToolHost host) {
    if (isEditingGrip) {
      _reset();
      return;
    }
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
    final id = _gripEntity;
    final target = _gripTarget;
    if (id != null && target != null && _gripIndex >= 0) {
      // Show the entity as it would be after the stretch, so the user is
      // committing to something they have already seen.
      final entity = host.document.entity(id);
      if (entity != null) {
        final moved = entity.withGrip(_gripIndex, target);
        final sink = PolylineSink();
        moved.emit(
          host.document.emitContext(tolerance: host.viewport.tolerance),
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

  /// Grips are drawn as one flat list across the selection, so a per-entity
  /// grip index has to be offset by everything selected before it.
  int _gripOrdinalOf(ToolHost host, int entityId, int gripIndex) {
    var ordinal = 0;
    for (final id in host.selection.ids) {
      final entity = host.document.entity(id);
      if (entity == null) continue;
      if (id == entityId) return ordinal + gripIndex;
      ordinal += entity.grips().length;
    }
    return -1;
  }

  @override
  int get hotGripIndex => _hotGrip;

  static List<Vec2> _toPoints(List<double> xy) => [
    for (var i = 0; i + 1 < xy.length; i += 2) Vec2(xy[i], xy[i + 1]),
  ];
}
