import 'package:fancad_core/fancad_core.dart';

import 'drawing.dart';

/// Emits [entity] into a collecting sink.
PolylineSink emit(
  CadEntity entity, {
  CadDocument? document,
  double tolerance = 0.1,
}) {
  final host = document ?? drawingOf(entity);
  final sink = PolylineSink();
  entity.emit(host.emitContext(tolerance: tolerance), sink);
  return sink;
}
