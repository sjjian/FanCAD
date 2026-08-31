/// The FanCAD viewport and its interaction layer.
///
/// The render pipeline is: cull with the spatial index, tessellate at a
/// tolerance matched to the zoom, merge everything into one batch per colour and
/// line weight, and paint the batches with `drawRawPoints`. A drawing with a
/// quarter of a million entities becomes a couple of dozen draw calls.
///
/// On top of that sits the interaction layer: a snap engine that turns a cursor
/// position into the point the user meant, and a tool state machine that every
/// interactive command is written against.
library;

export 'src/drawing_font.dart';
export 'src/batch.dart'
    show BatchKey, FillBatch, ImageItem, LineBatch, PointBatch, TextItem;
export 'src/cad_canvas.dart';
export 'src/dynamic_input.dart';
export 'src/overlay.dart';
export 'src/palette.dart';
export 'src/picking.dart';
export 'src/scene.dart';
export 'src/scene_painter.dart';
export 'src/select_tool.dart';
export 'src/snap.dart';
export 'src/tessellation_cache.dart'
    show CachedPrimitive, PrimitiveKind, RecordingSink, TessellationCache;
export 'src/text_cache.dart';
export 'src/tool.dart';
export 'src/viewport.dart';
export 'src/viewport_controller.dart';
