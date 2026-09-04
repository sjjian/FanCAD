/// Internals of `fancad_render` for package tests.
///
/// The application imports `package:fancad_render/fancad_render.dart`. Tests
/// that build scenes, inspect batches or paint overlays import this library.
library;

export 'fancad_render.dart';
export 'src/batch.dart';
export 'src/batching_sink.dart';
export 'src/device_space.dart';
export 'src/drawing_font.dart';
export 'src/line_aligner.dart';
export 'src/overlay.dart';
export 'src/picture_cache.dart';
export 'src/picking.dart';
export 'src/render_scene.dart';
export 'src/scene_builder.dart';
export 'src/scene_painter.dart';
export 'src/tessellation_cache.dart';
export 'src/text_cache.dart';
