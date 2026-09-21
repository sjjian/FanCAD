import 'package:fancad_ai/fancad_ai.dart';

import 'document_tab.dart';
import 'workspace.dart';

/// Collects [drawing], or the front tab, into a [SessionSnapshot].
///
/// The assistant may be bound to a pinned drawing that is not on screen.
/// Do not bring that tab forward just to describe it.
SessionSnapshot collectSessionSnapshot(
  Workspace workspace, {
  DocumentTab? drawing,
}) {
  final tab = drawing ?? workspace.active;
  final document = tab?.document;
  final ids = tab?.selection.ids.toList() ?? const <int>[];
  final listed = <SelectedObjectHint>[];
  if (document != null) {
    for (final id in ids.take(SessionSnapshot.maxListed)) {
      final entity = document.entity(id);
      if (entity == null) continue;
      final box = document.boundsOfEntity(entity);
      listed.add(
        SelectedObjectHint(
          id: id,
          kind: entity.kind.name,
          layer: entity.props.layer,
          bounds: box.isEmpty ? null : [box.minX, box.minY, box.maxX, box.maxY],
        ),
      );
    }
  }

  ViewportHint? viewport;
  if (tab != null) {
    final view = tab.viewport.viewport;
    final box = view.visibleBounds;
    viewport = ViewportHint(
      centerX: view.center.x,
      centerY: view.center.y,
      scale: view.scale,
      visible: box.isEmpty ? null : [box.minX, box.minY, box.maxX, box.maxY],
    );
  }

  final snap = workspace.snapEngine;
  final modes = [for (final mode in snap.modes) mode.name]..sort();
  final prompt = workspace.commandLine.pending?.message;
  return SessionSnapshot(
    drawingId: tab?.session.id,
    drawingTitle: tab?.title,
    drawingPath: tab?.filePath,
    selectionCount: ids.length,
    selection: listed,
    viewport: viewport,
    snapEnabled: snap.enabled,
    snapModes: modes,
    ortho: snap.tracking.ortho,
    polar: snap.tracking.polar,
    showGrid: tab?.showGrid ?? true,
    runningCommand: workspace.runningCommand,
    prompt: prompt,
    collectedPointCount: workspace.collectedPointCount,
    lastCreatedIds: [
      ...workspace.lastCreatedIds.take(SessionSnapshot.maxResultIds),
    ],
    lastModifiedIds: [
      ...workspace.lastModifiedIds.take(SessionSnapshot.maxResultIds),
    ],
  );
}
