import 'package:fancad_core/fancad_core.dart';

import 'isolate.dart';
import 'layer_delete.dart';
import 'layer_isolate.dart';
import 'layer_new.dart';
import 'layer_purge.dart';
import 'layer_set_current.dart';
import 'layer_show_all.dart';
import 'layer_toggle_lock.dart';
import 'layer_toggle_visible.dart';
import 'preferences.dart';
import 'regen.dart';
import 'select_all.dart';
import 'select_by_block.dart';
import 'select_by_color.dart';
import 'select_by_layer.dart';
import 'select_by_linetype.dart';
import 'select_by_lineweight.dart';
import 'select_by_type.dart';
import 'select_invert.dart';
import 'select_similar.dart';
import 'unisolate.dart';
import 'units.dart';
import 'zoom.dart';
import 'zoom_extents.dart';
import 'zoom_selected.dart';
import 'zoom_window.dart';

/// View, selection and layer commands.
///
/// These are the commands that change what you are looking at rather than what
/// is in the drawing, so none of them opens a transaction and none of them is
/// undoable — which is exactly the behaviour a user expects from ZOOM.
class ViewCommands {
  const ViewCommands._();

  static List<CommandDescriptor> all() => [
    WorkbenchPreferencesCommand().toDescriptor(),
    ViewZoomExtentsCommand().toDescriptor(),
    ViewZoomWindowCommand().toDescriptor(),
    ViewZoomInCommand().toDescriptor(),
    ViewZoomOutCommand().toDescriptor(),
    ViewZoomSelectedCommand().toDescriptor(),
    ViewRegenCommand().toDescriptor(),
    ViewUnitsCommand().toDescriptor(),
    SelectAllCommand().toDescriptor(),
    SelectNoneCommand().toDescriptor(),
    SelectInvertCommand().toDescriptor(),
    SelectSimilarCommand().toDescriptor(),
    SelectByLayerCommand().toDescriptor(),
    SelectByColorCommand().toDescriptor(),
    SelectByLinetypeCommand().toDescriptor(),
    SelectByLineweightCommand().toDescriptor(),
    SelectByTypeCommand().toDescriptor(),
    SelectByBlockCommand().toDescriptor(),
    ViewIsolateObjectsCommand().toDescriptor(),
    ViewHideObjectsCommand().toDescriptor(),
    ViewUnisolateObjectsCommand().toDescriptor(),
    LayerNewCommand().toDescriptor(),
    LayerSetCurrentCommand().toDescriptor(),
    LayerToggleVisibleCommand().toDescriptor(),
    LayerIsolateCommand().toDescriptor(),
    LayerShowAllCommand().toDescriptor(),
    LayerToggleLockCommand().toDescriptor(),
    LayerDeleteCommand().toDescriptor(),
    LayerPurgeCommand().toDescriptor(),
  ];
}
