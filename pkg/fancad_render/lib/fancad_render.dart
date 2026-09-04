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
///
/// Pipeline types used only by tests live in `package:fancad_render/testing.dart`.
library;

export 'src/cad_canvas.dart';
export 'src/dynamic_input.dart';
export 'src/overlay.dart' show OverlayModel, OverlayTheme;
export 'src/palette.dart';
export 'src/picking.dart' show GripHit, LayoutSpace, PickHit, Picker;
export 'src/render_scene.dart' show RenderScene;
export 'src/select_tool.dart';
export 'src/snap.dart';
export 'src/tessellation_cache.dart' show TessellationCache;
export 'src/tool.dart';
export 'src/viewport.dart';
export 'src/viewport_controller.dart';
