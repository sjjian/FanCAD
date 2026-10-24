/// The view-tree catalog lives in `fancad_widget`.
///
/// This export keeps the plugin host on the schema library, which does not
/// import Flutter, so a worker isolate can validate a tree without the
/// renderer.
library;

export 'package:fancad_widget/schema.dart';
