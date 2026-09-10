import '../geometry/vector.dart';
import '../model/document.dart';

/// The command a canvas double-click should run, or null to leave the view.
///
/// Inside a paper viewport that is VPMAX; on a maximized model view that is
/// VPMIN. Empty space does not zoom — that is too easy to hit by accident.
({String id, Map<String, Object?> args})? canvasDoubleClick({
  required Layout layout,
  required Vec2 point,
  bool isMaximized = false,
}) {
  if (layout.isModelSpace) {
    if (!isMaximized) return null;
    return (id: 'layout.vpmin', args: const {});
  }
  final index = layout.viewportIndexAt(point.x, point.y);
  if (index == null) return null;
  return (id: 'layout.vpmax', args: {'index': index});
}
