import 'dart:async';

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'cad_canvas.dart';
import 'dynamic_input.dart';
import 'overlay.dart';
import 'picking.dart';
import 'snap.dart';
import 'tessellation_cache.dart';
import 'viewport.dart';

/// The services a tool may use.
///
/// Tools are written against this rather than against widgets, so a tool can be
/// unit tested, replayed from a macro, or driven by a script without a widget
/// tree existing at all.
abstract class ToolHost {
  DocumentSession get session;
  CadDocument get document;
  CadViewport get viewport;
  SnapEngine get snapEngine;
  Picker get picker;

  /// The live selection set for the active document.
  SelectionSet get selection;

  /// Asks the canvas to repaint the overlay.
  void requestRepaint();

  /// Writes a line to the command history.
  void write(String message);

  /// Replaces the transient prompt shown at the command line.
  void prompt(String message);

  /// Hands control back to the default tool.
  void finishTool();

  /// Polar locks for the cursor HUD. Empty when no field is locked.
  DynamicInput get dynamicInput;
}

/// An interactive mode that owns the pointer.
///
/// There are only two kinds in FanCAD: the selection tool, which is what runs
/// when nothing else is happening, and the prompt tools, which exist for as
/// long as one `await` inside a command. Commands themselves are never tools —
/// that is what lets the same command implementation serve the mouse, the
/// keyboard and an AI tool call.
abstract class CadTool {
  /// Identifier used for the status bar and for cancelling a specific tool.
  String get id;

  /// What to show at the command line while this tool is running.
  String get promptText => '';

  /// Whether the crosshair should be drawn.
  bool get showCrosshair => true;

  /// Whether object snapping should be resolved. The selection tool turns it
  /// off while merely hovering, because snapping to pick is visual noise.
  bool get wantsSnap => true;

  /// The base point a rubber band and tracking are measured from.
  Vec2? get basePoint => null;

  /// Whether the cursor HUD may lock distance / angle from [basePoint].
  ///
  /// Window corners and the first point of a command stay off; a second
  /// point or a live grip stretch stay on.
  bool get wantsDynamicInput => false;

  /// Entities the snap engine should ignore, typically the ones being dragged.
  Set<int> get snapExclusions => const {};

  /// Commits [point] as if the user clicked it, used by the dynamic-input HUD.
  void acceptResolvedPoint(ToolHost host, Vec2 point) {}

  void onActivate(ToolHost host) {}
  void onDeactivate() {}

  /// Called on every resolved cursor move. [point] is already snapped.
  void onMove(ToolHost host, Vec2 point, SnapResult snap) {}

  /// Returns true when the tool consumed the click.
  bool onClick(
    ToolHost host,
    Vec2 point,
    SnapResult snap,
    PointerDownEvent event,
  ) => false;

  void onDragStart(ToolHost host, Vec2 point, SnapResult snap) {}
  void onDragUpdate(ToolHost host, Vec2 point, SnapResult snap) {}
  void onDragEnd(ToolHost host, Vec2 point, SnapResult snap) {}

  /// Returns true when the tool consumed the key.
  bool onKey(ToolHost host, LogicalKeyboardKey key) => false;

  /// Called when the user presses Escape or another tool takes over.
  void onCancel(ToolHost host) {}

  /// An in-flight grip, window or first-corner pick that Escape should drop
  /// before it cancels the whole tool or the selection.
  bool get hasCancellableGesture => false;

  /// Drops [hasCancellableGesture] without finishing or cancelling the tool.
  void onCancelGesture(ToolHost host) {}

  /// Preview geometry drawn on the overlay, in drawing coordinates.
  List<OverlayShape> buildPreview(ToolHost host) => const [];

  /// Extra points to draw as grips, for example the vertices placed so far.
  List<Vec2> buildMarkers(ToolHost host) => const [];

  /// Entities to highlight, for example the one under the cursor.
  List<int> buildHighlights(ToolHost host) => const [];

  /// The index into the flattened grip list that the cursor is over, or -1.
  int get hotGripIndex => -1;
}

/// Drives the active tool and turns pointer events into resolved drawing
/// points.
///
/// This sits between the canvas and the tools: it owns snapping, drag
/// detection and the overlay model, so that every tool gets identical, correctly
/// snapped input without reimplementing any of it.
class ToolController extends ChangeNotifier
    implements CanvasInputHandler, ToolHost {
  ToolController({
    required DocumentSession session,
    required CadViewport Function() viewportProvider,
    SnapEngine? snapEngine,
    Picker? picker,
    TessellationCache? tessellation,
    this.onWrite,
    this.onPrompt,
  }) : _session = session,
       _viewportProvider = viewportProvider,
       snapEngine = snapEngine ?? SnapEngine(),
       picker = picker ?? Picker(cache: tessellation);

  DocumentSession _session;
  final CadViewport Function() _viewportProvider;

  @override
  final SnapEngine snapEngine;

  @override
  final Picker picker;

  @override
  final DynamicInput dynamicInput = DynamicInput();

  /// Receives command-history lines. The shell wires this to the command line.
  final void Function(String message)? onWrite;

  /// Receives the transient prompt.
  final void Function(String message)? onPrompt;

  /// Optional shell hook so a digit typed in the command line can jump into
  /// the cursor HUD without the command line swallowing it.
  void Function(String character)? onHudTypeIn;

  CadTool? _tool;
  CadTool? _defaultTool;

  Vec2? _cursor;
  SnapResult? _snap;

  /// Set between a pointer-down and the drag threshold being crossed, so a
  /// click and a drag can be told apart without a gesture recogniser.
  Vec2? _pressWorld;
  Offset? _pressScreen;
  bool _dragging = false;

  /// How far the pointer must travel before a press becomes a drag. Small
  /// enough not to feel sticky, large enough that a click on a grip is not
  /// misread as a one-pixel drag.
  static const double dragThresholdPixels = 4;

  @override
  DocumentSession get session => _session;

  @override
  CadDocument get document => _session.document;

  @override
  CadViewport get viewport => _viewportProvider();

  @override
  SelectionSet get selection => _session.selection;

  CadTool? get activeTool => _tool;

  /// The tool that runs when nothing else is active, normally selection.
  CadTool? get defaultTool => _defaultTool;

  Vec2? get cursor => _cursor;
  SnapResult? get snap => _snap;

  /// True while a prompt tool owns the pointer, which is how the shell knows a
  /// command is mid-flight.
  bool get isPrompting => _tool != null && _tool != _defaultTool;

  /// Whether the cursor HUD should be shown for the current tool and cursor.
  bool get showDynamicInput =>
      _tool != null &&
      _tool!.wantsDynamicInput &&
      _tool!.basePoint != null &&
      _cursor != null;

  /// Sends [character] to the cursor HUD when it is visible.
  bool offerHudTypeIn(String character) {
    if (!showDynamicInput) return false;
    final handler = onHudTypeIn;
    if (handler == null) return false;
    handler(character);
    return true;
  }

  set defaultTool(CadTool? value) {
    _defaultTool = value;
    if (_tool == null && value != null) {
      _tool = value;
      value.onActivate(this);
      _emitPrompt();
    }
  }

  /// Makes [tool] active, cancelling whatever was running.
  void push(CadTool tool) {
    final previous = _tool;
    if (previous != null) {
      if (previous != _defaultTool) previous.onCancel(this);
      previous.onDeactivate();
    }
    dynamicInput.reset();
    _tool = tool;
    tool.onActivate(this);
    _emitPrompt();
    notifyListeners();
  }

  /// Ends the current tool and returns to the default one.
  @override
  void finishTool() {
    final previous = _tool;
    if (previous == null || previous == _defaultTool) return;
    previous.onDeactivate();
    dynamicInput.reset();
    _tool = _defaultTool;
    _defaultTool?.onActivate(this);
    _emitPrompt();
    notifyListeners();
  }

  /// Cancels the current tool, as Escape does.
  void cancel() {
    _clearPointer();
    final previous = _tool;
    if (previous == null) return;
    previous.onCancel(this);
    if (previous != _defaultTool) {
      previous.onDeactivate();
      _tool = _defaultTool;
      _defaultTool?.onActivate(this);
    }
    dynamicInput.reset();
    _emitPrompt();
    notifyListeners();
  }

  /// True while the tool has a grip, window or first-corner pick in flight.
  ///
  /// A bare pointer drag does not count. Point prompts complete on click, and
  /// treating the rubber-band move as a gesture would let Escape drop the
  /// drag and leave the command waiting.
  bool get hasCancellableGesture => _tool?.hasCancellableGesture ?? false;

  /// Drops the in-flight pointer gesture and keeps the current tool.
  ///
  /// Escape uses this first so a window drag or grip stretch dies without
  /// also cancelling the command or the selection.
  bool cancelGesture() {
    final active = hasCancellableGesture;
    _clearPointer();
    if (!active) return false;
    _tool?.onCancelGesture(this);
    dynamicInput.reset();
    notifyListeners();
    return true;
  }

  void _clearPointer() {
    _dragging = false;
    _pressScreen = null;
    _pressWorld = null;
  }

  @override
  void requestRepaint() => notifyListeners();

  @override
  void write(String message) => onWrite?.call(message);

  @override
  void prompt(String message) => onPrompt?.call(message);

  void _emitPrompt() => onPrompt?.call(_tool?.promptText ?? '');

  // -------------------------------------------------------------------------
  // Input
  // -------------------------------------------------------------------------

  SnapResult _resolve(Vec2 raw) {
    final tool = _tool;
    final snapped = tool == null || !tool.wantsSnap
        ? SnapResult.free(raw)
        : snapEngine.resolve(
            document,
            viewport,
            raw,
            basePoint: tool.basePoint,
            excludedIds: tool.snapExclusions,
          );
    return _constrain(tool, snapped);
  }

  SnapResult _constrain(CadTool? tool, SnapResult snapped) {
    if (tool == null || !tool.wantsDynamicInput) return snapped;
    final base = tool.basePoint;
    if (base == null) return snapped;
    final constrained = dynamicInput.constrain(base, snapped.point);
    if ((constrained - snapped.point).lengthSquared < 1e-16) {
      if (dynamicInput.lockedAngle == null) return snapped;
      return SnapResult(
        point: snapped.point,
        origin: snapped.origin,
        marker: snapped.marker,
        trackingAngle: dynamicInput.lockedAngle,
        trackingLabel: snapped.trackingLabel,
      );
    }
    return SnapResult(
      point: constrained,
      origin: snapped.origin,
      marker: null,
      trackingAngle: dynamicInput.lockedAngle ?? snapped.trackingAngle,
      trackingLabel: snapped.trackingLabel,
    );
  }

  /// Re-projects the last cursor after the HUD changes a lock.
  void applyDynamicLocks() {
    final cursor = _cursor;
    if (cursor == null) {
      notifyListeners();
      return;
    }
    final resolved = _constrain(_tool, _snap ?? SnapResult.free(cursor));
    _cursor = resolved.point;
    _snap = resolved;
    final tool = _tool;
    if (tool != null) {
      if (_dragging) {
        tool.onDragUpdate(this, resolved.point, resolved);
      } else {
        tool.onMove(this, resolved.point, resolved);
      }
    }
    notifyListeners();
  }

  /// Commits the current (already constrained) cursor as a click would.
  bool acceptDynamicPoint([Vec2? point]) {
    final tool = _tool;
    final resolved = point ?? _cursor;
    if (tool == null || resolved == null) return false;
    tool.acceptResolvedPoint(this, resolved);
    notifyListeners();
    return true;
  }

  @override
  bool onPointerDown(Vec2 world, PointerDownEvent event) {
    // Only the primary button drives tools; the middle button pans and the
    // right button is the context menu, both handled elsewhere.
    if (event.buttons & kPrimaryMouseButton == 0) return false;
    final resolved = _resolve(world);
    _cursor = resolved.point;
    _snap = resolved;
    _pressWorld = resolved.point;
    _pressScreen = event.localPosition;
    _dragging = false;
    final tool = _tool;
    if (tool == null) return false;
    final consumed = tool.onClick(this, resolved.point, resolved, event);
    notifyListeners();
    return consumed;
  }

  @override
  bool onPointerMove(Vec2 world, PointerEvent event) {
    final resolved = _resolve(world);
    _cursor = resolved.point;
    _snap = resolved;
    final tool = _tool;
    if (tool == null) {
      notifyListeners();
      return false;
    }

    final press = _pressScreen;
    if (press != null && !_dragging) {
      if ((event.localPosition - press).distance >= dragThresholdPixels) {
        _dragging = true;
        tool.onDragStart(this, _pressWorld ?? resolved.point, resolved);
      }
    }
    if (_dragging) {
      tool.onDragUpdate(this, resolved.point, resolved);
    } else {
      tool.onMove(this, resolved.point, resolved);
    }
    notifyListeners();
    return true;
  }

  @override
  bool onPointerUp(Vec2 world, PointerUpEvent event) {
    final resolved = _resolve(world);
    _cursor = resolved.point;
    _snap = resolved;
    final tool = _tool;
    if (_dragging && tool != null) {
      tool.onDragEnd(this, resolved.point, resolved);
    }
    _dragging = false;
    _pressScreen = null;
    _pressWorld = null;
    notifyListeners();
    return true;
  }

  @override
  void onPointerExit() {
    _cursor = null;
    _snap = null;
    notifyListeners();
  }

  /// Routes a key press. Escape always cancels, which is a guarantee the shell
  /// makes rather than something each tool has to remember.
  bool handleKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.escape) {
      if (!cancelGesture()) cancel();
      return true;
    }
    final tool = _tool;
    if (tool == null) return false;
    final consumed = tool.onKey(this, key);
    if (consumed) notifyListeners();
    return consumed;
  }

  // -------------------------------------------------------------------------
  // Overlay
  // -------------------------------------------------------------------------

  /// Builds the overlay for the current frame.
  OverlayModel buildOverlay() {
    final tool = _tool;
    final selected = selection.ids.toList();
    final grips = <Vec2>[];
    // Grips are only useful up to the point where they stop being individually
    // clickable; past that they are a solid wall of blue squares.
    if (selected.length <= 64) {
      for (final grip in picker.displayGrips(document, selected)) {
        grips.add(grip.paperPoint);
      }
    }
    for (final grip in picker.displayViewportGrips(
      document,
      selection.viewportIndices,
    )) {
      grips.add(grip.paperPoint);
    }
    if (tool != null) grips.addAll(tool.buildMarkers(this));

    final snapResult = _snap;
    final base = tool?.basePoint;
    final shapes = <OverlayShape>[
      ...?tool?.buildPreview(this),
      for (final index in selection.viewportIndices)
        if (index >= 0 && index < document.activeLayout.viewports.length)
          OverlayPolyline(
            _viewportCorners(
              document.activeLayout.viewports[index].paperBounds,
            ),
            closed: true,
          ),
      if (snapResult != null &&
          snapResult.trackingAngle != null &&
          TrackingSettings.isCardinalAngle(snapResult.trackingAngle!) &&
          base != null)
        OverlayTrackingLine(
          base,
          snapResult.trackingAngle!,
          label: snapResult.trackingLabel,
        ),
    ];

    return OverlayModel(
      selectedIds: selected,
      highlightedIds: tool?.buildHighlights(this) ?? const [],
      grips: grips,
      hotGripIndex: tool?.hotGripIndex ?? -1,
      shapes: shapes,
      snap: snapResult?.marker,
      cursor: _cursor,
      showCrosshair: tool?.showCrosshair ?? true,
    );
  }

  /// Rebinds this controller to a different document tab.
  void bind(DocumentSession session) {
    if (identical(session, _session)) return;
    cancel();
    _session = session;
    _cursor = null;
    _snap = null;
    dynamicInput.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    _tool?.onDeactivate();
    _tool = null;
    super.dispose();
  }
}

/// A tool that resolves a [Future] when the user supplies one value.
///
/// This is the bridge between the imperative style a command wants to be written
/// in (`final a = await input.point('From point:')`) and the event-driven reality
/// of a canvas. The command reads as a script; the tool makes it interactive.
abstract class PromptTool<T> extends CadTool {
  PromptTool({required this.message, this.preview, this.markers = const []});

  final String message;

  /// Live feedback supplied by the running command, evaluated at the cursor.
  final PreviewBuilder? preview;

  /// Points the command has already collected, drawn as markers.
  final List<Vec2> markers;

  final Completer<T> _completer = Completer<T>();

  Future<T> get result => _completer.future;

  bool get isComplete => _completer.isCompleted;

  Vec2? hover;

  @override
  String get promptText => message;

  @override
  void onMove(ToolHost host, Vec2 point, SnapResult snap) {
    hover = point;
    if (snap.trackingLabel.isNotEmpty) {
      host.prompt('$message  ${snap.trackingLabel}');
    }
  }

  void complete(ToolHost host, T value) {
    if (_completer.isCompleted) return;
    _completer.complete(value);
    host.finishTool();
  }

  @override
  void onCancel(ToolHost host) {
    if (_completer.isCompleted) return;
    _completer.completeError(const CommandCancelled());
  }

  @override
  List<Vec2> buildMarkers(ToolHost host) => markers;

  @override
  List<OverlayShape> buildPreview(ToolHost host) {
    final cursor = hover;
    final builder = preview;
    if (cursor == null || builder == null) return const [];
    return builder(cursor);
  }
}

/// Waits for one point click.
class PointPromptTool extends PromptTool<Vec2> {
  PointPromptTool({
    required super.message,
    this.anchor,
    super.preview,
    super.markers,
  });

  /// The rubber-band anchor, which is also what tracking measures from.
  final Vec2? anchor;

  @override
  String get id => 'prompt.point';

  @override
  Vec2? get basePoint => anchor;

  @override
  bool get wantsDynamicInput => anchor != null;

  @override
  void acceptResolvedPoint(ToolHost host, Vec2 point) => complete(host, point);

  @override
  bool onClick(
    ToolHost host,
    Vec2 point,
    SnapResult snap,
    PointerDownEvent event,
  ) {
    complete(host, point);
    return true;
  }

  @override
  List<OverlayShape> buildPreview(ToolHost host) {
    final supplied = super.buildPreview(host);
    if (supplied.isNotEmpty) return supplied;
    // Without a command-supplied preview, a plain rubber band from the anchor
    // is still better than no feedback at all.
    final from = anchor;
    final to = hover;
    if (from == null || to == null) return const [];
    return [OverlayLine(from, to)];
  }
}

/// Waits for entity picks, finishing on Enter or Space.
class SelectionPromptTool extends PromptTool<List<int>> {
  SelectionPromptTool({
    required super.message,
    this.single = false,
    this.filter,
  });

  /// Completes on the first pick rather than waiting for Enter.
  final bool single;
  final bool Function(CadEntity entity)? filter;

  final List<int> _picked = [];
  int? _hovered;
  Vec2? _windowStart;
  Vec2? _windowEnd;

  /// The last click that selected something, so TTR can remember the side.
  Vec2? lastClick;

  @override
  String get id => 'prompt.selection';

  @override
  bool get wantsSnap => false;

  @override
  String get promptText => _picked.isEmpty
      ? message
      : '$message (${_picked.length} found, Enter to accept)';

  @override
  void onMove(ToolHost host, Vec2 point, SnapResult snap) {
    hover = point;
    _hovered = host.picker
        .pickTopmost(host.document, host.viewport, point, filter: filter)
        ?.entityId;
    host.prompt(promptText);
  }

  @override
  bool onClick(
    ToolHost host,
    Vec2 point,
    SnapResult snap,
    PointerDownEvent event,
  ) {
    final hit = host.picker.pickTopmost(
      host.document,
      host.viewport,
      point,
      filter: filter,
    );
    if (hit == null) return true;
    lastClick = point;
    if (single) {
      complete(host, [hit.entityId]);
      return true;
    }
    if (!_picked.remove(hit.entityId)) _picked.add(hit.entityId);
    host.prompt(promptText);
    return true;
  }

  @override
  void onDragStart(ToolHost host, Vec2 point, SnapResult snap) {
    _windowStart = point;
    _windowEnd = point;
  }

  @override
  void onDragUpdate(ToolHost host, Vec2 point, SnapResult snap) {
    _windowEnd = point;
  }

  @override
  void onDragEnd(ToolHost host, Vec2 point, SnapResult snap) {
    final start = _windowStart;
    _windowStart = null;
    _windowEnd = null;
    if (start == null) return;
    // Dragging right selects only what is wholly enclosed, dragging left
    // catches anything it touches. That convention is muscle memory for anyone
    // who has used a CAD package.
    final found = host.picker.pickWindow(
      host.document,
      host.viewport,
      Bounds2.fromCorners(start, point),
      crossing: point.x < start.x,
      filter: filter,
    );
    for (final id in found) {
      if (!_picked.contains(id)) _picked.add(id);
    }
    if (single && _picked.isNotEmpty) {
      complete(host, [_picked.first]);
      return;
    }
    host.prompt(promptText);
  }

  @override
  bool onKey(ToolHost host, LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      complete(host, List.of(_picked));
      return true;
    }
    if (key == LogicalKeyboardKey.keyA &&
        HardwareKeyboard.instance.isControlPressed) {
      _picked
        ..clear()
        ..addAll([
          for (final entity in host.document.activeEntities) entity.id,
        ]);
      host.prompt(promptText);
      return true;
    }
    return false;
  }

  @override
  bool get hasCancellableGesture => _windowStart != null;

  @override
  void onCancelGesture(ToolHost host) {
    _windowStart = null;
    _windowEnd = null;
  }

  @override
  List<int> buildHighlights(ToolHost host) => [
    ..._picked,
    if (_hovered != null && !_picked.contains(_hovered)) _hovered!,
  ];

  @override
  List<OverlayShape> buildPreview(ToolHost host) {
    final start = _windowStart;
    final end = _windowEnd;
    if (start == null || end == null) return const [];
    return [OverlayRect(start, end, crossing: end.x < start.x)];
  }
}

/// Shows a command's preview and markers while a keyword or confirm waits.
///
/// Clicks stay on the canvas so the user can look at the proposed points; the
/// answer still comes from the command line (or a keyword chip).
class PreviewHoldTool extends CadTool {
  PreviewHoldTool({
    required this.message,
    this.preview,
    this.markers = const [],
  });

  final String message;
  final PreviewBuilder? preview;
  final List<Vec2> markers;
  Vec2? hover;

  @override
  String get id => 'prompt.preview';

  @override
  String get promptText => message;

  @override
  bool get wantsSnap => false;

  @override
  void onMove(ToolHost host, Vec2 point, SnapResult snap) {
    hover = point;
  }

  @override
  bool onClick(
    ToolHost host,
    Vec2 point,
    SnapResult snap,
    PointerDownEvent event,
  ) {
    return true;
  }

  @override
  List<Vec2> buildMarkers(ToolHost host) => markers;

  @override
  List<OverlayShape> buildPreview(ToolHost host) {
    final cursor = hover;
    final builder = preview;
    if (cursor == null || builder == null) return const [];
    return builder(cursor);
  }
}

/// Waits for two corners of a rectangular window.
class WindowPromptTool extends PromptTool<Bounds2> {
  WindowPromptTool({required super.message});

  Vec2? _first;

  @override
  String get id => 'prompt.window';

  @override
  Vec2? get basePoint => _first;

  @override
  bool onClick(
    ToolHost host,
    Vec2 point,
    SnapResult snap,
    PointerDownEvent event,
  ) {
    final first = _first;
    if (first == null) {
      _first = point;
      host.prompt('$message (opposite corner)');
      return true;
    }
    complete(host, Bounds2.fromCorners(first, point));
    return true;
  }

  @override
  bool get hasCancellableGesture => _first != null;

  @override
  void onCancelGesture(ToolHost host) {
    _first = null;
    host.prompt(message);
  }

  @override
  List<OverlayShape> buildPreview(ToolHost host) {
    final first = _first;
    final cursor = hover;
    if (first == null || cursor == null) return const [];
    return [OverlayRect(first, cursor)];
  }
}

List<Vec2> _viewportCorners(Bounds2 box) => [
  Vec2(box.minX, box.minY),
  Vec2(box.maxX, box.minY),
  Vec2(box.maxX, box.maxY),
  Vec2(box.minX, box.maxY),
];
