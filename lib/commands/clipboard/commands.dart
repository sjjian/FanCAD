import 'package:fancad_core/fancad_core.dart';

import 'copy_base.dart';
import 'copy_clip.dart';
import 'paste_clip.dart';
import 'paste_orig.dart';

/// Clipboard copy / paste, the family that moves geometry between drawings.
///
/// Distinct from `edit.copy`, which only duplicates inside the active document.
/// The store is process-wide so Ctrl+C in one tab and Ctrl+V in another share
/// a clip without touching the OS clipboard.
class ClipboardCommands {
  const ClipboardCommands({required this.store});

  final DrawingClipboard store;

  List<CommandDescriptor> all() => [
    CopyClipCommand(store).toDescriptor(),
    CopyBaseCommand(store).toDescriptor(),
    CutClipCommand(store).toDescriptor(),
    PasteClipCommand(store).toDescriptor(),
    PasteOrigCommand(store).toDescriptor(),
    PasteBlockCommand(store).toDescriptor(),
  ];
}
