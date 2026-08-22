import '../geometry/vector.dart';
import '../model/document.dart';

/// The command a canvas double-click should run.
///
/// Inside a paper viewport that is VPMAX; on a maximized model view that is
/// VPMIN; everywhere else it is zoom extents.
({String id, Map<String, Object?> args}) canvasDoubleClick({
  required Layout layout,
  required Vec2 point,
  bool isMaximized = false,
}) {
  if (layout.isModelSpace) {
    return (
      id: isMaximized ? 'layout.vpmin' : 'view.zoomExtents',
      args: const {},
    );
  }
  final index = layout.viewportIndexAt(point.x, point.y);
  if (index == null) {
    return (id: 'view.zoomExtents', args: const {});
  }
  return (id: 'layout.vpmax', args: {'index': index});
}
