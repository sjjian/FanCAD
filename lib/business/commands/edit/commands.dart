import 'package:fancad_core/fancad_core.dart';

import 'align.dart';
import 'array.dart';
import 'attedit.dart';
import 'block.dart';
import 'break_entity.dart';
import 'chamfer.dart';
import 'change_color.dart';
import 'change_layer.dart';
import 'change_linetype.dart';
import 'change_lineweight.dart';
import 'close.dart';
import 'copy.dart';
import 'dim_tedit.dart';
import 'dimension_text.dart';
import 'erase.dart';
import 'explode.dart';
import 'fillet.dart';
import 'hatch.dart';
import 'insert.dart';
import 'join.dart';
import 'justify_text.dart';
import 'lengthen.dart';
import 'match_prop.dart';
import 'minsert.dart';
import 'mirror.dart';
import 'move.dart';
import 'offset.dart';
import 'open_polyline.dart';
import 'overkill.dart';
import 'polar_array.dart';
import 'polyline_width.dart';
import 'purge.dart';
import 'rename.dart';
import 'reverse.dart';
import 'rotate.dart';
import 'scale.dart';
import 'stretch.dart';
import 'text_content.dart';
import 'to_polyline.dart';
import 'trim.dart';
import 'undo.dart';

/// The editing commands.
///
/// The transform family (move, rotate, scale, mirror, array) all reduce to
/// "collect points, build a matrix, apply it to a selection", so they share
/// [editTransform] and differ only in the matrix they produce. Copy is the same
/// idea but keeps asking for destinations from one base so one undo covers
/// every placement.
class EditCommands {
  const EditCommands._();

  static List<CommandDescriptor> all() => [
    EditEraseCommand().toDescriptor(),
    EditOverkillCommand().toDescriptor(),
    EditMoveCommand().toDescriptor(),
    EditCopyCommand().toDescriptor(),
    EditStretchCommand().toDescriptor(),
    EditRotateCommand().toDescriptor(),
    EditScaleCommand().toDescriptor(),
    EditMirrorCommand().toDescriptor(),
    EditAlignCommand().toDescriptor(),
    EditArrayCommand().toDescriptor(),
    EditPolarArrayCommand().toDescriptor(),
    EditOffsetCommand().toDescriptor(),
    EditTrimCommand().toDescriptor(),
    EditExtendCommand().toDescriptor(),
    EditFilletCommand().toDescriptor(),
    EditChamferCommand().toDescriptor(),
    EditBreakCommand().toDescriptor(),
    EditLengthenCommand().toDescriptor(),
    EditExplodeCommand().toDescriptor(),
    EditBlockCommand().toDescriptor(),
    EditInsertCommand().toDescriptor(),
    EditMinsertCommand().toDescriptor(),
    BlockPurgeCommand().toDescriptor(),
    BlockRenameCommand().toDescriptor(),
    EditJoinCommand().toDescriptor(),
    EditCloseCommand().toDescriptor(),
    EditOpenCommand().toDescriptor(),
    EditToPolylineCommand().toDescriptor(),
    EditPolylineWidthCommand().toDescriptor(),
    EditHatchCommand().toDescriptor(),
    EditReverseCommand().toDescriptor(),
    EditUndoCommand().toDescriptor(),
    EditRedoCommand().toDescriptor(),
    EditChangeLayerCommand().toDescriptor(),
    EditChangeColorCommand().toDescriptor(),
    EditChangeLinetypeCommand().toDescriptor(),
    EditChangeLineweightCommand().toDescriptor(),
    EditDimensionTextCommand().toDescriptor(),
    EditDimTeditCommand().toDescriptor(),
    EditTextContentCommand().toDescriptor(),
    EditAtteditCommand().toDescriptor(),
    EditJustifyTextCommand().toDescriptor(),
    EditMatchPropCommand().toDescriptor(),
  ];
}
