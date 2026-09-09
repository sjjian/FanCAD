import 'package:fancad_core/fancad_core.dart';

import 'angle.dart';
import 'area.dart';
import 'distance.dart';
import 'entities.dart';
import 'id.dart';
import 'layers.dart';
import 'list.dart';
import 'selection.dart';
import 'summary.dart';
import 'viewport.dart';

/// Read-only commands that answer questions about the drawing.
///
/// These matter out of proportion to their size, because they are what the AI
/// layer uses instead of being handed the whole drawing. A model that can ask
/// "how many objects are on layer WALLS and where are they" does not need a
/// megabyte of geometry in its context window to answer a question about it.
class QueryCommands {
  const QueryCommands._();

  static List<CommandDescriptor> all() => [
    QuerySummaryCommand().toDescriptor(),
    QueryListCommand().toDescriptor(),
    QueryEntitiesCommand().toDescriptor(),
    QuerySelectionCommand().toDescriptor(),
    QueryViewportCommand().toDescriptor(),
    QueryIdCommand().toDescriptor(),
    QueryDistanceCommand().toDescriptor(),
    QueryAngleCommand().toDescriptor(),
    QueryAreaCommand().toDescriptor(),
    QueryLayersCommand().toDescriptor(),
  ];
}
