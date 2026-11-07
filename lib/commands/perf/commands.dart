import 'package:fancad_command/fancad_command.dart';

import 'reset.dart';
import 'session.dart';

/// Renderer diagnostics, kept apart from the drawing commands.
///
/// These commands answer "how expensive was the last frame", not "what is in
/// the drawing". They are marked [AiExposure.hidden] so the drafting assistant
/// never sees them; operators reach them through the MCP `perf` tool.
class PerfCommands {
  const PerfCommands._();

  static List<CommandDescriptor> all() => [
    PerfSessionCommand().toDescriptor(),
    PerfResetCommand().toDescriptor(),
  ];
}
