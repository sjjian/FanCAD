/// The FanCAD kernel: geometry, document model, transactions and the command
/// registry.
///
/// This package is pure Dart with no Flutter dependency, so it runs on
/// background isolates (file import, geometry generation) and under plain
/// `dart test`.
library;

export 'src/annotation/dimension.dart';
export 'src/clipboard/clip.dart';
export 'src/command/args_input.dart';
export 'src/command/command.dart';
export 'src/command/disposable.dart';
export 'src/command/param.dart';
export 'src/command/registry.dart';
export 'src/geometry/boundary.dart';
export 'src/geometry/bounds.dart';
export 'src/geometry/construct.dart';
export 'src/geometry/flatten.dart';
export 'src/geometry/intersect.dart';
export 'src/geometry/matrix.dart';
export 'src/geometry/vector.dart';
export 'src/hatch/generator.dart';
export 'src/hatch/pattern.dart';
export 'src/layout/double_click.dart';
export 'src/layout/paper_viewport.dart';
export 'src/model/document.dart';
export 'src/model/entity.dart';
export 'src/model/geometry_sink.dart';
export 'src/model/preview.dart';
export 'src/model/spatial_index.dart';
export 'src/model/style.dart';
export 'src/model/units.dart';
export 'src/print/plotter.dart';
export 'src/session/selection.dart';
export 'src/session/session.dart';
export 'src/text/mtext_layout.dart';
export 'src/text/shx_font.dart';
export 'src/txn/patch.dart';
export 'src/txn/transaction.dart';
export 'src/xref/resolver.dart';
