/// FanCAD command protocol: declarations, parameters, registry and host ports.
///
/// This package sits above `fancad_core`. It owns no CAD geometry or document
/// state; it only decides how an action is declared, resolved, run and exposed
/// to the command line, plugins and AI tools.
library;

export 'package:fancad_core/fancad_core.dart' show CommandCancelled;

export 'src/args_input.dart';
export 'src/command.dart';
export 'src/disposable.dart';
export 'src/param.dart';
export 'src/registry.dart';
